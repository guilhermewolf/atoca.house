# Command to initilize the cluster

## Initial install
```bash
mkdir -p $HOME/.config/age/
chmod 700 ~/.config/age/
op read op://K8s/age-key/age.key > $HOME/.config/age/age.key
chmod 600 ~/.config/age/age.key

sops --config .sops.yaml -d infra/talos/controlplante.enc.yaml > infra/talos/controlplante.yaml
sops --config .sops.yaml -d infra/talos/worker-1.enc.yaml > infra/talos/worker-1.yaml
sops --config .sops.yaml -d infra/talos/worker-2.enc.yaml > infra/talos/worker-2.yaml
sops --config .sops.yaml -d infra/talos/worker-3.enc.yaml > infra/talos/worker-3.yaml
sops --config .sops.yaml -d infra/talos/config.enc.yaml > $HOME/.talos/config

talosctl apply-config --insecure --nodes 192.168.178.201 --file infra/talos/controlplane.yaml
talosctl bootstrap -n 192.168.178.201
talosctl apply-config --insecure --nodes 192.168.178.202 --file infra/talos/worker-1.yaml
talosctl apply-config --insecure --nodes 192.168.178.203 --file infra/talos/worker-2.yaml
talosctl apply-config --insecure --nodes 192.168.178.204 --file infra/talos/worker-3.yaml

talosctl kubeconfig -n 192.168.178.201

rm infra/talos/controlplane.yaml infra/talos/worker-1.yaml infra/talos/worker-2.yaml infra/talos/worker-3.yaml

kubectl kustomize --enable-helm argocd | kubectl apply -f -
kubectl kustomize sets/ | kubectl apply -f -

ansible-playbook infra/ansible/one-password.yaml
```