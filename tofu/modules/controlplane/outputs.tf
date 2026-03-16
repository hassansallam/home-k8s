output "controlplane_ids" {
  description = "Libvirt domain IDs of the control-plane nodes"
  value       = libvirt_domain.controlplane[*].id
}

output "controlplane_macs" {
  description = "MAC addresses of the control-plane nodes"
  value       = var.mac_addresses
}
