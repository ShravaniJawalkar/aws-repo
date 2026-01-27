# Lambda Function Deployment Guide

## Summary of Changes Completed

✅ **SQS Queue & SNS Topic Created** - CloudFormation stack `webproject-sqs-sns-resources` has been deployed with:
- SQS Queue: `webproject-UploadsNotificationQueue` 
- SNS Topic: `webproject-UploadsNotificationTopic`
- SNS-to-SQS subscription already configured

✅ **Web Application Updated** - `app-enhanced.js` has been modified to:
- Remove the background worker that processes SQS messages
- Remove SNS publishing logic from the web app
- Keep only the SQS queue sending functionality

## Remaining Task: Deploy Lambda Function

The Lambda function needs to be created and linked to the SQS queue. This requires IAM permissions that your current profile doesn't have.

### Option 1: Use AWS Console (Recommended for you)

1. **Create Lambda Function**
   - Go to: AWS Lambda Console
   - Click "Create function"
   - Function name: `webproject-UploadsNotificationFunction`
   - Runtime: Node.js 18.x
   - Execution role: Create a new role (see step 2)

2. **Create Execution Role**
   - Go to: IAM → Roles → Create role
   - Trusted entity: Lambda service
   - Role name: `webproject-UploadsNotificationLambdaRole`
   - Attach policies:
     - `AWSLambdaBasicExecutionRole` (for CloudWatch logs)
     - Custom policy for SQS (see below)
     - Custom policy for SNS (see below)

3. **Add SQS Read Policy**
   - Policy Name: `webproject-lambda-sqs-policy`
   - ```json
     {
       "Version": "2012-10-17",
       "Statement": [{
         "Effect": "Allow",
         "Action": [
           "sqs:ReceiveMessage",
           "sqs:DeleteMessage",
           "sqs:GetQueueAttributes",
           "sqs:ChangeMessageVisibility"
         ],
         "Resource": "arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue"
       }]
     }
     ```

4. **Add SNS Publish Policy**
   - Policy Name: `webproject-lambda-sns-policy`
   - ```json
     {
       "Version": "2012-10-17",
       "Statement": [{
         "Effect": "Allow",
         "Action": "sns:Publish",
         "Resource": "arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic"
       }]
     }
     ```

5. **Add Lambda Function Code**
   - Copy the code from: [lambda-function/index.js](./lambda-function/index.js)
   - Paste into the Lambda code editor
   - Click "Deploy"

6. **Add Environment Variables**
   - Key: `SNS_TOPIC_ARN`
   - Value: `arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic`
   - Click "Save"

7. **Add SQS Trigger**
   - Go to Lambda function → Add trigger
   - Trigger type: SQS
   - SQS queue: `webproject-UploadsNotificationQueue`
   - Batch size: 10
   - Batch window: 5 seconds
   - Function response types: Report batch item failures
   - Click "Add"

### Option 2: Use AWS CLI with Admin Profile

If you have an admin profile or IAM user with full permissions, run these commands:

```powershell
# 1. Create Role
aws iam create-role `
  --role-name webproject-UploadsNotificationLambdaRole `
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' `
  --region ap-south-1 `
  --profile admin-profile

# 2. Attach policies (replace admin-profile with your admin account profile)
aws iam attach-role-policy `
  --role-name webproject-UploadsNotificationLambdaRole `
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole `
  --region ap-south-1 `
  --profile admin-profile

# 3. Create SQS policy
$sqsPolicy = @{
  Version = "2012-10-17"
  Statement = @(@{
    Effect = "Allow"
    Action = @("sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility")
    Resource = "arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue"
  })
} | ConvertTo-Json

aws iam put-role-policy `
  --role-name webproject-UploadsNotificationLambdaRole `
  --policy-name webproject-lambda-sqs-policy `
  --policy-document $sqsPolicy `
  --region ap-south-1 `
  --profile admin-profile

# 4. Create SNS policy
$snsPolicy = @{
  Version = "2012-10-17"
  Statement = @(@{
    Effect = "Allow"
    Action = "sns:Publish"
    Resource = "arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic"
  })
} | ConvertTo-Json

aws iam put-role-policy `
  --role-name webproject-UploadsNotificationLambdaRole `
  --policy-name webproject-lambda-sns-policy `
  --policy-document $snsPolicy `
  --region ap-south-1 `
  --profile admin-profile

# 5. Create Lambda function (get role ARN first)
$roleArn = aws iam get-role --role-name webproject-UploadsNotificationLambdaRole --query 'Role.Arn' --output text

# Create zip file with Lambda code
Compress-Archive -Path lambda-function\index.js -DestinationPath lambda-function.zip -Force

aws lambda create-function `
  --function-name webproject-UploadsNotificationFunction `
  --runtime nodejs18.x `
  --role $roleArn `
  --handler index.handler `
  --timeout 60 `
  --memory-size 256 `
  --environment Variables={SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic} `
  --zip-file fileb://lambda-function.zip `
  --region ap-south-1 `
  --profile admin-profile

# 6. Create SQS trigger
aws lambda create-event-source-mapping `
  --event-source-arn arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue `
  --function-name webproject-UploadsNotificationFunction `
  --enabled `
  --batch-size 10 `
  --maximum-batching-window-in-seconds 5 `
  --function-response-types ReportBatchItemFailures `
  --region ap-south-1 `
  --profile admin-profile
```

## Testing the Setup

Once the Lambda function is deployed:

1. **Upload Images** - Use your web application to upload 2 or more images
2. **Check Logs** - View Lambda execution logs:
   ```powershell
   aws logs tail /aws/lambda/webproject-UploadsNotificationFunction --follow --region ap-south-1
   ```
3. **Verify Emails** - Check your inbox for SNS notification emails

## Architecture Overview

```
[Web App] → [SQS Queue] → [Lambda Function] → [SNS Topic] → [Email Subscribers]
   ↑                              ↓
   └──────────── (removed) ───────┘
```

**Before:** Web app sends message to SQS, then processes it immediately and publishes to SNS
**After:** Web app sends message to SQS, Lambda processes asynchronously and publishes to SNS

## Key Resources

- **Lambda Function**: `webproject-UploadsNotificationFunction`
- **Execution Role**: `webproject-UploadsNotificationLambdaRole`
- **SQS Queue**: `webproject-UploadsNotificationQueue`
- **SNS Topic**: `webproject-UploadsNotificationTopic`
- **Region**: ap-south-1
- **Account ID**: 908601827639

## Next Steps

1. Deploy the Lambda function using Option 1 or 2 above
2. Update your web application to use the updated `app-enhanced.js` (already done)
3. Test with 2+ image uploads
4. Verify email notifications are received by SNS subscribers
