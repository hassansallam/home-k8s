#!/usr/bin/env bash
set -euo pipefail

# Initialize the home-k8s project: select versions and download Talos image.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TFVARS_FILE="${PROJECT_DIR}/tofu/terraform.tfvars"
ANSIBLE_VARS_FILE="${PROJECT_DIR}/ansible/group_vars/all.yml"

# ── Colored output helpers ───────────────────────────────────────────────────

info()    { echo -e "\033[34m[INFO]\033[0m $*"; }
warn()    { echo -e "\033[33m[WARN]\033[0m $*"; }
error()   { echo -e "\033[31m[ERROR]\033[0m $*"; }
success() { echo -e "\033[32m[OK]\033[0m $*"; }

# ── tfvars helpers ───────────────────────────────────────────────────────────

parse_tfvar() {
    local key="$1"
    grep -E "^${key}\s*=" "$TFVARS_FILE" | head -1 | sed 's/.*=\s*"\?\([^"]*\)"\?.*/\1/' | xargs
}

update_tfvar() {
    local key="$1" value="$2"
    sed -i "s|^\(${key}\s*=\s*\).*|\1\"${value}\"|" "$TFVARS_FILE"
}

# ── YAML helpers (ansible/group_vars/all.yml) ───────────────────────────────

parse_yaml_var() {
    local key="$1"
    grep -E "^${key}:" "$ANSIBLE_VARS_FILE" | head -1 | sed 's/^[^:]*:\s*"\?\([^"]*\)"\?.*/\1/'
}

update_yaml_var() {
    local key="$1" value="$2"
    sed -i "s|^\(${key}:\s*\).*|\1\"${value}\"|" "$ANSIBLE_VARS_FILE"
}

# ── ArgoCD app version helper ───────────────────────────────────────────────

update_argocd_app_version() {
    local file="$1" old_version="$2" new_version="$3"
    if [[ "$old_version" != "$new_version" ]]; then
        sed -i "s|targetRevision: ${old_version}|targetRevision: ${new_version}|" "$file"
    fi
}

# ── Version prompt helper ───────────────────────────────────────────────────

prompt_version() {
    local component="$1" current="$2"
    local chosen
    read -rp "  ${component} [${current}]: " chosen
    echo "${chosen:-$current}"
}

# ══════════════════════════════════════════════════════════════════════════════
# Phase 1: Version selection
# ══════════════════════════════════════════════════════════════════════════════

select_versions() {
    info "Phase 1: Version selection"
    echo ""
    info "Press Enter to keep the current value, or type a new version."
    echo ""

    # kubectl — display only
    if command -v kubectl &>/dev/null; then
        local kubectl_ver
        kubectl_ver=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null || echo "unknown")
        info "  kubectl: ${kubectl_ver} (system-installed, not managed here)"
    else
        warn "  kubectl: not found in PATH"
    fi

    # ── Kubernetes ───────────────────────────────────────────────────────
    local cur_k8s new_k8s
    cur_k8s=$(parse_yaml_var "kubernetes_version")
    new_k8s=$(prompt_version "Kubernetes" "$cur_k8s")
    if [[ "$new_k8s" != "$cur_k8s" ]]; then
        update_yaml_var "kubernetes_version" "$new_k8s"
        success "  Kubernetes: ${cur_k8s} → ${new_k8s}"
    fi

    # ── Talos ────────────────────────────────────────────────────────────
    local cur_talos new_talos
    cur_talos=$(parse_yaml_var "talos_version")
    new_talos=$(prompt_version "Talos" "$cur_talos")
    if [[ "$new_talos" != "$cur_talos" ]]; then
        update_yaml_var "talos_version" "$new_talos"

        # Update tofu/terraform.tfvars: version + image path
        local cur_tfvar_talos cur_image_path new_image_path
        cur_tfvar_talos=$(parse_tfvar "talos_version")
        cur_image_path=$(parse_tfvar "talos_image_path")
        new_image_path="${cur_image_path//$cur_tfvar_talos/$new_talos}"
        update_tfvar "talos_version" "$new_talos"
        update_tfvar "talos_image_path" "$new_image_path"
        success "  Talos: ${cur_talos} → ${new_talos}"
    fi

    # ── Cilium ───────────────────────────────────────────────────────────
    local cur_cilium new_cilium
    cur_cilium=$(parse_yaml_var "cilium_version")
    new_cilium=$(prompt_version "Cilium" "$cur_cilium")
    if [[ "$new_cilium" != "$cur_cilium" ]]; then
        update_yaml_var "cilium_version" "$new_cilium"
        update_argocd_app_version "${PROJECT_DIR}/k8s/argocd/apps/cilium.yaml" "$cur_cilium" "$new_cilium"
        success "  Cilium: ${cur_cilium} → ${new_cilium}"
    fi

    # ── ArgoCD ───────────────────────────────────────────────────────────
    local cur_argocd new_argocd
    cur_argocd=$(parse_yaml_var "argocd_version")
    new_argocd=$(prompt_version "ArgoCD" "$cur_argocd")
    if [[ "$new_argocd" != "$cur_argocd" ]]; then
        update_yaml_var "argocd_version" "$new_argocd"
        # Update kustomization.yaml manifest URL
        local kust_file="${PROJECT_DIR}/k8s/argocd/install/kustomization.yaml"
        sed -i "s|/argo-cd/${cur_argocd}/|/argo-cd/${new_argocd}/|" "$kust_file"
        success "  ArgoCD: ${cur_argocd} → ${new_argocd}"
    fi

    # ── MetalLB ──────────────────────────────────────────────────────────
    local metallb_file="${PROJECT_DIR}/k8s/argocd/apps/metallb.yaml"
    local cur_metallb new_metallb
    cur_metallb=$(grep 'chart: metallb' -A1 "$metallb_file" | grep 'targetRevision' | sed 's/.*targetRevision:\s*//')
    new_metallb=$(prompt_version "MetalLB" "$cur_metallb")
    if [[ "$new_metallb" != "$cur_metallb" ]]; then
        update_argocd_app_version "$metallb_file" "$cur_metallb" "$new_metallb"
        success "  MetalLB: ${cur_metallb} → ${new_metallb}"
    fi

    # ── Cert-Manager ─────────────────────────────────────────────────────
    local certmgr_file="${PROJECT_DIR}/k8s/argocd/apps/cert-manager.yaml"
    local cur_certmgr new_certmgr
    cur_certmgr=$(grep 'chart: cert-manager' -A1 "$certmgr_file" | grep 'targetRevision' | sed 's/.*targetRevision:\s*//')
    new_certmgr=$(prompt_version "Cert-Manager" "$cur_certmgr")
    if [[ "$new_certmgr" != "$cur_certmgr" ]]; then
        update_argocd_app_version "$certmgr_file" "$cur_certmgr" "$new_certmgr"
        success "  Cert-Manager: ${cur_certmgr} → ${new_certmgr}"
    fi

    # ── Longhorn ─────────────────────────────────────────────────────────
    local longhorn_file="${PROJECT_DIR}/k8s/argocd/apps/longhorn.yaml"
    local cur_longhorn new_longhorn
    cur_longhorn=$(grep 'chart: longhorn' -A1 "$longhorn_file" | grep 'targetRevision' | sed 's/.*targetRevision:\s*//')
    new_longhorn=$(prompt_version "Longhorn" "$cur_longhorn")
    if [[ "$new_longhorn" != "$cur_longhorn" ]]; then
        update_argocd_app_version "$longhorn_file" "$cur_longhorn" "$new_longhorn"
        success "  Longhorn: ${cur_longhorn} → ${new_longhorn}"
    fi

    # ── Gateway API ──────────────────────────────────────────────────────
    local gwapi_file="${PROJECT_DIR}/k8s/argocd/apps/gateway-api.yaml"
    local cur_gwapi new_gwapi
    cur_gwapi=$(grep 'targetRevision:' "$gwapi_file" | head -1 | sed 's/.*targetRevision:\s*//')
    new_gwapi=$(prompt_version "Gateway API" "$cur_gwapi")
    if [[ "$new_gwapi" != "$cur_gwapi" ]]; then
        update_argocd_app_version "$gwapi_file" "$cur_gwapi" "$new_gwapi"
        success "  Gateway API: ${cur_gwapi} → ${new_gwapi}"
    fi

    # ── Kube-Prometheus-Stack ────────────────────────────────────────────
    local kprom_file="${PROJECT_DIR}/k8s/argocd/apps/kube-prometheus.yaml"
    local cur_kprom new_kprom
    cur_kprom=$(grep 'chart: kube-prometheus-stack' -A1 "$kprom_file" | grep 'targetRevision' | sed 's/.*targetRevision:\s*//')
    new_kprom=$(prompt_version "Kube-Prometheus-Stack" "$cur_kprom")
    if [[ "$new_kprom" != "$cur_kprom" ]]; then
        update_argocd_app_version "$kprom_file" "$cur_kprom" "$new_kprom"
        success "  Kube-Prometheus-Stack: ${cur_kprom} → ${new_kprom}"
    fi

    echo ""
    success "Version selection complete."
}

# ══════════════════════════════════════════════════════════════════════════════
# Phase 2: Talos image download
# ══════════════════════════════════════════════════════════════════════════════

download_talos_image() {
    info "Phase 2: Talos image download"

    local version schematic_id image_path
    version=$(parse_tfvar "talos_version")
    schematic_id=$(parse_tfvar "talos_schematic_id")
    image_path=$(parse_tfvar "talos_image_path")

    if [[ -f "$image_path" ]]; then
        success "Talos image already exists at ${image_path}"
        return
    fi

    info "Downloading Talos ${version} image..."
    local download_url="https://factory.talos.dev/image/${schematic_id}/${version}/nocloud-amd64.raw.xz"
    local tmp_xz="/tmp/talos-${version}.raw.xz"
    local tmp_raw="/tmp/talos-${version}.raw"

    curl -fSL -o "$tmp_xz" "$download_url"
    success "Downloaded to ${tmp_xz}"

    info "Decompressing..."
    xz -df "$tmp_xz"

    info "Converting to qcow2..."
    local image_dir
    image_dir=$(dirname "$image_path")

    if [[ -w "$image_dir" ]]; then
        qemu-img convert -f raw -O qcow2 "$tmp_raw" "$image_path"
    else
        info "Using sudo to write to ${image_dir}"
        sudo qemu-img convert -f raw -O qcow2 "$tmp_raw" "$image_path"
    fi

    # Clean up
    rm -f "$tmp_raw"

    # Verify
    info "Verifying image..."
    qemu-img info "$image_path" | head -5
    success "Talos image ready at ${image_path}"
}

# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  home-k8s initialization"
echo "═══════════════════════════════════════════════════════════"
echo ""

select_versions
echo ""
download_talos_image

echo ""
success "Initialization complete! Run 'make deploy' to create the cluster."
