output "network_id" {
  description = "ID of the libvirt NAT network"
  value       = libvirt_network.k8s_nat.id
}

output "network_name" {
  description = "Name of the libvirt NAT network"
  value       = libvirt_network.k8s_nat.name
}
