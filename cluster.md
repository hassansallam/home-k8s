# Cluster Overview

## Network: 192.168.122.0/24 (libvirt NAT via `virbr-k8s`)

## Nodes

| VM Name | IP Address | Role | OS | Resources |
|---------|-----------|------|-----|-----------|
| k8s-haproxy | 192.168.122.100 | Load balancer (K8s API + Talos API) | Alpine 3.21 | 1 vCPU, 512 MiB |
| k8s-cp-1 | 192.168.122.101 | Control plane (etcd, apiserver, scheduler, controller) | Talos v1.12.5 | 2 vCPU, 4 GiB |
| k8s-cp-2 | 192.168.122.102 | Control plane | Talos v1.12.5 | 2 vCPU, 4 GiB |
| k8s-cp-3 | 192.168.122.103 | Control plane | Talos v1.12.5 | 2 vCPU, 4 GiB |
| k8s-worker-1 | 192.168.122.104 | Worker (runs workloads) | Talos v1.12.5 | 2 vCPU, 4 GiB |
| k8s-worker-2 | 192.168.122.105 | Worker | Talos v1.12.5 | 2 vCPU, 4 GiB |
| k8s-worker-3 | 192.168.122.106 | Worker | Talos v1.12.5 | 2 vCPU, 4 GiB |

## Infrastructure Services

| Service | IP / Port | Access URL | Notes |
|---------|----------|------------|-------|
| HAProxy Stats | 192.168.122.100:8404 | http://192.168.122.100:8404/stats | HAProxy dashboard |
| K8s API | 192.168.122.100:6443 | `kubectl --kubeconfig kubeconfig` | Via HAProxy → 3 CP nodes |
| Talos API | 192.168.122.100:50000 | `talosctl --talosconfig ansible/talos-generated/talosconfig` | Via HAProxy → 3 CP nodes |

## Cluster Apps (managed by ArgoCD)

| App | Namespace | Access URL | Port | Type |
|-----|-----------|------------|------|------|
| Grafana | monitoring | http://192.168.122.200 | 80 | LoadBalancer (MetalLB) |
| Prometheus | monitoring | `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090` | 9090 | ClusterIP |
| Alertmanager | monitoring | `kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093` | 9093 | ClusterIP |
| ArgoCD | argocd | `kubectl port-forward -n argocd svc/argocd-server 8080:443` | 443 | ClusterIP |
| Hubble UI | kube-system | `kubectl port-forward -n kube-system svc/hubble-ui 8081:80` | 80 | ClusterIP |
| Cert-Manager | cert-manager | N/A (no UI) | - | - |
| Cilium | kube-system | `cilium status` | - | - |
| MetalLB | metallb-system | N/A (no UI) | - | - |

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
