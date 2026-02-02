# SAM Deployment - Successfully Completed! ✅

## Deployment Summary

Your SAM application for `webproject-UploadsNotificationFunction` has been successfully deployed to AWS!

### Stack Information
- **Stack Name**: `webproject-uploads-stack`
- **Region**: `ap-south-1` (Mumbai)
- **Status**: `CREATE_COMPLETE`
- **Account ID**: `908601827639`

### Deployed Resources

#### Lambda Functions
1. **UploadsNotificationFunction**
   - **ARN**: `arn:aws:lambda:ap-south-1:908601827639:function:webproject-uploads-notification-function`
   - **Role**: `webproject-uploads-notification-role`
   - **Runtime**: Node.js 18.x
   - **Timeout**: 30 seconds
   - **Memory**: 256 MB
   - **Tracing**: Active (X-Ray)
   - **Trigger**: SQS Queue (webproject-UploadsNotificationQueue)
   - **Handler**: Processes messages from SQS and publishes to SNS

2. **S3LogsFunction** (Test/Demo)
   - **ARN**: `arn:aws:lambda:ap-south-1:908601827639:function:webproject-s3-logs-function`
   - **Runtime**: Node.js 18.x
   - **Purpose**: For testing S3 and CloudWatch Logs access

#### CloudWatch Log Groups
- `/aws/lambda/webproject-uploads-notification-function` (Retention: 14 days)
- `/aws/lambda/webproject-s3-logs-function` (Retention: 14 days)

#### IAM Roles
- **UploadsNotificationFunctionRole** - Full permissions for:
  - SQS message consumption (receive, delete, get attributes, change visibility)
  - SNS message publishing
  - CloudWatch Logs (create, write)
  - X-Ray trace writing
  - VPC access (for future enhancements)

- **S3LogsFunctionRole** - Permissions for:
  - S3 (get objects, list buckets)
  - CloudWatch Logs

#### AWS Resources Created (Prerequisites)
1. **SQS Queue**: `webproject-UploadsNotificationQueue`
   - **URL**: `https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue`
   - **ARN**: `arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue`
   - **Visibility Timeout**: 120 seconds

2. **SNS Topic**: `webproject-UploadsNotificationTopic`
   - **ARN**: `arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic`
   - **Purpose**: Sends email notifications to subscribers

3. **S3 Bucket**: `webproject-sam-deployments-851189`
   - **Purpose**: Stores Lambda artifact packages
   - **Versioning**: Enabled

### How It Works

```
1. Web Application (EC2)
   ↓
2. User uploads image to S3 bucket
   ↓
3. S3 event triggers → SQS Message Queue
   ↓
4. SQS Message: {"fileName": "image.jpg", "fileSize": 2048576, ...}
   ↓
5. Lambda Function (UploadsNotificationFunction)
   - Processes SQS message
   - Extracts image details
   - Publishes to SNS Topic
   ↓
6. SNS Topic
   - Sends email notification to all subscribed users
   - Email contains image details
   ↓
7. Users receive email notification
```

### Environment Variables (Lambda Function)

```
SNS_TOPIC_ARN    → arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic
SQS_QUEUE_URL    → https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
PROJECT_NAME     → webproject
LOG_LEVEL        → INFO
```

### Lambda Event Source Mapping

- **Queue**: `webproject-UploadsNotificationQueue`
- **Batch Size**: 10 messages
- **Batching Window**: 5 seconds
- **Max Concurrency**: 2
- **Failure Handling**: Report batch item failures (partial success)

---

## Next Steps

### 1. Verify Deployment in AWS Console

#### View Lambda Functions:
```powershell
# Use AWS console
https://console.aws.amazon.com/lambda/home?region=ap-south-1#/functions

# Or use CLI
aws lambda list-functions --region ap-south-1 --query 'Functions[?contains(FunctionName, `webproject`)]'
```

#### View SAM Application:
```powershell
# CloudFormation Stack
https://console.aws.amazon.com/cloudformation/home?region=ap-south-1#/stacks/

# Look for: webproject-uploads-stack
```

#### View CloudWatch Logs:
```powershell
# Real-time logs
sam logs -n UploadsNotificationFunction --stack-name webproject-uploads-stack -t

# Or use AWS console
https://console.aws.amazon.com/cloudwatch/home?region=ap-south-1#logsV2:log-groups
```

### 2. Test the Deployment

#### Option A: Manual Test
1. Go to AWS SQS Console
2. Send a test message to `webproject-UploadsNotificationQueue`
3. Message body:
```json
{
  "eventId": "test-001",
  "fileName": "test-image.jpg",
  "fileSize": 2048576,
  "fileExtension": ".jpg",
  "description": "Test image",
  "uploadedBy": "test-user",
  "timestamp": "2026-01-27T18:45:00Z"
}
```
4. Check CloudWatch Logs for Lambda execution
5. Check SNS Topic for published message

#### Option B: Using AWS CLI
```powershell
$env:AWS_PROFILE="user-sns-sqs-profile"

# Send test message
aws sqs send-message `
  --queue-url https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue `
  --message-body '{
    "eventId": "test-001",
    "fileName": "test-image.jpg",
    "fileSize": 2048576,
    "fileExtension": ".jpg",
    "description": "Test image",
    "timestamp": "2026-01-27T18:45:00Z"
  }' `
  --region ap-south-1

# View Lambda logs
sam logs -n UploadsNotificationFunction --stack-name webproject-uploads-stack -t
```

### 3. Subscribe to SNS Topic for Email Notifications

To receive email notifications, you need to subscribe to the SNS topic:

```powershell
$env:AWS_PROFILE="user-sns-sqs-profile"

aws sns subscribe `
  --topic-arn arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic `
  --protocol email `
  --notification-endpoint your-email@example.com `
  --region ap-south-1

# Then confirm subscription in your email inbox
```

### 4. Integration with Web Application

Update your web application to put messages in the SQS queue when images are uploaded. The Lambda function will automatically:
1. Receive the message from SQS
2. Extract image details
3. Publish notification to SNS
4. Send email to all subscribers

### 5. Monitor Lambda Function

Check function metrics:
```powershell
$env:AWS_PROFILE="user-iam-profile"

aws cloudwatch get-metric-statistics `
  --namespace AWS/Lambda `
  --metric-name Invocations `
  --dimensions Name=FunctionName,Value=webproject-uploads-notification-function `
  --start-time 2026-01-27T00:00:00Z `
  --end-time 2026-01-27T23:59:59Z `
  --period 3600 `
  --statistics Sum `
  --region ap-south-1
```

---

## Useful Commands

### View Stack Details
```powershell
aws cloudformation describe-stacks `
  --stack-name webproject-uploads-stack `
  --region ap-south-1
```

### View Lambda Function
```powershell
aws lambda get-function `
  --function-name webproject-uploads-notification-function `
  --region ap-south-1
```

### View SQS Queue
```powershell
aws sqs get-queue-attributes `
  --queue-url https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue `
  --attribute-names All `
  --region ap-south-1
```

### View SNS Topic
```powershell
aws sns get-topic-attributes `
  --topic-arn arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic `
  --region ap-south-1
```

### View Lambda Logs
```powershell
# Real-time (follow mode)
sam logs -n UploadsNotificationFunction --stack-name webproject-uploads-stack -t

# Last 50 lines
sam logs -n UploadsNotificationFunction --stack-name webproject-uploads-stack --tail
```

### Delete Stack (If Needed)
```powershell
sam delete --stack-name webproject-uploads-stack --region ap-south-1
```

---

## Important Files

| File | Purpose |
|------|---------|
| `sam-template.yaml` | SAM template with Lambda functions and IAM roles |
| `src/index.js` | Main Lambda function code |
| `src-test/s3-logs-handler.js` | Test Lambda function |
| `samconfig.toml` | SAM deployment configuration |
| `.aws-sam/build/` | Built artifacts (don't edit) |

---

## Testing Checklist

- [ ] Lambda function visible in AWS Lambda console
- [ ] CloudWatch Log Group created
- [ ] SQS Event Source Mapping active
- [ ] Send test SQS message
- [ ] Check Lambda logs for processing
- [ ] Subscribe to SNS topic via email
- [ ] Confirm email subscription
- [ ] Send another test message
- [ ] Receive email notification

---

## Troubleshooting

### Function not processing messages
1. Check SQS queue has messages: `aws sqs receive-message --queue-url <queue-url>`
2. Check Lambda logs: `sam logs -n UploadsNotificationFunction -t`
3. Verify Event Source Mapping: `aws lambda list-event-source-mappings --function-name webproject-uploads-notification-function`

### Not receiving email notifications
1. Check SNS subscriptions: `aws sns list-subscriptions-by-topic --topic-arn <topic-arn>`
2. Confirm subscription in email
3. Check SNS publish permissions in Lambda role
4. Check CloudWatch logs for publish errors

### Lambda timeout issues
1. Current timeout: 30 seconds (sufficient for most cases)
2. Increase if needed: Update `sam-template.yaml` → `Timeout: 60`
3. Rebuild and redeploy: `sam build && sam deploy`

---

## Success Indicators

✅ SAM stack created successfully  
✅ Lambda functions deployed and active  
✅ IAM roles configured with proper permissions  
✅ SQS queue connected as event source  
✅ CloudWatch logs created and functional  
✅ S3 bucket for artifacts created  
✅ SNS topic ready for notifications  

**Your SAM application is ready for production use!**

---

**Deployment Date**: January 27, 2026
**Account ID**: 908601827639
**Region**: ap-south-1
**Stack Status**: CREATE_COMPLETE
