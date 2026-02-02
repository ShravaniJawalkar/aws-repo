# SAM Deployment - Quick Command Reference

## Deployed Lambda Functions

```
webproject-uploads-notification-function
  - ARN: arn:aws:lambda:ap-south-1:908601827639:function:webproject-uploads-notification-function
  - Runtime: Node.js 18.x
  - Trigger: SQS Queue
  - Handler: processes image upload notifications
  
webproject-s3-logs-function
  - ARN: arn:aws:lambda:ap-south-1:908601827639:function:webproject-s3-logs-function
  - Runtime: Node.js 18.x
  - Purpose: Test/demo function for S3 and logs access
```

## AWS Resources

```
SQS Queue:
  webproject-UploadsNotificationQueue
  https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue

SNS Topic:
  webproject-UploadsNotificationTopic
  arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic

S3 Bucket:
  webproject-sam-deployments-851189

CloudFormation Stack:
  webproject-uploads-stack
```

## Essential Commands

### View Lambda Logs (Real-time)
```powershell
$env:AWS_PROFILE="user-iam-profile"
sam logs -n UploadsNotificationFunction --stack-name webproject-uploads-stack -t
```

### Send Test SQS Message
```powershell
$env:AWS_PROFILE="user-sns-sqs-profile"

aws sqs send-message `
  --queue-url https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue `
  --message-body '{"eventId":"test-1","fileName":"test.jpg","fileSize":1024000,"fileExtension":".jpg","description":"Test","timestamp":"2026-01-27T18:45:00Z"}' `
  --region ap-south-1
```

### Subscribe to Email Notifications
```powershell
$env:AWS_PROFILE="user-sns-sqs-profile"

aws sns subscribe `
  --topic-arn arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic `
  --protocol email `
  --notification-endpoint your-email@example.com `
  --region ap-south-1
```

### View Stack Status
```powershell
$env:AWS_PROFILE="user-iam-profile"

aws cloudformation describe-stacks `
  --stack-name webproject-uploads-stack `
  --region ap-south-1 `
  --query 'Stacks[0].[StackStatus,CreationTime]'
```

### View SQS Queue Attributes
```powershell
$env:AWS_PROFILE="user-sns-sqs-profile"

aws sqs get-queue-attributes `
  --queue-url https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue `
  --attribute-names All `
  --region ap-south-1
```

### View SNS Topic Subscriptions
```powershell
$env:AWS_PROFILE="user-sns-sqs-profile"

aws sns list-subscriptions-by-topic `
  --topic-arn arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic `
  --region ap-south-1
```

### Redeploy SAM (After Code Changes)
```powershell
$env:AWS_PROFILE="user-iam-profile"
cd c:\Users\Shravani_Jawalkar\aws
sam build -t sam-template.yaml
sam deploy -t sam-template.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --region ap-south-1
```

### Delete Stack (Cleanup)
```powershell
$env:AWS_PROFILE="user-iam-profile"
sam delete --stack-name webproject-uploads-stack --region ap-south-1
```

---

## AWS Profiles

| Profile | Use Case |
|---------|----------|
| `user-iam-profile` | CloudFormation/SAM deployment |
| `user-sns-sqs-profile` | Testing SNS/SQS |
| `user-s3-profile` | S3 operations |
| `user-ec2-profile` | EC2 operations |

---

## Verification Steps

1. Lambda is deployed:
   ```powershell
   aws lambda get-function --function-name webproject-uploads-notification-function --region ap-south-1
   ```

2. SQS trigger is active:
   ```powershell
   aws lambda list-event-source-mappings --function-name webproject-uploads-notification-function --region ap-south-1
   ```

3. CloudWatch Log Group exists:
   ```powershell
   aws logs describe-log-groups --log-group-name-prefix /aws/lambda/webproject --region ap-south-1
   ```

---

## Performance Settings

| Setting | Value |
|---------|-------|
| Lambda Memory | 256 MB |
| Lambda Timeout | 30 seconds |
| SQS Batch Size | 10 |
| SQS Visibility | 120 seconds |
| Max Concurrency | 2 |

---

**Stack Status**: ✅ CREATE_COMPLETE  
**Deployed**: January 27, 2026  
**Region**: ap-south-1
