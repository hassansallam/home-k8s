variable "name" {
  description = "VM name"
  type        = string
  default     = "haproxy"
}

variable "vcpus" {
  description = "Number of vCPUs"
  type        = number
  default     = 1
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 1024
}

variable "disk_size" {
  description = "Disk size in bytes"
  type        = number
  default     = 5368709120 # 5 GB
}

variable "ip_address" {
  description = "Static IP address for the HAProxy VM"
  type        = string
}

variable "gateway" {
  description = "Default gateway"
  type        = string
}

variable "dns_server" {
  description = "DNS server"
  type        = string
  default     = "192.168.122.1"
}

variable "mac_address" {
  description = "MAC address for the VM NIC"
  type        = string
}

variable "network_name" {
  description = "Libvirt network name to attach VMs to"
  type        = string
}

variable "controlplane_ips" {
  description = "List of control-plane node IPs for backend config"
  type        = list(string)
}

variable "base_image_url" {
  description = "URL for the Alpine cloud image"
  type        = string
  default     = "https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.3-x86_64-bios-cloudinit-r0.qcow2"
}

variable "storage_pool" {
  description = "Libvirt storage pool name"
  type        = string
  default     = "default"
}

variable "ssh_pubkey" {
  description = "SSH public key for the alpine user"
  type        = string
}
