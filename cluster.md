# Cluster Overview

## Network: 192.168.122.0/24 (libvirt NAT via `virbr-k8s`)

## Nodes

| VM Name | IP Address | Role | OS | Resources |
|---------|-----------|------|-----|-----------|
| k8s-haproxy | 192.168.122.100 | Load balancer (K8s API + Talos API) | Alpine 3.21 | 1 vCPU, 512 MiB |
| k8s-cp-1 | 192.168.122.101 | Control plane (etcd, apiserver, scheduler, controller) | Talos v1.12.5 | 2 vCPU, 6 GiB |
| k8s-cp-2 | 192.168.122.102 | Control plane | Talos v1.12.5 | 2 vCPU, 6 GiB |
| k8s-cp-3 | 192.168.122.103 | Control plane | Talos v1.12.5 | 2 vCPU, 6 GiB |
| k8s-worker-1 | 192.168.122.104 | Worker (runs workloads) | Talos v1.12.5 | 4 vCPU, 8 GiB |
| k8s-worker-2 | 192.168.122.105 | Worker | Talos v1.12.5 | 4 vCPU, 8 GiB |
| k8s-worker-3 | 192.168.122.106 | Worker | Talos v1.12.5 | 4 vCPU, 8 GiB |

## Infrastructure Services

| Service | IP / Port | Access URL | Notes |
|---------|----------|------------|-------|
| HAProxy Stats | 192.168.122.100:8404 | http://192.168.122.100:8404/stats | HAProxy dashboard |
| K8s API | 192.168.122.100:6443 | `kubectl --kubeconfig kubeconfig` | Via HAProxy → 3 CP nodes |
| Talos API | 192.168.122.100:50000 | `talosctl --talosconfig ansible/talos-generated/talosconfig` | Via HAProxy → 3 CP nodes |

## Cluster Apps (23 apps managed by ArgoCD)

### Core Infrastructure

| App | Namespace | Chart | Access |
|-----|-----------|-------|--------|
| Cilium (CNI) | kube-system | `1.19.1` | `cilium status` |
| MetalLB | metallb-system | `0.15.3` | N/A (L2 load balancer) |
| Cert-Manager | cert-manager | `v1.20.0` | N/A (certificate automation) |
| Gateway API CRDs | default | `v1.5.1` | N/A (API gateway CRDs) |

### Observability

| App | Namespace | Chart | Access |
|-----|-----------|-------|--------|
| Grafana (via kube-prometheus-stack) | monitoring | `82.10.4` | http://192.168.122.200 (LoadBalancer) |
| Prometheus | monitoring | `82.10.4` | `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090` |
| Alertmanager | monitoring | `82.10.4` | `kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093` |
| Loki | monitoring | `6.55.0` | Internal (log storage for Promtail) |
| Promtail | monitoring | `6.17.1` | N/A (log shipper DaemonSet) |
| metrics-server | kube-system | `3.13.0` | N/A (HPA/VPA metrics) |
| Event Exporter | monitoring | `3.5.0` | N/A (K8s events → stdout) |
| Node Problem Detector | kube-system | `2.3.14` | N/A (node health DaemonSet) |

### Security

| App | Namespace | Chart | Access |
|-----|-----------|-------|--------|
| Falco | falco | `8.0.1` | N/A (runtime threat detection) |
| Trivy Operator | trivy-system | `0.32.1` | N/A (vulnerability scanning) |
| Kyverno | kyverno | `3.3.8` | N/A (policy engine, failurePolicy=Ignore) |
| Kyverno Policies | kyverno | N/A | Audit-mode policies (raw manifests) |
| Cilium Network Policies | default | N/A | Baseline `allow-cluster-ingress` policy |

### Operations

| App | Namespace | Chart | Access |
|-----|-----------|-------|--------|
| External Secrets | external-secrets | `2.1.0` | N/A (secrets sync) |
| Reloader | reloader | `2.2.9` | N/A (restart on ConfigMap/Secret change) |
| Reflector | reflector | `10.0.20` | N/A (cross-namespace secret mirroring) |
| Descheduler | kube-system | `0.35.1` | N/A (pod rebalancing CronJob) |

### Right-sizing & UI

| App | Namespace | Chart | Access |
|-----|-----------|-------|--------|
| VPA | kube-system | `4.10.2` | N/A (resource recommendations) |
| Goldilocks | goldilocks | `10.3.0` | `kubectl port-forward -n goldilocks svc/goldilocks-dashboard 8082:80` |
| Headlamp | kubernetes-dashboard | `0.39.0` | `kubectl port-forward -n kubernetes-dashboard svc/headlamp 8083:80` |

### Cluster UIs

| App | Namespace | Access |
|-----|-----------|--------|
| ArgoCD | argocd | `kubectl port-forward -n argocd svc/argocd-server 8080:443` |
| Hubble UI | kube-system | `kubectl port-forward -n kube-system svc/hubble-ui 8081:80` |

## Credentials

| Service | Username | Password |
|---------|----------|----------|
| Grafana | admin | admin |
| ArgoCD | admin | `make argocd-password` |
| HAProxy VM (SSH) | alpine | `ssh alpine@192.168.122.100` |

## MetalLB IP Pool

| Range | Purpose |
|-------|---------|
| 192.168.122.200 - 192.168.122.230 | LoadBalancer service IPs (L2 mode) |

## Disabled Components

| Component | Reason |
|-----------|--------|
| Velero | No storage backend (S3/MinIO) — code in `velero.yaml.disabled` |
| Longhorn | Requires Talos `iscsi-tools` system extension |
