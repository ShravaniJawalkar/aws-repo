# Deploy Web Application to EC2 via SSH
# This script connects to the EC2 instance and deploys the application

param(
    [string]$InstanceIP = "3.110.142.62",
    [string]$KeyPath = "web-server.ppk",
    [string]$SSHUser = "ec2-user",
    [string]$S3Bucket = "shravani-jawalkar-webproject-bucket",
    [string]$Region = "ap-south-1"
)

Write-Host "=========================================="
Write-Host "EC2 App Deployment Script"
Write-Host "=========================================="
Write-Host ""
Write-Host "Configuration:"
Write-Host "  EC2 Instance: $InstanceIP"
Write-Host "  SSH User: $SSHUser"
Write-Host "  SSH Key: $KeyPath"
Write-Host "  S3 Bucket: $S3Bucket"
Write-Host ""

# Check if SSH key exists
if (-not (Test-Path $KeyPath)) {
    Write-Host "✗ SSH key not found: $KeyPath"
    exit 1
}

Write-Host "✓ SSH key found"
Write-Host ""

# Step 1: Test SSH connection
Write-Host "1. Testing SSH connection..."
try {
    $sshTest = ssh -i $KeyPath -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSHUser@$InstanceIP" "echo 'Connected'" 2>&1
    if ($sshTest -like "*Connected*") {
        Write-Host "✓ SSH connection successful"
    } else {
        Write-Host "⚠ Connection test response: $sshTest"
    }
} catch {
    Write-Host "✗ SSH connection failed: $_"
    exit 1
}

Write-Host ""

# Step 2: Create deployment script
Write-Host "2. Creating deployment script..."

$deployScript = @'
#!/bin/bash
set -e

echo "=========================================="
echo "Deploying Web Application"
echo "=========================================="
echo ""

# Variables
AWS_REGION="ap-south-1"
S3_BUCKET="shravani-jawalkar-webproject-bucket"
SQS_QUEUE_URL="https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue"
SNS_TOPIC_ARN="arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic"
APP_DIR="$HOME/webapp"

echo "1. Creating app directory..."
mkdir -p "$APP_DIR"
cd "$APP_DIR"
echo "✓ Directory ready"

echo ""
echo "2. Downloading files from S3..."
aws s3 cp "s3://$S3_BUCKET/app-enhanced.js" . --region "$AWS_REGION"
aws s3 cp "s3://$S3_BUCKET/package.json" . --region "$AWS_REGION"
echo "✓ Files downloaded"

echo ""
echo "3. Installing Node.js (if needed)..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
    sudo yum install -y nodejs
fi
NODE_VERSION=$(node --version)
echo "✓ Node.js: $NODE_VERSION"

echo ""
echo "4. Installing npm dependencies..."
npm install --production
echo "✓ Dependencies installed"

echo ""
echo "5. Setting environment variables..."
export AWS_REGION="$AWS_REGION"
export S3_BUCKET="$S3_BUCKET"
export SQS_QUEUE_URL="$SQS_QUEUE_URL"
export SNS_TOPIC_ARN="$SNS_TOPIC_ARN"
echo "✓ Environment configured"

echo ""
echo "=========================================="
echo "✅ Deployment complete!"
echo "=========================================="
echo ""
echo "To start the application:"
echo "  cd $APP_DIR"
echo "  export AWS_REGION=$AWS_REGION"
echo "  export S3_BUCKET=$S3_BUCKET"
echo "  export SQS_QUEUE_URL=$SQS_QUEUE_URL"
echo "  export SNS_TOPIC_ARN=$SNS_TOPIC_ARN"
echo "  npm start"
echo ""
echo "Or run in background:"
echo "  nohup npm start > app.log 2>&1 &"
'@

# Write script to temp file
$tempScript = ".\deploy-temp.sh"
$deployScript | Set-Content -Path $tempScript -Encoding UTF8

Write-Host "✓ Deployment script created"
Write-Host ""

# Step 3: Transfer script to EC2
Write-Host "3. Transferring deployment script to EC2..."
try {
    scp -i $KeyPath -o StrictHostKeyChecking=no $tempScript "$SSHUser@$InstanceIP`:/tmp/deploy.sh" 2>&1 | Write-Host
    Write-Host "✓ Script transferred"
} catch {
    Write-Host "✗ Transfer failed: $_"
    Remove-Item $tempScript -Force
    exit 1
}

Write-Host ""

# Step 4: Execute deployment
Write-Host "4. Executing deployment on EC2..."
try {
    $result = ssh -i $KeyPath -o StrictHostKeyChecking=no "$SSHUser@$InstanceIP" "chmod +x /tmp/deploy.sh && bash /tmp/deploy.sh" 2>&1
    Write-Host $result
} catch {
    Write-Host "✗ Deployment failed: $_"
    Remove-Item $tempScript -Force
    exit 1
}

Write-Host ""

# Cleanup
Remove-Item $tempScript -Force

# Step 5: Start application
Write-Host "5. Starting application on EC2..."
$startCmd = @'
cd ~/webapp
export AWS_REGION=ap-south-1
export S3_BUCKET=shravani-jawalkar-webproject-bucket
export SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
export SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic
nohup npm start > ~/webapp/app.log 2>&1 &
sleep 3
ps aux | grep "npm start" | grep -v grep
'@

try {
    $result = ssh -i $KeyPath -o StrictHostKeyChecking=no "$SSHUser@$InstanceIP" $startCmd 2>&1
    Write-Host $result
    Write-Host "✓ Application started"
} catch {
    Write-Host "⚠ Startup check: $_"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "✅ EC2 Deployment Complete!"
Write-Host "=========================================="
Write-Host ""
Write-Host "Application Details:"
Write-Host "  Instance: $InstanceIP:8080"
Write-Host "  Load Balancer: http://webproject-LoadBalancer-418397374.ap-south-1.elb.amazonaws.com"
Write-Host ""
Write-Host "To check application logs:"
Write-Host "  ssh -i $KeyPath $SSHUser@$InstanceIP"
Write-Host "  tail -f ~/webapp/app.log"
Write-Host ""
Write-Host "Next step: Test the application"
Write-Host ""
