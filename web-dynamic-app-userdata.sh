#!/bin/bash

# Update system packages
sudo yum update -y

# Install Node.js (using NodeSource repository for latest LTS version)
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs

# Install unzip utility
sudo yum install -y unzip

# Create application directory
sudo mkdir -p /opt/web-dynamic-app
cd /opt/web-dynamic-app

# Download application from S3
aws s3 cp s3://shravani-jawalkar-web-project/web-dynamic-app.zip . --region ap-south-1

sudo mkdir -p /opt/web-dynamic-app/web-dynamic-app

sudo chown -R ec2-user:ec2-user /opt/web-dynamic-app

cd /opt/web-dynamic-app/web-dynamic-app

# Unzip the application
sudo unzip /opt/web-dynamic-app/web-dynamic-app.zip

# Set proper ownership
sudo chown -R ec2-user:ec2-user /opt/web-dynamic-app

# Navigate to app directory and install dependencies
cd /opt/web-dynamic-app/web-dynamic-app
sudo npm install

# Create systemd service file for the application
sudo cat > /etc/systemd/system/web-dynamic-app.service <<EOF
[Unit]
Description=Web Dynamic Application
After=network.target

[Service]
Type=simple
User=ec2-user
Group=ec2-user
WorkingDirectory=/opt/web-dynamic-app/web-dynamic-app
ExecStart=/usr/bin/node /opt/web-dynamic-app/web-dynamic-app/app.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=web-dynamic-app
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to recognize the new service
sudo systemctl daemon-reload

# Enable the service to start on boot
sudo systemctl enable web-dynamic-app.service

# Start the application
sudo systemctl start web-dynamic-app.service

# Check service status
sudo systemctl status web-dynamic-app.service
