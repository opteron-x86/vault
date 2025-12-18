output "network_id" {
  description = "VPC network ID"
  value       = google_compute_network.lab.id
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.lab.name
}

output "network_self_link" {
  description = "VPC network self link"
  value       = google_compute_network.lab.self_link
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = google_compute_subnetwork.public.id
}

output "public_subnet_name" {
  description = "Public subnet name"
  value       = google_compute_subnetwork.public.name
}

output "public_subnet_cidr" {
  description = "Public subnet CIDR"
  value       = google_compute_subnetwork.public.ip_cidr_range
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = var.enable_private_subnet ? google_compute_subnetwork.private[0].id : null
}

output "private_subnet_name" {
  description = "Private subnet name"
  value       = var.enable_private_subnet ? google_compute_subnetwork.private[0].name : null
}

output "private_subnet_cidr" {
  description = "Private subnet CIDR"
  value       = var.enable_private_subnet ? google_compute_subnetwork.private[0].ip_cidr_range : null
}

output "ssh_firewall_name" {
  description = "SSH firewall rule name"
  value       = var.create_ssh_firewall ? google_compute_firewall.ssh[0].name : null
}

output "web_firewall_name" {
  description = "Web firewall rule name"
  value       = var.create_web_firewall ? google_compute_firewall.web[0].name : null
}

output "ssh_target_tag" {
  description = "Network tag for SSH access"
  value       = "ssh"
}

output "web_target_tag" {
  description = "Network tag for web access"
  value       = "web"
}

output "router_name" {
  description = "Cloud Router name"
  value       = var.enable_cloud_nat ? google_compute_router.lab[0].name : null
}

output "nat_name" {
  description = "Cloud NAT name"
  value       = var.enable_cloud_nat ? google_compute_router_nat.lab[0].name : null
}