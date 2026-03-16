variable "count_wk" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "vcpus" {
  description = "vCPUs per node"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MB per node"
  type        = number
  default     = 4096
}

variable "disk_size_gb" {
  description = "Disk size in GB per node"
  type        = number
  default     = 40
}

variable "mac_addresses" {
  description = "MAC addresses for each worker node"
  type        = list(string)
}

variable "network_name" {
  description = "Libvirt network name to attach VMs to"
  type        = string
}

variable "talos_image_path" {
  description = "Path to the Talos qcow2 image"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for VM names"
  type        = string
  default     = "worker"
}

variable "storage_pool" {
  description = "Libvirt storage pool name"
  type        = string
  default     = "default"
}
