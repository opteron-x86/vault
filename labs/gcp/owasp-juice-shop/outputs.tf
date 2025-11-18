output "juice_shop_url" {
  description = "OWASP Juice Shop application URL"
  value       = "http://${google_compute_instance.juice_shop.network_interface[0].access_config[0].nat_ip}:3000"
}

output "ssh_connection" {
  description = "SSH connection string"
  value       = "gcloud compute ssh ${google_compute_instance.juice_shop.name} --zone=${local.zone} --project=${var.gcp_project}"
}

output "instance_name" {
  description = "GCE instance name"
  value       = google_compute_instance.juice_shop.name
}

output "service_account" {
  description = "Service account email"
  value       = google_service_account.juice_shop.email
}

output "data_bucket" {
  description = "GCS bucket containing application data"
  value       = google_storage_bucket.juice_data.name
}

output "secret_id" {
  description = "Secret Manager secret ID"
  value       = google_secret_manager_secret.juice_config.secret_id
}

output "admin_token" {
  description = "Admin API token"
  value       = random_password.admin_token.result
  sensitive   = true
}

output "external_ip" {
  description = "Instance external IP address"
  value       = google_compute_instance.juice_shop.network_interface[0].access_config[0].nat_ip
}

output "attack_chain_hint" {
  description = "Starting point for the lab"
  value       = "Access Juice Shop on port 3000 and explore the application for vulnerabilities"
}