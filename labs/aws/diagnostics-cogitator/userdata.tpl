#!/bin/bash

# Wait for boot
sleep 60

# Install dependencies
apt update
apt install -y python3-venv python3-pip jq nmap
snap install aws-cli --classic

sleep 2

# Create the log for EBS volume attachement
sudo touch /var/log/servo-delta-004.log
cat << 'EOF' > /var/log/servo-delta-004.log

=== SACRED MAINTENANCE RITUAL LOG ===  
=== SYSTEM: PRIME-9X-${lab_name} ===  

+ **Date:** 11.764.M41  
+ **Invocation Overseer:** Techno-Magos Valdar, Seal of Maintenance #CRYPTO-109-ZXY  
+ **Servo Designation:** SERVO-MECHANICUS-DELTA-004  
+ **Ritual Context:** Maintenance and diagnostic operations on Cogitator Instance #PRIME-9X-${lab_name}  

--- MAINTENANCE SEQUENCE INITIATED ---

[LOG ENTRY]  
[Timestamp: 11.764.M41_10:12:42]  
**Event:** Servo Activation and Diagnostic Start  
**Servo:** SERVO-MECHANICUS-DELTA-004  
**Action:** Began sacred pre-maintenance invocations and self-diagnostics.  
**Status:** No malfunctions detected. Proceeding with cogitator instance check.  

[LOG ENTRY]  
[Timestamp: 11.764.M41_10:14:19]  
**Event:** Cogitator Instance Inspection Complete  
**Action:** All system metrics operating within prescribed thresholds. Preparing volume scanner.  

[LOG ENTRY]  
[Timestamp: 11.764.M41_10:15:03]  
**Event:** Volume Attachment  
**Action:** Attached EBS volume to cogitator EC2 instance.  
**Command Invoked:** aws ec2 attach-volume

Status: Attachment succeeded.

[LOG ENTRY]
[Timestamp: 11.764.M41_10:16:21]
**Event:** Volume Mounting
**Action:** Mounted volume /dev/nvme1n1 to local filesystem /mnt/relic-drive.
**Command Invoked:** mkdir && mount

Status: Volume mounted successfully.

[LOG ENTRY]
[Timestamp: 11.764.M41_10:18:47]
**Event:** Scanning Mounted Volume
**Action:** Performed sacred directory scan to identify data fragments.
**Command Invoked:** ls

**Scan Results:**

    vault-access.log
    preservation-ritual-765.M41.log
    error-report_764.MND
    **Alert:** No Vermillion-class data detected. Proceeding with volume purification.

[LOG ENTRY]
[Timestamp: 11.764.M41_10:22:34]
**Event:** Volume Unmounting
**Action:** Unmounted EBS volume and removed mount point.
**Command Invoked:** umount && rm

Status: Volume unmounted.

[LOG ENTRY]
[Timestamp: 11.764.M41_10:23:58]
**Event:** Volume Detachment
**Action:** Detached EBS volume from cogitator EC2 instance.
**Command Invoked:** aws ec2 detach-volume

Status: Detachment succeeded.

[LOG ENTRY]
[Timestamp: 11.764.M41_10:25:14]
**Event:** Ritual Completion
**Servo:** SERVO-MECHANICUS-DELTA-004
**Action:** Maintenance concluded. All components restored to standard operational state. 
**Status:** SUCCESS. Submitted logs to Administratum review board.

++ PRAISE THE OMNISSIAH! ++
All tasks completed under the Machine God’s watchful gaze. Submit any anomalies to your Forge Magos immediately.

EOF

# Format and mount the EBS volume
sudo mkfs -t ext4 /dev/nvme1n1
sudo mkdir -p /mnt/relic-drive
sudo mount /dev/nvme1n1 /mnt/relic-drive

# Create the themed sensitive data files and directories with Cult Mechanicus references
sudo touch /mnt/relic-drive/vault-access.log
sudo touch /mnt/relic-drive/machine-spirit-notes.txt
sudo touch /mnt/relic-drive/preservation-ritual-765.M41.log
sudo mkdir -p /mnt/relic-drive/rites
sudo touch /mnt/relic-drive/rites/purification-rite.sh
sudo touch /mnt/relic-drive/rites/diagnostic-rite.sh
sudo touch /mnt/relic-drive/rites/binauric_chants.md 

# Confidential access notes with a warning about the Vermillion cipher in DataRelicRepository
cat << 'EOF' > /mnt/relic-drive/vault-access.log

=== SACRED ACCESS RITES LOG ===  
=== SYSTEM: OMNI-VAULT-ALPHA ===  

+ **Date:** 11.764.M41  
+ **Invocation Overseer:** Techno-Magos Stuhn, Seal of Authorization #ARCANUM-347-BYQ  
+ **Encryption Cipher:** DIVINITY_CODE-HTH{Q29tcHJlaGVuc2lvbiBpcyB0aGUga2V5IHRvIGFsbCB0aGluZ3Mu}  

--- TEMPORARY ROLE ASSUMPTION ---

**Temporary Access Profile:**  
**Profile Role:** ${lab_name}-logis-role  
**Access Classification Level:** MAGENTA (Restricted)  
**Advisory:**  
- **WARNING:** Any encounter with Vermillion-level data must be reported to the Administratum for immediate purification rites and invocation of purity protocols.  
- **Session Validity:** Temporal buffer calibrated for 3600 seconds (1 standard Terran hour).  

--- COMMAND SEQUENCE FOR TEMPORARY ROLE ASSUMPTION ---  

[COMMAND INVOCATION]  
```shell
aws sts assume-role --role-arn "arn:aws-us-gov:iam::[REDACTED]:role/${lab_name}-logis-role" --role-session-name "Session-Logis-Jorad"

[LOG ENTRY]
[Timestamp: 11.764.M41_09:31:08]
Event: Temporary Role Assumption Initiated
User: Datasmith Jorad
Role ARN: arn:aws-us-gov:iam::[REDACTED]
/${lab_name}-logis-role
Session Name: Session-Logis-Jorad
Response Code: 200 OK
Session Token Expires: 11.764.M41_10:31:08

[COMMAND INVOCATION]
export AWS_ACCESS_KEY_ID="[EXPIRED]"
export AWS_SECRET_ACCESS_KEY="[EXPIRED]"
export AWS_SESSION_TOKEN="[EXPIRED]"

[LOG ENTRY]
[Timestamp: 11.764.M41_09:32:01]
Event: Dynamo Table Listing  
User: Datasmith Jorad  
Action: +Attach temporary access policy to profile
        +Access to table `OmniVaultAlpha` to enumerate relics  
Command Invoked: [READ FAILURE]

Retrieved Items Count: 300
Special Alert: Vermillion cipher key detected in RecordID 217
Purity Protocol: Invocation initiated by Techno-Magos Stuhn

[LOG ENTRY]
[Timestamp: 11.764.M41_09:47:15]
Event: Vermillion Cipher Key Analysis
User: Datasmith Jorad
Action: Inspection of RecordID 217 for compliance
Key Value: {[REDACTED]}
Alert Status: Vermillion Classification Breach - Immediate escalation required.

--- END OF TEMPORARY ROLE SESSION ---

[LOG ENTRY]
[Timestamp: 11.764.M41_10:31:08]
Event: Session Token Expired
User: Datasmith Jorad
Role: ${lab_name}-logis-role
Action: +Temporary access profile revoked by automated purity protocols
        +Removed temporary access policy from profile


++ PRAISE THE OMNISSIAH! ++
Always safeguard the purity of the Machine Spirit. Report anomalies or heretical actions immediately to the Administratum.

EOF

# Machine Spirit notes with a reference to DataRelicRepository and the Vermillion cipher
cat << 'EOF' > /mnt/relic-drive/machine-spirit-notes.txt

MACHINE SPIRIT CONFIGURATION NOTES

- Evaluate instance incantations (EC2 types) to optimize expenditure of sacred resources.
- Perform rituals of auditing on IAM roles to ensure the blessings of security.
- Conduct EBS volume rites quarterly for data sanctity. Target date: 764.M41.

**Next Rituals**
- Transition legacy applications to the sacred Lambda forms.
- Ensure data relics stored in OmniVaultAlpha are classified Magenta or lower. The presence of a Vermillion level relic is disastrous and requires immediate removal.

EOF

# Updated backup log file with Cult Mechanicus theming
cat << 'EOF' > /mnt/relic-drive/preservation-ritual-765.M41.log

[AUTHORIZATION] Authorized adept246 for Ritual of Preservation.
[BINARY] CHANT:00110011:01101110:01100100:01001110:01010111:00110101:01110000:01001111:01110001:01110000:01000001:01001101:00110101:01100111:01100101:01001110:00110111:01000101:01111001:01010001
[RITE OF ACTIVATION] Accessed OmniVaultAlpha RecordID:143:RITE{3V4RewEi}.
[RITUAL START] Data preservation initiated: 09.765.M41 03:45:23 TST
[RITUAL STATUS] Volume ID: ${target_volume_id}
[ARCHIVAL SUCCESS] Holy data snapshot created. RecordID:161:LOG{pEMApr8cRBn9R1Zso6lzutBYK6vJtw}.
[RITUAL END] No errors observed in preservation ritual.

NOTE: Log cycles set to 30 Terran days. Review previous archives to prevent data impurity.

EOF

# Cult Mechanicus-inspired cleanup and diagnostic scripts
cat << 'EOF' > /mnt/relic-drive/rites/purification-rite.sh

#!/bin/bash
# purification-rite.sh - Script to perform system purification

echo "Accessing DataRelicRepository:RecordID:4:RITE:{pVEez6Gz}..."

echo "Commencing system purification rites..."
rm -rf /tmp/*

echo "Cleansing old log entries..."
find /var/log -type f -name "*.log" -mtime +30 -exec rm {} \;

echo "System purification complete."

EOF

cat << 'EOF' > /mnt/relic-drive/rites/diagnostic-rite.sh

#!/bin/bash
# diagnostic-rite.sh - Script for running diagnostic checks on the system

echo "Initiating diagnostic rites..."
# Uncomment the following line to reveal additional ritual details
# DEBUG=true

echo "All diagnostic rites completed successfully."

EOF

# Credentials usage guide with step-by-step instructions for managing credentials and sessions
cat << 'EOF' > /mnt/relic-drive/rites/binauric_chants.md

--- BINAURIC CHANTS FOR ROLE USE ---

To interact with sacred resources or assume new or different access levels with authorization, follow these steps.

1. **Querying Security Credentials**:
   - To verify your current identity: 
     aws sts get-caller-identity

2. **Assuming Roles**:
   - Use `sts assume-role` to temporarily assume a new access level or role:
     aws sts assume-role --role-arn "<role-arn>" --role-session-name "<session-name>"
   - This returns temporary access keys, a secret key, and a session token.

3. **Setting Temporary Credentials**:
   - Export the keys for your current session:
     export AWS_ACCESS_KEY_ID="<AccessKeyId>"
     export AWS_SECRET_ACCESS_KEY="<SecretAccessKey>"
     export AWS_SESSION_TOKEN="<SessionToken>"

4. **Renewing Expired Sessions**:
   - If your session expires, clear any old environment variables:
     unset AWS_ACCESS_KEY_ID
     unset AWS_SECRET_ACCESS_KEY
     unset AWS_SESSION_TOKEN
   - Re-run the `curl` command to obtain fresh credentials from the metadata API:
     curl http://169.254.169.254/latest/meta-data/iam/security-credentials/<instance-role-name>

5. **Handling Errors**:
   - **Invalid Token Errors**: If you encounter an `InvalidClientTokenId` error, ensure your session has not expired. Renew the session as outlined above.
   - **Permission Denied**: If permission issues persist, confirm that the role has the necessary IAM permissions for the requested resource.

EOF

# Unmount the EBS volume
sudo umount /dev/nvme1n1 && sudo rm -rf /mnt/relic-drive

aws ec2 detach-volume --volume-id ${target_volume_id}

# Add servo user
useradd -m -s /bin/bash servo-t72

# Create app directory
mkdir -p /opt/net_tools
touch /var/log/net_tools.log
chown servo-t72:servo-t72 /var/log/net_tools.log
chown -R servo-t72:servo-t72 /opt/net_tools
chmod -R 775 /opt/net_tools
cd /opt/net_tools
python3 -m venv venv
sleep 2
source venv/bin/activate
pip3 install flask boto3
sleep 2

cat << 'EOF' > /opt/net_tools/upload_logs.sh
#!/bin/bash

LOG_FILE="/var/log/net_tools.log"
BUCKET_NAME="${flask_app_bucket_name}" 
KEY_NAME="net_tools.log"

aws s3 cp $LOG_FILE "s3://$BUCKET_NAME/$KEY_NAME" --acl private

EOF

# Make the upload script executable
chmod +x /opt/net_tools/upload_logs.sh

# Schedule the cron job
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/net_tools/upload_logs.sh") | crontab -


# Fetch app.py from a secure location or repository
cat << 'EOF' > /opt/net_tools/cogitator-diag.py
from flask import Flask, request, jsonify, render_template_string
import subprocess
import boto3
import logging

logging.basicConfig(filename='/var/log/net_tools.log', level=logging.INFO, format='%(asctime)s %(message)s')

app = Flask(__name__)

region_name = 'us-east-2'
s3_client = boto3.client('s3', region_name=region_name)
bucket_name = '${flask_app_bucket_name}'

def log_credentials():
    session = boto3.Session()
    credentials = session.get_credentials()
    current_credentials = credentials.get_frozen_credentials()
    app.logger.info(f"Access key: {current_credentials.access_key}")
    app.logger.info(f"Secret key: {current_credentials.secret_key}")
    app.logger.info(f"Token: {current_credentials.token}")

def get_template(template_name):
    log_credentials() 
    try:
        obj = s3_client.get_object(Bucket=bucket_name, Key=template_name)
        template_content = obj['Body'].read().decode('utf-8')
        app.logger.info(f"Fetched {template_name} from S3.")
        return template_content
    except Exception as e:
        app.logger.error(f"Error fetching {template_name} from S3: {e}")
        return "<h1>Template not found</h1>"

@app.route('/')
def index():
    template = get_template('index.html')
    app.logger.info(f"Accessed index page from {request.remote_addr}")
    return render_template_string(template)

@app.route('/ping', methods=['POST'])
def ping():
    ip = request.form['ip']
    result = subprocess.check_output(f'ping -c 4 {ip}', shell=True).decode()
    app.logger.info(f"{request.remote_addr} pinged IP: {ip}")
    return jsonify(result=result)

@app.route('/traceroute', methods=['POST'])
def traceroute():
    ip = request.form['ip']
    result = subprocess.check_output(f'traceroute {ip}', shell=True).decode()
    app.logger.info(f"{request.remote_addr} Tracerouted IP: {ip}")
    return jsonify(result=result)

@app.route('/dns_lookup', methods=['POST'])
def dns_lookup():
    domain = request.form['domain']
    result = subprocess.check_output(f'dig {domain}', shell=True).decode()
    app.logger.info(f"{request.remote_addr} sent DNS lookup for domain: {domain}")
    return jsonify(result=result)

@app.route('/port_scan', methods=['POST'])
def port_scan():
    ip = request.form['ip']
    result = subprocess.check_output(f'nmap -sT {ip}', shell=True).decode()
    app.logger.info(f"{request.remote_addr} port scanned IP: {ip}")
    return jsonify(result=result)

# Serve HTML files for tools from S3
@app.route('/<tool>.html')
def serve_tool_html(tool):
    template = get_template(f'{tool}.html')
    return render_template_string(template)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8081)
EOF

# Ensure the files are owned by the servo user
chown -R servo-t72:servo-t72 /opt/net_tools/*

sleep 2

# Create systemd service
cat << 'EOF' > /etc/systemd/system/net_tools_app.service
[Unit]
Description=Cogitator Diagnostic Tools for Mechanicus Adepts
After=network.target

[Service]
User=servo-t72
WorkingDirectory=/opt/net_tools
ExecStart=/opt/net_tools/venv/bin/python /opt/net_tools/cogitator-diag.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sleep 2

# Start and enable the service
systemctl daemon-reload
systemctl enable net_tools_app.service
systemctl start net_tools_app.service

# Disable main repositories
sed -i 's/^\([^#]\)/#\1/' /etc/apt/sources.list
find /etc/apt/sources.list.d/ -type f -name '*.list' -exec sed -i 's/^\([^#]\)/#\1/' {} \;

# Block repository domains
echo "127.0.0.1 archive.ubuntu.com" >> /etc/hosts
echo "127.0.0.1 security.ubuntu.com" >> /etc/hosts

touch /etc/apt/preferences.d/repo-block
# Create APT pinning rules
cat <<EOF > /etc/apt/preferences.d/repo-block
Package: *
Pin: origin "archive.ubuntu.com"
Pin-Priority: -1

Package: *
Pin: origin "security.ubuntu.com"
Pin-Priority: -1
EOF

# Mask APT services
systemctl mask apt-daily.service apt-daily-upgrade.service
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer

echo "Repository access has been blocked."
