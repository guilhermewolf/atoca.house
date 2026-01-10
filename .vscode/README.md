# VSCode Configuration

This directory contains VSCode workspace configuration optimized for Kubernetes/GitOps development.

## Files

### `settings.json`
Workspace settings including:
- **Editor**: FiraCode font with ligatures, bracket colorization, format on save
- **File Nesting**: Groups related files (e.g., `app.yaml` with `app.enc.yaml`)
- **YAML Language Server**: Schema validation for Kubernetes, ArgoCD, Taskfile
- **Icon Theme**: Material icons with custom associations for infra categories
- **Terminal**: Environment variables for KUBECONFIG and SOPS
- **Language Formatters**: Configured for YAML, JSON, Markdown, Shell, Terraform
- **Git**: Smart commit, autofetch, commit message validation
- **Ansible**: Python interpreter and validation

### `extensions.json`
Recommended VSCode extensions for this repository:
- Kubernetes Tools
- YAML Language Server
- SOPS encryption support
- Taskfile support
- GitLens & Git Graph
- Terraform & Ansible support
- Markdown tools

### `kubernetes.code-snippets`
Custom code snippets for faster development:
- **ArgoCD**: Application manifests, parent apps, Helm apps
- **Kubernetes**: Namespaces, ConfigMaps, Secrets, PVCs, HTTPRoutes
- **External Secrets**: 1Password integration
- **Helm**: Values file templates
- **Ansible**: Playbook templates
- **Taskfile**: Task definitions
- **Documentation**: README templates

## Quick Start

### 1. Install Recommended Extensions

When you open this workspace, VSCode will prompt you to install recommended extensions. Click **Install All** or:

```bash
# View recommendations
code --list-extensions

# Install all recommended
cat .vscode/extensions.json | jq -r '.recommendations[]' | xargs -L 1 code --install-extension
```

### 2. Configure Prerequisites

Some settings require external tools:

```bash
# Install tools via Taskfile
task workstation:brew   # Installs Homebrew packages
task workstation:krew   # Installs kubectl plugins

# Or manually
brew install kubectl helm talosctl sops age ansible terraform
```

### 3. Setup Secrets

Configure age encryption key for SOPS:

```bash
mkdir -p ~/.config/age
chmod 700 ~/.config/age
op read op://K8s/age-key/age.key > ~/.config/age/age.key
chmod 600 ~/.config/age/age.key
```

### 4. Use Code Snippets

Type a snippet prefix and press `Tab`:

| Prefix | Description |
|--------|-------------|
| `argo-app` | ArgoCD Application manifest |
| `argo-helm` | ArgoCD Application with Helm chart |
| `argo-parent` | ArgoCD parent app (discovers children) |
| `k8s-pvc` | Kubernetes PersistentVolumeClaim |
| `k8s-httproute` | Gateway API HTTPRoute |
| `external-secret` | External Secret from 1Password |
| `helm-values` | Helm values.yaml template |
| `task` | Taskfile task definition |
| `readme` | README template for apps |

## Features

### File Nesting

Related files are nested under their parent:

```
app/
├── application.yaml
│   ├── values.yaml          (nested)
│   └── secrets.yaml         (nested)
└── config.yaml
    └── config.enc.yaml      (nested)
```

This keeps the file explorer clean while showing related files together.

### Schema Validation

YAML files get automatic schema validation and autocomplete:

- **`application.yaml`** → ArgoCD Application schema
- **`kustomization.yaml`** → Kustomize schema
- **`Taskfile.yaml`** → Taskfile schema
- **`.github/workflows/*.yaml`** → GitHub Actions schema

Type to get autocomplete suggestions!

### Icon Theme

Folders and files have custom icons:

- 🔒 Encrypted files (`*.enc.yaml`, `*.sops.yaml`)
- ⚓ Kubernetes files (`application.yaml`, `kustomization.yaml`)
- 🎯 Taskfiles (`Taskfile.yaml`)
- 🔐 Security folders (`security/`, `sealed-secrets/`)
- 🌐 Networking folders (`networking/`, `cilium/`)
- 💾 Storage folders (`storage/`, `rook-ceph/`)
- 📊 Monitoring folders (`monitoring/`, `grafana/`)
- 🎬 Media folders (`media/`, `radarr/`, `sonarr/`)

### Format On Save

Files are automatically formatted on save:

- **YAML**: Consistent indentation, spacing
- **JSON**: Consistent formatting
- **Markdown**: Consistent list formatting
- **Shell**: Consistent shell script formatting
- **Terraform**: `terraform fmt` on save

### Git Integration

Enhanced git features:

- Commit message length validation (50 char subject, 72 char body)
- Auto-fetch from remote
- Smart commit (stage all changes with one click)
- GitLens inline blame and history

### Terminal Environment

Integrated terminal has environment variables pre-configured:

```bash
KUBECONFIG=~/kubeconfig
SOPS_AGE_KEY_FILE=~/.config/age/age.key
```

Open terminal and commands work immediately:
```bash
kubectl get pods
sops -d secret.enc.yaml
```

### Search Exclusions

Search excludes noise:
- Lock files (`*.lock`, `Brewfile.lock.json`)
- Generated files (`infra/talos/generated/`)
- Backup directories (`infra/talos/old-cluster-backup/`)
- Log files (`*.log`)

### Better Comments

Color-coded comments for better readability:

```yaml
# ! Important warning (red)
# ? Question or unclear section (blue)
# TODO Something to do later (orange)
# FIXME Bug that needs fixing (red, bold)
# NOTE Informational note (green)
```

## Customization

### Personal Settings

To override workspace settings without committing changes:

1. **File** → **Preferences** → **Settings**
2. Choose **User** tab (not Workspace)
3. Settings in User override Workspace

### Additional Extensions

Add to `.vscode/extensions.json`:

```json
{
  "recommendations": [
    "existing.extensions",
    "your.new.extension"
  ]
}
```

### Custom Snippets

Add to `.vscode/*.code-snippets`:

```json
{
  "Your Snippet Name": {
    "prefix": "trigger",
    "description": "Description",
    "body": [
      "snippet body",
      "$0"
    ]
  }
}
```

## Troubleshooting

### YAML Schema Not Working

1. Check YAML extension is installed: `YAML Language Support by Red Hat`
2. Reload window: `Ctrl+Shift+P` → `Reload Window`
3. Check file matches pattern in `settings.json` → `yaml.schemas`

### Icons Not Showing

1. Check icon theme: `Ctrl+Shift+P` → `Material Icons: Activate Icon Theme`
2. Reload window: `Ctrl+Shift+P` → `Reload Window`

### Format On Save Not Working

1. Check formatter is installed for the language
2. Check `settings.json` has formatter configured for language
3. Check file is not excluded in `files.exclude`

### Snippets Not Working

1. Start typing the prefix
2. Press `Tab` (not Enter)
3. If multiple matches, use arrow keys to select

### SOPS Extension Can't Decrypt

1. Check age key exists: `ls ~/.config/age/age.key`
2. Check permissions: `chmod 600 ~/.config/age/age.key`
3. Check `SOPS_AGE_KEY_FILE` in settings matches key location
4. Reload window

## Tips & Tricks

### Quick Actions

| Action | Shortcut |
|--------|----------|
| Command Palette | `Cmd+Shift+P` |
| Quick Open File | `Cmd+P` |
| Search in Files | `Cmd+Shift+F` |
| Toggle Terminal | `Ctrl+\`` |
| Format Document | `Cmd+Shift+I` |
| Rename Symbol | `F2` |
| Go to Definition | `F12` |

### Multi-Cursor Editing

1. Hold `Option` and click to add cursors
2. Or: `Cmd+Option+Up/Down` to add cursor above/below
3. Edit all cursors simultaneously

### Peek Definition

- `Option+F12` to peek definition without leaving file
- Useful for checking values in imported files

### Breadcrumbs

Top of editor shows file location:
```
infra > k8s > networking > cilium > application.yaml
```

Click any part to navigate the hierarchy.

### Zen Mode

`Cmd+K Z` to enter zen mode (distraction-free editing)

### Git Blame

GitLens shows inline blame:
```yaml
apiVersion: v1  # John Doe, 2 days ago
```

Click to see full commit details.

## Resources

- [VSCode Kubernetes Tools](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-kubernetes-tools)
- [YAML Language Server](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml)
- [Material Icon Theme](https://marketplace.visualstudio.com/items?itemName=PKief.material-icon-theme)
- [GitLens](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens)
- [VSCode Keyboard Shortcuts](https://code.visualstudio.com/shortcuts/keyboard-shortcuts-macos.pdf)
