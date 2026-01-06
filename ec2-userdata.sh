#!/bin/bash
# User Data script for EC2 instance to install Apache and sync S3 website

# Log output to file for debugging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user data script execution..."

# Update system packages
echo "Updating system packages..."
sudo yum update -y

# Install Apache HTTP server
echo "Installing Apache HTTP server..."
sudo yum install -y httpd

# Start Apache and enable it to start on boot
echo "Starting and enabling Apache..."
sudo systemctl start httpd
sudo systemctl enable httpd

# Sync static website files from S3 to Apache document root
# Note: Instance must have IAM role with S3 read permissions
echo "Syncing website files from S3..."
sudo aws s3 sync s3://shravani-jawalkar-web-project /var/www/html --region ap-south-1

# Set proper permissions
echo "Setting file permissions..."
sudo chmod -R 755 /var/www/html
sudo chown -R apache:apache /var/www/html

# Restart Apache to ensure everything is loaded
echo "Restarting Apache..."
sudo systemctl restart httpd

echo "User data script completed successfully!"
