#!/usr/bin/env bash

# Generate Talos configurations for 3-node control plane cluster
# This script automates the creation and encryption of Talos configs

set -euo pipefail

# Configuration
CLUSTER_NAME="atoca-k8s"
CLUSTER_ENDPOINT="https://192.168.178.201:6443"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN_DIR="${SCRIPT_DIR}/generated"
PATCHES_DIR="${SCRIPT_DIR}/patches"
TALOS_VERSION="${TALOS_VERSION:-v1.9.0}"

# Node configuration
declare -A NODES=(
  ["node-01"]="192.168.178.201"
  ["node-02"]="192.168.178.202"
  ["node-03"]="192.168.178.203"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
  log_info "Checking requirements..."

  local missing_tools=()

  if ! command -v talosctl &> /dev/null; then
    missing_tools+=("talosctl")
  fi

  if ! command -v sops &> /dev/null; then
    missing_tools+=("sops")
  fi

  if ! command -v yq &> /dev/null; then
    missing_tools+=("yq")
  fi

  if [ ${#missing_tools[@]} -gt 0 ]; then
    log_error "Missing required tools: ${missing_tools[*]}"
    echo ""
    echo "Install missing tools:"
    echo "  talosctl: curl -sL https://talos.dev/install | sh"
    echo "  sops: brew install sops (or from https://github.com/getsops/sops)"
    echo "  yq: brew install yq (or from https://github.com/mikefarah/yq)"
    exit 1
  fi

  log_info "All requirements satisfied"
}

generate_base_configs() {
  log_info "Generating base Talos configurations..."

  # Clean up old generated configs
  rm -rf "${GEN_DIR}"
  mkdir -p "${GEN_DIR}"

  # Generate base config with secrets
  talosctl gen config "${CLUSTER_NAME}" "${CLUSTER_ENDPOINT}" \
    --output-dir "${GEN_DIR}" \
    --with-secrets "${GEN_DIR}/secrets.yaml" \
    --force

  log_info "Base configurations generated"
}

apply_patches() {
  local node_name=$1
  local node_ip=$2
  local input_file=$3
  local output_file=$4

  log_info "Applying patches for ${node_name} (${node_ip})..."

  # Apply common control plane patch
  yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
    "${input_file}" \
    "${PATCHES_DIR}/controlplane-common.yaml" > "${output_file}.tmp"

  # Apply node-specific patch
  if [ -f "${PATCHES_DIR}/${node_name}.yaml" ]; then
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
      "${output_file}.tmp" \
      "${PATCHES_DIR}/${node_name}.yaml" > "${output_file}"
    rm "${output_file}.tmp"
  else
    mv "${output_file}.tmp" "${output_file}"
    log_warn "No node-specific patch found for ${node_name}"
  fi
}

generate_node_configs() {
  log_info "Generating node-specific configurations..."

  local base_cp="${GEN_DIR}/controlplane.yaml"

  if [ ! -f "${base_cp}" ]; then
    log_error "Base controlplane.yaml not found at ${base_cp}"
    exit 1
  fi

  # Generate config for each node
  for node_name in "${!NODES[@]}"; do
    local node_ip="${NODES[$node_name]}"
    local output_file="${GEN_DIR}/controlplane-${node_name}.yaml"

    apply_patches "${node_name}" "${node_ip}" "${base_cp}" "${output_file}"
    log_info "Generated config for ${node_name}"
  done
}

encrypt_configs() {
  log_info "Encrypting configurations with SOPS..."

  # Check if age key exists
  local age_key="${HOME}/.config/age/age.key"
  if [ ! -f "${age_key}" ]; then
    log_error "Age key not found at ${age_key}"
    log_error "Run: op read op://K8s/age-key/age.key > ${age_key}"
    exit 1
  fi

  export SOPS_AGE_KEY_FILE="${age_key}"

  # Encrypt each control plane config
  for node_name in "${!NODES[@]}"; do
    local input="${GEN_DIR}/controlplane-${node_name}.yaml"
    local output="${SCRIPT_DIR}/controlplane-${node_name}.enc.yaml"

    if [ -f "${input}" ]; then
      sops --encrypt --config "${SCRIPT_DIR}/../../.sops.yaml" "${input}" > "${output}"
      log_info "Encrypted ${node_name} config"
    else
      log_warn "Config not found for ${node_name}, skipping encryption"
    fi
  done

  # Encrypt talosconfig
  if [ -f "${GEN_DIR}/talosconfig" ]; then
    sops --encrypt --config "${SCRIPT_DIR}/../../.sops.yaml" \
      --input-type yaml --output-type yaml \
      "${GEN_DIR}/talosconfig" > "${SCRIPT_DIR}/config.enc.yaml"
    log_info "Encrypted talosconfig"
  fi

  # Backup secrets.yaml (do not commit this file!)
  if [ -f "${GEN_DIR}/secrets.yaml" ]; then
    local secrets_backup="${HOME}/.talos/atoca-secrets-$(date +%Y%m%d-%H%M%S).yaml"
    cp "${GEN_DIR}/secrets.yaml" "${secrets_backup}"
    log_warn "Cluster secrets backed up to: ${secrets_backup}"
    log_warn "Store this file securely and DO NOT commit to Git!"
  fi
}

cleanup() {
  log_info "Cleaning up temporary files..."

  # Remove generated directory (contains unencrypted configs)
  if [ -d "${GEN_DIR}" ]; then
    rm -rf "${GEN_DIR}"
    log_info "Removed ${GEN_DIR}"
  fi
}

show_summary() {
  echo ""
  echo "========================================"
  echo " Talos Configuration Generation Complete"
  echo "========================================"
  echo ""
  echo "Generated encrypted configs for:"
  for node_name in "${!NODES[@]}"; do
    echo "  - ${node_name} (${NODES[$node_name]})"
  done
  echo ""
  echo "Next steps:"
  echo "  1. Review the encrypted configs in infra/talos/"
  echo "  2. Commit the encrypted configs to Git"
  echo "  3. Boot all 3 nodes with Talos ISO"
  echo "  4. Run the bootstrap playbook:"
  echo "     cd infra/ansible && ansible-playbook bootstrap.yaml"
  echo ""
  echo "Backup reminder:"
  echo "  - Cluster secrets backed up to ~/.talos/"
  echo "  - Store securely and DO NOT commit to Git"
  echo ""
}

main() {
  echo "========================================"
  echo " Talos Configuration Generator"
  echo " Cluster: ${CLUSTER_NAME}"
  echo " Endpoint: ${CLUSTER_ENDPOINT}"
  echo "========================================"
  echo ""

  check_requirements
  generate_base_configs
  generate_node_configs
  encrypt_configs
  cleanup
  show_summary
}

# Run main function
main "$@"
