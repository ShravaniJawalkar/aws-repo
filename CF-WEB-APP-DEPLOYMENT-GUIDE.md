# CloudFormation Deployment Guide: Web Application with SQS/SNS

## Overview

The `cloudformation-web-app-deployment.yaml` template creates:
- ✅ EC2 instance (t2.micro or t3.micro)
- ✅ IAM role with SQS/SNS permissions
- ✅ Security groups (SSH, HTTP, HTTPS, port 8080)
- ✅ Complete web application deployment
- ✅ Node.js runtime
- ✅ npm dependencies installed
- ✅ Systemd service for auto-restart
- ✅ Environment configuration

---

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
3. **SQS Queue URL** - Created via `.\setup-sqssns-feature.ps1`
4. **SNS Topic ARN** - Created via `.\setup-sqssns-feature.ps1`
5. **EC2 Key Pair** - For SSH access

---

## Step 1: Get SQS and SNS Details

First, create the AWS resources if not already done:

```powershell
cd c:\Users\Shravani_Jawalkar\aws
.\setup-sqssns-feature.ps1
```

This will output:
```
SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/123456789012/webproject-UploadsNotificationQueue
SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:123456789012:webproject-UploadsNotificationTopic
```

**Save these values** - you'll need them in Step 2.

---

## Step 2: Create CloudFormation Stack

### Option A: Using AWS CLI (Recommended)

```powershell
# Set your parameters
$StackName = "webproject-app-stack"
$ProjectName = "webproject"
$InstanceType = "t2.micro"
$SSHLocation = "0.0.0.0/0"  # Change this to your IP for security
$SQSQueueURL = "https://sqs.ap-south-1.amazonaws.com/123456789012/webproject-UploadsNotificationQueue"
$SNSTopicARN = "arn:aws:sns:ap-south-1:123456789012:webproject-UploadsNotificationTopic"

# Create the stack
aws cloudformation create-stack `
  --stack-name $StackName `
  --template-body file://cloudformation-web-app-deployment.yaml `
  --parameters `
    ParameterKey=ProjectName,ParameterValue=$ProjectName `
    ParameterKey=ProjectInstanceType,ParameterValue=$InstanceType `
    ParameterKey=SSHLocation,ParameterValue=$SSHLocation `
    ParameterKey=SQSQueueURL,ParameterValue=$SQSQueueURL `
    ParameterKey=SNSTopicARN,ParameterValue=$SNSTopicARN `
  --capabilities CAPABILITY_NAMED_IAM `
  --region ap-south-1 `
  --profile user-iam-profile

Write-Host "Stack creation initiated. Checking status..."

# Wait for stack to complete
aws cloudformation wait stack-create-complete `
  --stack-name $StackName `
  --region ap-south-1 `
  --profile user-iam-profile

Write-Host "Stack created successfully!"
```

### Option B: Using AWS Console

1. Go to CloudFormation console
2. Click "Create Stack"
3. Upload: `cloudformation-web-app-deployment.yaml`
4. Fill in parameters:
   - ProjectName: `webproject`
   - ProjectInstanceType: `t2.micro`
   - SSHLocation: `0.0.0.0/0` (or your IP)
   - SQSQueueURL: `<from step 1>`
   - SNSTopicARN: `<from step 1>`
5. Click "Create Stack"
6. Wait for completion

---

## Step 3: Get Instance Details

After stack creation completes:

```powershell
# Get stack outputs
aws cloudformation describe-stacks `
  --stack-name webproject-app-stack `
  --region ap-south-1 `
  --profile user-iam-profile `
  --query 'Stacks[0].Outputs' `
  --output table
```

You'll see:
```
InstanceId:        i-0123456789abcdef0
InstancePublicIP:  54.123.45.67
InstancePrivateIP: 10.0.1.100
SecurityGroupId:   sg-0123456789abcdef0
IAMRoleName:       webproject-instance-role
ApplicationURL:    http://54.123.45.67:8080
SSHCommand:        ssh -i your-key.pem ec2-user@54.123.45.67
```

**Save the Instance Public IP** - you'll use this to access the application.

---

## Step 4: Verify Deployment

### Check Application Status

```powershell
# Replace with your instance IP
$InstanceIP = "54.123.45.67"

# Health check
curl http://$InstanceIP:8080/health

# Expected response:
# {
#   "status": "healthy",
#   "timestamp": "2025-01-07T10:00:00.000Z"
# }
```

### SSH into Instance

```powershell
# Replace with your key pair path and instance IP
ssh -i "path/to/key.pem" ec2-user@54.123.45.67

# Check application status
sudo systemctl status web-app

# View application logs
sudo journalctl -u web-app -f

# Check application files
ls -la /var/www/web-dynamic-app/
```

---

## Step 5: Test the Application

### Subscribe Email

```powershell
$InstanceIP = "54.123.45.67"
curl -X POST "http://$InstanceIP:8080/api/subscribe?email=test@example.com"
```

Expected response:
```json
{
  "success": true,
  "message": "Subscription pending confirmation...",
  "subscriptionArn": "arn:aws:sns:..."
}
```

### Upload Image

```powershell
curl -X POST "http://$InstanceIP:8080/api/upload?fileName=vacation.jpg&fileSize=2048576"
```

### Check Queue Status

```powershell
curl http://$InstanceIP:8080/admin/queue-status
```

### Process Queue Manually

```powershell
curl -X POST http://$InstanceIP:8080/admin/process-queue
```

---

## Stack Management

### Update Stack

If you need to update the stack:

```powershell
aws cloudformation update-stack `
  --stack-name webproject-app-stack `
  --template-body file://cloudformation-web-app-deployment.yaml `
  --parameters `
    ParameterKey=SQSQueueURL,ParameterValue="https://sqs.ap-south-1.amazonaws.com/..." `
    ParameterKey=SNSTopicARN,ParameterValue="arn:aws:sns:ap-south-1:..." `
  --capabilities CAPABILITY_NAMED_IAM `
  --region ap-south-1 `
  --profile user-iam-profile
```

### Delete Stack

```powershell
aws cloudformation delete-stack `
  --stack-name webproject-app-stack `
  --region ap-south-1 `
  --profile user-iam-profile
```

### Check Stack Events

```powershell
aws cloudformation describe-stack-events `
  --stack-name webproject-app-stack `
  --region ap-south-1 `
  --profile user-iam-profile
```

---

## Troubleshooting

### Stack Creation Failed

Check the events:
```powershell
aws cloudformation describe-stack-events `
  --stack-name webproject-app-stack `
  --region ap-south-1 `
  --profile user-iam-profile `
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]' `
  --output table
```

### Application Not Running

SSH into instance and check:
```bash
# Check service status
sudo systemctl status web-app

# View recent logs
sudo journalctl -u web-app -n 50

# Check if Node.js is installed
node --version

# Check npm
npm --version

# Manually restart service
sudo systemctl restart web-app
```

### Port 8080 Not Accessible

1. Verify security group allows port 8080:
```powershell
aws ec2 describe-security-groups `
  --group-ids sg-0123456789abcdef0 `
  --region ap-south-1 `
  --profile user-iam-profile
```

2. Check if application is listening:
```bash
# SSH to instance
lsof -i :8080
netstat -tlnp | grep 8080
```

### SQS/SNS Permissions Issues

The template includes IAM permissions, but verify:
```bash
# On instance, check role
ec2-metadata --iam-security-credentials

# Check SQS access
aws sqs list-queues --region ap-south-1
```

---

## Template Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| ProjectName | webproject | Name for all resources |
| ProjectAMI | ami-0c55b159cbfafe1f0 | Amazon Linux 2 AMI |
| ProjectInstanceType | t2.micro | EC2 instance type |
| SSHLocation | 0.0.0.0/0 | IP for SSH access |
| SQSQueueURL | (empty) | Your SQS queue URL |
| SNSTopicARN | (empty) | Your SNS topic ARN |

---

## What Gets Deployed

### On EC2 Instance

1. **System Updates**
   - Latest packages
   - Security patches

2. **Runtime**
   - Node.js 18
   - npm package manager

3. **Application**
   - app.js (520 lines)
   - package.json (dependencies)
   - .env (configuration)

4. **Dependencies**
   - express (web framework)
   - aws-sdk (AWS services)
   - uuid (unique IDs)
   - axios (HTTP client)
   - dotenv (configuration)

5. **Service**
   - Systemd service file
   - Auto-restart on failure
   - Auto-start on boot

---

## Post-Deployment Steps

### 1. Verify Application

```powershell
curl http://YOUR_IP:8080/health
curl http://YOUR_IP:8080/
```

### 2. Configure Email Notifications

```powershell
# Subscribe
curl -X POST "http://YOUR_IP:8080/api/subscribe?email=your@email.com"

# Check your email for AWS confirmation link
# Click the confirmation link

# Verify subscription
curl http://YOUR_IP:8080/api/subscriptions
```

### 3. Test Upload Flow

```powershell
# Upload test image
curl -X POST "http://YOUR_IP:8080/api/upload?fileName=test.jpg&fileSize=1024000"

# Wait 30 seconds for background worker

# Check your email for notification
```

### 4. Monitor Application

```bash
# SSH to instance
ssh -i key.pem ec2-user@YOUR_IP

# Watch logs
sudo journalctl -u web-app -f

# Check queue status
curl http://YOUR_IP:8080/admin/queue-status
```

---

## Performance Tuning

### Increase Instance Size

For higher load, update the stack with larger instance:

```powershell
aws cloudformation update-stack `
  --stack-name webproject-app-stack `
  --use-previous-template `
  --parameters `
    ParameterKey=ProjectInstanceType,ParameterValue=t3.small `
  --capabilities CAPABILITY_NAMED_IAM
```

### Adjust Worker Interval

SSH to instance and edit:
```bash
sudo vi /var/www/web-dynamic-app/.env

# Change:
# WORKER_INTERVAL_MS=30000  (to 10000 for faster processing)

# Restart:
sudo systemctl restart web-app
```

---

## Cost Estimation

### Monthly Cost (ap-south-1 region)

| Resource | Cost |
|----------|------|
| t2.micro | ~$0.47/month |
| SQS | Free (< 1M) |
| SNS | Free (< 1M) |
| **Total** | **~$0.47/month** |

---

## Security Notes

1. **SSH Access**: Change `SSHLocation` from `0.0.0.0/0` to your IP
2. **HTTPS**: Use Application Load Balancer with certificate
3. **Secrets**: Store in AWS Secrets Manager (not in .env)
4. **IAM**: Use least privilege (current is already restricted)
5. **Logging**: Enable CloudWatch Logs for audit trail

---

## Scaling Options

### Option 1: Auto-Scaling Group
Modify template to use Launch Template + ASG

### Option 2: Load Balancer
Add ALB in front of instances

### Option 3: Container
Use ECS with Docker

### Option 4: Serverless
Migrate to Lambda + API Gateway

---

## Rollback

If something goes wrong:

```powershell
aws cloudformation cancel-update-stack `
  --stack-name webproject-app-stack `
  --region ap-south-1 `
  --profile user-iam-profile
```

Or delete and recreate:

```powershell
# Delete
aws cloudformation delete-stack `
  --stack-name webproject-app-stack `
  --region ap-south-1

# Wait for deletion
aws cloudformation wait stack-delete-complete `
  --stack-name webproject-app-stack `
  --region ap-south-1

# Recreate with fixed parameters
aws cloudformation create-stack ...
```

---

## Quick Commands Reference

```powershell
# Get instance IP
aws cloudformation describe-stacks `
  --stack-name webproject-app-stack `
  --query 'Stacks[0].Outputs[?OutputKey==`InstancePublicIP`].OutputValue' `
  --output text

# Get application URL
aws cloudformation describe-stacks `
  --stack-name webproject-app-stack `
  --query 'Stacks[0].Outputs[?OutputKey==`ApplicationURL`].OutputValue' `
  --output text

# Health check
curl (aws cloudformation describe-stacks `
  --stack-name webproject-app-stack `
  --query 'Stacks[0].Outputs[?OutputKey==`InstancePublicIP`].OutputValue' `
  --output text):8080/health
```

---

## Support

For issues:
1. Check CloudWatch Logs
2. SSH to instance and review journalctl
3. Check stack events for creation errors
4. Review IAM permissions
5. Verify SQS/SNS resources exist

---

**You're all set! Access your application at the URL from the stack outputs.** 🚀

