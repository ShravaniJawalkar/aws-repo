# Implementation Guide: SQS/SNS Subscription Feature

## Overview

This guide provides step-by-step instructions to implement the subscription feature for your web application using AWS SQS (Simple Queue Service) and SNS (Simple Notification Service).

---

## Architecture Overview

```
┌──────────────────────┐
│  Web Application     │
│  - Upload Endpoint   │
│  - Subscribe Endpoint│
│  - Unsubscribe EP    │
└──────────┬───────────┘
           │
           │ 1. POST /api/upload
           │    (publish to SQS)
           ▼
    ┌─────────────┐
    │ SQS Queue   │
    │ (Buffer)    │
    └──────┬──────┘
           │
           │ 2. Background Worker
           │    (every 30 sec)
           ▼
    ┌─────────────┐
    │ SNS Topic   │
    └──────┬──────┘
           │
      ┌────┴────────┬──────────────┐
      │             │              │
      ▼             ▼              ▼
   Email      SMS/HTTP         Lambda/
 Subscribers  Webhooks         Other
```

---

## Phase 1: AWS Resource Creation

### 1.1 Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed and configured
- PowerShell (for running setup scripts)
- EC2 instance running your web application

### 1.2 Quick Setup (Automated)

Run the provided setup script:

```powershell
# Navigate to your AWS workspace
cd c:\Users\Shravani_Jawalkar\aws

# Run the automated setup
.\setup-sqssns-feature.ps1
```

This script will:
1. ✅ Create SQS Queue
2. ✅ Create SNS Topic
3. ✅ Connect SQS to SNS
4. ✅ Configure queue policies
5. ✅ Generate configuration file

### 1.3 Manual Setup (Step-by-Step)

If you prefer manual control, follow the commands in `SQS-SNS-SUBSCRIPTION-CLI-GUIDE.md`.

---

## Phase 2: Update Your Application

### 2.1 Install Dependencies

Update your `package.json`:

```json
{
  "name": "web-dynamic-app",
  "version": "1.0.0",
  "description": "Web application with subscription feature",
  "main": "app-enhanced.js",
  "dependencies": {
    "express": "^4.18.0",
    "aws-sdk": "^2.1400.0",
    "uuid": "^9.0.0",
    "axios": "^1.4.0",
    "dotenv": "^16.0.0"
  },
  "scripts": {
    "start": "node app-enhanced.js",
    "dev": "nodemon app-enhanced.js",
    "test": "npm run test:api"
  }
}
```

Install dependencies:

```powershell
cd .\web-dynamic-app
npm install
```

### 2.2 Configure Environment

Copy and update the environment file:

```powershell
# Copy example to actual env file
Copy-Item -Path ".\.env.example" -Destination ".\.env"

# Edit .env with your values
# Update these with actual values from setup script output:
# - SQS_QUEUE_URL
# - SNS_TOPIC_ARN
```

### 2.3 Deploy Application Code

Replace or update your `app.js` with `app-enhanced.js`:

```powershell
# Backup original
Rename-Item -Path "app.js" -NewName "app.js.backup"

# Use enhanced version
Copy-Item -Path "app-enhanced.js" -Destination "app.js"
```

Or merge the new code into your existing `app.js` by adding:
- Subscription endpoints (`/api/subscribe`, `/api/unsubscribe`)
- Upload endpoint modification to publish to SQS
- Background worker process
- Management endpoints for testing

---

## Phase 3: Update EC2 IAM Role

Your EC2 instance needs permissions to access SQS and SNS.

### Option A: Via CloudFormation (Recommended)

Update your `webproject-infrastructure.yaml` and redeploy:

```bash
aws cloudformation update-stack \
  --stack-name webProject-infrastructure \
  --template-body file://webproject-infrastructure.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=webproject \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-south-1 \
  --profile user-iam-profile
```

### Option B: Via CLI (Immediate)

```powershell
# Create policy file
$policy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Action = @(
                "sqs:SendMessage",
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "sqs:GetQueueAttributes",
                "sqs:GetQueueUrl"
            )
            Resource = "arn:aws:sqs:ap-south-1:*:webproject-UploadsNotificationQueue"
        },
        @{
            Effect = "Allow"
            Action = @(
                "sns:Publish",
                "sns:Subscribe",
                "sns:Unsubscribe",
                "sns:ListSubscriptionsByTopic"
            )
            Resource = "arn:aws:sns:ap-south-1:*:webproject-UploadsNotificationTopic"
        }
    )
}

$policy | ConvertTo-Json -Depth 10 | Out-File "sqssns-policy.json"

# Attach policy to EC2 instance role
aws iam put-role-policy `
  --role-name webproject-instance-role `
  --policy-name sqssns-access `
  --policy-document file://sqssns-policy.json `
  --profile user-iam-profile
```

---

## Phase 4: Testing the Implementation

### 4.1 Start Your Application

```powershell
cd .\web-dynamic-app
npm start
```

You should see:
```
Application started on port 8080
Background worker started. Processing interval: 30 seconds
```

### 4.2 Test Subscription Endpoint

**Via Browser:**
```
http://YOUR_EC2_IP:8080/api/subscribe?email=test@example.com
```

**Via PowerShell:**
```powershell
$email = "test@example.com"
curl -X POST "http://localhost:8080/api/subscribe?email=$email"
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Subscription pending confirmation. Please check test@example.com for a confirmation email from AWS.",
  "subscriptionArn": "arn:aws:sns:ap-south-1:...:PendingConfirmation"
}
```

**⚠️ Action Required:** User must click the confirmation link in the email they receive.

### 4.3 Test Image Upload

```powershell
curl -X POST "http://localhost:8080/api/upload?fileName=vacation.jpg&fileSize=2048576&description=Beach%20photo"
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Image uploaded successfully. Notification queued.",
  "uploadEvent": {
    "eventId": "550e8400-e29b-41d4-a716-446655440000",
    "fileName": "vacation.jpg",
    "fileSize": 2048576,
    "fileExtension": ".jpg",
    ...
  },
  "downloadUrl": "/api/download/550e8400.../vacation.jpg"
}
```

### 4.4 Monitor Queue Status

```powershell
curl http://localhost:8080/admin/queue-status
```

**Expected Response:**
```json
{
  "success": true,
  "queueUrl": "https://sqs.ap-south-1.amazonaws.com/...",
  "messages": {
    "available": 5,
    "delayed": 0,
    "notVisible": 0
  }
}
```

### 4.5 Manually Trigger Queue Processing

```powershell
curl -X POST http://localhost:8080/admin/process-queue
```

Check your email for the notification!

### 4.6 List Active Subscriptions

```powershell
curl http://localhost:8080/api/subscriptions
```

---

## Phase 5: Configure Message Filtering (Optional)

Filter notifications to only send specific file types:

### 5.1 PNG Files Only

```powershell
# Get subscription ARN from /api/subscriptions
$SubscriptionArn = "arn:aws:sns:ap-south-1:...:xxx"

# Create filter policy
$filterPolicy = @{ ImageExtension = @[".png"] } | ConvertTo-Json

# Apply filter
aws sns set-subscription-attributes `
  --subscription-arn $SubscriptionArn `
  --attribute-name FilterPolicy `
  --attribute-value $filterPolicy `
  --profile user-iam-profile
```

### 5.2 Multiple Extensions

```powershell
# JPG and PNG only
$filterPolicy = @{ ImageExtension = @[".jpg", ".png"] } | ConvertTo-Json
```

---

## Phase 6: Monitoring & Troubleshooting

### 6.1 Check CloudWatch Logs

```powershell
# View recent application logs
aws logs tail /aws/ec2/webproject-instance --follow `
  --profile user-iam-profile
```

### 6.2 Verify SQS Messages

```powershell
# Check queue attributes
$queueUrl = "https://sqs.ap-south-1.amazonaws.com/YOUR_ACCOUNT_ID/webproject-UploadsNotificationQueue"

aws sqs get-queue-attributes `
  --queue-url $queueUrl `
  --attribute-names All `
  --profile user-iam-profile
```

### 6.3 Common Issues

**Issue: "No messages in queue"**
- Ensure background worker is running
- Check EC2 instance has SQS permissions
- Verify queue URL is correct

**Issue: "Email not received"**
- Check SNS subscription status (should be "Confirmed")
- Verify email in subscription list
- Check AWS account email notification settings
- Look for confirmation email if pending

**Issue: "Permission Denied"**
- Verify EC2 IAM role has correct policies
- Check role name matches CloudFormation outputs
- Re-run IAM policy update

---

## Phase 7: Production Considerations

### 7.1 Error Handling

The application includes error handling for:
- Network failures (automatic retries via SQS)
- Invalid emails (validation before processing)
- Missing resources (graceful error messages)

### 7.2 Performance Tuning

Adjust in `.env`:
```
WORKER_INTERVAL_MS=30000     # Process every 30 seconds
SQS_BATCH_SIZE=10            # Max 10 messages per batch
SQS_VISIBILITY_TIMEOUT=300   # 5 minutes to process
```

### 7.3 Security

- Use EC2 IAM role (not access keys)
- Restrict queue policies to specific SNS topic
- Validate email addresses before subscription
- Enable encryption in transit (HTTPS)

### 7.4 Scaling

For high volume:
- Increase batch size (up to 10)
- Run multiple worker instances
- Use SNS fanout to multiple queues
- Consider Lambda for processing

---

## Alternative Notification Methods

Beyond email, your application can send notifications via:

### SMS (Text Message)
```powershell
aws sns subscribe `
  --topic-arn $TopicArn `
  --protocol sms `
  --notification-endpoint "+1234567890" `
  --profile user-iam-profile
```

### HTTP/HTTPS Webhook
```powershell
aws sns subscribe `
  --topic-arn $TopicArn `
  --protocol https `
  --notification-endpoint "https://example.com/webhook" `
  --profile user-iam-profile
```

### Lambda Function
```powershell
aws sns subscribe `
  --topic-arn $TopicArn `
  --protocol lambda `
  --notification-endpoint "arn:aws:lambda:ap-south-1:...:function:ProcessUploads" `
  --profile user-iam-profile
```

### Application Integration
```powershell
# Subscribe application to SQS (already done)
# Application polls SQS and processes messages
# Can send to multiple destinations (email, database, file storage)
```

---

## API Reference

### Subscription Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/subscribe` | POST | Subscribe email to notifications |
| `/api/unsubscribe` | POST | Unsubscribe email |
| `/api/subscriptions` | GET | List all subscriptions |

### Upload Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/upload` | POST | Upload image and queue notification |
| `/api/download/:eventId/:fileName` | GET | Download image |

### Admin Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/admin/queue-status` | GET | View SQS queue stats |
| `/admin/process-queue` | POST | Manually process queue |
| `/admin/send-test-message` | POST | Send test message |
| `/health` | GET | Health check |

---

## Deployment Checklist

- [ ] AWS resources created (SQS, SNS)
- [ ] EC2 IAM role updated with SQS/SNS permissions
- [ ] Application code deployed
- [ ] Dependencies installed
- [ ] Environment variables configured
- [ ] Application tested locally
- [ ] Email subscription tested and confirmed
- [ ] Background worker running
- [ ] Monitoring configured
- [ ] Error handling verified

---

## Next Steps

1. Deploy the updated application to EC2
2. Test all endpoints thoroughly
3. Monitor CloudWatch metrics
4. Configure additional notification channels as needed
5. Set up automated backups of subscription data
6. Implement retry logic for failed notifications
7. Add logging and monitoring dashboard

---

## Support & Resources

- [AWS SQS Documentation](https://docs.aws.amazon.com/sqs/)
- [AWS SNS Documentation](https://docs.aws.amazon.com/sns/)
- [AWS SDK for Node.js](https://docs.aws.amazon.com/sdk-for-javascript/)
- [Express.js Documentation](https://expressjs.com/)

