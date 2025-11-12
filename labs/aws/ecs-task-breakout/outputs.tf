output "alb_endpoint" {
  description = "Application Load Balancer DNS name"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing images"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "task_role_arn" {
  description = "ECS task role ARN (overly permissive)"
  value       = aws_iam_role.ecs_task_role.arn
}

output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.main.address
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "s3_bucket" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.app_data.id
}

output "secrets_manager_arn" {
  description = "Secrets Manager secret ARN"
  value       = aws_secretsmanager_secret.db_creds.arn
}

output "build_instructions" {
  description = "Instructions for building and pushing the Docker image"
  value       = <<-EOT
    
    === Build and Deploy Container Image ===
    
    1. Authenticate to ECR:
       aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}
    
    2. Build the Docker image:
       cd labs/aws/ecs-task-breakout/app
       docker build -t ${aws_ecr_repository.app.repository_url}:latest .
    
    3. Push to ECR:
       docker push ${aws_ecr_repository.app.repository_url}:latest
    
    4. Force new deployment:
       aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${aws_ecs_service.app.name} --force-new-deployment --region ${var.aws_region}
    
    5. Wait for deployment (2-3 minutes)
    
    6. Access application:
       ${aws_lb.main.dns_name}
    
    EOT
}

output "attack_start" {
  description = "Initial attack entry point"
  value       = "http://${aws_lb.main.dns_name}/debug"
}

output "attack_chain_overview" {
  description = "High-level attack path"
  value       = "ALB → Task Metadata Endpoint → Extract Role Credentials → ECR Image Pull → Credential Discovery → RDS Access"
}

