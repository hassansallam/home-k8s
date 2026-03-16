#!/usr/bin/env bash
set -euo pipefail

# Install all host dependencies for the home Kubernetes cluster on CachyOS (Arch-based).

# ── Root check ────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root or with sudo."
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"

command_exists() { command -v "$1" &>/dev/null; }

# ── Sync repos ───────────────────────────────────────────────────────────────
echo "Syncing package databases..."
pacman -Sy --noconfirm

# ── Pacman packages ──────────────────────────────────────────────────────────
PACMAN_PKGS=(
    libvirt
    qemu-full
    virt-manager
    dnsmasq
    ebtables
    iptables-nft
    dmidecode
    helm
    kubectl
    jq
    ansible
)

echo "Ensuring all pacman packages are installed and up-to-date..."
pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

# ── AUR helper check ─────────────────────────────────────────────────────────
if command_exists yay; then
    AUR_HELPER="yay"
elif command_exists paru; then
    AUR_HELPER="paru"
else
    echo "ERROR: No AUR helper found (yay or paru). Install one first."
    exit 1
fi

# ── AUR: opentofu + yq (install or upgrade to latest) ───────────────────────
AUR_PKGS=(opentofu-bin go-yq)
echo "Ensuring AUR packages are installed and up-to-date..."
sudo -u "$REAL_USER" "$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS[@]}"

# ── talosctl (GitHub binary — install or upgrade) ────────────────────────────
TALOS_LATEST=$(curl -sL https://api.github.com/repos/siderolabs/talos/releases/latest | jq -r '.tag_name')
TALOS_INSTALLED=""
if command_exists talosctl; then
    TALOS_INSTALLED=$(talosctl version --client --short 2>/dev/null | grep -oP 'Talos \K\S+' || echo "")
fi

if [[ "$TALOS_INSTALLED" == "$TALOS_LATEST" ]]; then
    echo "[ok] talosctl is latest ($TALOS_LATEST)"
else
    echo "Installing talosctl ${TALOS_LATEST}..."
    curl -sL "https://github.com/siderolabs/talos/releases/download/${TALOS_LATEST}/talosctl-linux-amd64" \
        -o /usr/local/bin/talosctl
    chmod +x /usr/local/bin/talosctl
    echo "Installed talosctl ${TALOS_LATEST}"
fi

# ── cilium-cli (GitHub binary — install or upgrade) ─────────────────────────
CILIUM_LATEST=$(curl -sL https://api.github.com/repos/cilium/cilium-cli/releases/latest | jq -r '.tag_name')
CILIUM_INSTALLED=""
if command_exists cilium; then
    CILIUM_INSTALLED=$(cilium version --client 2>/dev/null | grep -oP 'cilium-cli: \K\S+' || echo "")
fi

if [[ "$CILIUM_INSTALLED" == "$CILIUM_LATEST" ]]; then
    echo "[ok] cilium-cli is latest ($CILIUM_LATEST)"
else
    echo "Installing cilium-cli ${CILIUM_LATEST}..."
    curl -sL "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_LATEST}/cilium-linux-amd64.tar.gz" \
        | tar xz -C /usr/local/bin
    chmod +x /usr/local/bin/cilium
    echo "Installed cilium-cli ${CILIUM_LATEST}"
fi

# ── libvirtd service ─────────────────────────────────────────────────────────
echo "Enabling and starting libvirtd..."
systemctl enable --now libvirtd

# ── Add user to libvirt group ─────────────────────────────────────────────────
if id -nG "$REAL_USER" | grep -qw libvirt; then
    echo "[ok] User $REAL_USER already in libvirt group"
else
    echo "Adding $REAL_USER to libvirt group..."
    usermod -aG libvirt "$REAL_USER"
    echo "NOTE: Log out and back in for group membership to take effect."
fi

# ── Default libvirt storage pool ──────────────────────────────────────────────
if virsh -c qemu:///system pool-info default &>/dev/null; then
    echo "[ok] Default storage pool already exists"
else
    echo "Creating default storage pool..."
    virsh -c qemu:///system pool-define-as default dir --target /var/lib/libvirt/images
    virsh -c qemu:///system pool-build default
    virsh -c qemu:///system pool-start default
    virsh -c qemu:///system pool-autostart default
fi

echo ""
echo "All prerequisites installed successfully."
echo "NOTE: NAT networking is handled by libvirt — no host bridge (br0) required."
