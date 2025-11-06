#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/.state/aws_ecs-task-breakout/terraform.tfstate"

echo "=== Database Initialization ==="
echo ""

if [ ! -f "$STATE_FILE" ]; then
    echo "Error: Terraform state not found at $STATE_FILE"
    exit 1
fi

cd "$SCRIPT_DIR"

DB_ENDPOINT=$(terraform output -state="$STATE_FILE" -raw rds_endpoint 2>/dev/null)
DB_NAME=$(terraform output -state="$STATE_FILE" -raw db_name 2>/dev/null)
SECRET_ARN=$(terraform output -state="$STATE_FILE" -raw secrets_manager_arn 2>/dev/null)
REGION=$(terraform output -state="$STATE_FILE" -raw aws_region 2>/dev/null || echo "us-gov-east-1")

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