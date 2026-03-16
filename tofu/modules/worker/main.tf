terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8"
    }
  }
}

locals {
  worker_disk_paths = [
    for i in range(var.count_wk) :
    "/var/lib/libvirt/images/${var.name_prefix}-${i + 1}-disk.qcow2"
  ]
}

# ---------------------------------------------------------------------------
# Per-node overlay disk (virsh vol-create-as produces correct qcow2 backing)
# ---------------------------------------------------------------------------

resource "terraform_data" "worker_disk" {
  count = var.count_wk

  input = {
    vol_name  = "${var.name_prefix}-${count.index + 1}-disk.qcow2"
    disk_path = local.worker_disk_paths[count.index]
    pool      = var.storage_pool
    base_path = var.talos_image_path
    size      = var.disk_size_gb * 1073741824
  }

  provisioner "local-exec" {
    command = <<-EOF
      virsh -c qemu:///system vol-create-as '${self.input.pool}' '${self.input.vol_name}' '${self.input.size}B' \
        --format qcow2 \
        --backing-vol '${self.input.base_path}' \
        --backing-vol-format qcow2
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = "virsh -c qemu:///system vol-delete '${self.input.vol_name}' --pool '${self.input.pool}' 2>/dev/null || true"
  }
}

# ---------------------------------------------------------------------------
# VM domain
# ---------------------------------------------------------------------------

resource "libvirt_domain" "worker" {
  count = var.count_wk

  depends_on = [terraform_data.worker_disk]

  name        = "${var.name_prefix}-${count.index + 1}"
  type        = "kvm"
  running     = true
  autostart   = true
  vcpu        = var.vcpus
  memory      = var.memory
  memory_unit = "MiB"

  cpu = {
    mode = "host-passthrough"
  }

  features = {
    acpi = true
    apic = {}
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
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
          file = {
            file = local.worker_disk_paths[count.index]
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      }
    ]

    interfaces = [
      {
        mac = {
          address = var.mac_addresses[count.index]
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

    channels = [
      {
        source = { unix = {} }
        target = {
          virt_io = {
            name = "org.qemu.guest_agent.0"
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
