#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log) 2>&1

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl git nodejs npm

npm install -g n
n 20

cat > /opt/webapp/.env << 'EOF'
STORAGE_ACCOUNT=${storage_account}
KEY_VAULT_NAME=${key_vault_name}
AZURE_CLIENT_ID=${client_id}
NODE_ENV=production
INTERNAL_API_KEY=${api_key}
EOF

mkdir -p /opt/webapp
cd /opt/webapp

cat > package.json << 'EOF'
{
  "name": "customer-portal",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start -p 3000"
  },
  "dependencies": {
    "next": "16.0.6",
    "react": "19.0.0",
    "react-dom": "19.0.0"
  }
}
EOF

cat > next.config.js << 'EOF'
module.exports = {
  reactStrictMode: false,
  poweredByHeader: true,
  experimental: {
    serverActions: true
  }
}
EOF

mkdir -p app
cat > app/layout.js << 'EOF'
export const metadata = {
  title: 'Customer Portal',
  description: 'Enterprise SaaS Platform'
}

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
EOF

cat > app/page.js << 'EOF'
import { CustomerDashboard } from './components/Dashboard'

export default function Home() {
  return (
    <main style={{ padding: '2rem', fontFamily: 'system-ui' }}>
      <h1>Customer Portal</h1>
      <p>Welcome to your enterprise dashboard.</p>
      <CustomerDashboard />
    </main>
  )
}
EOF

mkdir -p app/components
cat > app/components/Dashboard.js << 'EOF'
'use client'
import { useState } from 'react'
import { processReport } from '../actions'

export function CustomerDashboard() {
  const [result, setResult] = useState(null)
  
  async function handleGenerate() {
    const data = await processReport({ type: 'monthly' })
    setResult(data)
  }
  
  return (
    <div style={{ marginTop: '1rem' }}>
      <button onClick={handleGenerate}>Generate Report</button>
      {result && <pre>{JSON.stringify(result, null, 2)}</pre>}
    </div>
  )
}
EOF

cat > app/actions.js << 'EOF'
'use server'

export async function processReport(options) {
  return {
    status: 'generated',
    timestamp: new Date().toISOString(),
    type: options.type,
    records: 1247
  }
}

export async function updatePreferences(data) {
  return { updated: true, ...data }
}
EOF

npm install

cat > /etc/systemd/system/webapp.service << 'EOF'
[Unit]
Description=Customer Portal
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/webapp
ExecStart=/usr/local/bin/node /opt/webapp/node_modules/.bin/next start -p 3000
Restart=on-failure
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

npm run build

systemctl daemon-reload
systemctl enable webapp
systemctl start webapp

shutdown_time=$(date -d "+${shutdown_hours} hours" +"%H:%M")
echo "shutdown -h now" | at $shutdown_time 2>/dev/null || true

echo "Setup complete at $(date)"