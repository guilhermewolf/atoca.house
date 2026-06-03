#!/usr/bin/env -S just --justfile

set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

mod bootstrap "bootstrap"
mod kube "infra/k8s"
mod talos "infra/talos"

[private]
default:
    just -l

[doc('Validate all required CLI tools are installed on this machine')]
check-tools:
    #!/usr/bin/env bash
    set -uo pipefail

    if [[ -t 1 ]]; then
        red=$(tput setaf 1); grn=$(tput setaf 2); ylw=$(tput setaf 3)
        blu=$(tput setaf 4); bld=$(tput bold); rst=$(tput sgr0)
    else
        red=""; grn=""; ylw=""; blu=""; bld=""; rst=""
    fi

    miss_required=0
    miss_optional=0

    # name | binary | required(1/0) | purpose | install-hint
    tools=(
        "just|just|1|task runner (this file)|brew install just"
        "talosctl|talosctl|1|Talos Linux node management|brew install siderolabs/talos/talosctl"
        "kubectl|kubectl|1|Kubernetes CLI|brew install kubectl"
        "helm|helm|1|Helm (helmfile backend)|brew install helm"
        "helmfile|helmfile|1|bootstrap CRDs + apps|brew install helmfile"
        "yq|yq|1|YAML query (config/talos parsing)|brew install yq"
        "jq|jq|1|JSON query (schematic IDs)|brew install jq"
        "minijinja-cli|minijinja-cli|1|render Jinja2 templates|brew install minijinja-cli"
        "op|op|1|1Password CLI (secret injection)|brew install 1password-cli"
        "gum|gum|1|interactive prompts + logging|brew install gum"
        "curl|curl|1|download Talos images / API calls|preinstalled on macOS"
        "git|git|1|GitOps repo|brew install git"
        "tofu|tofu|0|OpenTofu (Cloudflare DNS/R2/Tunnel)|brew install opentofu"
        "krew|kubectl-krew|0|kubectl plugin manager|brew install krew"
        "browse-pvc|kubectl-browse_pvc|0|just kube browse-pvc|kubectl krew install browse-pvc"
        "view-secret|kubectl-view_secret|0|just kube view-secret|kubectl krew install view-secret"
    )

    printf "\n%s%sTool check — atoca.house cluster%s\n\n" "$bld" "$blu" "$rst"

    check_one() {
        local name="$1" bin="$2" req="$3" purpose="$4" hint="$5"
        if command -v "$bin" >/dev/null 2>&1; then
            ver="$("$bin" --version 2>/dev/null | head -n1 || true)"
            [[ -z "$ver" ]] && ver="$("$bin" version 2>/dev/null | head -n1 || true)"
            [[ -z "$ver" ]] && ver="installed"
            printf "  %s✓%s  %-14s %s\n" "$grn" "$rst" "$name" "${ver}"
        else
            if [[ "$req" == "1" ]]; then
                printf "  %s✗%s  %-14s %sMISSING (required)%s — %s\n" "$red" "$rst" "$name" "$red" "$rst" "$purpose"
                printf "       %s↳ install:%s %s\n" "$ylw" "$rst" "$hint"
                miss_required=$((miss_required+1))
            else
                printf "  %s○%s  %-14s %smissing (optional)%s — %s\n" "$ylw" "$rst" "$name" "$ylw" "$rst" "$purpose"
                printf "       %s↳ install:%s %s\n" "$ylw" "$rst" "$hint"
                miss_optional=$((miss_optional+1))
            fi
        fi
    }

    for row in "${tools[@]}"; do
        IFS="|" read -r name bin req purpose hint <<< "$row"
        check_one "$name" "$bin" "$req" "$purpose" "$hint"
    done

    printf "\n"
    if [[ "$miss_required" -gt 0 ]]; then
        printf "%s%s%d required tool(s) missing.%s Run %sjust install-tools%s to install them.\n\n" "$bld" "$red" "$miss_required" "$rst" "$bld" "$rst"
        exit 1
    fi
    if [[ "$miss_optional" -gt 0 ]]; then
        printf "%s%sAll required tools present%s (%d optional missing — %sjust install-tools%s installs them).\n\n" "$bld" "$grn" "$rst" "$miss_optional" "$bld" "$rst"
    else
        printf "%s%sAll tools present — you are ready to run the cluster.%s\n\n" "$bld" "$grn" "$rst"
    fi

[doc('Install any missing CLI tools via Homebrew + krew')]
install-tools:
    #!/usr/bin/env bash
    set -uo pipefail

    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew not found. Install it first: https://brew.sh"
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        exit 1
    fi

    # name | binary | install-hint
    tools=(
        "just|just|brew install just"
        "talosctl|talosctl|brew install siderolabs/talos/talosctl"
        "kubectl|kubectl|brew install kubectl"
        "helm|helm|brew install helm"
        "helmfile|helmfile|brew install helmfile"
        "yq|yq|brew install yq"
        "jq|jq|brew install jq"
        "minijinja-cli|minijinja-cli|brew install minijinja-cli"
        "op|op|brew install 1password-cli"
        "gum|gum|brew install gum"
        "git|git|brew install git"
        "tofu|tofu|brew install opentofu"
        "krew|kubectl-krew|brew install krew"
        "browse-pvc|kubectl-browse_pvc|kubectl krew install browse-pvc"
        "view-secret|kubectl-view_secret|kubectl krew install view-secret"
    )

    installed=0
    failed=0
    for row in "${tools[@]}"; do
        IFS="|" read -r name bin hint <<< "$row"
        if command -v "$bin" >/dev/null 2>&1; then
            echo "✓ $name already installed"
            continue
        fi
        echo "→ installing $name: $hint"
        if $hint; then
            installed=$((installed+1))
        else
            echo "✗ failed to install $name ($hint)"
            failed=$((failed+1))
        fi
    done

    echo ""
    echo "Installed $installed, failed $failed."
    [[ "$failed" -gt 0 ]] && exit 1 || just check-tools

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
template file *args:
    minijinja-cli "{{ file }}" {{ if env_var_or_default("IS_CONTROLLER", "") != "" { "-D IS_CONTROLLER=" + env_var("IS_CONTROLLER") } else { "" } }} {{ args }} | op inject
