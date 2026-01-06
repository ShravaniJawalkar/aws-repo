# RDS Testing and SQL Queries Guide
# Execute this step-by-step to test RDS connectivity from EC2

## STEP 1: Get Stack Information
$region = "ap-south-1"
$profile = "user-iam-profile"
$stackName = "webProject-infrastructure"

# Get RDS endpoint, port, and username
$dbInfo = aws cloudformation describe-stacks `
  --stack-name $stackName `
  --region $region `
  --profile $profile `
  --query "Stacks[0].Outputs[?OutputKey=='DBEndpoint' || OutputKey=='DBPort' || OutputKey=='DBUsername']" | ConvertFrom-Json

$dbEndpoint = ($dbInfo | Where-Object OutputKey -eq DBEndpoint).OutputValue
$dbPort = ($dbInfo | Where-Object OutputKey -eq DBPort).OutputValue
$dbUsername = ($dbInfo | Where-Object OutputKey -eq DBUsername).OutputValue
$dbPassword = "PasswordwebProject2024"

Write-Host "=== RDS Information ===" -ForegroundColor Cyan
Write-Host "Endpoint: $dbEndpoint"
Write-Host "Port: $dbPort"
Write-Host "Username: $dbUsername"
Write-Host "Password: $dbPassword`n"

# Get EC2 Instance details
Write-Host "=== EC2 Instance Information ===" -ForegroundColor Cyan
$instance = aws ec2 describe-instances `
  --region $region `
  --profile $profile `
  --filters "Name=tag:aws:cloudformation:stack-name,Values=$stackName" `
  --query "Reservations[0].Instances[0]" | ConvertFrom-Json

$instanceId = $instance.InstanceId
$publicIp = $instance.PublicIpAddress
$keyFile = "web-server.ppk"

Write-Host "Instance ID: $instanceId"
Write-Host "Public IP: $publicIp"
Write-Host "Key File: $keyFile`n"

## STEP 2: Connect to EC2 via SSH
Write-Host "=== Connecting to EC2 ===" -ForegroundColor Yellow
Write-Host "Command to run:"
Write-Host "ssh -i $keyFile ec2-user@$publicIp`n"

Write-Host "Once connected, run the following commands:

## STEP 3: Install MySQL Client on EC2 (run via SSH)
sudo yum install -y mysql80

## STEP 4: Test RDS Connectivity (run via SSH)
mysql -h $dbEndpoint -P $dbPort -u $dbUsername -p$dbPassword -e 'SELECT 1 as connection_test;'

## Expected output:
# +------------------+
# | connection_test  |
# +------------------+
# |        1         |
# +------------------+

## STEP 5: Create Database and Table for Image Metadata (run via SSH)
mysql -h $dbEndpoint -P $dbPort -u $dbUsername -p$dbPassword << 'EOF'
CREATE DATABASE IF NOT EXISTS imagedb;

USE imagedb;

CREATE TABLE IF NOT EXISTS image_metadata (
    id INT AUTO_INCREMENT PRIMARY KEY,
    filename VARCHAR(255) NOT NULL UNIQUE,
    size_bytes INT,
    content_type VARCHAR(100),
    upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    s3_key VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

SHOW TABLES;
DESCRIBE image_metadata;
EOF

## STEP 6: Verify IAM Role is Attached (run via SSH)
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

## Expected output: Role name (e.g., webProject-EC2-S3-Read-Role)

## STEP 7: Test S3 Access from EC2 (run via SSH)
aws s3 ls s3://shravani-jawalkar-webproject-bucket/ --region ap-south-1

## STEP 8: Insert Test Data into RDS (run via SSH)
mysql -h $dbEndpoint -P $dbPort -u $dbUsername -p$dbPassword imagedb << 'EOF'
INSERT INTO image_metadata (filename, size_bytes, content_type, s3_key) VALUES
('test-image-1.jpg', 6912, 'image/jpeg', 'test-image-1.jpg'),
('test-image-2.jpg', 7200, 'image/jpeg', 'test-image-2.jpg');

SELECT * FROM image_metadata;
EOF

## STEP 9: Query Image Metadata (run via SSH)
mysql -h $dbEndpoint -P $dbPort -u $dbUsername -p$dbPassword imagedb -e 'SELECT * FROM image_metadata;'

## STEP 10: Optional - Set Up IAM Database Authentication (run via SSH)
# Create IAM DB user
mysql -h $dbEndpoint -P $dbPort -u $dbUsername -p$dbPassword imagedb << 'EOF'
CREATE USER IF NOT EXISTS 'iamdb_user' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
GRANT ALL PRIVILEGES ON imagedb.* TO 'iamdb_user'@'%';
FLUSH PRIVILEGES;
SELECT User FROM mysql.user WHERE User='iamdb_user';
EOF

## STEP 11: Test IAM Authentication (run via SSH)
# Generate auth token
TOKEN=\$(aws rds generate-db-auth-token \\
  --hostname $dbEndpoint \\
  --port $dbPort \\
  --region $region \\
  --username iamdb_user)

# Connect using token
mysql -h $dbEndpoint -P $dbPort -u iamdb_user \\
  --ssl-ca=/etc/ssl/certs/ca-bundle.crt \\
  --ssl-mode=VERIFY_IDENTITY \\
  -e \"SELECT 'IAM Authentication Successful!' as result;\" \\
  --password=\"\$TOKEN\" \\
  imagedb

"
