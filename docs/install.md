# Command to initilize the cluster

## Initial install
```bash
curl -sLS https://get.k3sup.dev | sh
sudo cp k3sup-darwin-arm64 /usr/local/bin/k3sup

NODE-1=
NODE-2=
NODE-3=
NODE-4=
k3sup install --ip $NODE-1 --user ubuntu --no-extras --context rpi-k8s --k3s-extra-args '--disable traefik' --ssh-key $ --cluster

k3sup join --ip $NODE-2 --user ubuntu --server-user ubuntu --server-ip $NODE-1 --server --no-extras --k3s-extra-args '--disable traefik' --ssh-key


k3sup join --ip $NODE-3 --server-ip $NODE-1 --user ubuntu --ssh-key 
k3sup join --ip $NODE-4 --server-ip $NODE-2 --user ubuntu --ssh-key 
```

## ArgoCD
```bash
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

