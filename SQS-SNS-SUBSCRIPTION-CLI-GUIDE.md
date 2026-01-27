# AWS SQS & SNS Subscription Feature - Complete CLI Guide

This guide walks you through implementing a subscription feature for image upload notifications using AWS SQS and SNS via the AWS CLI.

## Project Configuration
- **Project Name**: `webproject`
- **Region**: `ap-south-1`
- **Profile**: `user-iam-profile`

---

## Phase 1: Create AWS Resources (SQS & SNS)

### Step 1.1: Create the SQS Queue

Create a standard SQS queue for upload notifications:

```powershell
$QueueUrl = aws sqs create-queue `
  --queue-name webproject-UploadsNotificationQueue `
  --region ap-south-1 `
  --profile user-iam-profile `
  --query 'QueueUrl' `
  --output text

Write-Host "Queue URL: $QueueUrl"
```

**Expected Output**: `https://sqs.ap-south-1.amazonaws.com/123456789012/webproject-UploadsNotificationQueue`

Get the Queue ARN:

```powershell
$QueueArn = aws sqs get-queue-attributes `
  --queue-url $QueueUrl `
  --attribute-names QueueArn `
  --region ap-south-1 `
  --profile user-iam-profile `
  --query 'Attributes.QueueArn' `
  --output text

Write-Host "Queue ARN: $QueueArn"
```

### Step 1.2: Create the SNS Topic

Create an SNS topic for sending notifications:

```powershell
$TopicArn = aws sns create-topic `
  --name webproject-UploadsNotificationTopic `
  --region ap-south-1 `
  --profile user-iam-profile `
  --query 'TopicArn' `
  --output text

Write-Host "Topic ARN: $TopicArn"
```

**Expected Output**: `arn:aws:sns:ap-south-1:123456789012:webproject-UploadsNotificationTopic`

### Step 1.3: Subscribe the SQS Queue to the SNS Topic

Create a subscription so the SNS topic can send messages to the SQS queue:

```powershell
aws sns subscribe `
  --topic-arn $TopicArn `
  --protocol sqs `
  --notification-endpoint $QueueArn `
  --region ap-south-1 `
  --profile user-iam-profile
```

### Step 1.4: Create SQS Queue Policy

The SQS queue needs a policy to allow SNS to send messages:

```powershell
$PolicyDocument = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Principal = @{
                Service = "sns.amazonaws.com"
            }
            Action = "sqs:SendMessage"
            Resource = $QueueArn
            Condition = @{
                ArnEquals = @{
                    "aws:SourceArn" = $TopicArn
                }
            }
        }
    )
} | ConvertTo-Json -Depth 10

# Save to file
$PolicyDocument | Out-File -FilePath "sqs-queue-policy.json" -Encoding UTF8

# Apply the policy
aws sqs set-queue-attributes `
  --queue-url $QueueUrl `
  --attributes "{`"Policy`":`"$(Get-Content sqs-queue-policy.json -Raw | ConvertTo-Json -AsArray)`"}" `
  --region ap-south-1 `
  --profile user-iam-profile
```

**Alternative (Simpler approach)**:

Create `sqs-queue-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:ap-south-1:123456789012:webproject-UploadsNotificationQueue",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:sns:ap-south-1:123456789012:webproject-UploadsNotificationTopic"
        }
      }
    }
  ]
}
```

Apply it:

```powershell
aws sqs set-queue-attributes `
  --queue-url $QueueUrl `
  --attributes file://sqs-queue-policy.json `
  --region ap-south-1 `
  --profile user-iam-profile
```

---

## Phase 2: Update IAM Role for EC2 Instance

Your EC2 instance needs permissions to interact with SQS and SNS. Update the CloudFormation template or create an inline policy.

### Option A: Update CloudFormation Template

Add to the IAM role in `webproject-infrastructure.yaml`:

```yaml
ProjectInstanceRole:
  Type: AWS::IAM::Role
  Properties:
    RoleName: webproject-instance-role
    AssumeRolePolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Principal:
            Service: ec2.amazonaws.com
          Action: sts:AssumeRole
    Policies:
      - PolicyName: S3Access
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
            - Effect: Allow
              Action:
                - s3:*
              Resource: '*'
      # Add SQS & SNS permissions
      - PolicyName: SQSAccess
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
            - Effect: Allow
              Action:
                - sqs:SendMessage
                - sqs:ReceiveMessage
                - sqs:DeleteMessage
                - sqs:GetQueueAttributes
              Resource: 'arn:aws:sqs:ap-south-1:*:webproject-UploadsNotificationQueue'
      - PolicyName: SNSAccess
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
            - Effect: Allow
              Action:
                - sns:Publish
              Resource: 'arn:aws:sns:ap-south-1:*:webproject-UploadsNotificationTopic'
```

### Option B: Create Inline Policy via CLI

```powershell
# Create policy document
$SQSSNSPolicy = @{
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
} | ConvertTo-Json -Depth 10

# Save policy
$SQSSNSPolicy | Out-File -FilePath "sqssns-policy.json" -Encoding UTF8

# Attach to role (get role name from CloudFormation)
aws iam put-role-policy `
  --role-name webproject-instance-role `
  --policy-name sqssns-policy `
  --policy-document file://sqssns-policy.json `
  --region ap-south-1 `
  --profile user-iam-profile
```

---

## Phase 3: Update Web Application Code

### Step 3.1: Install Required Dependencies

Update `package.json` in the `web-dynamic-app` directory:

```json
{
  "dependencies": {
    "express": "^4.18.0",
    "aws-sdk": "^2.1400.0",
    "uuid": "^9.0.0"
  }
}
```

Install dependencies:

```powershell
cd web-dynamic-app
npm install
```

### Step 3.2: Update app.js with SQS/SNS Integration

Add the following code to handle:
- Email subscription endpoint
- Email unsubscription endpoint
- Image upload with SQS message publication
- Background process for batch processing

**See the updated app.js file sections below.**

---

## Phase 4: AWS CLI Commands for Runtime Operations

### Test SQS Queue

Send a test message:

```powershell
aws sqs send-message `
  --queue-url $QueueUrl `
  --message-body "Test message from CLI" `
  --message-attributes "ImageExtension={StringValue=.jpg,DataType=String}" `
  --region ap-south-1 `
  --profile user-iam-profile
```

Receive messages:

```powershell
aws sqs receive-message `
  --queue-url $QueueUrl `
  --max-number-of-messages 10 `
  --wait-time-seconds 20 `
  --region ap-south-1 `
  --profile user-iam-profile
```

Delete a message:

```powershell
aws sqs delete-message `
  --queue-url $QueueUrl `
  --receipt-handle "RECEIPT_HANDLE_VALUE" `
  --region ap-south-1 `
  --profile user-iam-profile
```

### Test SNS Topic

Publish a test notification:

```powershell
aws sns publish `
  --topic-arn $TopicArn `
  --subject "Test Notification" `
  --message "This is a test notification" `
  --message-attributes "FileExtension={DataType=String,StringValue=.jpg}" `
  --region ap-south-1 `
  --profile user-iam-profile
```

Subscribe an email (manual subscription):

```powershell
aws sns subscribe `
  --topic-arn $TopicArn `
  --protocol email `
  --notification-endpoint "test@example.com" `
  --region ap-south-1 `
  --profile user-iam-profile
```

### Manage Email Subscriptions via Application Endpoints

The application will provide these endpoints:

```
POST /api/subscribe?email=user@example.com
POST /api/unsubscribe?email=user@example.com
```

**CLI Alternative for Testing Subscriptions**:

List all subscriptions:

```powershell
aws sns list-subscriptions-by-topic `
  --topic-arn $TopicArn `
  --region ap-south-1 `
  --profile user-iam-profile
```

Unsubscribe:

```powershell
aws sns unsubscribe `
  --subscription-arn "arn:aws:sns:ap-south-1:123456789012:webproject-UploadsNotificationTopic:12345678-1234-1234-1234-123456789012" `
  --region ap-south-1 `
  --profile user-iam-profile
```

---

## Phase 5: Message Filtering Policy (Optional)

If using message filtering based on image extension attributes:

### Configure Filter Policy for PNG Images Only

Create `filter-policy.json`:

```json
{
  "ImageExtension": [".png"]
}
```

Apply to subscription:

```powershell
$SubscriptionArn = "arn:aws:sns:ap-south-1:123456789012:webproject-UploadsNotificationTopic:xxxxx"

aws sns set-subscription-attributes `
  --subscription-arn $SubscriptionArn `
  --attribute-name FilterPolicy `
  --attribute-value file://filter-policy.json `
  --region ap-south-1 `
  --profile user-iam-profile
```

---

## Phase 6: Monitoring & Troubleshooting

### View SQS Queue Metrics

```powershell
aws cloudwatch get-metric-statistics `
  --namespace AWS/SQS `
  --metric-name NumberOfMessagesSent `
  --dimensions Name=QueueName,Value=webproject-UploadsNotificationQueue `
  --start-time (Get-Date).AddHours(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") `
  --end-time (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") `
  --period 300 `
  --statistics Sum `
  --region ap-south-1 `
  --profile user-iam-profile
```

### View SNS Topic Metrics

```powershell
aws cloudwatch get-metric-statistics `
  --namespace AWS/SNS `
  --metric-name NumberOfMessagesPublished `
  --dimensions Name=TopicName,Value=webproject-UploadsNotificationTopic `
  --start-time (Get-Date).AddHours(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") `
  --end-time (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") `
  --period 300 `
  --statistics Sum `
  --region ap-south-1 `
  --profile user-iam-profile
```

### Purge Queue (Delete All Messages)

```powershell
aws sqs purge-queue `
  --queue-url $QueueUrl `
  --region ap-south-1 `
  --profile user-iam-profile
```

---

## Alternative SNS Notification Methods

Beyond email subscriptions, you can receive SNS notifications via:

### 1. **SMS (Text Message)**
```powershell
aws sns subscribe `
  --topic-arn $TopicArn `
  --protocol sms `
  --notification-endpoint "+1234567890" `
  --region ap-south-1 `
  --profile user-iam-profile
```

### 2. **HTTP/HTTPS Webhook**
```powershell
aws sns subscribe `
  --topic-arn $TopicArn `
  --protocol https `
  --notification-endpoint "https://example.com/webhook" `
  --region ap-south-1 `
  --profile user-iam-profile
```

### 3. **Lambda Function (Serverless Processing)**
```powershell
aws sns subscribe `
  --topic-arn $TopicArn `
  --protocol lambda `
  --notification-endpoint "arn:aws:lambda:ap-south-1:123456789012:function:ProcessImageUploads" `
  --region ap-south-1 `
  --profile user-iam-profile
```

### 4. **SQS (Already Configured Above)**
- Messages go to SQS queue for batch processing

### 5. **Application as SQS Poller**
- Your application continuously polls SQS and processes messages
- Can trigger Lambda, send emails, store in database, etc.

### 6. **EventBridge (For Advanced Routing)**
Create an EventBridge rule to route SNS messages to multiple targets (SQS, Lambda, Kinesis, etc.)

---

## Summary: Complete Workflow

1. **User uploads image** → 
2. **Application publishes to SQS** with metadata →
3. **Background process polls SQS** (batch) →
4. **Background process publishes to SNS** →
5. **SNS delivers to subscribers** (email, SMS, HTTP, Lambda, etc.)

---

## Quick Reference: All Variables

Store these in your PowerShell profile for easy access:

```powershell
# AWS Configuration
$Region = "ap-south-1"
$Profile = "user-iam-profile"
$ProjectName = "webproject"

# Resource Names
$QueueName = "$ProjectName-UploadsNotificationQueue"
$TopicName = "$ProjectName-UploadsNotificationTopic"

# URLs and ARNs (after creation)
$QueueUrl = "https://sqs.ap-south-1.amazonaws.com/123456789012/webproject-UploadsNotificationQueue"
$QueueArn = "arn:aws:sqs:ap-south-1:123456789012:webproject-UploadsNotificationQueue"
$TopicArn = "arn:aws:sns:ap-south-1:123456789012:webproject-UploadsNotificationTopic"
```

---

## Next Steps

1. ✅ Create SQS queue and SNS topic (Phase 1)
2. ✅ Update IAM permissions (Phase 2)
3. ⏳ Update web application code (Phase 3)
4. ⏳ Deploy and test (Phase 4)
5. ⏳ Configure filtering policies (Phase 5)
6. ⏳ Monitor and troubleshoot (Phase 6)
