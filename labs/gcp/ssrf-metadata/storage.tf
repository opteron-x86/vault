resource "google_storage_bucket" "sensitive_data" {
  name          = "${var.lab_prefix}-customer-data-${random_string.suffix.result}"
  location      = var.gcp_region
  force_destroy = true

  uniform_bucket_level_access = true

  labels = merge(local.common_labels, {
    data_classification = "internal"
  })
}

resource "google_storage_bucket_object" "customer_data" {
  name    = "customers/customer_database.csv"
  bucket  = google_storage_bucket.sensitive_data.name
  content = <<-EOT
customer_id,name,email,credit_card_last4,account_balance
1001,John Smith,jsmith@example.com,4532,15430.50
1002,Sarah Johnson,sjohnson@example.com,8921,8750.00
1003,Michael Brown,mbrown@example.com,3467,22100.75
1004,Emma Wilson,ewilson@example.com,9823,5600.25
1005,FLAG{gcp_metadata_to_impersonation_complete},flag@example.com,0000,999999.99
EOT
}

resource "google_storage_bucket_object" "api_keys" {
  name   = "config/api_keys.json"
  bucket = google_storage_bucket.sensitive_data.name
  content = jsonencode({
    production = {
      stripe_key   = "sk_live_simulated_key_do_not_use"
      db_password  = "SuperSecretPassword123!"
      api_endpoint = "https://internal-api.example.com"
    }
  })
}