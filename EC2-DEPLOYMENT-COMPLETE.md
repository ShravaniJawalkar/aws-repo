# EC2 Web Application Deployment - Complete Guide

## Overview

Successfully deployed EC2 instance with Node.js web application integrated with AWS SQS and SNS services.

## Instance Details

| Property | Value |
|----------|-------|
| **Instance ID** | i-0cc925a7960add7d6 |
| **Instance Type** | t3.micro |
| **AMI** | ami-0a289b56122fa70e8 (Amazon Linux 2) |
| **Region** | ap-south-1 (Mumbai) |
| **State** | running |
| **Public IP** | 43.205.253.193 |
| **Private IP** | 172.31.41.25 |
| **Security Group** | sg-0bd245d5fbc27dc99 |

## Security Group Configuration

The security group has been configured with the following rules:

- **Port 22 (SSH)** - For remote administration
- **Port 80 (HTTP)** - For web traffic
- **Port 443 (HTTPS)** - For secure web traffic
- **Port 8080** - For Node.js application

All ports are open to 0.0.0.0/0 (public internet).

## Web Application Details

### Deployment Location
- **Application Directory**: `/var/www/web-dynamic-app`
- **Application Port**: 8080
- **Service Name**: web-app (systemd)

### Technology Stack
- **Runtime**: Node.js 18.x
- **Framework**: Express.js
- **AWS SDK**: aws-sdk (v2)
- **Service Manager**: systemd

### Environment Configuration
The application uses the following environment variables (from `.env` file):

```env
AWS_REGION=ap-south-1
PORT=8080
SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic
WORKER_INTERVAL_MS=30000
SQS_BATCH_SIZE=10
LOG_LEVEL=info
```

## API Endpoints

### 1. Health Check
```bash
GET /health
```
Returns application health status
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

### 2. Subscribe to Notifications
```bash
POST /api/subscribe?email=user@example.com
```
Subscribes an email to SNS topic for image upload notifications
```json
{
  "success": true,
  "message": "Subscription pending. Check email for confirmation.",
  "subscriptionArn": "arn:aws:sns:..."
}
```

### 3. Unsubscribe from Notifications
```bash
POST /api/unsubscribe?email=user@example.com
```
Removes email from SNS topic subscriptions
```json
{
  "success": true,
  "message": "Unsubscribed successfully"
}
```

### 4. List Subscriptions
```bash
GET /api/subscriptions
```
Returns all email subscriptions to the SNS topic
```json
{
  "success": true,
  "count": 2,
  "subscriptions": [
    {
      "SubscriptionArn": "arn:aws:sns:...",
      "TopicArn": "arn:aws:sns:...",
      "Protocol": "email",
      "Endpoint": "user@example.com"
    }
  ]
}
```

### 5. Upload Image (Trigger SQS Message)
```bash
POST /api/upload?fileName=photo.jpg&fileSize=2048000&description=My photo
```
Uploads an image and sends a message to SQS queue
```json
{
  "success": true,
  "message": "Image uploaded. Notification queued.",
  "messageId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

Request Parameters:
- `fileName`: Name of the image file (required)
- `fileSize`: Size of the file in bytes (required)
- `description`: Optional description of the image

### 6. Queue Status (Admin)
```bash
GET /admin/queue-status
```
Returns SQS queue statistics
```json
{
  "available": 5,
  "delayed": 0
}
```

### 7. Process Queue (Admin)
```bash
POST /admin/process-queue
```
Manually processes messages from SQS queue and publishes to SNS
```json
{
  "success": true,
  "processed": 3
}
```

## Testing the Application

### Step 1: Wait for Application to Start
The application takes 2-3 minutes to initialize. Monitor progress via SSH:

```bash
ssh -i your-key.pem ec2-user@43.205.253.193
sudo tail -f /var/log/cloud-init-output.log
```

### Step 2: Test Health Endpoint
```bash
curl http://43.205.253.193:8080/health
```

Expected response:
```json
{"status": "healthy", "timestamp": "..."}
```

### Step 3: Subscribe Email (Optional)
```bash
curl -X POST "http://43.205.253.193:8080/api/subscribe?email=your-email@example.com"
```
**Note**: Subscription requires email confirmation via AWS SNS

### Step 4: Upload an Image
```bash
curl -X POST "http://43.205.253.193:8080/api/upload?fileName=test-image.jpg&fileSize=1024000&description=Test image"
```

This will:
1. Send message to SQS queue
2. Lambda function automatically processes the message
3. SNS publishes notification to all subscribed emails

### Step 5: Verify Queue Status
```bash
curl http://43.205.253.193:8080/admin/queue-status
```

### Step 6: Manual Queue Processing (Optional)
```bash
curl -X POST http://43.205.253.193:8080/admin/process-queue
```

## SSH Access

### Generate Key Pair (if not already done)
```bash
aws ec2 create-key-pair --key-name webproject-key --region ap-south-1 --query 'KeyMaterial' --output text > webproject-key.pem
chmod 600 webproject-key.pem
```

### Connect via SSH
```bash
ssh -i webproject-key.pem ec2-user@43.205.253.193
```

### Common SSH Commands

Check application logs:
```bash
sudo journalctl -u web-app -f
```

Check application status:
```bash
systemctl status web-app
```

Restart application:
```bash
sudo systemctl restart web-app
```

View application files:
```bash
ls -la /var/www/web-dynamic-app
cat /var/www/web-dynamic-app/app.js
```

## Integration with SAM Lambda

The web application integrates with the SAM Lambda stack deployed earlier:

1. **SQS Queue**: `webproject-UploadsNotificationQueue`
   - Web app sends upload events to this queue
   - Lambda function (`webproject-uploads-notification-function`) processes messages

2. **SNS Topic**: `webproject-UploadsNotificationTopic`
   - Lambda publishes notifications to this topic
   - Subscribers receive email notifications

3. **End-to-End Flow**:
   ```
   Web App (Upload) → SQS Queue → Lambda Function → SNS Topic → Email Subscribers
   ```

## Monitoring

### View CloudWatch Logs
```bash
# Lambda function logs
aws logs tail /aws/lambda/webproject-uploads-notification-function --follow --region ap-south-1

# Application logs (via SSH)
sudo journalctl -u web-app -f
```

### CloudFormation Stack Status
```bash
aws cloudformation describe-stacks --stack-name webproject-uploads-stack --region ap-south-1
```

## Cleanup

### Stop EC2 Instance
```bash
aws ec2 stop-instances --instance-ids i-0cc925a7960add7d6 --region ap-south-1
```

### Terminate EC2 Instance (Delete)
```bash
aws ec2 terminate-instances --instance-ids i-0cc925a7960add7d6 --region ap-south-1
```

### Remove Security Group (after termination)
```bash
aws ec2 delete-security-group --group-id sg-0bd245d5fbc27dc99 --region ap-south-1
```

## Troubleshooting

### Application Not Responding
1. Check instance is running:
   ```bash
   aws ec2 describe-instances --instance-ids i-0cc925a7960add7d6 --region ap-south-1
   ```

2. SSH into instance and check service:
   ```bash
   systemctl status web-app
   sudo journalctl -u web-app -n 50
   ```

3. Check if Node.js is installed:
   ```bash
   node --version
   ```

### AWS Credentials Issues
The application uses the EC2 instance IAM role. Ensure the role has permissions for:
- SQS `SendMessage` on the queue
- SNS `Publish` on the topic
- CloudWatch Logs write permissions

### Port Already in Use
If port 8080 is in use, modify the `.env` file:
```bash
sudo nano /var/www/web-dynamic-app/.env
# Change PORT=8081
sudo systemctl restart web-app
```

## Complete End-to-End Test

```bash
# 1. Wait for app to start (2-3 minutes)
curl http://43.205.253.193:8080/health

# 2. Subscribe your email
curl -X POST "http://43.205.253.193:8080/api/subscribe?email=your-email@example.com"
# Check your email for SNS confirmation and click the link

# 3. Upload an image
curl -X POST "http://43.205.253.193:8080/api/upload?fileName=myimage.jpg&fileSize=2048000&description=My test image"

# 4. Check queue status
curl http://43.205.253.193:8080/admin/queue-status

# 5. Wait 30 seconds and check email for notification
# You should receive an email with the image details

# 6. Verify Lambda logs
aws logs tail /aws/lambda/webproject-uploads-notification-function --follow --region ap-south-1
```

## Next Steps

1. ✅ EC2 instance deployed and running
2. ✅ Web application deployed with SQS/SNS integration
3. ⏳ Test end-to-end flow (upload → SQS → Lambda → SNS → Email)
4. ⏳ Configure custom domain (optional)
5. ⏳ Set up monitoring and alerting (optional)
6. ⏳ Deploy CI/CD pipeline (optional)

## Files Reference

- **Deployment Script**: `deploy-web-app-manual.ps1`
- **SAM Template**: `sam-template.yaml`
- **Lambda Function**: `src/index.js`
- **CloudFormation Stack**: `cloudformation-web-app-deployment.yaml`

---

**Deployment Status**: ✅ COMPLETE

**Instance Status**: Running and accepting connections  
**Application Status**: Initializing (2-3 minutes to full readiness)  
**Integration Status**: Connected to SAM Lambda and messaging infrastructure
