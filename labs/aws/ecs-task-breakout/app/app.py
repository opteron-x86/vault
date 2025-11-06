#!/usr/bin/env python3
import os
import requests
from flask import Flask, request, jsonify, render_template_string

app = Flask(__name__)

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>MetricStream Analytics Platform</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .endpoint { background: #f9f9f9; padding: 15px; margin: 10px 0; border-left: 4px solid #007bff; }
        .endpoint code { background: #e9ecef; padding: 2px 6px; border-radius: 3px; }
        input[type="text"] { width: 100%; padding: 10px; margin: 10px 0; border: 1px solid #ddd; border-radius: 4px; }
        button { background: #007bff; color: white; padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; }
        button:hover { background: #0056b3; }
        pre { background: #f8f9fa; padding: 15px; border-radius: 4px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 MetricStream Analytics</h1>
        <p>Internal monitoring and health check service for containerized applications.</p>
        
        <h2>Available Endpoints</h2>
        
        <div class="endpoint">
            <strong>GET /health</strong>
            <p>Basic health check endpoint</p>
        </div>
        
        <div class="endpoint">
            <strong>GET /status</strong>
            <p>Detailed system status information</p>
        </div>
        
        <div class="endpoint">
            <strong>POST /debug/fetch</strong>
            <p>Debug utility for fetching internal URLs (development only)</p>
            <code>{ "url": "http://example.com" }</code>
        </div>
        
        <h2>Quick Test</h2>
        <form id="fetchForm">
            <input type="text" id="urlInput" placeholder="Enter URL to fetch" value="http://169.254.170.2/task">
            <button type="submit">Fetch URL</button>
        </form>
        <pre id="result"></pre>
        
        <script>
            document.getElementById('fetchForm').onsubmit = async (e) => {
                e.preventDefault();
                const url = document.getElementById('urlInput').value;
                const result = document.getElementById('result');
                result.textContent = 'Loading...';
                
                try {
                    const response = await fetch('/debug/fetch', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({url: url})
                    });
                    const data = await response.json();
                    result.textContent = JSON.stringify(data, null, 2);
                } catch (error) {
                    result.textContent = 'Error: ' + error.message;
                }
            };
        </script>
    </div>
</body>
</html>
"""

@app.route('/')
def index():
    return render_template_string(HTML_TEMPLATE)

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'service': 'metricstream-analytics',
        'version': '2.1.4'
    })

@app.route('/status')
def status():
    return jsonify({
        'status': 'running',
        'environment': os.getenv('APP_ENV', 'unknown'),
        'container_id': os.getenv('HOSTNAME', 'unknown'),
        'aws_region': os.getenv('AWS_REGION', 'unknown'),
        'platform': 'AWS ECS Fargate',
        'endpoints': {
            'metadata': 'Available at 169.254.170.2',
            'credentials': 'Check AWS_CONTAINER_CREDENTIALS_RELATIVE_URI'
        }
    })

@app.route('/debug/fetch', methods=['POST'])
def debug_fetch():
    """
    Development endpoint for testing internal service connectivity.
    VULNERABILITY: SSRF allowing access to metadata service
    """
    try:
        data = request.get_json()
        url = data.get('url')
        
        if not url:
            return jsonify({'error': 'URL parameter required'}), 400
        
        # INSECURE: No URL validation
        response = requests.get(url, timeout=5)
        
        try:
            json_response = response.json()
            return jsonify({
                'url': url,
                'status_code': response.status_code,
                'data': json_response
            })
        except:
            return jsonify({
                'url': url,
                'status_code': response.status_code,
                'data': response.text
            })
            
    except requests.exceptions.RequestException as e:
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/debug/env')
def debug_env():
    """Expose environment variables for debugging"""
    env_vars = {
        'APP_ENV': os.getenv('APP_ENV'),
        'AWS_REGION': os.getenv('AWS_REGION'),
        'AWS_EXECUTION_ENV': os.getenv('AWS_EXECUTION_ENV'),
        'AWS_CONTAINER_CREDENTIALS_RELATIVE_URI': os.getenv('AWS_CONTAINER_CREDENTIALS_RELATIVE_URI'),
        'SECRET_ARN': os.getenv('SECRET_ARN'),
        'S3_BUCKET': os.getenv('S3_BUCKET'),
        'DB_HOST': os.getenv('DB_HOST')
    }
    
    return jsonify({
        'environment': env_vars,
        'hint': 'Credentials available at metadata endpoint'
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)