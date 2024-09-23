<div align="center">

<img src="./docs/assets/raspbernetes.png" alt="Raspbernetes">

## A Toca - K8s

My _Personal_ Kubernetes GitOps Repository

_... managed with ArgoCD and GitHub Actions_

</div>


<div align="center">

[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=white&color=blue&label=%20)](https://k3s.io/)&nbsp;&nbsp;
</div>

<div align="center">

[![Age-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fcluster_age_days&style=flat-square&label=Age)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Uptime-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fcluster_uptime_days&style=flat-square&label=Uptime)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Node-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fcluster_node_count&style=flat-square&label=Nodes)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Pod-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fcluster_pod_count&style=flat-square&label=Pods)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![CPU-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fcluster_cpu_usage&style=flat-square&label=CPU)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Memory-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fcluster_memory_usage&style=flat-square&label=Memory)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
</div>

---

## 📖 Overview

This is a mono repository for my home infrastructure and Kubernetes cluster. I try to adhere to Infrastructure as Code (IaC) and GitOps practices using the tools like [Kubernetes](https://kubernetes.io/), [ArgoCD](https://argoproj.github.io/argo-cd/), [GitHub Actions](https://github.com/features/actions).

---

### Installation

My cluster is [k3s](https://k3s.io/) provisioned overtop bare-metal Ubuntu 22 using the [k3sup](https://github.com/alexellis/k3sup). This is a semi-hyper-converged cluster, workloads and block storage are sharing the same available resources on my nodes while I have a separate server for (NFS) file storage.

---

### Core Components

- [1Password Controler](https://github.com/1Password/onepassword-operator): Secrets storage using [1Password Connect](https://github.com/1Password/connect).
- [actions-runner-controller](https://github.com/actions/actions-runner-controller): self-hosted Github runners
- [ArgoCD](https://argoproj.github.io/argo-cd/): GitOps continuous delivery tool for Kubernetes
- [cert-manager](https://cert-manager.io/docs/): creates SSL certificates for services in my cluster
- [Cloudfrare-Controler](https://github.com/adyanth/cloudflare-operator): External tunnel for exposing services on my cluster to the internet
- [Cloud Native Postgres](https://cloudnative-pg.io/): Operator to deploy highly available PostgreSQL database cluster
- [external-dns](https://github.com/kubernetes-sigs/external-dns): automatically syncs DNS records from my cluster ingresses to a DNS provider
- [ingress-nginx](https://github.com/kubernetes/ingress-nginx/): ingress controller for Kubernetes using NGINX as a reverse proxy and load balancer
- [kured](https://kured.dev/): Kubernetes reboot daemon
- [MetalLB](https://metallb.universe.tf/): load balancer for bare metal Kubernetes clusters
- [Longhorn](https://longhorn.io/): distributed block storage for Kubernetes
- [Prometheus](https://prometheus.io/): monitoring and alerting toolkit
- [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets): encrypted secrets for Kubernetes

---

### Directories

This Git repository contains the following directories.

```sh
📁 .github         # Github workflows
📁 apps            # Apps deployed into my cluster grouped by namespace
📁 argocd          # ArgoCD Helm Chart and configuration
📁 docs            # Extra documentation and assets
📁 infra           # Core infrastructure configurations
└─📁 ansible       # Ansible playbooks
└─📁 helm          # Helm charts
└─📁 terraform     # Terraform configurations
📁 sets            # ArgoCD application sets
📁 stacks          # docker-compose files running on Asustor NAS
└─📁 media-stack   # Media management stack
📁 terraform       # terraform configuration for cloud resources
```

---

### Networking

| Name                  | CIDR              |
|-----------------------|-------------------|
| Server VLAN           | `192.168.178.0/24` |
| Kubernetes pods       | `10.42.0.0/16`    |
| Kubernetes services   | `10.43.0.0/16`    |

---

## ☁️ Cloud Dependencies

While most of my infrastructure and workloads are self-hosted I do rely upon the cloud for certain key parts of my setup. This saves me from having to worry about two things. (1) Dealing with chicken/egg scenarios and (2) services I critically need whether my cluster is online or not.

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

| Device                          | Count | OS Disk Size | Data Disk Size              | Ram  | Operating System | Purpose             |
|---------------------------------|-------|--------------|-----------------------------|------|------------------|---------------------|
| Raspberry Pi 4                  | 3     | 128GB (SD)   | -                           | 4GB  | Ubuntu 24.04     | K8s nodes           |
| Raspberry Pi 4                  | 1     | 128GB (SD)   | -                           | 8GB  | Ubuntu 24.04     | K8s node            |
| Raspberry PoE Hat               | 4     | -            | -                           | -    | -                | Power the Pi's      |
| TP-Link TL-SG108PE              | 1     | -            | -                           | -    | -                | Network PoE Switch  |
| Asustor AS5404T                 | 1     | 32GB (USB)   | 4x 1TB Nvme + 1x 2TB SSD    | 8GB  | Unraid 6.12.13   | NAS                 |

---
## 💪 TO-DO 

- [ ] Ansible playbook for deploying the cluster
- [x] Implement terraform for managing cloud resources

---

## 🤝 Gratitude and Thanks

Thanks to all the people who share their knowledge and experience on Github. I have learned a lot from reading blog posts and watching YouTube videos. I have tried to link to the sources of my inspiration where possible

- [k8s-at-home](https://github.com/topics/k8s-at-home)
- [Christian Lempa](https://www.youtube.com/@christianlempa)
- [pi-cluster](https://github.com/ricsanfre/pi-cluster)

---

## 📜 Changelog

See my _awful_ [commit history](https://github.com/guilhermewolf/atoca.house/commits/main)

---

## 🔏 License

See [LICENSE](./LICENSE)
