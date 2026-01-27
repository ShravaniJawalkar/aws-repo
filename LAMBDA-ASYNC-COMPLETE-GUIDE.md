# Sub-Task 1: Lambda with Asynchronous Invocation (Polling)
# Complete Implementation & Deployment Guide

## 📋 Overview

This guide provides complete step-by-step instructions to implement and deploy:

✅ **Lambda Function** with SQS Polling (Event Source Mapping)
✅ **Enhanced Web Application** with image upload and subscription endpoints
✅ **Asynchronous Email Notifications** via SNS
✅ **End-to-End Testing** for the complete notification flow

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User (Browser)                            │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────┐
        │  Web Application (Node.js/EC2)   │
        │ - Image Upload Endpoint          │
        │ - Subscribe/Unsubscribe Email    │
        └──────┬───────────────────────────┘
               │
       ┌───────┴────────┐
       │                │
       ▼                ▼
  ┌─────────┐      ┌──────────────┐
  │    S3   │      │ SQS Queue    │
  │ (Images)│      │(Event Buffer)│
  └─────────┘      └──────┬───────┘
                          │
                          │(Async Polling)
                          ▼
                   ┌─────────────────────┐
                   │  Lambda Function    │
                   │- Process Messages   │
                   │- Format Messages    │
                   └────────┬────────────┘
                            │
                            ▼
                   ┌─────────────────────┐
                   │    SNS Topic        │
                   │ (Message Broker)    │
                   └────────┬────────────┘
                            │
                            ▼
                   ┌─────────────────────┐
                   │  Email Subscribers  │
                   │ (Notifications)     │
                   └─────────────────────┘
```

---

## 📦 Deliverables

| Component | File | Purpose |
|-----------|------|---------|
| **Web App** | web-dynamic-app/app-enhanced.js | Enhanced app with S3, SQS, SNS integration |
| **Dependencies** | web-dynamic-app/package.json | Updated with AWS SDK, multer |
| **Lambda Template** | lambda-uploads-notification-template.yaml | CloudFormation for Lambda + trigger |
| **Lambda Code** | lambda-function/index.js | Handler for processing SQS messages |
| **Deployment Scripts** | deploy-lambda-async.ps1 | Deploy Lambda via CloudFormation |
| **Upload Script** | upload-app-to-s3.ps1 | Upload app files to S3 |
| **Test Script** | test-lambda-async.ps1 | Complete end-to-end testing |
| **Guides** | LAMBDA-ASYNC-DEPLOYMENT-GUIDE.md | Detailed deployment instructions |

---

## ✅ Prerequisites Checklist

Before starting, ensure you have:

- [ ] AWS Account with appropriate IAM permissions
- [ ] AWS CLI configured with profile `user-iam-profile` for region `ap-south-1`
- [ ] SQS Queue created: `webproject-UploadsNotificationQueue`
- [ ] SNS Topic created: `webproject-UploadsNotificationTopic`
- [ ] S3 Bucket created: `shravani-jawalkar-webproject-bucket`
- [ ] CloudFormation template for infrastructure: `webproject-infrastructure.yaml`
- [ ] PowerShell 5.0+ installed (for scripts)
- [ ] EC2 instance available (from infrastructure stack)

---

## 🚀 Quick Start (5 Steps)

### Step 1: Deploy Lambda Function (2 minutes)

```powershell
cd C:\Users\Shravani_Jawalkar\aws

# Deploy Lambda with SQS trigger
.\deploy-lambda-async.ps1 `
    -ProjectName webproject `
    -StackName webproject-lambda-notifications `
    -Region ap-south-1 `
    -Profile user-iam-profile
```

**Expected Output:**
```
✓ Stack operation completed successfully!
✓ Lambda Function: webproject-UploadsNotificationFunction
✓ Event Source Mapping: UUID...
✅ Deployment Complete!
```

### Step 2: Upload Web App to S3 (1 minute)

```powershell
# Upload app files to S3
.\upload-app-to-s3.ps1 `
    -AppDir web-dynamic-app `
    -BucketName shravani-jawalkar-webproject-bucket `
    -Region ap-south-1 `
    -Profile user-iam-profile
```

**Expected Output:**
```
✓ S3 Bucket exists
✓ Uploaded: package.json
✓ Uploaded: app-enhanced.js
✓ Uploaded: app.js
✅ Upload Complete!
```

### Step 3: Deploy App to EC2 (5 minutes)

```bash
# SSH to EC2 instance
ssh -i web-server.ppk ec2-user@<EC2_PUBLIC_IP>

# Create and setup app directory
mkdir -p ~/webapp && cd ~/webapp

# Download app from S3
aws s3 cp s3://shravani-jawalkar-webproject-bucket/app-enhanced.js . \
    --region ap-south-1

aws s3 cp s3://shravani-jawalkar-webproject-bucket/package.json . \
    --region ap-south-1

# Install dependencies
npm install

# Set environment variables
export AWS_REGION=ap-south-1
export S3_BUCKET=shravani-jawalkar-webproject-bucket
export SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
export SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic

# Start application
npm start
```

### Step 4: Test the Complete Flow (5 minutes)

```powershell
# Run comprehensive test
.\test-lambda-async.ps1 `
    -LoadBalancerURL "http://<load-balancer-dns>" `
    -TestEmail "your-email@example.com" `
    -NumImages 2
```

**Expected Flow:**
1. ✅ Health check passes
2. ✅ Email subscription request sent
3. ⚠️ Check email for subscription confirmation and confirm it
4. ✅ Upload 2 test images
5. ⏳ Wait 1-2 minutes
6. ✅ Receive 2 notification emails with image details

### Step 5: Verify Success

Check your email for:
- Subscription confirmation email (click to confirm)
- 2 Image upload notification emails containing:
  - Image file name
  - File size in MB
  - File extension
  - Timestamp
  - Event ID

---

## 📋 Detailed Deployment Steps

### Prerequisites Setup

#### A. Check AWS CLI Configuration

```powershell
# List configured profiles
aws configure list --profile user-iam-profile

# Should show:
#       name    mfa_serial  mfa_device
# region      ap-south-1
```

#### B. Verify Infrastructure Stack

```powershell
# Check if infrastructure stack exists
aws cloudformation describe-stacks `
    --stack-name webProject-infrastructure `
    --region ap-south-1 `
    --profile user-iam-profile

# Get Load Balancer URL
$lbUrl = aws cloudformation describe-stacks `
    --stack-name webProject-infrastructure `
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' `
    --output text `
    --region ap-south-1 `
    --profile user-iam-profile

Write-Host "Load Balancer: $lbUrl"
```

#### C. Verify SQS and SNS Resources

```powershell
# Check SQS Queue
aws sqs get-queue-url `
    --queue-name webproject-UploadsNotificationQueue `
    --region ap-south-1 `
    --profile user-iam-profile

# Check SNS Topic
aws sns list-topics `
    --region ap-south-1 `
    --profile user-iam-profile | Select-String "UploadsNotificationTopic"
```

### Lambda Deployment

#### A. Deploy Lambda Function

```powershell
cd C:\Users\Shravani_Jawalkar\aws

# Deploy Lambda stack
aws cloudformation create-stack `
    --stack-name webproject-lambda-notifications `
    --template-body file://lambda-uploads-notification-template.yaml `
    --parameters `
        ParameterKey=ProjectName,ParameterValue=webproject `
        ParameterKey=SQSQueueArn,ParameterValue=arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue `
        ParameterKey=SQSQueueUrl,ParameterValue=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue `
        ParameterKey=SNSTopicArn,ParameterValue=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic `
        ParameterKey=LambdaRuntime,ParameterValue=nodejs18.x `
    --capabilities CAPABILITY_NAMED_IAM `
    --region ap-south-1 `
    --profile user-iam-profile
```

#### B. Wait for Stack to Complete

```powershell
# Monitor stack creation
aws cloudformation wait stack-create-complete `
    --stack-name webproject-lambda-notifications `
    --region ap-south-1 `
    --profile user-iam-profile
```

#### C. Verify Lambda Deployment

```powershell
# Get Lambda function
aws lambda get-function `
    --function-name webproject-UploadsNotificationFunction `
    --region ap-south-1 `
    --profile user-iam-profile | ConvertFrom-Json | Select-Object -ExpandProperty Configuration

# Get Event Source Mapping
aws lambda list-event-source-mappings `
    --function-name webproject-UploadsNotificationFunction `
    --region ap-south-1 `
    --profile user-iam-profile | ConvertFrom-Json | Select-Object -ExpandProperty EventSourceMappings | Format-List
```

### Web Application Deployment

#### A. Upload to S3

```powershell
cd C:\Users\Shravani_Jawalkar\aws\web-dynamic-app

# Upload application files
aws s3 cp app-enhanced.js s3://shravani-jawalkar-webproject-bucket/ `
    --region ap-south-1 `
    --profile user-iam-profile

aws s3 cp package.json s3://shravani-jawalkar-webproject-bucket/ `
    --region ap-south-1 `
    --profile user-iam-profile
```

#### B. Deploy to EC2

```bash
# SSH to EC2
ssh -i web-server.ppk ec2-user@<PUBLIC_IP>

# Setup application
mkdir -p ~/webapp && cd ~/webapp

aws s3 cp s3://shravani-jawalkar-webproject-bucket/app-enhanced.js . \
    --region ap-south-1

aws s3 cp s3://shravani-jawalkar-webproject-bucket/package.json . \
    --region ap-south-1

# Install dependencies
npm install

# Create .env file or export variables
cat > ~/.bashrc << 'EOF'
export AWS_REGION=ap-south-1
export S3_BUCKET=shravani-jawalkar-webproject-bucket
export SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
export SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic
EOF

source ~/.bashrc

# Start application
npm start
```

**Expected Output:**
```
========================================
Server is running on port 8080
Access the application at http://localhost:8080
========================================
S3 Bucket: shravani-jawalkar-webproject-bucket
SQS Queue URL: https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
SNS Topic ARN: arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic
========================================
```

### Testing & Verification

#### A. Access Web Application

```powershell
# Get Load Balancer URL
$lbUrl = aws cloudformation describe-stacks `
    --stack-name webProject-infrastructure `
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' `
    --output text `
    --region ap-south-1 `
    --profile user-iam-profile

# Open in browser
Start-Process "$lbUrl"

# Or test with PowerShell
Invoke-WebRequest "$lbUrl/health" | Select-Object StatusCode, Content
```

#### B. Subscribe Email Address

```powershell
$email = "your-email@example.com"

$response = Invoke-WebRequest `
    -Uri "$lbUrl/api/subscribe" `
    -Method POST `
    -Headers @{ "Content-Type" = "application/json" } `
    -Body (ConvertTo-Json @{ email = $email })

$response.Content | ConvertFrom-Json | Format-List
```

**Response Example:**
```
message        : Subscription successful! Please check your email for a confirmation message.
email          : your-email@example.com
subscriptionArn: arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic:...
```

⚠️ **IMPORTANT:** Check your email inbox and confirm the subscription by clicking the link!

#### C. Upload Test Images

```powershell
# Upload image 1
Invoke-WebRequest `
    -Uri "$lbUrl/api/upload" `
    -Method POST `
    -InFile "C:\path\to\image1.jpg"

# Upload image 2
Invoke-WebRequest `
    -Uri "$lbUrl/api/upload" `
    -Method POST `
    -InFile "C:\path\to\image2.jpg"
```

#### D. Monitor Lambda Execution

```powershell
# Watch Lambda logs in real-time
aws logs tail /aws/lambda/webproject-UploadsNotificationFunction `
    --follow `
    --region ap-south-1 `
    --profile user-iam-profile
```

**Expected Log Output:**
```
Received event: {...}
Processing Message ID: xxx...
Parsed upload event: {...}
Publishing notification for file: image1.jpg
✓ Successfully published to SNS. Message ID: xxx...
Processing Summary
Success: 1, Failures: 0
```

#### E. Verify SQS Queue

```powershell
# Check queue attributes
aws sqs get-queue-attributes `
    --queue-url https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue `
    --attribute-names ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible `
    --region ap-south-1 `
    --profile user-iam-profile
```

---

## 🔍 Troubleshooting

### Problem: Lambda Not Triggering

**Check Event Source Mapping:**
```powershell
aws lambda get-event-source-mapping `
    --uuid <EventSourceMappingId> `
    --region ap-south-1 `
    --profile user-iam-profile
```

Should show: `"State": "Enabled"`

**Solution:** Re-create event source mapping if needed:
```powershell
aws lambda create-event-source-mapping `
    --event-source-arn arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue `
    --function-name webproject-UploadsNotificationFunction `
    --batch-size 10 `
    --region ap-south-1 `
    --profile user-iam-profile
```

### Problem: Emails Not Received

**Check SNS Subscriptions:**
```powershell
aws sns list-subscriptions-by-topic `
    --topic-arn arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic `
    --region ap-south-1 `
    --profile user-iam-profile
```

Should show your email with `"SubscriptionArn"` (not just pending)

**Solution:**
1. Confirm subscription via email link
2. Check spam folder
3. Verify email address in subscription

### Problem: App Can't Connect to AWS Services

**Check IAM Role Permissions:**
```powershell
# EC2 instance needs permissions for:
# - S3: GetObject (to read app from bucket)
# - SQS: SendMessage (to send upload notifications)
# - SNS: Subscribe, Unsubscribe, ListSubscriptionsByTopic
# - SNS: Publish (via Lambda, not EC2)
```

**Solution:** Update EC2 IAM role with proper policy

---

## 📊 Success Checklist

- [ ] Lambda function deployed and enabled
- [ ] Event Source Mapping active (SQS → Lambda)
- [ ] Web application running on EC2
- [ ] Health check endpoint responds with `{"status": "healthy"}`
- [ ] Email subscription confirmed (click link in confirmation email)
- [ ] First image uploaded successfully
- [ ] First notification email received within 1-2 minutes
- [ ] Second image uploaded successfully
- [ ] Second notification email received
- [ ] Notification emails contain:
  - [ ] Image file name
  - [ ] File size in MB
  - [ ] File extension
  - [ ] Timestamp
  - [ ] Event ID
- [ ] Lambda logs show successful processing

---

## 📝 Key Files

| File | Status | Purpose |
|------|--------|---------|
| `web-dynamic-app/app-enhanced.js` | ✅ Created | Enhanced web app with S3, SQS, SNS |
| `web-dynamic-app/package.json` | ✅ Updated | Added AWS SDK, multer dependencies |
| `lambda-uploads-notification-template.yaml` | ✅ Ready | CloudFormation for Lambda + trigger |
| `lambda-function/index.js` | ✅ Ready | Lambda handler code |
| `deploy-lambda-async.ps1` | ✅ Created | Deployment automation script |
| `upload-app-to-s3.ps1` | ✅ Created | S3 upload automation script |
| `test-lambda-async.ps1` | ✅ Created | End-to-end testing script |
| `LAMBDA-ASYNC-DEPLOYMENT-GUIDE.md` | ✅ Created | Detailed deployment guide |

---

## 🎉 Expected Final Result

✅ **Complete Asynchronous Notification System:**

1. User uploads image via web app
2. Image stored in S3
3. Message sent to SQS queue
4. Lambda triggered automatically (async polling)
5. Lambda processes message
6. SNS notification published
7. Email sent to all subscribers
8. Email contains image metadata

**All with zero web app processing delays!**

---

## 📞 Next Steps

1. Follow Quick Start (Step 1-4)
2. Verify Success Checklist
3. Test with multiple uploads
4. Monitor CloudWatch logs
5. Verify all notification emails received

---

**Module:** 10 - Lambda with Asynchronous Invocation  
**Task:** Sub-task 1 - Lambda with Polling Invocation  
**Status:** Ready for Deployment  
**Last Updated:** 2026-01-20
