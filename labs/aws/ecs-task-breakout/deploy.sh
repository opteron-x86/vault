#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== ECS Task Breakout Lab Deployment ==="
echo ""

if [ ! -f "terraform.tfstate" ]; then
    echo "Error: Terraform state not found. Deploy the lab first with 'vault deploy aws/ecs-task-breakout'"
    exit 1
fi

ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-gov-east-1")
CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null)
SERVICE=$(terraform output -raw ecs_service_name 2>/dev/null)

if [ -z "$ECR_REPO" ]; then
    echo "Error: Could not determine ECR repository URL"
    exit 1
fi

echo "ECR Repository: $ECR_REPO"
echo "Region: $REGION"
echo ""

echo "[1/5] Authenticating to ECR..."
aws ecr get-login-password --region "$REGION" | \
    docker login --username AWS --password-stdin "$ECR_REPO"

echo ""
echo "[2/5] Building Docker image..."
cd app
docker build -t "$ECR_REPO:latest" .

echo ""
echo "[3/5] Pushing image to ECR..."
docker push "$ECR_REPO:latest"

echo ""
echo "[4/5] Forcing ECS service update..."
aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$SERVICE" \
    --force-new-deployment \
    --region "$REGION" > /dev/null

echo ""
echo "[5/5] Waiting for deployment (this may take 2-3 minutes)..."
aws ecs wait services-stable \
    --cluster "$CLUSTER" \
    --services "$SERVICE" \
    --region "$REGION"

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Application endpoint:"
terraform output alb_endpoint
echo ""
echo "To initialize the database, run:"
echo "  ./init_database.sh"
echo ""