# atoca.house kubernetes cluster

Raspberry 4 + Ubuntu 22.04

### Before add SD card to Raspberry
in boot folder
```bash
touch ssh
```

Edit cmdline.txt and add:
```bash
cgroup_memory=1 cgroup_enable=memory
```

### After connecting to Raspberry
Configure SSH keys in all node

Update and install neded packages
```bash
apt update
apt upgrade -y
apt install linux-modules-extra-raspi -y 
reboot
```
> linux-modules-extra-raspi is needed  since version 21 of ubuntu, it moves out the Vxlan from the kernel

Set hostname
```bash
hostnamectl set-hostname rpi-k8s-4.atoca.house
```
Add static IP's
Create file /etc/netplan/01-network-manager-all.yaml
add:
```yaml
network:
    ethernets:
        eth0:
            dhcp4: false
            addresses: [192.168.178.XXX/24]
            gateway4: 192.168.178.1
            nameservers:
              addresses: [8.8.8.8,8.8.4.4]
    version: 2
```
Apply changes
```bash
netplan apply
```
### Deploy cluster

k3sup install --ip $IP --user ubuntu


```shell
k3sup install --ip 192.168.178.201  --user ubuntu --context rpi-k8s --cluster --no-extras

k3sup join --ip 192.168.178.202 --server-ip 192.168.178.201 --user ubuntu 

k3sup join --ip 192.168.178.203 --server-ip 192.168.178.201 --user ubuntu
```

### Setup 1Password

```bash
kubectl create namespace one-password
kubectl create secret generic onepassword-token --namespace=one-password --from-literal=token=<<ACCESS TOKEN>>
helm install --namespace one-password connect 1password/connect --set-file connect.credentials=1password-credentials.json  --set operator.create=true
```
Deployed this way because it's not working when i use kustomize + helm

## certmanager

```bash
helm install cert-manager jetstack/cert-manager --create-namespace --namespace cert-manager --set installCRDs=true
```
Deployed this way because it's not working when i use kustomize + helm

