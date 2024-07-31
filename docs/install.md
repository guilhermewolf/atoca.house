# Command to initilize the cluster

## Initial install
```bash
curl -sLS https://get.k3sup.dev | sh
sudo cp k3sup-darwin-arm64 /usr/local/bin/k3sup

export GPU_NODE=
export NODE1=
export NODE2=
export NODE3=
export NODE4=
export SSH_KEY=

k3sup install --ip $GPU_NODE --user ubuntu --no-extras --context atoca-k8s --k3s-extra-args '--disable traefik  --embedded-registry' --k3s-version v1.30.2+k3s1 --ssh-key $SSH_KEY --cluster

k3sup join --ip $NODE1 --user ubuntu --server-user ubuntu --server-ip $GPU_NODE --server --no-extras  --k3s-version v1.30.2+k3s1 --k3s-extra-args '--disable traefik --embedded-registry' --ssh-key $SSH_KEY


k3sup join --ip $NODE2 --server-ip $GPU_NODE  --k3s-version v1.30.2+k3s1 --user ubuntu --ssh-key $SSH_KEY
k3sup join --ip $NODE3 --server-ip $NODE1  --k3s-version v1.30.2+k3s1 --user ubuntu --ssh-key $SSH_KEY
k3sup join --ip $NODE4 --server-ip $NODE1  --k3s-version v1.30.2+k3s1 --user ubuntu --ssh-key $SSH_KEY
```

## GPU_NODE

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg   && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |     sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |     sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt update
apt install -y nvidia-container-toolkit nvidia-container-runtime cuda-drivers-fabricmanager-550 nvidia-headless-550-server nvidia-utils-550-server
```

## ArgoCD
```bash
CONTEXT=$(kubectl config current-context)
if [[ $CONTEXT != *"atoca-k8s"* ]]; then echo -e "You are using $CONTEXT\nPlease switch to 'atoca-k8s' context";exit 1; fi

kubectl kustomize --enable-helm argocd | kubectl apply -f -


kubectl kustomize sets/ | kubectl apply -f -

```

### One password
Create a new connect server in 1password
```bash
echo -n "<token>"  | kubectl -n one-password create secret generic onepassword-token --dry-run=client --from-file=token=/dev/stdin -o yaml > onepassword-token-no-seal.yaml
kubeseal --controller-namespace=sealed-secrets -f onepassword-token-no-seal.yaml -w onepassword-token.yaml

mv 1password-credentials.json 1password-credentials.json.pre-encode
cat 1password-credentials.json.pre-encode | base64 | tr -d \\n > 1password-credentials.json
kubectl -n one-password create secret generic op-credentials --dry-run=client --from-file=1password-credentials.json=1password-credentials.json -o yaml > op-credentials-no-seal.yaml
kubeseal --controller-namespace=sealed-secrets -f op-credentials-no-seal.yaml -w op-credentials.yaml

cat onepassword-token.yaml | kubeseal --controller-namespace=sealed-secrets --validate
cat op-credentials.yaml| kubeseal --controller-namespace=sealed-secrets --validate

rm -rf 1password-credentials.json 1password-credentials.json.pre-encode onepassword-token-no-seal.yaml op-credentials-no-seal.yaml
```