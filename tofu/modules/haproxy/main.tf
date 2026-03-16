terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8"
    }
  }
}

# ---------------------------------------------------------------------------
# Base image (downloaded once)
# ---------------------------------------------------------------------------

resource "libvirt_volume" "alpine_base" {
  name = "${var.name}-alpine-base.qcow2"
  pool = var.storage_pool

  target = {
    format = { type = "qcow2" }
  }

  create = {
    content = { url = var.base_image_url }
  }
}

# ---------------------------------------------------------------------------
# Data volume (backed by base image)
# ---------------------------------------------------------------------------

resource "libvirt_volume" "haproxy_disk" {
  name     = "${var.name}-disk.qcow2"
  pool     = var.storage_pool
  capacity = var.disk_size

  target = {
    format = { type = "qcow2" }
  }

  backing_store = {
    path   = libvirt_volume.alpine_base.path
    format = { type = "qcow2" }
  }
}

# ---------------------------------------------------------------------------
# Cloud-init
# ---------------------------------------------------------------------------

resource "libvirt_cloudinit_disk" "haproxy_init" {
  name = "${var.name}-cloudinit.iso"

  meta_data = yamlencode({
    instance-id    = var.name
    local-hostname = var.name
  })

  user_data = templatefile("${path.module}/templates/cloud_init.cfg.tpl", {
    hostname         = var.name
    controlplane_ips = var.controlplane_ips
    ssh_pubkey       = var.ssh_pubkey
    dns_server       = var.dns_server
  })

  network_config = templatefile("${path.module}/templates/network_config.cfg.tpl", {
    ip_address = var.ip_address
    gateway    = var.gateway
    dns_server = var.dns_server
  })
}

# ---------------------------------------------------------------------------
# VM
# ---------------------------------------------------------------------------

resource "libvirt_domain" "haproxy" {
  name        = var.name
  type        = "kvm"
  running     = true
  autostart   = true
  vcpu        = var.vcpus
  memory      = var.memory
  memory_unit = "MiB"

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    boot_devices = [{ dev = "hd" }]
  }

  devices = {
    disks = [
      {
        driver = {
          name = "qemu"
          type = "qcow2"
        }
        source = {
          volume = {
            pool   = var.storage_pool
            volume = libvirt_volume.haproxy_disk.name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        device = "cdrom"
        source = {
          file = {
            file = libvirt_cloudinit_disk.haproxy_init.path
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
      }
    ]

    interfaces = [
      {
        mac = {
          address = var.mac_address
        }
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = var.network_name
          }
        }
      }
    ]

    consoles = [
      {
        target = {
          type = "serial"
          port = 0
        }
      }
    ]

    graphics = []
  }
}
