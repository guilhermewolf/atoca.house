# Command to initilize the cluster

## Initial install
```bash
curl -sLS https://get.k3sup.dev | sh
sudo cp k3sup-darwin-arm64 /usr/local/bin/k3sup

export NODE1=
export NODE2=
export NODE3=
export NODE4=
export SSH_KEY=

k3sup install --ip $NODE1 --user ubuntu --no-extras --context rpi-k8s --k3s-extra-args '--disable traefik' --k3s-version v1.30.2+k3s1 --ssh-key $SSH_KEY --cluster

k3sup join --ip $NODE2 --user ubuntu --server-user ubuntu --server-ip $NODE1 --server --no-extras  --k3s-version v1.30.2+k3s1 --k3s-extra-args '--disable traefik' --ssh-key $SSH_KEY


k3sup join --ip $NODE3 --server-ip $NODE1  --k3s-version v1.30.2+k3s1 --user ubuntu --ssh-key $SSH_KEY
k3sup join --ip $NODE4 --server-ip $NODE2  --k3s-version v1.30.2+k3s1 --user ubuntu --ssh-key $SSH_KEY
```

## ArgoCD
```bash
CONTEXT=$(kubectl config current-context)
if [[ $CONTEXT != *"rpi-k8s"* ]]; then echo -e "You are using $CONTEXT\nPlease switch to 'rpi-k8s' context";exit 1; fi

kubectl kustomize --enable-helm infra/argocd | kubectl apply -f -


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