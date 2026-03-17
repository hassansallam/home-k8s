# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A complete IaC project deploying a Kubernetes homelab on libvirt/KVM using Talos Linux, managed via OpenTofu + Ansible + ArgoCD.

## Commands

```bash
# Full lifecycle
make deploy          # infra → configure → bootstrap (end-to-end)
make destroy         # talos-reset → destroy-infra

# Individual phases
make prereqs         # Install host dependencies (libvirt, qemu, talosctl, cilium-cli)
make init            # Interactive version selection + Talos image download
make infra           # OpenTofu apply (NAT network + VMs)
make infra-plan      # Preview tofu changes
make configure       # Generate inventory + configure HAProxy + apply Talos configs
make bootstrap       # Bootstrap etcd + Cilium + kubeconfig + ArgoCD
make destroy-infra   # OpenTofu destroy

# Operations
make status          # Show VMs, nodes, pods
make kubeconfig      # Fetch fresh kubeconfig
make talos-health    # Check Talos cluster health
make ssh-haproxy     # SSH into HAProxy VM
make argocd-password # Get ArgoCD admin password
make scale           # After changing terraform.tfvars counts

# Ansible playbooks (from ansible/ directory)
ansible-playbook playbooks/haproxy.yml
ansible-playbook playbooks/talos-config.yml
ansible-playbook playbooks/talos-bootstrap.yml
ansible-playbook playbooks/cilium.yml
ansible-playbook playbooks/argocd-bootstrap.yml
```

## Architecture

### Three-Phase Deployment

1. **Infrastructure** (OpenTofu): Creates libvirt NAT network with DHCP static reservations, HAProxy Alpine VM (cloud-init), 3 CP + 3 worker Talos VMs
2. **Configuration** (Ansible): Generates Ansible inventory from tofu outputs, configures HAProxy via SSH, generates per-node Talos machine configs with patches, applies configs via `talosctl`
3. **Bootstrap** (Ansible + Helm): Bootstraps etcd, installs Cilium CNI, fetches kubeconfig, deploys ArgoCD

### Network Layout (192.168.122.0/24 NAT)

- Gateway/DNS: `.1` (host via libvirt dnsmasq)
- HAProxy LB: `.100` (K8s API :6443, Talos API :50000)
- Control plane: `.101-.103`
- Workers: `.104-.106`
- MetalLB pool: `.200-.230`

### GitOps Pipeline

ArgoCD manages cluster apps via an app-of-apps pattern. Each app in `k8s/argocd/apps/` references a Helm chart with values from `k8s/<app>/values.yaml`. Sync wave annotations control deployment order. ArgoCD is configured with `controller.operation.processors: 1` to sync one app at a time, preventing Cilium BPF overload on startup.

- **Wave -1**: Gateway API CRDs
- **Wave 0**: Cilium (CNI)
- **Wave 1**: MetalLB (L2 load balancer)
- **Wave 2**: Cert-Manager, metrics-server
- **Wave 4**: Prometheus/Grafana
- **Wave 5**: Loki + Promtail (log aggregation)
- **Wave 6**: Falco, Trivy, Kyverno (security layer)
- **Wave 7**: External Secrets, Reloader, Reflector (config/secrets)
- **Wave 8**: Descheduler, Node Problem Detector, Event Exporter (operations)
- **Wave 9**: VPA + Goldilocks (resource right-sizing)
- **Wave 10**: Headlamp (K8s dashboard), Cilium Network Policies

## Key Patterns & Gotchas

**Disk overlay creation**: The `dmacvicar/libvirt` provider v0.9.5 creates qcow2 overlays with broken backing chains. CP and worker modules use `terraform_data` + `virsh vol-create-as` local-exec to create proper overlays, then reference them via `source.file` (not `source.volume`) in domains.

**VM domain requirements**: Talos VMs require `cpu = { mode = "host-passthrough" }` and `features = { acpi = true, apic = {} }` in the `libvirt_domain` resource. Without these, the guest OS cannot initialize hardware (NICs won't send any traffic). VMs must also include a virtio serial channel (`org.qemu.guest_agent.0`) for the QEMU guest agent extension — without it, the Talos boot sequence never completes and nodes stay in "BOOTING" state on the console.

**MAC address scheme**: Deterministic format `52:54:00:00:XX:YY` where XX = node type (01=haproxy, 02=cp, 03=worker), YY = index. Defined in `tofu/main.tf` locals.

**HAProxy VM specifics**: Alpine Linux uses `doas` not `sudo`. Inventory sets `ansible_become_method: doas`. Cloud-init must include the user's SSH public key (read from `~/.ssh/id_ed25519.pub` via tofu `file()` function). Alpine's cloud-init does NOT create `/etc/resolv.conf` from `network_config` — it must be written explicitly via `write_files` in cloud-init user-data. The HAProxy playbook waits for cloud-init to finish before running Ansible tasks. HAProxy 3.0+ does not support the old `option httpchk` inline syntax — use `option tcp-check` or `http-check send` directives instead.

**Ansible variable loading**: Playbooks running on `localhost` (Talos operations) need explicit `vars_files: ../group_vars/all.yml` to access shared variables like `talos_version`, `kubernetes_version`, etc.

**Talos config generation**: `talosctl gen config` generates base configs, then per-node patches add static IPs and routes. In Talos v1.12+, do NOT set `hostname` in patches (conflicts with base config validation). Endpoints in talosconfig must be set after generation (use `yq` to inject CP IPs).

**Bootstrap idempotency**: The `talos-bootstrap` role ignores "AlreadyExists" errors from `talosctl bootstrap`, making `make bootstrap` safely re-runnable. Cilium install includes a K8s API readiness retry (12 attempts, 10s apart) to handle the brief API unavailability after etcd bootstrap.

**ArgoCD CRD size**: ArgoCD v3.x CRDs exceed the 256KB `last-applied-configuration` annotation limit. The install uses `kubectl apply --server-side --force-conflicts` to avoid this.

**ArgoCD sequential sync**: `controller.operation.processors` is set to `1` to prevent deployment storms that overwhelm Cilium's BPF datapath. Apps deploy one at a time in sync-wave order.

**Cluster access**: The kubeconfig is at the project root (`kubeconfig`). Use `export KUBECONFIG=/path/to/home-k8s/kubeconfig` or pass `--kubeconfig kubeconfig` per command.

**PodSecurity namespaces**: MetalLB (`metallb-system`) and monitoring (`monitoring`) namespaces require `pod-security.kubernetes.io/enforce: privileged` labels. These are set via `managedNamespaceMetadata` in their ArgoCD app manifests. Falco (`falco`) also needs privileged. New namespaces running DaemonSets with host access need this label.

**Falco on Talos**: Uses `modern_ebpf` driver (no kernel module loading). Talos is immutable so kernel module-based drivers won't work.

**Kyverno webhooks**: Use `features.forceFailurePolicyIgnore.enabled: true` in values to set all webhook failurePolicies to Ignore. Without this, a Kyverno outage blocks ALL Kubernetes operations cluster-wide. The `config.webhooks` key in chart 3.3.8 is an object (not a list) — do not pass a list format.

**Kyverno cleanup jobs**: The chart default image `bitnami/kubectl:1.30.2` does not exist on Docker Hub. Override with `webhooksCleanup.image.tag` and `policyReportsCleanup.image.tag` set to a valid version like `1.31.0`.

**Cilium network policies**: CiliumClusterwideNetworkPolicies with `endpointSelector: {}` activate enforcement on ALL pods. NEVER use `ingressDeny` with `ingress` allows in the same policy — deny always overrides allow. NEVER add an egress policy with `endpointSelector: {}` unless you explicitly allow K8s API, DNS, and all needed egress. The current baseline policy (`allow-cluster-ingress`) allows all cluster-internal and local-network ingress with no egress enforcement.

**Cilium auto-generated secrets**: Cilium generates CA and Hubble TLS certificates as Secrets. The ArgoCD cilium app uses `ignoreDifferences` for Secret data and `RespectIgnoreDifferences=true` sync option to prevent perpetual OutOfSync.

**Loki on homelab**: Runs in SingleBinary mode. Must explicitly set `read/write/backend.replicas: 0` to avoid chart validation error. Uses `emptyDir` for `/var/loki` (no persistent storage provisioner). The container has `readOnlyRootFilesystem: true`, so an explicit emptyDir volume mount at `/var/loki` is required.

**Event Exporter image override**: When using non-Bitnami images with the Bitnami chart, set `global.security.allowInsecureImages: true` in values — otherwise the chart blocks deployment.

**Headlamp chart compatibility**: Chart 0.40.1 passes `--session-ttl` flag that the binary doesn't support. Use chart 0.39.0 instead.

**Velero**: Disabled (`.yaml.disabled`). Code preserved but not deployed. Needs a real storage backend (MinIO, S3, etc.) before enabling.

**ArgoCD public repo**: The GitHub repo is public. All app manifests use `https://github.com/hassansallam/home-k8s.git`.

## Version Management

All component versions are tracked in two places:
- `tofu/terraform.tfvars` — Talos version, image path
- `ansible/group_vars/all.yml` — Kubernetes, Cilium, ArgoCD versions
- `k8s/argocd/apps/*.yaml` — Helm chart `targetRevision` for each app

`make init` (scripts/init.sh) provides interactive version selection that updates all locations.

## File Generation

These files are generated and should not be manually edited:
- `ansible/inventory/hosts.yml` — generated by `scripts/generate-inventory.sh` from tofu outputs
- `ansible/talos-generated/` — machine configs from `talosctl gen config` + patches
- `kubeconfig` — fetched from Talos via `talosctl kubeconfig`
