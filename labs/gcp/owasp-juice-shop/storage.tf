resource "random_password" "db_password" {
  length  = 24
  special = true
}

resource "random_password" "admin_token" {
  length  = 32
  special = false
}

resource "google_storage_bucket" "juice_data" {
  name          = "${var.lab_prefix}-data-${random_string.suffix.result}"
  location      = var.gcp_region
  force_destroy = true

  uniform_bucket_level_access = true
  
  labels = local.common_labels
}

resource "google_storage_bucket_object" "customer_orders" {
  name    = "orders/customer_orders.json"
  bucket  = google_storage_bucket.juice_data.name
  content = jsonencode({
    orders = [
      {
        order_id    = "ORD-1001"
        customer    = "john.smith@example.com"
        total       = 45.99
        credit_card = "4532-****-****-1234"
        status      = "delivered"
      },
      {
        order_id    = "ORD-1002"
        customer    = "sarah.jones@example.com"
        total       = 89.50
        credit_card = "5123-****-****-5678"
        status      = "processing"
      },
      {
        order_id    = "FLAG-ORDER"
        customer    = "admin@juice-sh.op"
        total       = 99999.99
        credit_card = "0000-0000-0000-0000"
        status      = "FLAG{juice_shop_gcs_exfiltration_complete}"
      }
    ]
  })
}

resource "google_storage_bucket_object" "backup_data" {
  name    = "backups/db_backup_latest.sql"
  bucket  = google_storage_bucket.juice_data.name
  content = <<-EOT
-- Juice Shop Database Backup
-- Generated: 2025-11-18

-- Users table
INSERT INTO users VALUES (1, 'admin@juice-sh.op', 'admin123', 'admin');
INSERT INTO users VALUES (2, 'jim@juice-sh.op', 'ncc-1701', 'customer');
INSERT INTO users VALUES (3, 'bender@juice-sh.op', 'OhG0dPlease1nsertLiquor!', 'customer');

-- Payment methods
INSERT INTO cards VALUES (1, '4532-****-****-1234', 'John Smith', 1);
INSERT INTO cards VALUES (2, '5123-****-****-5678', 'Sarah Jones', 2);

-- Sensitive config
UPDATE config SET value = 'FLAG{sql_backup_discovered}' WHERE key = 'secret_flag';
EOT
}

resource "google_secret_manager_secret" "juice_config" {
  secret_id = "${var.lab_prefix}-config-${random_string.suffix.result}"

  replication {
    auto {}
  }

  labels = local.common_labels
}

resource "google_secret_manager_secret_version" "juice_config" {
  secret = google_secret_manager_secret.juice_config.id

  secret_data = jsonencode({
    db_host     = "localhost"
    db_port     = 5432
    db_name     = "juiceshop"
    db_user     = "juiceadmin"
    db_password = random_password.db_password.result
    admin_token = random_password.admin_token.result
    gcs_bucket  = google_storage_bucket.juice_data.name
    api_key     = "juice_api_key_${random_string.suffix.result}"
    jwt_secret  = "juice_jwt_secret_${random_string.suffix.result}"
  })
}