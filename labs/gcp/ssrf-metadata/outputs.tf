output "service_url" {
  description = "URL Inspector Service endpoint"
  value       = "http://${google_compute_instance.webapp.network_interface[0].access_config[0].nat_ip}:8080"
}

output "ssh_connection" {
  description = "SSH connection string"
  value       = "gcloud compute ssh ${google_compute_instance.webapp.name} --zone=${local.zone} --project=${var.gcp_project}"
}

output "data_bucket" {
  description = "GCS bucket for customer data storage"
  value       = google_storage_bucket.sensitive_data.name
}

output "instance_name" {
  description = "GCE instance name"
  value       = google_compute_instance.webapp.name
}

output "instance_service_account" {
  description = "Service account attached to the instance"
  value       = google_service_account.webapp.email
}

output "data_processor_service_account" {
  description = "Data processor service account (target for impersonation)"
  value       = google_service_account.data_processor.email
}

output "gcp_project" {
  description = "GCP project ID"
  value       = var.gcp_project
}

output "attack_chain_hint" {
  description = "Starting point for the lab"
  value       = "Begin by exploring the URL Inspector service on port 8080"
}