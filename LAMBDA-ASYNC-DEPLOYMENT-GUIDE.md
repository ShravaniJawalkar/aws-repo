# Lambda with Asynchronous Invocation - Deployment Complete Guide

## Overview

This guide provides step-by-step instructions to deploy a Lambda function that:
- Listens to SQS messages from the image upload queue
- Publishes notifications to SNS topic
- Sends emails to subscribers with image metadata

## Prerequisites

✅ **Already Created:**
- SQS Queue: `webproject-UploadsNotificationQueue`
- SNS Topic: `webproject-UploadsNotificationTopic`
- Web Application: Enhanced with subscription/unsubscription endpoints
- Lambda Function: Ready for deployment with code in `lambda-uploads-notification-template.yaml`

## Architecture

```
Web Application (EC2)
        ↓
    Upload Image
        ↓
Send to SQS Queue
        ↓
    Lambda Trigger
(Asynchronous Polling)
        ↓
Process Message
        ↓
Publish to SNS Topic
        ↓
Send Email to Subscribers
```

## Deployment Steps

### Step 1: Update EC2 IAM Role for SQS/SNS Access

The EC2 instance role needs permissions to send messages to SQS and SNS.

**Create IAM Policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage"
      ],
      "Resource": "arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sns:Subscribe",
        "sns:Unsubscribe",
        "sns:ListSubscriptionsByTopic"
      ],
      "Resource": "arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic"
    }
  ]
}
```

### Step 2: Deploy Lambda CloudFormation Stack

#### Using AWS Console:

1. Go to **CloudFormation**
2. Click **Create Stack**
3. Choose **Upload a template file**
4. Upload `lambda-uploads-notification-template.yaml`
5. Stack name: `webproject-lambda-notifications`
6. Parameters:
   - ProjectName: `webproject`
   - SQSQueueArn: `arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue`
   - SQSQueueUrl: `https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue`
   - SNSTopicArn: `arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic`
7. Click **Create Stack**

#### Using AWS CLI:

```powershell
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

**Wait for Stack Creation to Complete:**

```powershell
aws cloudformation wait stack-create-complete `
  --stack-name webproject-lambda-notifications `
  --region ap-south-1 `
  --profile user-iam-profile
```

### Step 3: Deploy Web Application to EC2

#### A. Upload Application to S3

```powershell
# Navigate to web app directory
cd C:\Users\Shravani_Jawalkar\aws\web-dynamic-app

# Upload the enhanced app file
aws s3 cp app-enhanced.js s3://shravani-jawalkar-webproject-bucket/ `
  --region ap-south-1 `
  --profile user-iam-profile

# Upload package.json
aws s3 cp package.json s3://shravani-jawalkar-webproject-bucket/ `
  --region ap-south-1 `
  --profile user-iam-profile
```

#### B. SSH to EC2 Instance and Deploy

```bash
# SSH to EC2 instance
ssh -i web-server.ppk ec2-user@<EC2_PUBLIC_IP>

# Create application directory
mkdir -p ~/webapp
cd ~/webapp

# Download application from S3
aws s3 cp s3://shravani-jawalkar-webproject-bucket/app-enhanced.js . \
  --region ap-south-1

aws s3 cp s3://shravani-jawalkar-webproject-bucket/package.json . \
  --region ap-south-1

# Install dependencies
npm install

# Set environment variables (update with actual values)
export AWS_REGION=ap-south-1
export S3_BUCKET=shravani-jawalkar-webproject-bucket
export SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
export SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic

# Start the application
npm start
```

### Step 4: Verify Deployment

#### A. Check Lambda Function

```powershell
# Get Lambda function info
aws lambda get-function `
  --function-name webproject-UploadsNotificationFunction `
  --region ap-south-1 `
  --profile user-iam-profile
```

#### B. Check Event Source Mapping

```powershell
# List event source mappings
aws lambda list-event-source-mappings `
  --function-name webproject-UploadsNotificationFunction `
  --region ap-south-1 `
  --profile user-iam-profile
```

#### C. Check SQS Queue Attributes

```powershell
aws sqs get-queue-attributes `
  --queue-url https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue `
  --attribute-names All `
  --region ap-south-1 `
  --profile user-iam-profile
```

### Step 5: Test the Complete Flow

#### A. Get Load Balancer URL

```powershell
$lbUrl = aws cloudformation describe-stacks `
  --stack-name webProject-infrastructure `
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' `
  --output text `
  --region ap-south-1 `
  --profile user-iam-profile

Write-Host "Load Balancer URL: $lbUrl"
```

#### B. Subscribe Email for Notifications

```powershell
$email = "your-email@example.com"

Invoke-WebRequest `
  -Uri "$lbUrl/api/subscribe" `
  -Method POST `
  -Headers @{ "Content-Type" = "application/json" } `
  -Body (ConvertTo-Json @{ email = $email })
```

**Expected Response:**
```json
{
  "message": "Subscription successful! Please check your email for a confirmation message.",
  "email": "your-email@example.com",
  "subscriptionArn": "arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic:..."
}
```

**Action:** Check your email for SNS confirmation - you must confirm the subscription!

#### C. Upload Test Images

```powershell
# Upload first image
$imagePath1 = "C:\path\to\image1.jpg"
$file1 = [System.IO.File]::ReadAllBytes($imagePath1)

Invoke-WebRequest `
  -Uri "$lbUrl/api/upload" `
  -Method POST `
  -InFile $imagePath1 `
  -ContentType "multipart/form-data"

# Upload second image
$imagePath2 = "C:\path\to\image2.png"
Invoke-WebRequest `
  -Uri "$lbUrl/api/upload" `
  -Method POST `
  -InFile $imagePath2 `
  -ContentType "multipart/form-data"
```

#### D. Check Lambda CloudWatch Logs

```powershell
# Get log stream names
aws logs describe-log-streams `
  --log-group-name /aws/lambda/webproject-UploadsNotificationFunction `
  --region ap-south-1 `
  --profile user-iam-profile

# Get recent logs
aws logs tail /aws/lambda/webproject-UploadsNotificationFunction `
  --follow `
  --region ap-south-1 `
  --profile user-iam-profile
```

#### E. Verify Emails Received

Check your email inbox and confirm you received notification emails for each image upload with:
- Image file name
- File size in MB
- File extension
- Timestamp
- Event ID

## Troubleshooting

### Issue: Lambda is not triggering

**Solution:**
```powershell
# Check Event Source Mapping Status
aws lambda get-event-source-mapping `
  --uuid <EventSourceMappingId> `
  --region ap-south-1 `
  --profile user-iam-profile

# Should show State: "Enabled" and StateTransitionReason: ""
```

### Issue: No emails received

**Solutions:**
1. Check SNS subscription confirmation email was accepted
2. Verify SNS topic has email subscription in "Confirmed" state
3. Check spam folder
4. Check CloudWatch logs for Lambda errors

```powershell
# List SNS subscriptions
aws sns list-subscriptions-by-topic `
  --topic-arn arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic `
  --region ap-south-1 `
  --profile user-iam-profile
```

### Issue: SQS messages not being consumed

```powershell
# Check queue for messages
aws sqs receive-message `
  --queue-url https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue `
  --region ap-south-1 `
  --profile user-iam-profile
```

## Key Files Modified/Created

| File | Purpose |
|------|---------|
| web-dynamic-app/app-enhanced.js | Enhanced web app with subscription endpoints and SQS sending |
| web-dynamic-app/package.json | Updated dependencies (AWS SDK, multer, etc.) |
| lambda-uploads-notification-template.yaml | CloudFormation template for Lambda + SQS trigger + SNS permissions |
| lambda-function/index.js | Full Lambda function code |
| webproject-infrastructure.yaml | Infrastructure stack (VPC, EC2, ALB, S3) |
| sqs-sns-resources-template.yaml | SQS queue and SNS topic |

## Success Criteria

✅ **Deployment is successful when:**
- Lambda function created and enabled
- Event Source Mapping active (SQS → Lambda)
- Email subscription confirmed
- Images upload successfully
- Notification emails received within 1-2 minutes per upload
- Lambda logs show successful message processing
- No failures in Lambda execution

## Next Steps

1. ✅ Deploy infrastructure (EC2, VPC, ALB, S3)
2. ✅ Create SQS queue and SNS topic
3. ✅ Deploy Lambda function with this guide
4. ✅ Deploy web application to EC2
5. ✅ Test complete flow end-to-end

---

**Created:** 2026-01-20
**Module:** 10 - Lambda with Asynchronous Invocation
**Status:** Ready for Deployment
