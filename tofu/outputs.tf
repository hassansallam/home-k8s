output "haproxy_ip" {
  description = "IP address of the HAProxy load-balancer"
  value       = var.haproxy_ip
}

output "controlplane_ips" {
  description = "IP addresses of the control-plane nodes"
  value       = var.controlplane_ips
}

output "worker_ips" {
  description = "IP addresses of the worker nodes"
  value       = var.worker_ips
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint via HAProxy"
  value       = "https://${var.haproxy_ip}:6443"
}

output "metallb_range" {
  description = "MetalLB address pool range"
  value       = "${var.metallb_pool_start}-${var.metallb_pool_end}"
}

output "haproxy_mac" {
  description = "MAC address of the HAProxy VM"
  value       = local.haproxy_mac
}

output "controlplane_macs" {
  description = "MAC addresses of the control-plane nodes"
  value       = local.controlplane_macs
}

output "worker_macs" {
  description = "MAC addresses of the worker nodes"
  value       = local.worker_macs
}

output "cluster_name" {
  description = "Name of the cluster"
  value       = var.cluster_name
}

output "gateway" {
  description = "Gateway IP on the NAT network"
  value       = var.gateway
}

output "dns_server" {
  description = "DNS server IP on the NAT network"
  value       = var.dns_server
}
