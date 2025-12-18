# Developer service account - initial access point
resource "google_service_account" "developer" {
  account_id   = "${var.lab_prefix}-developer-${random_string.suffix.result}"
  display_name = "Developer Service Account"
  description  = "Service account for application developers"
}

resource "google_service_account_key" "developer" {
  service_account_id = google_service_account.developer.name
}

# Developer base permissions - read-only enumeration
resource "google_project_iam_custom_role" "developer_base" {
  role_id     = replace("${var.lab_prefix}_developer_base_${random_string.suffix.result}", "-", "_")
  title       = "Developer Base Permissions"
  description = "Read-only permissions for developers"
  permissions = [
    "iam.serviceAccounts.list",
    "iam.serviceAccounts.get",
    "iam.serviceAccountKeys.list",
    "iam.roles.list",
    "iam.roles.get",
    "resourcemanager.projects.get",
    "storage.buckets.list",
    "storage.buckets.get",
    "logging.logEntries.create",
  ]
}

resource "google_project_iam_member" "developer_base" {
  project = var.gcp_project
  role    = google_project_iam_custom_role.developer_base.id
  member  = "serviceAccount:${google_service_account.developer.email}"
}

# Vulnerability: Developer can modify IAM policy on service accounts
# Intended for "self-service" key rotation, but scoped too broadly
resource "google_project_iam_custom_role" "developer_self_service" {
  role_id     = replace("${var.lab_prefix}_developer_self_svc_${random_string.suffix.result}", "-", "_")
  title       = "Developer Self-Service"
  description = "Self-service permissions for developers"
  permissions = [
    "iam.serviceAccounts.getIamPolicy",
    "iam.serviceAccounts.setIamPolicy",
    "iam.serviceAccountKeys.create",
    "iam.serviceAccountKeys.delete",
  ]
}

resource "google_project_iam_member" "developer_self_service" {
  project = var.gcp_project
  role    = google_project_iam_custom_role.developer_self_service.id
  member  = "serviceAccount:${google_service_account.developer.email}"
}

# Admin automation service account - target for impersonation
resource "google_service_account" "admin_automation" {
  account_id   = "${var.lab_prefix}-admin-auto-${random_string.suffix.result}"
  display_name = "Admin Automation Service Account"
  description  = "Service account for automated administrative tasks"
}

resource "google_storage_bucket_iam_member" "admin_storage_access" {
  bucket = google_storage_bucket.protected_data.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.admin_automation.email}"
}

# Audit logging (optional)
resource "google_project_iam_audit_config" "iam_audit" {
  count   = var.enable_audit_logging ? 1 : 0
  project = var.gcp_project
  service = "iam.googleapis.com"

  audit_log_config {
    log_type = "ADMIN_READ"
  }
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