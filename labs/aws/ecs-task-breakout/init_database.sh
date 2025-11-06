#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Database Initialization ==="
echo ""

if [ ! -f "terraform.tfstate" ]; then
    echo "Error: Terraform state not found"
    exit 1
fi

DB_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null)
DB_NAME=$(terraform output -raw db_name 2>/dev/null)
SECRET_ARN=$(terraform output -raw secrets_manager_arn 2>/dev/null)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-gov-east-1")

if [ -z "$DB_ENDPOINT" ] || [ -z "$SECRET_ARN" ]; then
    echo "Error: Could not retrieve database details from Terraform"
    exit 1
fi

echo "Database: $DB_ENDPOINT"
echo "Secret: $SECRET_ARN"
echo ""

echo "Retrieving credentials from Secrets Manager..."
SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_ARN" \
    --region "$REGION" \
    --query SecretString \
    --output text)

DB_USER=$(echo "$SECRET_JSON" | jq -r '.username')
DB_PASS=$(echo "$SECRET_JSON" | jq -r '.password')

if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
    echo "Error: Could not parse credentials"
    exit 1
fi

export PGPASSWORD="$DB_PASS"

echo "Testing database connection..."
if ! psql -h "$DB_ENDPOINT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" > /dev/null 2>&1; then
    echo "Error: Cannot connect to database"
    echo "Ensure psql is installed and RDS security group allows your IP"
    exit 1
fi

echo "Initializing database schema and data..."
psql -h "$DB_ENDPOINT" -U "$DB_USER" -d "$DB_NAME" -f app/init.sql

echo ""
echo "=== Database initialized successfully ==="
echo ""
echo "Verify with:"
echo "  psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME"
echo ""