output "haproxy_ip" {
  description = "IP address of the HAProxy VM"
  value       = var.ip_address
}

output "haproxy_id" {
  description = "Libvirt domain ID of the HAProxy VM"
  value       = libvirt_domain.haproxy.id
}
