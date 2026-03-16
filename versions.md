# Component Versions

All managed component versions and their official sources.

## Host prerequisites (`make prereqs`)

| Component | Version | Source |
|-----------|---------|--------|
| libvirt | `12.1.0` | [Arch package](https://archlinux.org/packages/extra/x86_64/libvirt/) |
| QEMU | `10.2.1` | [Arch package](https://archlinux.org/packages/extra/x86_64/qemu-full/) |
| Helm | `v4.1.1` | [Arch package](https://archlinux.org/packages/extra/x86_64/helm/) |
| kubectl | `v1.35.2` | [Arch package](https://archlinux.org/packages/extra/x86_64/kubectl/) |
| Ansible (core) | `2.20.3` | [Arch package](https://archlinux.org/packages/extra/any/ansible/) |
| jq | `1.8.1` | [Arch package](https://archlinux.org/packages/extra/x86_64/jq/) |
| OpenTofu | `v1.11.5` | [AUR](https://aur.archlinux.org/packages/opentofu-bin) |
| yq | `v4.52.4` | [AUR](https://aur.archlinux.org/packages/go-yq) |
| talosctl | `v1.12.5` | [GitHub Releases](https://github.com/siderolabs/talos/releases) |
| cilium-cli | `v0.19.2` | [GitHub Releases](https://github.com/cilium/cilium-cli/releases) |

## VM components

| Component | Version | Source |
|-----------|---------|--------|
| Alpine Linux (HAProxy VM) | `3.21.3` | [Alpine Cloud Images](https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/) |
| HAProxy | `3.0.18` | Alpine apk (installed via cloud-init) |

## Cluster components (`make init`)

| Component | Version | Source |
|-----------|---------|--------|
| Kubernetes | `1.35.2` | [GitHub Releases](https://github.com/kubernetes/kubernetes/releases) |
| Talos | `v1.12.5` | [GitHub Releases](https://github.com/siderolabs/talos/releases) |
| Cilium | `1.19.1` | [Helm Chart](https://helm.cilium.io/) |
| ArgoCD | `v3.3.3` | [GitHub Releases](https://github.com/argoproj/argo-cd/releases) |
| MetalLB | `0.15.3` | [Helm Chart](https://metallb.github.io/metallb) |
| Cert-Manager | `v1.20.0` | [Helm Chart](https://charts.jetstack.io) |
| Longhorn | `1.11.0` | [Helm Chart](https://charts.longhorn.io) |
| Kube-Prometheus-Stack | `82.10.4` | [Helm Chart](https://prometheus-community.github.io/helm-charts) |
| Gateway API | `v1.5.1` | [GitHub Releases](https://github.com/kubernetes-sigs/gateway-api/releases) |

## Version locations

| Component | Files |
|-----------|-------|
| libvirt, QEMU, Helm, kubectl, Ansible, jq | System packages via `scripts/prerequisites.sh` |
| OpenTofu, yq | AUR packages via `scripts/prerequisites.sh` |
| talosctl, cilium-cli | GitHub binaries via `scripts/prerequisites.sh` |
| Kubernetes | `ansible/group_vars/all.yml` |
| Talos | `tofu/terraform.tfvars`, `ansible/group_vars/all.yml` |
| Cilium | `ansible/group_vars/all.yml`, `k8s/argocd/apps/cilium.yaml` |
| ArgoCD | `ansible/group_vars/all.yml`, `k8s/argocd/install/kustomization.yaml` |
| MetalLB | `k8s/argocd/apps/metallb.yaml` |
| Cert-Manager | `k8s/argocd/apps/cert-manager.yaml` |
| Longhorn | `k8s/argocd/apps/longhorn.yaml` |
| Kube-Prometheus-Stack | `k8s/argocd/apps/kube-prometheus.yaml` |
| Gateway API | `k8s/argocd/apps/gateway-api.yaml` |

Host tool versions are kept latest via `make prereqs`. Cluster component versions are managed interactively via `make init` (Phase 1).

## Notes

- HAProxy version is determined by the Alpine package repository at deploy time
- ArgoCD v3.x requires `kubectl apply --server-side --force-conflicts` due to CRD size exceeding annotation limits
- HAProxy 3.0+ dropped support for inline `option httpchk` syntax — use `option tcp-check` or `http-check send`
- Talos image includes the `qemu-guest-agent` system extension — VMs must have a virtio serial channel configured
