variable "network_name" {
  description = "Libvirt network name"
  type        = string
  default     = "k8s-nat"
}

variable "gateway" {
  description = "Host gateway IP on the NAT network"
  type        = string
  default     = "192.168.122.1"
}

variable "dhcp_pool_start" {
  description = "Start of the DHCP dynamic pool"
  type        = string
  default     = "192.168.122.140"
}

variable "dhcp_pool_end" {
  description = "End of the DHCP dynamic pool"
  type        = string
  default     = "192.168.122.199"
}

variable "dhcp_hosts" {
  description = "Static DHCP reservations (MAC → IP)"
  type = list(object({
    mac  = string
    name = string
    ip   = string
  }))
  default = []
}
