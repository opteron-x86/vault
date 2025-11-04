output "analyst_access_key_id" {
  description = "AWS Access Key ID for limited analyst user"
  value       = aws_iam_access_key.limited_user.id
}

output "analyst_secret_access_key" {
  description = "AWS Secret Access Key for limited analyst user"
  value       = aws_iam_access_key.limited_user.secret
  sensitive   = true
}

output "analyst_username" {
  description = "IAM username for the analyst account"
  value       = aws_iam_user.limited_user.name
}

output "snapshot_id" {
  description = "ID of the exposed EBS snapshot"
  value       = aws_ebs_snapshot.exposed_snapshot.id
}

output "snapshot_description" {
  description = "Description of the snapshot"
  value       = aws_ebs_snapshot.exposed_snapshot.description
}

output "aws_region" {
  description = "AWS region for resources"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS account ID where resources are deployed"
  value       = data.aws_caller_identity.current.account_id
}

output "lab_instructions" {
  description = "Quick start instructions"
  value       = <<-EOT
    
    === EBS Snapshot Exploitation Lab ===
    
    1. Configure AWS CLI with analyst credentials:
       aws configure set aws_access_key_id ${aws_iam_access_key.limited_user.id}
       aws configure set aws_secret_access_key ${aws_iam_access_key.limited_user.secret}
       aws configure set region ${var.aws_region}
    
    2. Enumerate snapshots:
       aws ec2 describe-snapshots --region ${var.aws_region}
       aws ec2 describe-snapshots --region ${var.aws_region} --restorable-by-user-ids all
    
    3. Look for publicly accessible snapshots from this account
    
    To view the secret access key after deployment:
       terraform output -raw analyst_secret_access_key
    
    EOT
}

output "attack_chain_overview" {
  description = "High-level attack path"
  value       = "IAM User → Enumerate Public Snapshots → Create Volume from Snapshot → Attach to Instance → Mount Volume → Extract Credentials"
}

output "cleanup_note" {
  description = "Important cleanup information"
  value       = "The original EC2 instance can be terminated after snapshot creation. The snapshot remains accessible for the attack scenario."
}