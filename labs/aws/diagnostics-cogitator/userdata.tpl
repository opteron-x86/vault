#!/bin/bash
set -e

# Wait for system initialization
sleep 30

# Install dependencies (AWS CLI pre-installed on AL2023)
dnf update -y
dnf install -y python3 python3-pip jq nmap bind-utils traceroute

# === EBS VOLUME SETUP (runs once during initialization) ===

# Get instance metadata
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)
REGION=$(ec2-metadata --availability-zone | cut -d ' ' -f 2 | sed 's/[a-z]$//')

# Attach the EBS volume using AWS CLI
echo "Attaching EBS volume ${volume_id}..."
aws ec2 attach-volume \
  --volume-id ${volume_id} \
  --instance-id $INSTANCE_ID \
  --device /dev/sdf \
  --region $REGION

# Wait for volume to appear (Nitro instances use nvme devices)
echo "Waiting for volume to be available..."
for i in {1..60}; do
    if [ -e /dev/nvme1n1 ]; then
        echo "Volume detected at /dev/nvme1n1"
        break
    fi
    sleep 2
done

# Format and mount the volume
mkfs -t ext4 /dev/nvme1n1
mkdir -p /mnt/evidence-vault
mount /dev/nvme1n1 /mnt/evidence-vault

# Populate volume with evidence and hints
cat > /mnt/evidence-vault/vault-access.log << 'EOF'
=== MAINTENANCE LOG - COGITATOR INSTANCE ${lab_name} ===
Date: 764.M41
Technician: Adept Jorad
Classification: MAGENTA

--- ROLE ASSUMPTION PROCEDURE ---

The secondary logis role provides extended privileges for data processing tasks.
Role ARN: ${logis_role_arn}

Standard assumption command:
aws sts assume-role \
  --role-arn "${logis_role_arn}" \
  --role-session-name maintenance-session

After assumption, export credentials:
export AWS_ACCESS_KEY_ID="<AccessKeyId>"
export AWS_SECRET_ACCESS_KEY="<SecretAccessKey>"
export AWS_SESSION_TOKEN="<SessionToken>"

Session duration: 3600 seconds (1 hour)

--- KNOWN ISSUES ---
- Logis role lacks direct database access
- Requires policy attachment for DynamoDB operations
- Use IAM permissions to attach AmazonDynamoDBReadOnlyAccess
- Target table: ${dynamodb_table}

FLAG{ebs_forensics_role_assumption_discovered}
EOF

cat > /mnt/evidence-vault/system-notes.txt << 'EOF'
SYSTEM CONFIGURATION NOTES

Current Infrastructure:
- EC2 Instance Type: t3.micro
- IAM Instance Profile: Primary access role
- Secondary Role: Logis role (assumable)
- Data Store: DynamoDB table for classified records

Security Posture:
- IAM roles follow separation of duties
- EBS volumes detached when not in use
- DynamoDB contains 300+ classified records
- Vermillion-level data requires special authorization

Maintenance Schedule:
- Log uploads: Every 5 minutes via cron
- Volume backups: Weekly
- Credential rotation: Monthly

Notes on Data Classification:
- MAGENTA: Standard operational data
- VERMILLION: Highly sensitive, requires escalated access
- Database contains mix of both classifications
EOF

cat > /mnt/evidence-vault/access-log-764.M41.txt << 'EOF'
[2024-11-15 09:31:08] Role assumption initiated by Adept Jorad
[2024-11-15 09:31:09] Assumed role: ${lab_name}-logis-role
[2024-11-15 09:32:01] DynamoDB table scan attempted - PERMISSION DENIED
[2024-11-15 09:33:15] Attached policy: AmazonDynamoDBReadOnlyAccess
[2024-11-15 09:33:45] DynamoDB access successful
[2024-11-15 09:47:15] Vermillion cipher detected in RecordID 217
[2024-11-15 10:31:08] Session expired
EOF

# Unmount and detach volume
sync
umount /mnt/evidence-vault
rm -rf /mnt/evidence-vault

# Detach the volume
echo "Detaching volume..."
aws ec2 detach-volume --volume-id ${volume_id} --region $REGION

# Wait for detachment to complete
sleep 10

# === APPLICATION SETUP ===

# Create non-privileged user for Flask app
useradd -m -s /bin/bash servo-t72
usermod -aG sudo servo-t72

# Setup application directory
mkdir -p /opt/net_tools
touch /var/log/net_tools.log
chown servo-t72:servo-t72 /var/log/net_tools.log
chown -R servo-t72:servo-t72 /opt/net_tools
chmod -R 755 /opt/net_tools

# Create Python virtual environment
cd /opt/net_tools
sudo -u servo-t72 python3 -m venv venv
sudo -u servo-t72 /opt/net_tools/venv/bin/pip install flask boto3

# Create the vulnerable Flask application
cat > /opt/net_tools/cogitator-diag.py << 'PYAPP'
from flask import Flask, request, jsonify, render_template_string
import subprocess
import boto3
import logging

logging.basicConfig(
    filename='/var/log/net_tools.log',
    level=logging.INFO,
    format='%(asctime)s %(message)s'
)

app = Flask(__name__)
s3_client = boto3.client('s3')
bucket_name = '${bucket_name}'

def log_credentials():
    """Log IAM credentials for debugging (security anti-pattern)"""
    session = boto3.Session()
    credentials = session.get_credentials()
    if credentials:
        current_creds = credentials.get_frozen_credentials()
        app.logger.info(f"Access key: {current_creds.access_key}")
        app.logger.info(f"Secret key: {current_creds.secret_key}")
        app.logger.info(f"Token: {current_creds.token}")

def get_template(template_name):
    """Fetch HTML templates from S3"""
    log_credentials()
    try:
        obj = s3_client.get_object(Bucket=bucket_name, Key=template_name)
        return obj['Body'].read().decode('utf-8')
    except Exception as e:
        app.logger.error(f"Error fetching {template_name}: {e}")
        return "<h1>Template not found</h1>"

@app.route('/')
def index():
    template = get_template('index.html')
    app.logger.info(f"Index accessed from {request.remote_addr}")
    return render_template_string(template)

@app.route('/ping', methods=['POST'])
def ping():
    """VULNERABLE: Command injection via shell=True"""
    ip = request.form.get('ip', '')
    try:
        result = subprocess.check_output(f'ping -c 4 {ip}', shell=True, timeout=10).decode()
        app.logger.info(f"Ping executed for: {ip}")
        return jsonify(result=result)
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.route('/traceroute', methods=['POST'])
def traceroute():
    """VULNERABLE: Command injection"""
    ip = request.form.get('ip', '')
    try:
        result = subprocess.check_output(f'traceroute -m 15 {ip}', shell=True, timeout=30).decode()
        app.logger.info(f"Traceroute executed for: {ip}")
        return jsonify(result=result)
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.route('/dns_lookup', methods=['POST'])
def dns_lookup():
    """VULNERABLE: Command injection"""
    domain = request.form.get('domain', '')
    try:
        result = subprocess.check_output(f'dig {domain}', shell=True, timeout=10).decode()
        app.logger.info(f"DNS lookup for: {domain}")
        return jsonify(result=result)
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.route('/port_scan', methods=['POST'])
def port_scan():
    """VULNERABLE: Command injection"""
    ip = request.form.get('ip', '')
    try:
        result = subprocess.check_output(f'nmap -sT -T4 --top-ports 20 {ip}', shell=True, timeout=60).decode()
        app.logger.info(f"Port scan for: {ip}")
        return jsonify(result=result)
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.route('/<tool>.html')
def serve_tool_html(tool):
    """Serve tool-specific HTML pages from S3"""
    template = get_template(f'{tool}.html')
    return render_template_string(template)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8081)
PYAPP

chown servo-t72:servo-t72 /opt/net_tools/cogitator-diag.py

# === PRIVILEGE ESCALATION VULNERABILITY ===

# Create log upload script (USER-WRITABLE, ROOT-EXECUTED)
cat > /opt/net_tools/upload_logs.sh << 'SCRIPT'
#!/bin/bash
LOG_FILE="/var/log/net_tools.log"
BUCKET_NAME="${bucket_name}"
KEY_NAME="net_tools.log"

aws s3 cp $LOG_FILE "s3://$BUCKET_NAME/$KEY_NAME" --acl private 2>&1 | logger -t log-upload
SCRIPT

# Make script executable
chmod 755 /opt/net_tools/upload_logs.sh

# CRITICAL: Script owned by servo-t72 (user-writable)
chown servo-t72:servo-t72 /opt/net_tools/upload_logs.sh

# CRITICAL: Cron job runs as ROOT but executes user-writable script
cat > /etc/cron.d/log-upload << 'CRON'
*/5 * * * * root /opt/net_tools/upload_logs.sh
CRON

chmod 644 /etc/cron.d/log-upload

# === SYSTEMD SERVICE ===

cat > /etc/systemd/system/cogitator-diag.service << 'SERVICE'
[Unit]
Description=Cogitator Diagnostic Service
After=network.target

[Service]
Type=simple
User=servo-t72
WorkingDirectory=/opt/net_tools
ExecStart=/opt/net_tools/venv/bin/python /opt/net_tools/cogitator-diag.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

# Start the service
systemctl daemon-reload
systemctl enable cogitator-diag.service
systemctl start cogitator-diag.service

# Block repository access (prevent apt-based persistence)
sed -i 's/^\([^#]\)/#\1/' /etc/apt/sources.list 2>/dev/null || true

echo "Setup complete" | logger -t cogitator-setup