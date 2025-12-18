data "google_project" "current" {
  project_id = var.gcp_project
}

data "google_client_config" "current" {}