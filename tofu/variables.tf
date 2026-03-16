################################################################################
# Cluster
################################################################################

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "k8s"
}

variable "controlplane_count" {
  description = "Number of control-plane nodes"
  type        = number
  default     = 3
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

################################################################################
# Control Plane sizing
################################################################################

variable "controlplane_vcpus" {
  description = "vCPUs per control-plane node"
  type        = number
  default     = 2
}

variable "controlplane_memory" {
  description = "Memory (MB) per control-plane node"
  type        = number
  default     = 4096
}

variable "controlplane_disk_gb" {
  description = "Disk size (GB) per control-plane node"
  type        = number
  default     = 20
}

################################################################################
# Worker sizing
################################################################################

variable "worker_vcpus" {
  description = "vCPUs per worker node"
  type        = number
  default     = 2
}

variable "worker_memory" {
  description = "Memory (MB) per worker node"
  type        = number
  default     = 4096
}

variable "worker_disk_gb" {
  description = "Disk size (GB) per worker node"
  type        = number
  default     = 40
}

################################################################################
# HAProxy sizing
################################################################################

variable "haproxy_vcpus" {
  description = "vCPUs for the HAProxy load-balancer"
  type        = number
  default     = 1
}

variable "haproxy_memory" {
  description = "Memory (MB) for the HAProxy load-balancer"
  type        = number
  default     = 1024
}

variable "haproxy_disk_gb" {
  description = "Disk size (GB) for the HAProxy load-balancer"
  type        = number
  default     = 5
}

################################################################################
# Talos
################################################################################

variable "talos_version" {
  description = "Talos Linux release version"
  type        = string
  default     = "v1.9.5"
}

variable "talos_schematic_id" {
  description = "Talos Factory schematic ID for custom image"
  type        = string
  default     = "ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515"
}

variable "talos_image_path" {
  description = "Local path to the Talos qcow2 image"
  type        = string
  default     = "/var/lib/libvirt/images/talos-v1.9.5.qcow2"
}

################################################################################
# IP assignments
################################################################################

variable "haproxy_ip" {
  description = "Static IP for the HAProxy load-balancer"
  type        = string
  default     = "192.168.122.100"
}

variable "controlplane_ips" {
  description = "Static IPs for the control-plane nodes"
  type        = list(string)
  default     = ["192.168.122.101", "192.168.122.102", "192.168.122.103"]
}

variable "worker_ips" {
  description = "Static IPs for the worker nodes"
  type        = list(string)
  default     = ["192.168.122.104", "192.168.122.105", "192.168.122.106"]
}

################################################################################
# MetalLB
################################################################################

variable "metallb_pool_start" {
  description = "Start of the MetalLB IP pool"
  type        = string
  default     = "192.168.122.200"
}

variable "metallb_pool_end" {
  description = "End of the MetalLB IP pool"
  type        = string
  default     = "192.168.122.230"
}

################################################################################
# Networking
################################################################################

variable "network_name" {
  description = "Libvirt network name"
  type        = string
  default     = "k8s-nat"
}

variable "gateway" {
  description = "Default gateway (host on NAT network)"
  type        = string
  default     = "192.168.122.1"
}

variable "dns_server" {
  description = "DNS server (host dnsmasq on NAT network)"
  type        = string
  default     = "192.168.122.1"
}

################################################################################
# Storage
################################################################################

variable "storage_pool" {
  description = "Libvirt storage pool name"
  type        = string
  default     = "default"
}

################################################################################
# Alpine base image for HAProxy
################################################################################

variable "alpine_image_url" {
  description = "URL for the Alpine cloud image"
  type        = string
  default     = "https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.0-x86_64-bios-cloudinit-r0.qcow2"
}
