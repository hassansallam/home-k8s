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

## Cluster components — Core (`make init`)

| Component | Chart Version | Source |
|-----------|--------------|--------|
| Kubernetes | `1.35.2` | [GitHub Releases](https://github.com/kubernetes/kubernetes/releases) |
| Talos | `v1.12.5` | [GitHub Releases](https://github.com/siderolabs/talos/releases) |
| Cilium | `1.19.1` | [Helm Chart](https://helm.cilium.io/) |
| ArgoCD | `v3.3.3` | [GitHub Releases](https://github.com/argoproj/argo-cd/releases) |
| MetalLB | `0.15.3` | [Helm Chart](https://metallb.github.io/metallb) |
| Cert-Manager | `v1.20.0` | [Helm Chart](https://charts.jetstack.io) |
| Gateway API | `v1.5.1` | [GitHub Releases](https://github.com/kubernetes-sigs/gateway-api/releases) |

## Cluster components — Observability

| Component | Chart Version | Source |
|-----------|--------------|--------|
| Kube-Prometheus-Stack | `82.10.4` | [Helm Chart](https://prometheus-community.github.io/helm-charts) |
| Loki | `6.55.0` | [Helm Chart](https://grafana.github.io/helm-charts) |
| Promtail | `6.17.1` | [Helm Chart](https://grafana.github.io/helm-charts) |
| metrics-server | `3.13.0` | [Helm Chart](https://kubernetes-sigs.github.io/metrics-server) |
| Event Exporter | `3.6.3` | [Helm Chart](https://charts.bitnami.com/bitnami) |
| Node Problem Detector | `2.3.14` | [Helm Chart](https://charts.deliveryhero.io) |

## Cluster components — Security

| Component | Chart Version | Source |
|-----------|--------------|--------|
| Falco | `8.0.1` | [Helm Chart](https://falcosecurity.github.io/charts) |
| Trivy Operator | `0.32.1` | [Helm Chart](https://aquasecurity.github.io/helm-charts) |
| Kyverno | `3.7.1` | [Helm Chart](https://kyverno.github.io/kyverno) |
| Cilium Network Policies | N/A | Raw manifests in `k8s/cilium-policies/` |

## Cluster components — Operations

| Component | Chart Version | Source |
|-----------|--------------|--------|
| External Secrets Operator | `2.1.0` | [Helm Chart](https://charts.external-secrets.io) |
| Reloader | `2.2.9` | [Helm Chart](https://stakater.github.io/stakater-charts) |
| Reflector | `10.0.20` | [Helm Chart](https://emberstack.github.io/helm-charts) |
| Velero | `12.0.0` | [Helm Chart](https://vmware-tanzu.github.io/helm-charts) |
| Descheduler | `0.35.1` | [Helm Chart](https://kubernetes-sigs.github.io/descheduler) |

## Cluster components — Right-sizing & UI

| Component | Chart Version | Source |
|-----------|--------------|--------|
| VPA | `4.10.2` | [Helm Chart](https://charts.fairwinds.com/stable) |
| Goldilocks | `10.3.0` | [Helm Chart](https://charts.fairwinds.com/stable) |
| Headlamp (K8s Dashboard) | `0.40.1` | [Helm Chart](https://kubernetes-sigs.github.io/headlamp) |

## Disabled components

| Component | Chart Version | Reason |
|-----------|--------------|--------|
| Longhorn | `1.11.0` | Requires Talos `iscsi-tools` system extension |

## Version locations

All ArgoCD-managed apps have their chart version in `k8s/argocd/apps/<app>.yaml` (targetRevision field) and values in `k8s/<app>/values.yaml`.

| Component | Files |
|-----------|-------|
| libvirt, QEMU, Helm, kubectl, Ansible, jq | System packages via `scripts/prerequisites.sh` |
| OpenTofu, yq | AUR packages via `scripts/prerequisites.sh` |
| talosctl, cilium-cli | GitHub binaries via `scripts/prerequisites.sh` |
| Kubernetes, Talos | `tofu/terraform.tfvars`, `ansible/group_vars/all.yml` |
| ArgoCD | `ansible/group_vars/all.yml` (install version) |
| All other apps | `k8s/argocd/apps/<app>.yaml` (Helm chart version) |

Host tool versions are kept latest via `make prereqs`. Cluster component versions are in ArgoCD app manifests.

## Notes

- HAProxy version is determined by the Alpine package repository at deploy time
- ArgoCD v3.x requires `kubectl apply --server-side --force-conflicts` due to CRD size exceeding annotation limits
- HAProxy 3.0+ dropped support for inline `option httpchk` syntax — use `option tcp-check` or `http-check send`
- Talos image includes the `qemu-guest-agent` system extension — VMs must have a virtio serial channel configured
- Falco uses `modern_ebpf` driver (no kernel modules — compatible with Talos)
- Kyverno policies are in `audit` mode by default to avoid breaking system pods
- VPA runs in recommend-only mode (no automatic pod resizing)
- Velero needs a storage backend configured separately (placeholder config)
