output "developer_service_account" {
  description = "Developer service account email"
  value       = google_service_account.developer.email
}

output "developer_key" {
  description = "Developer service account key (base64 encoded JSON)"
  value       = google_service_account_key.developer.private_key
  sensitive   = true
}

output "protected_bucket_name" {
  description = "GCS bucket containing protected data"
  value       = google_storage_bucket.protected_data.name
}

output "admin_service_account" {
  description = "Admin automation service account email"
  value       = google_service_account.admin_automation.email
}

output "gcp_project" {
  description = "GCP project ID"
  value       = var.gcp_project
}

output "gcp_region" {
  description = "GCP region for lab resources"
  value       = var.gcp_region
}

output "lab_instructions" {
  description = "Instructions for configuring gcloud CLI"
  sensitive   = true
  value       = <<-EOT
Save the service account key and activate it:

terraform output -raw developer_key | base64 -d > developer-key.json
gcloud auth activate-service-account --key-file=developer-key.json
gcloud config set project ${var.gcp_project}

Start by enumerating your IAM permissions:
gcloud iam service-accounts list
gcloud projects get-iam-policy ${var.gcp_project} --flatten="bindings[].members" --filter="bindings.members:${google_service_account.developer.email}"
EOT
}

output "attack_chain_hint" {
  description = "Starting point for the lab"
  value       = "Begin by understanding what permissions your service account has. What can you modify?"
}