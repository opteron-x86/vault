# Instance service account - attached to the vulnerable webapp
resource "google_service_account" "webapp" {
  account_id   = "${var.lab_prefix}-webapp-${random_string.suffix.result}"
  display_name = "URL Inspector Service Account"
  description  = "Service account for URL Inspector web application"
}

resource "google_project_iam_member" "webapp_logs" {
  project = var.gcp_project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.webapp.email}"
}

# Webapp SA can impersonate the data-processor SA
resource "google_service_account_iam_member" "webapp_can_impersonate" {
  service_account_id = google_service_account.data_processor.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.webapp.email}"
}

# Data processor service account - target for impersonation
resource "google_service_account" "data_processor" {
  account_id   = "${var.lab_prefix}-data-proc-${random_string.suffix.result}"
  display_name = "Data Processor Service Account"
  description  = "Service account for batch data processing jobs"
}

resource "google_storage_bucket_iam_member" "data_processor_access" {
  bucket = google_storage_bucket.sensitive_data.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.data_processor.email}"
}

# Audit logging (optional)
resource "google_project_iam_audit_config" "compute_audit" {
  count   = var.enable_audit_logging ? 1 : 0
  project = var.gcp_project
  service = "compute.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_project_iam_audit_config" "storage_audit" {
  count   = var.enable_audit_logging ? 1 : 0
  project = var.gcp_project
  service = "storage.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}