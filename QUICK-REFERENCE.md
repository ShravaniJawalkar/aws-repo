# Quick Reference: SQS/SNS Commands & Endpoints

## One-Liner Setup

```powershell
# Create all AWS resources automatically
cd c:\Users\Shravani_Jawalkar\aws
.\setup-sqssns-feature.ps1
```

---

## Essential AWS CLI Commands

### Create Resources
```bash
# Create queue
aws sqs create-queue --queue-name webproject-UploadsNotificationQueue --region ap-south-1

# Create topic
aws sns create-topic --name webproject-UploadsNotificationTopic --region ap-south-1

# Subscribe queue to topic
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-south-1:ACCOUNT_ID:webproject-UploadsNotificationTopic \
  --protocol sqs \
  --notification-endpoint arn:aws:sqs:ap-south-1:ACCOUNT_ID:webproject-UploadsNotificationQueue
```

### Manage Subscriptions
```bash
# List subscriptions
aws sns list-subscriptions-by-topic --topic-arn <TOPIC_ARN>

# Unsubscribe
aws sns unsubscribe --subscription-arn <SUB_ARN>

# Subscribe email
aws sns subscribe \
  --topic-arn <TOPIC_ARN> \
  --protocol email \
  --notification-endpoint user@example.com
```

### Test Messages
```bash
# Send to SQS
aws sqs send-message \
  --queue-url <QUEUE_URL> \
  --message-body "Test message"

# Receive from SQS
aws sqs receive-message --queue-url <QUEUE_URL>

# Publish to SNS
aws sns publish \
  --topic-arn <TOPIC_ARN> \
  --subject "Test" \
  --message "Test message"
```

### Monitor Queue
```bash
# Get queue attributes
aws sqs get-queue-attributes \
  --queue-url <QUEUE_URL> \
  --attribute-names All

# Purge queue (delete all messages)
aws sqs purge-queue --queue-url <QUEUE_URL>
```

---

## API Endpoints Quick Reference

### Subscribe/Unsubscribe
```
POST   /api/subscribe?email=user@example.com
POST   /api/unsubscribe?email=user@example.com
GET    /api/subscriptions
```

### Upload
```
POST   /api/upload?fileName=image.jpg&fileSize=1024000
GET    /api/download/:eventId/:fileName
```

### Admin
```
GET    /health
GET    /admin/queue-status
POST   /admin/process-queue
POST   /admin/send-test-message
```

---

## Testing Commands

### PowerShell
```powershell
# Subscribe
curl -X POST "http://localhost:8080/api/subscribe?email=test@example.com"

# Unsubscribe
curl -X POST "http://localhost:8080/api/unsubscribe?email=test@example.com"

# List subscriptions
curl http://localhost:8080/api/subscriptions

# Upload image
curl -X POST "http://localhost:8080/api/upload?fileName=photo.jpg&fileSize=2048576"

# Check queue status
curl http://localhost:8080/admin/queue-status

# Process queue
curl -X POST http://localhost:8080/admin/process-queue

# Send test message
curl -X POST http://localhost:8080/admin/send-test-message

# Health check
curl http://localhost:8080/health
```

### Bash/Linux
```bash
# Subscribe
curl -X POST "http://localhost:8080/api/subscribe?email=test@example.com"

# Upload
curl -X POST "http://localhost:8080/api/upload?fileName=photo.jpg&fileSize=2048576"

# Process queue
curl -X POST http://localhost:8080/admin/process-queue
```

---

## Environment Variables

```bash
# Required
SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/ACCOUNT/webproject-UploadsNotificationQueue
SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:ACCOUNT:webproject-UploadsNotificationTopic

# Optional
PORT=8080
NODE_ENV=production
WORKER_INTERVAL_MS=30000
SQS_BATCH_SIZE=10
```

---

## Application Lifecycle

```powershell
# 1. Navigate to app directory
cd web-dynamic-app

# 2. Install dependencies
npm install

# 3. Start application
npm start

# 4. In another terminal, test
.\test-subscription-feature.ps1

# 5. Check status
curl http://localhost:8080/health

# 6. Stop application (Ctrl+C)
```

---

## Troubleshooting Quick Fixes

| Problem | Fix |
|---------|-----|
| Queue not found | Check URL matches created queue |
| Permission denied | Update EC2 IAM role, restart instance |
| No email received | Click confirmation link, check spam folder |
| Worker not processing | Check app logs, verify SQS permissions |
| Queue has old messages | Run `aws sqs purge-queue --queue-url <URL>` |

---

## Message Formats

### Upload Event (SQS Message)
```json
{
  "eventId": "uuid",
  "fileName": "photo.jpg",
  "fileSize": 2048576,
  "fileExtension": ".jpg",
  "timestamp": "2024-01-07T10:00:00Z"
}
```

### SNS Notification (Email)
```
Subject: Image Upload Notification: photo.jpg

IMAGE UPLOAD NOTIFICATION
File: photo.jpg
Size: 2.0 MB
Type: .jpg
Time: 2024-01-07T10:00:00Z

Download: http://your-app/api/download/...
```

---

## Key Files Reference

| File | Purpose | Command |
|------|---------|---------|
| `app-enhanced.js` | Main app | `npm start` |
| `package.json` | Dependencies | `npm install` |
| `.env` | Configuration | Edit after setup |
| `setup-sqssns-feature.ps1` | AWS setup | `.\setup-sqssns-feature.ps1` |
| `test-subscription-feature.ps1` | Testing | `.\test-subscription-feature.ps1` |
| `API-DOCUMENTATION.md` | API reference | Read for examples |

---

## Ports & URLs

| Service | URL | Port |
|---------|-----|------|
| Web App | http://localhost:8080 | 8080 |
| SQS | https://sqs.ap-south-1.amazonaws.com | 443 |
| SNS | https://sns.ap-south-1.amazonaws.com | 443 |
| AWS Console | https://console.aws.amazon.com | 443 |

---

## IAM Permissions Needed

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:ap-south-1:*:webproject-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish",
        "sns:Subscribe",
        "sns:Unsubscribe",
        "sns:ListSubscriptionsByTopic"
      ],
      "Resource": "arn:aws:sns:ap-south-1:*:webproject-*"
    }
  ]
}
```

---

## Common Tasks

### Subscribe User to Notifications
```bash
curl -X POST "http://localhost:8080/api/subscribe?email=user@example.com"
# User receives confirmation email → clicks link → subscription active
```

### Upload Image and Trigger Notification
```bash
curl -X POST "http://localhost:8080/api/upload?fileName=vacation.jpg&fileSize=2048576"
# Message queued → background worker processes → email sent
```

### Check Queue Status
```bash
curl http://localhost:8080/admin/queue-status
# Shows available, delayed, not visible messages
```

### Force Queue Processing
```bash
curl -X POST http://localhost:8080/admin/process-queue
# Immediately processes all pending messages (normally happens every 30s)
```

### Unsubscribe User
```bash
curl -X POST "http://localhost:8080/api/unsubscribe?email=user@example.com"
# User stops receiving emails
```

---

## Performance Numbers

- **Queue polling interval:** 30 seconds
- **Batch size:** 10 messages max
- **Visibility timeout:** 30 seconds
- **Message retention:** 4 days
- **Email delivery:** <5 minutes typically
- **Cost for 10k uploads:** ~$0 (free tier)

---

## AWS Service Limits (Relevant)

- **SQS messages per second:** 300
- **SNS publishes per second:** 150,000
- **Email confirmations valid:** 3 days
- **Long polling max:** 20 seconds

---

## Important URLs

| Service | Link |
|---------|------|
| AWS Console | https://console.aws.amazon.com |
| SQS Dashboard | https://console.aws.amazon.com/sqs |
| SNS Dashboard | https://console.aws.amazon.com/sns |
| CloudWatch | https://console.aws.amazon.com/cloudwatch |
| IAM | https://console.aws.amazon.com/iam |

---

## How to Read Documentation

**Just setting up?**
→ Read: PROJECT-SUMMARY.md (overview) → setup-sqssns-feature.ps1 (automated setup)

**Need implementation details?**
→ Read: IMPLEMENTATION-GUIDE.md

**Building integration?**
→ Read: API-DOCUMENTATION.md

**Need AWS CLI commands?**
→ Read: SQS-SNS-SUBSCRIPTION-CLI-GUIDE.md

**Testing your setup?**
→ Run: test-subscription-feature.ps1

---

## Cheat Sheet: From Zero to Working

```powershell
# 1. Create infrastructure (5 min)
cd c:\Users\Shravani_Jawalkar\aws
.\setup-sqssns-feature.ps1
# → Saves config to aws-sqssns-config.env

# 2. Install app (2 min)
cd web-dynamic-app
npm install
Copy-Item "app-enhanced.js" "app.js"
Copy-Item ".\.env.example" ".\.env"

# 3. Edit .env (1 min)
# Update SQS_QUEUE_URL and SNS_TOPIC_ARN from step 1

# 4. Start app (1 min)
npm start

# 5. Test (3 min)
# In new terminal:
.\test-subscription-feature.ps1

# 6. Try it (5 min)
# Browser: http://localhost:8080
# Click Subscribe → Check email → Confirm

# Total time: ~20 minutes
```

---

## Email Subscription Confirmation Flow

```
1. User calls /api/subscribe?email=user@example.com
2. App calls sns.subscribe()
3. SNS sends confirmation email to user@example.com
4. Email contains link: https://sns.amazonaws.com/confirm/...
5. User clicks link in email
6. Subscription becomes ACTIVE
7. User now receives image upload notifications
```

---

## Debug Mode

```powershell
# View application logs
npm start 2>&1 | Tee-Object -FilePath "app.log"

# View SQS queue in AWS console
# https://console.aws.amazon.com/sqs/

# View SNS subscriptions in AWS console
# https://console.aws.amazon.com/sns/

# View CloudWatch logs
aws logs tail /aws/ec2/webproject --follow
```

---

## Common Error Messages & Solutions

```
"Queue does not exist"
→ Verify URL: aws sqs list-queues

"User is not authorized"
→ Update IAM role: aws iam list-role-policies --role-name webproject-instance-role

"Email not received"
→ Check: aws sns list-subscriptions-by-topic --topic-arn <ARN>

"No messages in queue"
→ Check: aws sqs get-queue-attributes --queue-url <URL> --attribute-names All

"Connection refused"
→ Verify app running: curl http://localhost:8080/health
```

---

## Next Quick Steps After Setup

1. ✅ Resources created
2. ✅ App installed
3. ⏭️ Test with email
4. ⏭️ Upload test image
5. ⏭️ Monitor queue status
6. ⏭️ Configure filters (optional)
7. ⏭️ Set up SMS (optional)

