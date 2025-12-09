#!/bin/bash
set -e

dnf update -y
dnf install -y at git

curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

mkdir -p /opt/webapp
cd /opt/webapp

npm init -y
npm install next@16.0.6 react@19.1.0 react-dom@19.1.0

mkdir -p app/dashboard

cat > app/layout.js << 'LAYOUT'
export const metadata = {
  title: 'SaaS Customer Portal',
  description: 'Enterprise customer management platform',
}

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body style={{ fontFamily: 'system-ui, sans-serif', margin: 0, padding: 0 }}>
        {children}
      </body>
    </html>
  )
}
LAYOUT

cat > app/page.js << 'PAGE'
import Link from 'next/link'

export default function Home() {
  return (
    <main style={{ maxWidth: '1200px', margin: '0 auto', padding: '2rem' }}>
      <header style={{ borderBottom: '1px solid #eee', paddingBottom: '1rem', marginBottom: '2rem' }}>
        <h1 style={{ margin: 0, color: '#333' }}>SaaS Customer Portal</h1>
        <p style={{ color: '#666', margin: '0.5rem 0 0 0' }}>Enterprise customer management platform</p>
      </header>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '1.5rem' }}>
        <div style={{ border: '1px solid #ddd', borderRadius: '8px', padding: '1.5rem' }}>
          <h2 style={{ marginTop: 0 }}>Customer Analytics</h2>
          <p style={{ color: '#666' }}>View customer engagement metrics and subscription analytics.</p>
          <Link href="/dashboard" style={{ color: '#0066cc' }}>View Dashboard →</Link>
        </div>

        <div style={{ border: '1px solid #ddd', borderRadius: '8px', padding: '1.5rem' }}>
          <h2 style={{ marginTop: 0 }}>API Documentation</h2>
          <p style={{ color: '#666' }}>Integration guides and REST API reference.</p>
          <Link href="/docs" style={{ color: '#0066cc' }}>View Docs →</Link>
        </div>

        <div style={{ border: '1px solid #ddd', borderRadius: '8px', padding: '1.5rem' }}>
          <h2 style={{ marginTop: 0 }}>Support</h2>
          <p style={{ color: '#666' }}>Contact our enterprise support team.</p>
          <Link href="/support" style={{ color: '#0066cc' }}>Get Help →</Link>
        </div>
      </div>

      <footer style={{ marginTop: '3rem', paddingTop: '1rem', borderTop: '1px solid #eee', color: '#999', fontSize: '0.875rem' }}>
        <p>© 2025 SaaS Portal Inc. All rights reserved.</p>
      </footer>
    </main>
  )
}
PAGE

cat > app/dashboard/page.js << 'DASHBOARD'
export default function Dashboard() {
  const stats = [
    { label: 'Active Customers', value: '2,847' },
    { label: 'Monthly Revenue', value: '$847,293' },
    { label: 'API Calls (24h)', value: '12.4M' },
    { label: 'Uptime', value: '99.97%' },
  ]

  return (
    <main style={{ maxWidth: '1200px', margin: '0 auto', padding: '2rem' }}>
      <h1>Dashboard</h1>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '1rem', marginTop: '2rem' }}>
        {stats.map((stat, i) => (
          <div key={i} style={{ background: '#f8f9fa', padding: '1.5rem', borderRadius: '8px' }}>
            <div style={{ fontSize: '2rem', fontWeight: 'bold' }}>{stat.value}</div>
            <div style={{ color: '#666' }}>{stat.label}</div>
          </div>
        ))}
      </div>
    </main>
  )
}
DASHBOARD

cat > app/actions.js << 'ACTIONS'
'use server'

export async function submitFeedback(formData) {
  const message = formData.get('message')
  return { success: true, received: message }
}

export async function getStatus() {
  return { status: 'operational', timestamp: new Date().toISOString() }
}
ACTIONS

cat > next.config.js << 'CONFIG'
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverActions: {
      allowedOrigins: ['*'],
    },
  },
}
module.exports = nextConfig
CONFIG

cat > package.json << 'PKGJSON'
{
  "name": "saas-portal",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start -p 3000 -H 0.0.0.0"
  },
  "dependencies": {
    "next": "16.0.6",
    "react": "19.1.0",
    "react-dom": "19.1.0"
  }
}
PKGJSON

cat > .env << ENVFILE
NODE_ENV=production
APP_NAME=saas-portal
S3_DATA_BUCKET=${s3_bucket}
SECRETS_ARN=${secrets_arn}
INTERNAL_API_KEY=${api_key}
ENVFILE

npm run build

cat > /etc/systemd/system/webapp.service << 'SYSD'
[Unit]
Description=SaaS Portal Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/webapp
ExecStart=/usr/bin/npm run start
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
SYSD

systemctl daemon-reload
systemctl enable webapp
systemctl start webapp

systemctl enable atd
systemctl start atd
echo "sudo shutdown -h now" | at now + ${shutdown_hours} hours