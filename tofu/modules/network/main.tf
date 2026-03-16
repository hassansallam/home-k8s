terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8"
    }
  }
}

# NAT-mode network — VMs are isolated behind host NAT with built-in DHCP.
resource "libvirt_network" "k8s_nat" {
  name      = var.network_name
  autostart = true

  forward = {
    mode = "nat"
    nat = {
      ports = [{ start = 1024, end = 65535 }]
    }
  }

  bridge = {
    name = "virbr-k8s"
    stp  = "on"
  }

  ips = [
    {
      family  = "ipv4"
      address = var.gateway
      netmask = "255.255.255.0"
      dhcp = {
        ranges = [
          { start = var.dhcp_pool_start, end = var.dhcp_pool_end }
        ]
        hosts = var.dhcp_hosts
      }
    }
  ]

  dns = {
    enable = "yes"
  }

  domain = {
    name       = "k8s.local"
    local_only = "yes"
  }
}
