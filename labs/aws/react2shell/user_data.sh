#!/bin/bash
set -e

dnf update -y
dnf install -y docker nodejs npm git

systemctl enable docker
systemctl start docker

usermod -aG docker ec2-user

mkdir -p /opt/webapp
cd /opt/webapp

# Create vulnerable Next.js application
cat > package.json << 'PACKAGE'
{
  "name": "internal-dashboard",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start -p 3000"
  },
  "dependencies": {
    "next": "16.0.6",
    "react": "19.1.0",
    "react-dom": "19.1.0"
  }
}
PACKAGE

cat > next.config.js << 'NEXTCONFIG'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
}
module.exports = nextConfig
NEXTCONFIG

mkdir -p app

cat > app/layout.js << 'LAYOUT'
export const metadata = {
  title: 'Internal Dashboard',
  description: 'Employee portal and analytics',
}

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body style={{ fontFamily: 'system-ui', margin: 0, padding: '20px', background: '#f5f5f5' }}>
        <header style={{ background: '#1a1a2e', color: 'white', padding: '15px 20px', marginBottom: '20px' }}>
          <h1 style={{ margin: 0, fontSize: '1.5rem' }}>Acme Corp Internal Dashboard</h1>
        </header>
        <main>{children}</main>
      </body>
    </html>
  )
}
LAYOUT

cat > app/page.js << 'PAGE'
export default function Home() {
  return (
    <div style={{ maxWidth: '800px', margin: '0 auto' }}>
      <div style={{ background: 'white', padding: '20px', borderRadius: '8px', marginBottom: '20px' }}>
        <h2>Welcome to the Internal Dashboard</h2>
        <p>Access company resources and analytics.</p>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '15px' }}>
        <div style={{ background: 'white', padding: '20px', borderRadius: '8px' }}>
          <h3>Employee Directory</h3>
          <p>View team contacts</p>
        </div>
        <div style={{ background: 'white', padding: '20px', borderRadius: '8px' }}>
          <h3>Analytics</h3>
          <p>Q4 2025 Reports</p>
        </div>
        <div style={{ background: 'white', padding: '20px', borderRadius: '8px' }}>
          <h3>Documents</h3>
          <p>Internal policies</p>
        </div>
      </div>
      <footer style={{ marginTop: '40px', color: '#666', fontSize: '0.9rem' }}>
        <p>Powered by Next.js | Internal use only</p>
      </footer>
    </div>
  )
}
PAGE

# Server action for RSC vulnerability surface
mkdir -p app/api/analytics

cat > app/actions.js << 'ACTIONS'
'use server'

export async function getAnalytics(params) {
  return { 
    visitors: 1234, 
    pageViews: 5678,
    timestamp: new Date().toISOString()
  }
}

export async function submitFeedback(formData) {
  const message = formData.get('message')
  return { success: true, received: message }
}
ACTIONS

npm install
npm run build

# Create systemd service
cat > /etc/systemd/system/nextjs.service << 'SERVICE'
[Unit]
Description=Next.js Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/webapp
ExecStart=/usr/bin/npm run start
Restart=on-failure
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable nextjs
systemctl start nextjs

# Auto-shutdown after 4 hours
echo "shutdown -h now" | at now + 4 hours

cat > /var/log/webapp-setup.log << LOGENTRY
React2Shell Lab Deployment Complete
Next.js Version: 16.0.6
React Version: 19.1.0
Application URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000
CVE: CVE-2025-55182
LOGENTRY