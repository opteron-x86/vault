resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  common_labels = {
    environment   = "lab"
    destroyable   = "true"
    scenario      = "iam-privilege-escalation"
    auto_shutdown = "24hours"
  }
}

resource "google_storage_bucket" "protected_data" {
  name          = "${var.lab_prefix}-protected-${random_string.suffix.result}"
  location      = var.gcp_region
  force_destroy = true

  uniform_bucket_level_access = true

  labels = merge(local.common_labels, {
    data_classification = "confidential"
    owner               = "security-team"
  })
}

resource "google_storage_bucket_object" "financial_records" {
  name    = "financial/q4-2024-revenue.csv"
  bucket  = google_storage_bucket.protected_data.name
  content = <<-EOT
department,revenue,expenses,profit_margin
Engineering,2500000,1800000,28.0
Sales,3200000,900000,71.9
Marketing,800000,750000,6.3
Operations,1500000,1200000,20.0
FLAG{gcp_iam_privilege_escalation_successful},999999999,0,100.0
EOT
}

resource "google_storage_bucket_object" "credentials" {
  name   = "secrets/production-credentials.json"
  bucket = google_storage_bucket.protected_data.name
  content = jsonencode({
    database = {
      host     = "prod-db.internal.example.com"
      username = "admin"
      password = "P@ssw0rd_Pr0d_2024!"
    }
    api_keys = {
      stripe   = "sk_live_abc123def456"
      sendgrid = "SG.xyz789.uvw321"
      datadog  = "dd_api_key_prod_456789"
    }
  })
}

resource "google_storage_bucket_object" "architecture_diagram" {
  name    = "docs/infrastructure-architecture.txt"
  bucket  = google_storage_bucket.protected_data.name
  content = <<-EOT
Production Infrastructure Overview
==================================

VPC: 10.0.0.0/16
Public Subnets: 10.0.1.0/24, 10.0.2.0/24
Private Subnets: 10.0.10.0/24, 10.0.11.0/24

Database Tier:
- Cloud SQL PostgreSQL (Regional)
- Memorystore Redis Cluster

Application Tier:
- Cloud Run Services
- Cloud Load Balancer

Note: All production credentials stored in this GCS bucket.
Admin access required for retrieval.
EOT
}