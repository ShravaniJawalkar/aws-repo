# EC2 Web Application Deployment Guide

## Overview

This guide will help you deploy the Node.js web application to an EC2 instance and integrate it with the SQS queue and SNS topic created for the SAM Lambda function.

## Prerequisites

1. ✅ SAM Lambda application deployed (webproject-uploads-stack)
2. ✅ SQS Queue created (webproject-UploadsNotificationQueue)
3. ✅ SNS Topic created (webproject-UploadsNotificationTopic)
4. ✅ AWS profiles configured
5. ✅ CloudFormation template available (cloudformation-web-app-deployment.yaml)

## Architecture

```
User Browser
    ↓
Web Application (EC2 Instance)
├─ Express.js Server (Port 8080)
├─ Subscribe/Unsubscribe endpoints
├─ Image Upload endpoints
└─ Admin endpoints
    ↓
SQS Queue (webproject-UploadsNotificationQueue)
    ↓
Lambda Function (webproject-uploads-notification-function)
    ↓
SNS Topic (webproject-UploadsNotificationTopic)
    ↓
Email Notifications to Subscribers
```

## Deployment Options

### Option 1: CloudFormation (Recommended)

Deploy the entire EC2 instance and application using CloudFormation:

```powershell
$env:AWS_PROFILE="user-ec2-profile"

aws cloudformation create-stack `
  --stack-name webproject-web-app-stack `
  --template-body file://cloudformation-web-app-deployment.yaml `
  --parameters `
    ParameterKey=ProjectName,ParameterValue=webproject `
    ParameterKey=ProjectInstanceType,ParameterValue=t3.micro `
    ParameterKey=SQSQueueURL,ParameterValue=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue `
    ParameterKey=SNSTopicARN,ParameterValue=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic `
  --region ap-south-1 `
  --capabilities CAPABILITY_NAMED_IAM
```

### Option 2: Manual EC2 Launch

Create and configure EC2 instance manually.

---

## Step 1: Launch EC2 Instance

### Using CloudFormation (Recommended)

```powershell
$env:AWS_PROFILE="user-ec2-profile"

# Create stack
aws cloudformation create-stack `
  --stack-name webproject-web-app-stack `
  --template-body file://cloudformation-web-app-deployment.yaml `
  --parameters `
    ParameterKey=ProjectName,ParameterValue=webproject `
    ParameterKey=ProjectInstanceType,ParameterValue=t3.micro `
    ParameterKey=SQSQueueURL,ParameterValue=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue `
    ParameterKey=SNSTopicARN,ParameterValue=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic `
  --region ap-south-1 `
  --capabilities CAPABILITY_NAMED_IAM

# Wait for stack creation
aws cloudformation wait stack-create-complete `
  --stack-name webproject-web-app-stack `
  --region ap-south-1

# Get instance details
aws cloudformation describe-stacks `
  --stack-name webproject-web-app-stack `
  --region ap-south-1 `
  --query 'Stacks[0].Outputs'
```

### Using AWS CLI (Manual)

```powershell
$env:AWS_PROFILE="user-ec2-profile"

# Get the latest Amazon Linux 2 AMI
$AMI_ID = aws ec2 describe-images `
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" `
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' `
  --output text `
  --region ap-south-1

# Create security group
$SG_ID = aws ec2 create-security-group `
  --group-name webproject-sg `
  --description "Security group for webproject" `
  --region ap-south-1 `
  --query 'GroupId' `
  --output text

# Add security group rules
aws ec2 authorize-security-group-ingress `
  --group-id $SG_ID `
  --protocol tcp `
  --port 22 `
  --cidr 0.0.0.0/0 `
  --region ap-south-1

aws ec2 authorize-security-group-ingress `
  --group-id $SG_ID `
  --protocol tcp `
  --port 80 `
  --cidr 0.0.0.0/0 `
  --region ap-south-1

aws ec2 authorize-security-group-ingress `
  --group-id $SG_ID `
  --protocol tcp `
  --port 443 `
  --cidr 0.0.0.0/0 `
  --region ap-south-1

aws ec2 authorize-security-group-ingress `
  --group-id $SG_ID `
  --protocol tcp `
  --port 8080 `
  --cidr 0.0.0.0/0 `
  --region ap-south-1

# Launch instance
$INSTANCE_ID = aws ec2 run-instances `
  --image-id $AMI_ID `
  --instance-type t3.micro `
  --security-group-ids $SG_ID `
  --iam-instance-profile Name=webproject-instance-profile `
  --region ap-south-1 `
  --query 'Instances[0].InstanceId' `
  --output text

Write-Host "Instance launched: $INSTANCE_ID"
```

---

## Step 2: Get Instance IP Address

```powershell
$env:AWS_PROFILE="user-ec2-profile"

# Get public IP
$PUBLIC_IP = aws ec2 describe-instances `
  --instance-ids $INSTANCE_ID `
  --region ap-south-1 `
  --query 'Reservations[0].Instances[0].PublicIpAddress' `
  --output text

Write-Host "Instance Public IP: $PUBLIC_IP"
Write-Host "Web App URL: http://$PUBLIC_IP:8080"
```

---

## Step 3: SSH into Instance

```powershell
# Connect via SSH
ssh -i your-key.pem ec2-user@<public-ip>

# Or using instance connect
aws ec2-instance-connect send-ssh-public-key `
  --instance-id $INSTANCE_ID `
  --os-user ec2-user `
  --ssh-public-key file://~/.ssh/id_rsa.pub `
  --region ap-south-1
```

---

## Step 4: Deploy Application (If Manual)

Once connected to the instance:

```bash
# Update system
sudo yum update -y
sudo yum install -y git curl wget

# Install Node.js 18
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs

# Clone or create application
mkdir -p /var/www/web-dynamic-app
cd /var/www/web-dynamic-app

# Create package.json
cat > package.json << 'EOF'
{
  "name": "web-dynamic-app",
  "version": "1.0.0",
  "main": "app.js",
  "dependencies": {
    "express": "^4.18.0",
    "aws-sdk": "^2.1400.0",
    "uuid": "^9.0.0",
    "axios": "^1.4.0",
    "dotenv": "^16.0.0"
  },
  "scripts": {
    "start": "node app.js"
  }
}
EOF

# Install dependencies
npm install

# Copy app.js from CloudFormation template UserData
# (See cloudformation-web-app-deployment.yaml for full app.js code)

# Create .env file with SQS and SNS configuration
cat > .env << 'EOF'
AWS_REGION=ap-south-1
PORT=8080
SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic
WORKER_INTERVAL_MS=30000
SQS_BATCH_SIZE=10
EOF

# Start application
npm start
```

---

## Step 5: Test Web Application

Once the application is running:

### Access Web Interface
```
Browser: http://<instance-public-ip>:8080
```

### Test Subscription Endpoint
```powershell
# Subscribe an email
curl -X POST "http://<instance-ip>:8080/api/subscribe?email=mangal.mudit111@gmail.com"

# Unsubscribe
curl -X POST "http://<instance-ip>:8080/api/unsubscribe?email=mangal.mudit111@gmail.com"

# List subscriptions
curl "http://<instance-ip>:8080/api/subscriptions"
```

### Test Upload Endpoint
```powershell
# Send image upload notification
curl -X POST "http://<instance-ip>:8080/api/upload?fileName=test-image.jpg&fileSize=2048576&description=Test%20Image"
```

### Test Admin Endpoints
```powershell
# Check queue status
curl "http://<instance-ip>:8080/admin/queue-status"

# Process queue manually
curl -X POST "http://<instance-ip>:8080/admin/process-queue"

# Send test message
curl -X POST "http://<instance-ip>:8080/admin/send-test-message"

# Health check
curl "http://<instance-ip>:8080/health"
```

---

## Step 6: End-to-End Test Flow

### Full Workflow Test

```powershell
# 1. Subscribe to SNS topic via email
curl -X POST "http://<instance-ip>:8080/api/subscribe?email=your-email@example.com"

# Wait for email confirmation and confirm subscription

# 2. Simulate image upload
curl -X POST "http://<instance-ip>:8080/api/upload?fileName=my-photo.jpg&fileSize=3145728&description=Family%20Photo"

# 3. Check queue status
curl "http://<instance-ip>:8080/admin/queue-status"

# 4. Manually trigger queue processing
curl -X POST "http://<instance-ip>:8080/admin/process-queue"

# 5. Check CloudWatch logs for Lambda execution
sam logs -n UploadsNotificationFunction --stack-name webproject-uploads-stack -t

# 6. Check email for notification
```

---

## CloudFormation Stack Outputs

After stack creation, get the instance information:

```powershell
$env:AWS_PROFILE="user-ec2-profile"

aws cloudformation describe-stacks `
  --stack-name webproject-web-app-stack `
  --region ap-south-1 `
  --query 'Stacks[0].Outputs' `
  --output table
```

Expected outputs:
- **InstanceId**: EC2 instance ID
- **InstancePublicIP**: Public IP to access web app
- **ApplicationURL**: Full URL to web application
- **SSHCommand**: SSH command to connect

---

## Application Endpoints

### Public Endpoints
- `GET /` - Web UI
- `GET /health` - Health check
- `POST /api/subscribe?email=user@example.com` - Subscribe to notifications
- `POST /api/unsubscribe?email=user@example.com` - Unsubscribe
- `GET /api/subscriptions` - List active subscriptions
- `POST /api/upload?fileName=...&fileSize=...` - Upload image

### Admin Endpoints
- `GET /admin/queue-status` - Check SQS queue status
- `POST /admin/process-queue` - Manually process messages
- `POST /admin/send-test-message` - Send test message to SQS

---

## Troubleshooting

### Application not responding
```powershell
# Check if instance is running
aws ec2 describe-instances `
  --instance-ids $INSTANCE_ID `
  --region ap-south-1 `
  --query 'Reservations[0].Instances[0].State.Name'

# Check security group rules
aws ec2 describe-security-groups `
  --group-ids $SG_ID `
  --region ap-south-1
```

### SSH connection fails
```powershell
# Verify key pair exists
Get-ChildItem ~/.ssh/your-key.pem

# Check instance details
aws ec2 describe-instances --instance-ids $INSTANCE_ID --region ap-south-1
```

### Application fails to start
```bash
# Check logs
tail -f /var/log/cloud-init-output.log
pm2 logs
node app.js  # Run manually to see errors
```

---

## Cleanup

To delete all resources:

```powershell
$env:AWS_PROFILE="user-ec2-profile"

# Delete EC2 stack
aws cloudformation delete-stack `
  --stack-name webproject-web-app-stack `
  --region ap-south-1

# Delete Lambda stack
aws cloudformation delete-stack `
  --stack-name webproject-uploads-stack `
  --region ap-south-1

# Delete SQS Queue
aws sqs delete-queue `
  --queue-url https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue `
  --region ap-south-1

# Delete SNS Topic
aws sns delete-topic `
  --topic-arn arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic `
  --region ap-south-1

# Empty and delete S3 bucket
aws s3 rm s3://webproject-sam-deployments-851189 --recursive
aws s3api delete-bucket --bucket webproject-sam-deployments-851189
```

---

## Success Indicators

✅ EC2 instance launched and running  
✅ Application accessible on port 8080  
✅ Can subscribe/unsubscribe via API  
✅ Can upload image notifications  
✅ SQS messages processed by Lambda  
✅ SNS publishes to email subscribers  
✅ CloudWatch logs show execution  

---

**Application Stack Ready!**
