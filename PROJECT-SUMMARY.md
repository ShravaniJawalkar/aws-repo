# Complete SQS/SNS Subscription Feature - Project Summary

## Project Overview

This is a comprehensive guide for implementing a **subscription and notification system** for a web application using AWS SQS (Simple Queue Service) and SNS (Simple Notification Service). The system enables:

1. **User Email Subscriptions** - Users subscribe to image upload notifications
2. **Image Upload Notifications** - When images are uploaded, notifications are queued
3. **Batch Processing** - Background worker processes messages in batches
4. **Email Delivery** - Notifications sent to all subscribers via email

---

## What You'll Have After Completing This Guide

✅ **AWS Infrastructure**
- SQS Queue for message buffering
- SNS Topic for message distribution
- Queue policies for service integration

✅ **Web Application Features**
- `/api/subscribe` - Subscribe emails
- `/api/unsubscribe` - Unsubscribe emails
- `/api/upload` - Upload images and queue notifications
- `/api/subscriptions` - List active subscriptions

✅ **Background Processing**
- Automatic message polling (every 30 seconds)
- Batch message processing
- SNS message publishing

✅ **Testing & Monitoring**
- Admin endpoints for testing
- Queue status monitoring
- Health check endpoints

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Web Application                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Express.js Server (Node.js)                         │  │
│  │  - Subscription Management                           │  │
│  │  - Image Upload Handler                              │  │
│  │  - Admin Endpoints                                   │  │
│  └──────────┬────────────────────────────────┬──────────┘  │
│             │                                │              │
│    Upload Event                      Background Worker      │
│    (SQS Message)                     (Timer: 30s)           │
│             │                                │              │
└─────────────┼────────────────────────────────┼──────────────┘
              │                                │
              ▼                                │
       ┌────────────────┐                     │
       │  SQS Queue     │                     │
       │  (Buffering)   │                     │
       └────────┬───────┘                     │
                │                            │
                │ Polling                    │
                │ (Batch: 10 msgs)           │
                │                            │
                └────────────┬────────────────┘
                             │
                             ▼
                      ┌────────────────┐
                      │   SNS Topic    │
                      │ (Distribution) │
                      └────────┬───────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
                ▼              ▼              ▼
           Email           SMS            Webhooks
         Subscribers      (Optional)      (Optional)
```

---

## Quick Start (5 Minutes)

### Step 1: Create AWS Resources

```powershell
cd c:\Users\Shravani_Jawalkar\aws
.\setup-sqssns-feature.ps1
```

This automatically:
- Creates SQS queue
- Creates SNS topic
- Configures policies
- Generates configuration file

### Step 2: Install Application Dependencies

```powershell
cd web-dynamic-app
npm install
```

### Step 3: Configure Application

```powershell
# Copy environment file
Copy-Item ".\.env.example" ".\.env"

# Edit with values from Step 1
# Update: SQS_QUEUE_URL, SNS_TOPIC_ARN
```

### Step 4: Update IAM Permissions

Ensure your EC2 instance IAM role has SQS and SNS permissions (included in the setup script).

### Step 5: Deploy & Test

```powershell
# Deploy enhanced app
Copy-Item "app-enhanced.js" "app.js"

# Start application
npm start

# In another terminal, run tests
.\test-subscription-feature.ps1
```

---

## File Structure

### Core Application Files

| File | Purpose |
|------|---------|
| `web-dynamic-app/app-enhanced.js` | Main application with SQS/SNS integration |
| `web-dynamic-app/package.json` | Node.js dependencies |
| `web-dynamic-app/.env.example` | Environment configuration template |

### Configuration & Setup

| File | Purpose |
|------|---------|
| `setup-sqssns-feature.ps1` | Automated AWS resource creation |
| `aws-sqssns-config.env` | Generated configuration (after setup) |
| `sqs-queue-policy.json` | SQS queue access policy |

### Documentation

| File | Purpose |
|------|---------|
| `SQS-SNS-SUBSCRIPTION-CLI-GUIDE.md` | Complete AWS CLI commands reference |
| `IMPLEMENTATION-GUIDE.md` | Step-by-step implementation instructions |
| `API-DOCUMENTATION.md` | Complete API reference with examples |
| `ARCHITECTURE-OVERVIEW.md` | This file |

### Testing

| File | Purpose |
|------|---------|
| `test-subscription-feature.ps1` | Automated test suite |

---

## Directory Structure

```
aws/
├── web-dynamic-app/
│   ├── app.js (original)
│   ├── app-enhanced.js (NEW - with SQS/SNS)
│   ├── package.json (updated)
│   ├── .env.example (NEW)
│   └── guide/
├── setup-sqssns-feature.ps1 (NEW)
├── test-subscription-feature.ps1 (NEW)
├── SQS-SNS-SUBSCRIPTION-CLI-GUIDE.md (NEW)
├── IMPLEMENTATION-GUIDE.md (NEW)
├── API-DOCUMENTATION.md (NEW)
├── webproject-infrastructure.yaml (existing - needs IAM updates)
└── ... (other existing files)
```

---

## Key Concepts

### SQS (Simple Queue Service)
- **Buffering Layer** - Decouples upload events from processing
- **Reliability** - Messages persist for 4 days
- **Scalability** - Handles millions of messages
- **Cost-effective** - Pay per request, free tier available

### SNS (Simple Notification Service)
- **Distribution Hub** - Routes messages to multiple subscribers
- **Multi-Protocol** - Email, SMS, webhooks, Lambda, SQS, etc.
- **Filtering** - Optional message attribute filters
- **Confirmation** - Required for email subscriptions

### Background Worker
- **Polling Model** - Continuously checks SQS for messages
- **Batch Processing** - Fetches up to 10 messages per cycle
- **Automatic Publishing** - Sends to SNS when processing
- **Error Handling** - Retries on failure

---

## API Summary

### Subscription Endpoints
```
POST   /api/subscribe?email=user@example.com
POST   /api/unsubscribe?email=user@example.com
GET    /api/subscriptions
```

### Upload Endpoints
```
POST   /api/upload?fileName=image.jpg&fileSize=1024000
GET    /api/download/:eventId/:fileName
```

### Admin Endpoints
```
POST   /admin/process-queue                    (manual trigger)
GET    /admin/queue-status                     (view metrics)
POST   /admin/send-test-message                (test message)
GET    /health                                 (health check)
```

---

## Message Flow Example

```
1. User calls: POST /api/subscribe?email=john@example.com
   ↓
2. Application calls: sns.subscribe()
   ↓
3. AWS SNS sends confirmation email to john@example.com
   ↓
4. User clicks confirmation link (email → AWS SNS)
   ↓
5. Subscription becomes ACTIVE
   ↓
6. User uploads image: POST /api/upload?fileName=photo.jpg
   ↓
7. Application publishes to SQS:
   {
     "eventId": "uuid",
     "fileName": "photo.jpg",
     "fileSize": 2048576,
     "timestamp": "2024-01-07T10:00:00Z"
   }
   ↓
8. Background worker polls SQS (every 30 seconds)
   ↓
9. Worker receives message, formats notification text
   ↓
10. Worker publishes to SNS:
    - Subject: "Image Upload Notification: photo.jpg"
    - Message: Formatted text with metadata and download link
    - Attributes: ImageExtension=".jpg", FileSize="2048576"
    ↓
11. SNS delivers to all ACTIVE subscribers
    ↓
12. john@example.com receives email with:
    - Image details
    - Download link
    - Unsubscribe option
```

---

## AWS CLI Command Reference

### Create SQS Queue
```bash
aws sqs create-queue \
  --queue-name webproject-UploadsNotificationQueue \
  --region ap-south-1 \
  --profile user-iam-profile
```

### Create SNS Topic
```bash
aws sns create-topic \
  --name webproject-UploadsNotificationTopic \
  --region ap-south-1 \
  --profile user-iam-profile
```

### Subscribe SQS to SNS
```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-south-1:...:webproject-UploadsNotificationTopic \
  --protocol sqs \
  --notification-endpoint arn:aws:sqs:ap-south-1:...:webproject-UploadsNotificationQueue \
  --region ap-south-1 \
  --profile user-iam-profile
```

### Subscribe Email
```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-south-1:...:webproject-UploadsNotificationTopic \
  --protocol email \
  --notification-endpoint user@example.com \
  --region ap-south-1 \
  --profile user-iam-profile
```

### Publish Message
```bash
aws sns publish \
  --topic-arn arn:aws:sns:ap-south-1:...:webproject-UploadsNotificationTopic \
  --subject "Image Upload" \
  --message "Photo uploaded" \
  --region ap-south-1 \
  --profile user-iam-profile
```

---

## Environment Variables

```bash
# AWS Configuration
AWS_REGION=ap-south-1
AWS_PROFILE=user-iam-profile

# SQS
SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/123456789012/webproject-UploadsNotificationQueue

# SNS
SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:123456789012:webproject-UploadsNotificationTopic

# Application
PORT=8080
NODE_ENV=production

# Worker Settings
WORKER_INTERVAL_MS=30000        # 30 seconds
SQS_BATCH_SIZE=10               # messages per poll
```

---

## Testing Checklist

- [ ] AWS resources created (SQS queue, SNS topic)
- [ ] Queue policy configured
- [ ] EC2 IAM role has SQS/SNS permissions
- [ ] Dependencies installed
- [ ] Environment variables set
- [ ] Application starts without errors
- [ ] Health check endpoint works
- [ ] Email subscription works
- [ ] Confirmation email received and clicked
- [ ] Image upload queues message
- [ ] Background worker processes messages
- [ ] Notification email received
- [ ] Unsubscribe works
- [ ] No further notifications received after unsubscribe

---

## Troubleshooting Guide

### Issue: "Queue does not exist"
**Solution:** Verify queue URL matches the queue you created. Check in AWS console.

### Issue: "User is not authorized"
**Solution:** Update EC2 IAM role with correct SQS/SNS permissions. Restart EC2 instance.

### Issue: "No email received"
**Solution:** 
1. Check subscription status (should be "active")
2. Check spam/junk folder
3. Verify AWS account email is verified
4. Check CloudWatch logs

### Issue: "Background worker not processing"
**Solution:**
1. Check application logs (look for "Processing SQS messages")
2. Verify SQS queue URL is correct
3. Check queue has messages (admin/queue-status)
4. Manually trigger: POST /admin/process-queue

### Issue: "Permission denied when polling SQS"
**Solution:** Verify EC2 instance IAM role has `sqs:ReceiveMessage` permission.

---

## Performance & Scaling

### Current Configuration
- **Batch Size:** 10 messages
- **Polling Interval:** 30 seconds
- **Visibility Timeout:** 30 seconds
- **Max Throughput:** 20 messages/minute per instance

### For Higher Load
1. Increase batch size (up to 10 - AWS limit)
2. Decrease polling interval (down to 1 second)
3. Run multiple instances with load balancer
4. Use Lambda for processing instead of polling

### AWS Limits
- SQS: 300 transactions/second per queue
- SNS: 150,000 requests/second per topic
- Email confirmations: Expire after 3 days

---

## Security Considerations

✅ **Implemented**
- IAM role-based access (no access keys)
- Queue policies restrict to specific SNS topic
- Email validation before subscription
- HTTPS recommended for production

⚠️ **Recommended**
- Enable encryption at rest for SQS
- Use KMS encryption for sensitive data
- Implement rate limiting on API endpoints
- Add authentication to admin endpoints
- Encrypt SNS messages

---

## Cost Estimation (AWS Free Tier)

### Free Tier Includes
- **SQS:** 1 million requests/month
- **SNS:** 1 million notifications/month
- **EC2:** 750 hours/month (t2.micro)

### Example Monthly Usage
- 10,000 image uploads
- 10,000 SQS messages (1 per upload)
- 50,000 SNS notifications (5 subscribers per upload)
- **Total Cost:** ~$0 (well within free tier)

---

## Next Steps

1. **Immediate (Today)**
   - Run setup script to create AWS resources
   - Install dependencies
   - Deploy application
   - Test with sample email

2. **Short-term (This Week)**
   - Test with multiple subscribers
   - Monitor CloudWatch metrics
   - Configure email filtering (optional)
   - Set up alerts for queue backlog

3. **Medium-term (This Month)**
   - Add SMS notifications
   - Implement webhook integration
   - Add Lambda processing
   - Implement message persistence to database

4. **Long-term (Future)**
   - Multi-region deployment
   - Advanced filtering policies
   - Real-time dashboard
   - Analytics and reporting

---

## Documentation Files

### For Setup
→ Read: `setup-sqssns-feature.ps1` (automated) or `SQS-SNS-SUBSCRIPTION-CLI-GUIDE.md` (manual)

### For Implementation
→ Read: `IMPLEMENTATION-GUIDE.md`

### For API Usage
→ Read: `API-DOCUMENTATION.md`

### For Testing
→ Run: `test-subscription-feature.ps1`

---

## Support Resources

- **AWS SQS:** https://docs.aws.amazon.com/sqs/
- **AWS SNS:** https://docs.aws.amazon.com/sns/
- **AWS SDK Node.js:** https://docs.aws.amazon.com/sdk-for-javascript/
- **Express.js:** https://expressjs.com/
- **AWS CloudWatch:** https://docs.aws.amazon.com/cloudwatch/

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Jan 7, 2025 | Initial implementation |

---

## Author Notes

This implementation provides a **production-ready** foundation for image upload notifications. It's designed to be:

- **Scalable** - AWS services handle growth automatically
- **Reliable** - Message buffering prevents data loss
- **Testable** - Comprehensive endpoints for verification
- **Maintainable** - Clear code structure and documentation
- **Cost-effective** - Free tier coverage for typical usage

---

## Questions?

Refer to the relevant documentation file:
- Setup issues → `SQS-SNS-SUBSCRIPTION-CLI-GUIDE.md`
- Implementation → `IMPLEMENTATION-GUIDE.md`
- API usage → `API-DOCUMENTATION.md`
- Testing → Run `test-subscription-feature.ps1` with `-Verbose` flag

