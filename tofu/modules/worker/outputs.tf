output "worker_ids" {
  description = "Libvirt domain IDs of the worker nodes"
  value       = libvirt_domain.worker[*].id
}

output "worker_macs" {
  description = "MAC addresses of the worker nodes"
  value       = var.mac_addresses
}
