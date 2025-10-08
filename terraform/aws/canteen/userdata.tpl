#!/bin/bash

# Wait for boot
sleep 60

# Install dependencies
apt update
apt install -y python3-venv python3-pip jq nmap
snap install aws-cli --classic

sleep 2

# Format and mount the EBS volume
sudo mkfs -t ext4 /dev/nvme1n1
sudo mkdir -p /mnt/dev
sudo mount /dev/nvme1n1 /mnt/dev

# Create the sensitive data file
sudo touch /mnt/dev/workshop_keys.txt
echo "WORKSHOP_USER_USERNAME=${workshop_user_username}" | sudo tee -a /mnt/dev/workshop_keys.txt
echo "WORKSHOP_USER_PASSWORD=${workshop_user_password}" | sudo tee -a /mnt/dev/workshop_keys.txt
echo "SIGNIN_URL=${signin_url}" | sudo tee -a /mnt/dev/workshop_keys.txt

# Verify the file content
cat /mnt/dev/workshop_keys.txt

# Unmount the EBS volume
sudo umount /mnt/dev

aws ec2 detach-volume --volume-id ${target_volume_id}

# Add canteen user
useradd -m -s /bin/bash canteen

# Create app directory
mkdir -p /opt/net_tools
touch /var/log/net_tools.log
chown canteen:canteen /var/log/net_tools.log
chown -R canteen:canteen /opt/net_tools
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
cat << 'EOF' > /opt/net_tools/app.py
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
    log_credentials()  # Log credentials before attempting to fetch the template
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

# Ensure the files are owned by the canteen user
chown -R canteen:canteen /opt/net_tools/*

sleep 2

# Create systemd service
cat << 'EOF' > /etc/systemd/system/net_tools_app.service
[Unit]
Description=Network Diagnostic Tools for Network Admins
After=network.target

[Service]
User=canteen
WorkingDirectory=/opt/net_tools
ExecStart=/opt/net_tools/venv/bin/python /opt/net_tools/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sleep 2

# Start and enable the service
systemctl daemon-reload
systemctl enable net_tools_app.service
systemctl start net_tools_app.service