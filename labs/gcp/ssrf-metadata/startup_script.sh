#!/bin/bash
set -e

apt-get update
apt-get install -y python3 python3-pip python3-venv

python3 -m venv /opt/webapp
/opt/webapp/bin/pip install flask requests

cat > /opt/webapp/app.py << 'PYAPP'
from flask import Flask, request, jsonify
import requests

app = Flask(__name__)

@app.route('/')
def index():
    return '''
    <h1>URL Inspector Service</h1>
    <p>Internal tool for checking URL accessibility</p>
    <form action="/check" method="get">
        <input type="text" name="url" placeholder="Enter URL to check" size="50">
        <input type="submit" value="Check URL">
    </form>
    '''

@app.route('/check')
def check_url():
    url = request.args.get('url')
    if not url:
        return jsonify({'error': 'No URL provided'}), 400
    
    try:
        headers = {}
        if 'metadata.google.internal' in url or '169.254.169.254' in url:
            headers['Metadata-Flavor'] = 'Google'
        
        response = requests.get(url, headers=headers, timeout=5)
        return jsonify({
            'url': url,
            'status_code': response.status_code,
            'content_preview': response.text[:2000]
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health():
    return 'OK'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
PYAPP

cat > /etc/systemd/system/webapp.service << 'SYSD'
[Unit]
Description=URL Inspector Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/webapp
ExecStart=/opt/webapp/bin/python /opt/webapp/app.py
Restart=always

[Install]
WantedBy=multi-user.target
SYSD

systemctl daemon-reload
systemctl enable webapp
systemctl start webapp

echo "Configuration note: Data processor SA: ${data_processor_sa}" >> /var/log/application-setup.log
echo "Project: ${gcp_project}" >> /var/log/application-setup.log

shutdown -h +240 &