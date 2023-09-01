<div align="center">

<img src="./docs/assets/raspbernetes.png" alt="Raspbernetes">

## A Toca - K8s

My _Personal_ Kubernetes GitOps Repository

_... managed with ArgoCD and GitHub Actions_

</div>

---

## 📖 Overview

This is a mono repository for my home infrastructure and Kubernetes cluster. I try to adhere to Infrastructure as Code (IaC) and GitOps practices using the tools like [Kubernetes](https://kubernetes.io/), [ArgoCD](https://argoproj.github.io/argo-cd/), [GitHub Actions](https://github.com/features/actions).

---

### Installation

My cluster is [k3s](https://k3s.io/) provisioned overtop bare-metal Ubuntu 22 using the [k3sup](https://github.com/alexellis/k3sup). This is a semi hyper-converged cluster, workloads and block storage are sharing the same available resources on my nodes while I have a separate server for (NFS) file storage.

---

### Core Components

- [actions-runner-controller](https://github.com/actions/actions-runner-controller): self-hosted Github runners
- [cert-manager](https://cert-manager.io/docs/): creates SSL certificates for services in my cluster
- [external-dns](https://github.com/kubernetes-sigs/external-dns): automatically syncs DNS records from my cluster ingresses to a DNS provider
- [1Password Controler](https://github.com/1Password/onepassword-operator): Secrets storage using [1Password Connect](https://github.com/1Password/connect).
- [ingress-nginx](https://github.com/kubernetes/ingress-nginx/): ingress controller for Kubernetes using NGINX as a reverse proxy and load balancer
- [ArgoCD](https://argoproj.github.io/argo-cd/): GitOps continuous delivery tool for Kubernetes
- [MetalLB](https://metallb.universe.tf/): load balancer for bare metal Kubernetes clusters
- [Longhorn](https://longhorn.io/): distributed block storage for Kubernetes
- [Prometheus](https://prometheus.io/): monitoring and alerting toolkit
- [Cloudfrare-Controler](https://github.com/adyanth/cloudflare-operator): External tunnel for exposing services on my cluster to the internet

---

### Directories

This Git repository contains the following directories.

```sh
📁 infra           # Kubernetes controlers grouped by namspaces
📁 apps            # Apps deployed into my cluster grouped by namespace
📁 docs            # Extra documentation and assets
📁 stacks          # docker-compose files running on Asustor NAS
└─📁 media-stack   # Media management stack
```

---

### Networking

| Name                  | CIDR              |
|-----------------------|-------------------|
| Server VLAN           | `192.168.178.0/24` |
| Kubernetes pods       | `10.32.0.0/16`    |
| Kubernetes services   | `10.33.0.0/16`    |

---

## ☁️ Cloud Dependencies

While most of my infrastructure and workloads are selfhosted I do rely upon the cloud for certain key parts of my setup. This saves me from having to worry about two things. (1) Dealing with chicken/egg scenarios and (2) services I critically need whether my cluster is online or not.

| Service                                         | Use                                                               | Cost           |
|-------------------------------------------------|-------------------------------------------------------------------|----------------|
| [1Password](https://1password.com/)             | Secrets with 1Password Connect and Controler                      | ~$65/yr        |
| [Cloudflare](https://www.cloudflare.com/)       | Domain and R2                                                     | ~$30/yr        |
| [GitHub](https://github.com/)                   | Hosting this repository and continuous integration/deployments    | Free           |
| [Terraform Cloud](https://www.terraform.io/)    | Storing Terraform state                                           | Free           |
| [Tailscale](https://tailscale.com/)             | VPN Serice                                                        | ~$48/yr        |
|                                                 |                                                                   |Total: ~$12/mo  |

---

## 🔧 Hardware

| Device                      | Count | OS Disk Size | Data Disk Size              | Ram  | Operating System | Purpose             |
|-----------------------------|-------|--------------|-----------------------------|------|------------------|---------------------|
| Raspberry Pi 4              | 3     | 128GB (SD)   | -                           | 4GB  | Ubuntu 22.04     | K8s nodes           |
| Raspberry Pi 4              | 1     | 128GB (SD)   | -                           | 8GB  | Ubuntu 22.04     | K8s node            |
| Raspberry PoE Hat           | 4     | -            | -                           | -    | -                | Power the Pi's      |
| TP-Link TL-SG108PE          | 1     | -            | -                           | -    | -                | Network PoE Switch  |
| Asustor AS6602T             | 1     | -            | 4x 1TB Nvme (RAID 5)        | 4GB  | ADM 4.0.0.RF53   | NAS                 |

---
## 💪 TO-DO 

- [ ] Ansible playbook for deploying the cluster
- [ ] Implement terraform for managing cloud resources

---

## 🤝 Gratitude and Thanks

Thanks to all people that share their knowledge and experience on Github. I have learned a lot from reading blog posts and watching YouTube videos. I have tried to link to the sources of my inspiration where possible

- [k8s-at-home](https://github.com/topics/k8s-at-home)
- [Christian Lempa](https://www.youtube.com/@christianlempa)
- [pi-cluster](https://github.com/ricsanfre/pi-cluster)

---

## 📜 Changelog

See my _awful_ [commit history](https://github.com/guilhermewolf/atoca.house/commits/main)

---

## 🔏 License

See [LICENSE](./LICENSE)
