resource "google_service_account" "juice_shop" {
  account_id   = "${var.lab_prefix}-sa-${random_string.suffix.result}"
  display_name = "Juice Shop Service Account"
  description  = "Service account for Juice Shop application"
}

resource "google_project_iam_member" "juice_shop_storage" {
  project = var.gcp_project
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.juice_shop.email}"
}

resource "google_project_iam_member" "juice_shop_secrets" {
  project = var.gcp_project
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.juice_shop.email}"
}

resource "google_project_iam_member" "juice_shop_logs" {
  project = var.gcp_project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.juice_shop.email}"
}