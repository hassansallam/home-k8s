################################################################################
# Deterministic MAC addresses
#
# Format: 52:54:00:k8:XX:YY
#   XX = node-type  (01 = haproxy, 02 = controlplane, 03 = worker)
#   YY = node index (01, 02, 03 …)
################################################################################

locals {
  haproxy_mac = "52:54:00:00:01:01"

  controlplane_macs = [
    for i in range(var.controlplane_count) :
    format("52:54:00:00:02:%02x", i + 1)
  ]

  worker_macs = [
    for i in range(var.worker_count) :
    format("52:54:00:00:03:%02x", i + 1)
  ]

  # Combine all VM definitions for libvirt DHCP host entries
  all_dhcp_hosts = concat(
    [
      {
        mac  = local.haproxy_mac
        name = "${var.cluster_name}-haproxy"
        ip   = var.haproxy_ip
      }
    ],
    [
      for i in range(var.controlplane_count) : {
        mac  = local.controlplane_macs[i]
        name = "${var.cluster_name}-cp-${i + 1}"
        ip   = var.controlplane_ips[i]
      }
    ],
    [
      for i in range(var.worker_count) : {
        mac  = local.worker_macs[i]
        name = "${var.cluster_name}-worker-${i + 1}"
        ip   = var.worker_ips[i]
      }
    ],
  )
}

################################################################################
# NAT network with DHCP static reservations
################################################################################

module "network" {
  source = "./modules/network"

  network_name   = var.network_name
  gateway        = var.gateway
  dhcp_pool_start = "192.168.122.140"
  dhcp_pool_end   = "192.168.122.199"
  dhcp_hosts     = local.all_dhcp_hosts
}

################################################################################
# HAProxy load-balancer
################################################################################

module "haproxy" {
  source = "./modules/haproxy"

  depends_on = [module.network]

  name             = "${var.cluster_name}-haproxy"
  vcpus            = var.haproxy_vcpus
  memory           = var.haproxy_memory
  disk_size        = var.haproxy_disk_gb * 1073741824
  ip_address       = var.haproxy_ip
  gateway          = var.gateway
  dns_server       = var.dns_server
  mac_address      = local.haproxy_mac
  network_name     = module.network.network_name
  controlplane_ips = var.controlplane_ips
  base_image_url   = var.alpine_image_url
  storage_pool     = var.storage_pool
  ssh_pubkey       = trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))
}

################################################################################
# Talos control-plane nodes
################################################################################

module "controlplane" {
  source = "./modules/controlplane"

  depends_on = [module.network]

  count_cp        = var.controlplane_count
  vcpus           = var.controlplane_vcpus
  memory          = var.controlplane_memory
  disk_size_gb    = var.controlplane_disk_gb
  mac_addresses   = local.controlplane_macs
  network_name    = module.network.network_name
  talos_image_path = var.talos_image_path
  name_prefix     = "${var.cluster_name}-cp"
  storage_pool    = var.storage_pool
}

################################################################################
# Talos worker nodes
################################################################################

module "worker" {
  source = "./modules/worker"

  depends_on = [module.network]

  count_wk        = var.worker_count
  vcpus           = var.worker_vcpus
  memory          = var.worker_memory
  disk_size_gb    = var.worker_disk_gb
  mac_addresses   = local.worker_macs
  network_name    = module.network.network_name
  talos_image_path = var.talos_image_path
  name_prefix     = "${var.cluster_name}-worker"
  storage_pool    = var.storage_pool
}
