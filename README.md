<div align="center">

<img src="./docs/assets/atoca-house.png" alt="AtocaHouse" width="250">

## A Toca - K8s

My _Personal_ Kubernetes GitOps Repository

_... managed with ArgoCD and GitHub Actions_

</div>

<div align="center">

[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fkubernetes_version&style=for-the-badge&logo=kubernetes&color=grey&label=%20)](https://k3s.io/)&nbsp;&nbsp;
[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Ftalos_version&style=for-the-badge&logo=talos&color=grey&label=%20)](https://talos.dev)&nbsp;&nbsp;
[![Unraid](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Funraid_version&style=for-the-badge&logo=unraid&color=grey&label=%20)](https://unraid.net/)&nbsp;&nbsp;
</div>

<div align="center">

[![Home-Internet](https://img.shields.io/endpoint?url=https%3A%2F%2Fstatus.atoca.house%2Fapi%2Fv1%2Fendpoints%2Fconnectivity_cloudflare%2Fhealth%2Fbadge.shields&style=for-the-badge&logo=ubiquiti&logoColor=white&label=Home%20Internet)](https://status.atoca.house)&nbsp;&nbsp;
[![Status-Page](https://img.shields.io/endpoint?url=https%3A%2F%2Fstatus.atoca.house%2Fapi%2Fv1%2Fendpoints%2Fconnectivity_google%2Fhealth%2Fbadge.shields&style=for-the-badge&logo=statuspage&logoColor=white&label=Status%20Page)](https://status.atoca.house)&nbsp;&nbsp;
[![Alertmanager](https://img.shields.io/endpoint?url=https%3A%2F%2Fstatus.atoca.house%2Fapi%2Fv1%2Fendpoints%2Finternal_alertmanager%2Fhealth%2Fbadge.shields&style=for-the-badge&logo=prometheus&logoColor=white&label=Alertmanager)](https://status.atoca.house)

</div>

<div align="center">

![Cluster](https://img.shields.io/badge/Cluster-grey?style=flat-square&logo=kubernetes)&nbsp;&nbsp;
[![Age-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fcluster_age_days&style=flat-square&label=Age)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Uptime-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fcluster_uptime_days&style=flat-square&label=Uptime)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Node-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fcluster_node_count&style=flat-square&label=Nodes)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Pod-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fcluster_pod_count&style=flat-square&label=Pods)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![CPU-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fcluster_cpu_usage&style=flat-square&label=CPU)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Memory-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fcluster_memory_usage&style=flat-square&label=Memory)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Alerts](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.atoca.house%2Fcluster_alert_count&style=flat-square&label=Alerts)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;

</div>

---

## 📖 Overview

This is a mono repository for my home infrastructure and Kubernetes cluster implementing GitOps practices using [Talos Linux](https://talos.dev/), [Kubernetes](https://kubernetes.io/), [ArgoCD](https://argoproj.github.io/argo-cd/), and [GitHub Actions](https://github.com/features/actions). The repository manages 60+ applications across a hyper-converged Kubernetes cluster with automated dependency updates via [Renovate](https://renovatebot.com/).

---

### Installation

My cluster is a 3-node high-availability setup running **Talos Linux** with **Kubernetes**. All three nodes function as control planes (no dedicated workers), providing both compute and distributed storage via Rook-Ceph. This hyper-converged architecture maximizes resource utilization across all nodes, with each node contributing:

- **Compute:** Kubernetes workload scheduling
- **Storage:** 1TB NVMe disk for Ceph distributed storage (block, filesystem, and object)
- **Control Plane:** etcd member and Kubernetes API server

The cluster uses **2-way replication** for storage, tolerating one node failure while maintaining data availability. Initial bootstrap is managed with [Helmfile](https://github.com/helmfile/helmfile) and [Just](https://github.com/casey/just), with ArgoCD taking over for ongoing GitOps management using an app-of-apps pattern.

---

### Core Components

**Networking & Ingress:** [Cilium](https://cilium.io/) provides eBPF-based networking with L2 announcements for LoadBalancer IPs. [Envoy Gateway](https://gateway.envoyproxy.io/) implements Gateway API, while [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) secures external access. [External-DNS](https://github.com/kubernetes-sigs/external-dns) syncs DNS records to Cloudflare, UniFi, and internal DNS. [Multus](https://github.com/k8snetworkplumbingwg/multus-cni) enables multi-network support with VLAN configurations.

**Security & Secrets:** [Cert-Manager](https://cert-manager.io/) automates SSL/TLS certificate management using Cloudflare DNS-01 challenges. [External Secrets Operator](https://external-secrets.io/) integrates with [1Password Connect](https://github.com/1Password/connect-helm-charts) to inject secrets from 1Password vaults into Kubernetes.

**Storage & Backup:** [Rook-Ceph](https://rook.io/) provides distributed storage with block (RBD), filesystem (CephFS), and object (S3) storage capabilities across the 3-node cluster. [Volsync](https://volsync.readthedocs.io/) handles automated backup/restore using Restic. [Spegel](https://github.com/spegel-org/spegel) runs a stateless cluster-local OCI image mirror.

**Data Management:** [Crunchy PostgreSQL Operator](https://github.com/CrunchyData/postgres-operator) manages HA PostgreSQL clusters with 3 replicas and dual backup repositories (MinIO local + Cloudflare R2). [Dragonfly Operator](https://github.com/dragonflydb/dragonfly-operator) provides a Redis-compatible in-memory datastore.

**Monitoring & Observability:** [Kube-Prometheus-Stack](https://github.com/prometheus-operator/kube-prometheus) delivers comprehensive monitoring with Prometheus, Alertmanager, and Grafana. [Victoria Logs](https://victoriametrics.com/products/victorialogs/) aggregates logs via [Fluent-Bit](https://fluentbit.io/). [Gatus](https://github.com/TwiN/gatus) provides uptime monitoring, [Headlamp](https://headlamp.dev/) offers a Kubernetes dashboard, and specialized exporters (Blackbox, Smartctl, Unpoller) monitor infrastructure. [KEDA](https://keda.sh/) enables event-driven autoscaling.

**Automation & CI/CD:** [Actions Runner Controller](https://github.com/actions/actions-runner-controller) runs self-hosted GitHub Actions runners in-cluster. [Renovate Bot](https://renovatebot.com/) automatically creates PRs for dependency updates with custom auto-merge rules.

**Cluster Utilities:** [Descheduler](https://github.com/kubernetes-sigs/descheduler) optimizes pod placement, [Reloader](https://github.com/stakater/Reloader) auto-restarts pods on config changes, and [Metrics Server](https://github.com/kubernetes-sigs/metrics-server) provides resource metrics. [AMD Device Plugin](https://github.com/ROCm/k8s-device-plugin) enables GPU workloads.

---

### Directories

This Git repository contains the following directories.

```sh
📁 .github              # GitHub workflows (Terraform, tagging, labels)
📁 .renovate            # Renovate configuration (auto-merge, grouping)
📁 apps                 # 60+ applications organized by category
  └─📁 media            # Media automation (Sonarr, Radarr, qBittorrent, etc.) - 13 apps
  └─📁 productivity     # Productivity tools (n8n, Vikunja, Twenty, etc.) - 10 apps
  └─📁 auth             # Authentication (Authelia, LLDAP) - 2 apps
  └─📁 communication    # Communication apps (TheLounge) - 1 app
  └─📁 monitoring       # Monitoring apps (Seerr, Whoami) - 2 apps
  └─📁 home-automation  # Smart home (Homebridge) - 1 app
  └─📁 data             # Database clusters (PostgreSQL, Dragonfly) - 2 apps
📁 argocd               # ArgoCD GitOps configuration
  └─📁 applications     # ApplicationSets for auto-discovery
  └─📁 install          # ArgoCD installation manifests
📁 bootstrap            # Initial cluster bootstrap with Helmfile
📁 docs                 # Documentation and assets
📁 infra                # Core infrastructure
  └─📁 k8s              # Kubernetes infrastructure by category
    └─📁 networking     # CNI, Gateway API, DNS (Cilium, Envoy, etc.) - 6 apps
    └─📁 storage        # Storage systems (Rook-Ceph, CSI, Volsync) - 5 apps
    └─📁 security       # Security (Cert-Manager, External Secrets) - 3 apps
    └─📁 monitoring     # Observability stack (Prometheus, Grafana, etc.) - 12 apps
    └─📁 cluster-management # Cluster utilities (Descheduler, Reloader) - 6 apps
    └─📁 operators      # Kubernetes operators (Postgres, GPU, etc.) - 6 apps
  └─📁 talos            # Talos Linux configurations (Jinja2 templates)
  └─📁 terraform        # OpenTofu/Terraform for Cloudflare (DNS, R2, Tunnel)
📁 stacks               # Docker Compose files for Unraid NAS
  └─📁 *                # Jellyfin, Lidarr, MinIO, Syncthing, etc.
```

---

### Networking

| Name                      | CIDR                |
|---------------------------|---------------------|
| Server VLAN               | `192.168.40.0/24`   |
| Kubernetes pods (Cilium)  | `10.244.0.0/16`     |
| Kubernetes services       | `10.96.0.0/12`      |
| Gateway LoadBalancer IP   | `192.168.60.10`     |

---

## ☁️ Cloud Dependencies

While most of my infrastructure and workloads are self-hosted, I rely on cloud services for critical functions that need to remain available regardless of cluster status.

| Service                                         | Use                                                               | Cost            |
|-------------------------------------------------|-------------------------------------------------------------------|-----------------|
| [1Password](https://1password.com/)             | Secrets management with 1Password Connect                         | ~$65/yr         |
| [Cloudflare](https://www.cloudflare.com/)       | Domain, DNS, R2 object storage, Zero Trust Tunnel                 | ~$30/yr         |
| [GitHub](https://github.com/)                   | Repository hosting, CI/CD workflows                               | Free            |
| [Tailscale](https://tailscale.com/)             | VPN service for secure remote access                              | Free            |
|                                                 |                                                                   |Total: ~$7.90/mo |

---

## 🔧 Hardware

| Device                          | Count | OS Disk Size | Data Disk Size   | RAM  | CPU              | Operating System | Purpose                    |
|---------------------------------|-------|--------------|------------------|------|------------------|------------------|----------------------------|
| Mini PC                         | 3     | 256GB NVMe   | 1TB NVMe         | 32GB | Ryzen 7 4800H    | Talos Linux      | K8s control plane nodes    |
| AI PC                           | 1     | 256GB NVMe   | 1TB NVMe         | 32GB | Ryzen 5 5600X    | Talos Linux      | K8s AI Node                |
| Asustor AS5404T                 | 1     | 32GB (USB)   | 4x 1TB + 4x 12TB | 32GB | Intel Celeron    | Unraid           | NAS (external storage)     |
| Unifi Cloud Gateway Max         | 1     | -            | -                | -    | -                | -                | Router                     |
| Unifi USW Enterprise 24 PoE     | 1     | -            | -                | -    | -                | -                | 2.5Gb PoE Switch           |

---

## 🤝 Gratitude and Thanks

Thanks to all the people who share their knowledge and experience on GitHub. I have learned a lot from the homelab and Kubernetes communities.

- [k8s-at-home](https://github.com/topics/k8s-at-home) - Community of homelabbers running Kubernetes
- [Christian Lempa](https://www.youtube.com/@christianlempa) - Excellent homelab content
- [pi-cluster](https://github.com/ricsanfre/pi-cluster) - Comprehensive homelab documentation
- [Techno Tim](https://www.youtube.com/@TechnoTim) - Homelab and infrastructure tutorials

---

## 📜 Changelog

See my _awful_ [commit history](https://github.com/guilhermewolf/atoca.house/commits/main)

---

## 🔏 License

See [LICENSE](./LICENSE)
