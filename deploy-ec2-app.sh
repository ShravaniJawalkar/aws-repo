#!/bin/bash

# Web Application Deployment Script for EC2
# This script downloads the app from S3, installs dependencies, and starts the server

set -e

echo "=========================================="
echo "Web App EC2 Deployment"
echo "=========================================="
echo ""

# Configuration
AWS_REGION="ap-south-1"
S3_BUCKET="shravani-jawalkar-webproject-bucket"
SQS_QUEUE_URL="https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue"
SNS_TOPIC_ARN="arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic"
APP_DIR="$HOME/webapp"
PORT="8080"

echo "Configuration:"
echo "  S3 Bucket: $S3_BUCKET"
echo "  AWS Region: $AWS_REGION"
echo "  App Directory: $APP_DIR"
echo "  Port: $PORT"
echo ""

# Step 1: Create app directory
echo "1. Creating app directory..."
mkdir -p "$APP_DIR"
cd "$APP_DIR"
echo "   ✓ Directory ready: $APP_DIR"
echo ""

# Step 2: Download files from S3
echo "2. Downloading application from S3..."
aws s3 cp "s3://$S3_BUCKET/app-enhanced.js" . --region "$AWS_REGION"
aws s3 cp "s3://$S3_BUCKET/package.json" . --region "$AWS_REGION"
echo "   ✓ Files downloaded"
echo ""

# Step 3: Check Node.js installation
echo "3. Checking Node.js installation..."
if ! command -v node &> /dev/null; then
    echo "   ⚠ Node.js not found, installing..."
    curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
    sudo yum install -y nodejs
else
    NODE_VERSION=$(node --version)
    echo "   ✓ Node.js installed: $NODE_VERSION"
fi
echo ""

# Step 4: Install dependencies
echo "4. Installing npm dependencies..."
npm install
echo "   ✓ Dependencies installed"
echo ""

# Step 5: Create .env file (optional, for reference)
echo "5. Setting up environment configuration..."
cat > "$APP_DIR/.env" << EOF
AWS_REGION=$AWS_REGION
S3_BUCKET=$S3_BUCKET
SQS_QUEUE_URL=$SQS_QUEUE_URL
SNS_TOPIC_ARN=$SNS_TOPIC_ARN
PORT=$PORT
EOF
echo "   ✓ Environment configured"
echo ""

# Step 6: Export environment variables
export AWS_REGION
export S3_BUCKET
export SQS_QUEUE_URL
export SNS_TOPIC_ARN
export PORT

# Step 7: Start the application
echo "6. Starting application..."
echo "=========================================="
echo "✅ Ready to start the application"
echo "=========================================="
echo ""
echo "Run the following command to start:"
echo "  npm start"
echo ""
echo "Or to run in the background:"
echo "  nohup npm start > app.log 2>&1 &"
echo ""
echo "The application will be available at:"
echo "  http://localhost:$PORT"
echo "  http://3.110.142.62:$PORT (via Load Balancer)"
echo ""

# Optional: Start the application
read -p "Start application now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting application..."
    npm start
else
    echo "Setup complete. To start later, run: npm start"
fi
