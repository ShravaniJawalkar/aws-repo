# SAM Application: webproject-UploadsNotificationFunction

This is a Serverless Application Model (SAM) application for the `webproject-UploadsNotificationFunction` Lambda function. It processes image upload events from SQS and publishes notifications via SNS.

## 📋 Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
3. **SAM CLI** installed (version 1.60.0 or later)
4. **Node.js** 18.x or later
5. **Git** (optional, for version control)

### AWS Resources Required

- SQS Queue: `webproject-UploadsNotificationQueue`
- SNS Topic: `webproject-UploadsNotificationTopic`
- S3 Bucket for Lambda deployment artifacts

### IAM Permissions Required

The deployment user needs the following permissions:
- CloudFormation: `cloudformation:*`
- Lambda: `lambda:*`
- IAM: `iam:*`
- SQS: `sqs:GetQueueAttributes`
- SNS: `sns:ListSubscriptionsByTopic`
- S3: `s3:*` (for SAM artifact storage)
- CloudWatch Logs: `logs:*`

## 📦 Project Structure

```
.
├── sam-template.yaml              # SAM template defining all resources
├── samconfig.toml                 # SAM CLI configuration
├── package.json                   # Project dependencies
├── src/
│   └── index.js                   # Main Lambda function code
├── src-test/
│   └── s3-logs-handler.js         # Test/demo Lambda function
├── events/
│   └── sqs-event.json             # Sample SQS event for local testing
└── README.md                       # This file
```

## 🚀 Installation & Deployment

### 1. Install SAM CLI

**Windows (using Chocolatey):**
```powershell
choco install aws-sam-cli
```

**Windows (using MSI):**
Download from [AWS SAM CLI releases](https://github.com/aws/aws-sam-cli/releases)

**macOS:**
```bash
brew install aws-sam-cli
```

**Linux:**
```bash
pip install aws-sam-cli
```

### 2. Verify SAM Installation

```bash
sam --version
```

### 3. Build the SAM Application

```powershell
sam build
```

This command:
- Validates the SAM template
- Downloads dependencies
- Prepares the application for deployment

### 4. Deploy the SAM Application

#### Option A: Guided Deployment (Recommended for first-time)

```powershell
sam deploy --guided
```

This will prompt you for:
- Stack name (e.g., `webproject-uploads-notification-stack`)
- AWS Region (e.g., `ap-south-1`)
- S3 bucket for artifacts (SAM will create if doesn't exist)
- Confirmation of IAM role creation
- Parameter overrides

#### Option B: Using samconfig.toml

If you've already configured `samconfig.toml`, simply run:

```powershell
sam deploy
```

### 5. Monitor Deployment Progress

```powershell
# View the stack events during deployment
aws cloudformation describe-stack-events `
  --stack-name webproject-uploads-notification-stack `
  --region ap-south-1 `
  --query 'StackEvents[*].[Timestamp,LogicalResourceId,ResourceStatus,ResourceStatusReason]' `
  --output table
```

### 6. Get Stack Outputs

```powershell
aws cloudformation describe-stacks `
  --stack-name webproject-uploads-notification-stack `
  --region ap-south-1 `
  --query 'Stacks[0].Outputs' `
  --output table
```

## 🧪 Local Testing

### Test with SAM Local

```powershell
# Start API locally
sam local start-api

# Invoke function with test event (in another terminal)
sam local invoke UploadsNotificationFunction -e events/sqs-event.json
```

### Manual Testing

1. Upload an image to your S3 bucket via the web application
2. The Lambda function will automatically:
   - Receive the message from SQS
   - Process it
   - Publish a notification to SNS
   - Send email notifications to subscribed users

## 📊 Configuration Parameters

Edit `sam-template.yaml` to modify:

```yaml
Parameters:
  ProjectName:
    Default: webproject
    Description: Name of the project
  
  SQSQueueArn:
    Default: arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue
    Description: ARN of the SQS queue

  SNSTopicArn:
    Default: arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic
    Description: ARN of the SNS topic

  DeploymentPreference:
    Default: Canary10Percent5Minutes
    AllowedValues:
      - Canary10Percent5Minutes      # Deploy to 10% of traffic, wait 5 minutes
      - Linear10PercentEvery10Minutes # Deploy to 10% every 10 minutes
      - AllAtOnce                    # Deploy to all traffic immediately
      - Gradual                       # Custom gradual deployment
```

## 🔍 Monitoring & Debugging

### View Lambda Logs

```powershell
# Stream logs in real-time
sam logs -n UploadsNotificationFunction --stack-name webproject-uploads-notification-stack -t

# View logs for a specific time period
aws logs tail /aws/lambda/webproject-uploads-notification-function --follow
```

### Monitor CloudWatch Metrics

```powershell
# Get Lambda invocations
aws cloudwatch get-metric-statistics `
  --namespace AWS/Lambda `
  --metric-name Invocations `
  --dimensions Name=FunctionName,Value=webproject-uploads-notification-function `
  --start-time 2024-01-27T00:00:00Z `
  --end-time 2024-01-27T23:59:59Z `
  --period 3600 `
  --statistics Sum
```

### Check Alarms

```powershell
aws cloudwatch describe-alarms `
  --region ap-south-1 `
  --query 'MetricAlarms[?starts_with(AlarmName, `webproject`)]' `
  --output table
```

## 🛠️ Advanced Features

### Deployment Preferences

This SAM template uses **Canary10Percent5Minutes** deployment preference by default:
- Deploys new version to 10% of traffic
- Monitors for 5 minutes
- If successful, deploys to remaining 90%
- Automatically rollbacks if errors occur

To change deployment preference:

```powershell
sam deploy --parameter-overrides DeploymentPreference=Linear10PercentEvery10Minutes
```

### Auto-Publishing Alias

The Lambda function uses an auto-publish alias (`live`) that automatically:
- Creates a new version on each deployment
- Routes traffic through the alias
- Enables safe gradual rollout

### X-Ray Tracing

Tracing is enabled by default. View traces in AWS X-Ray console:
```powershell
aws xray list-traces --region ap-south-1
```

## 📝 Environment Variables

The Lambda function uses these environment variables (set in SAM template):

| Variable | Description | Example |
|----------|-------------|---------|
| `SNS_TOPIC_ARN` | SNS topic for notifications | `arn:aws:sns:ap-south-1:...` |
| `SQS_QUEUE_URL` | SQS queue URL | `https://sqs.ap-south-1.amazonaws.com/...` |
| `PROJECT_NAME` | Project name | `webproject` |
| `AWS_REGION` | AWS region | `ap-south-1` |
| `LOG_LEVEL` | Logging level | `INFO` |

## 🔐 IAM Roles & Policies

The SAM template creates the following IAM role:

**Role Name:** `webproject-uploads-notification-role`

**Attached Policies:**
1. **CloudWatch Logs** - Create and write logs
2. **SQS Read** - Receive and delete messages from queue
3. **SNS Publish** - Publish messages to topic
4. **X-Ray** - Write trace segments
5. **VPC Access** - For future VPC integration

## 🧹 Cleanup

To delete the SAM application and all created resources:

```powershell
sam delete --stack-name webproject-uploads-notification-stack --region ap-south-1
```

Or manually via CloudFormation:

```powershell
aws cloudformation delete-stack `
  --stack-name webproject-uploads-notification-stack `
  --region ap-south-1
```

## 🐛 Troubleshooting

### Issue: Deployment fails with "Capability for IAM role"

**Solution:** Add capabilities to the deploy command:
```powershell
sam deploy --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

Or update `samconfig.toml`:
```toml
capabilities = "CAPABILITY_IAM,CAPABILITY_NAMED_IAM,CAPABILITY_AUTO_EXPAND"
```

### Issue: Lambda function can't access SQS/SNS

**Solution:** Verify:
1. SQS Queue ARN is correct
2. SNS Topic ARN is correct
3. Lambda role has permissions (check CloudFormation outputs)

### Issue: SQS messages not being processed

**Solution:** Check:
1. Event Source Mapping is enabled: `aws lambda list-event-source-mappings --function-name webproject-uploads-notification-function`
2. SQS queue has messages: `aws sqs receive-message --queue-url <queue-url>`
3. Lambda function logs: `sam logs -n UploadsNotificationFunction --follow`

### Issue: Email notifications not received

**Solution:** Verify:
1. SNS topic has email subscriptions
2. Subscriptions are confirmed (check spam folder)
3. SNS publish permissions are correct
4. Check SNS topic in AWS console

## 📖 Additional Resources

- [AWS SAM Documentation](https://docs.aws.amazon.com/serverless-application-model/)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [AWS SQS Documentation](https://docs.aws.amazon.com/sqs/)
- [AWS SNS Documentation](https://docs.aws.amazon.com/sns/)

## 🤝 Support

For issues or questions:
1. Check CloudWatch Logs for error messages
2. Review AWS CloudFormation events for deployment errors
3. Verify all prerequisites are installed and configured
4. Ensure AWS credentials have sufficient permissions

## 📄 License

ISC

---

**Last Updated:** January 2024
**SAM CLI Version:** 1.60.0+
**Runtime:** Node.js 18.x
