# SAM Deployment - Prerequisites Setup

## Current Status

✅ **Completed:**
- SAM template created (`sam-template.yaml`)
- Lambda function code written (`src/index.js`)
- Test Lambda function created (`src-test/s3-logs-handler.js`)
- SAM CLI installed (version 1.152.0)
- SAM application built successfully
- Comprehensive documentation created

❌ **Pending - AWS Resources Required:**
- SQS Queue: `webproject-UploadsNotificationQueue`
- SNS Topic: `webproject-UploadsNotificationTopic`
- S3 Bucket: For Lambda deployment artifacts

---

## What You Need to Do

### Step 1: Ensure AWS CLI is Configured

Run the following command in PowerShell:

```powershell
aws sts get-caller-identity
```

**Expected Output:**
```json
{
    "UserId": "...",
    "Account": "908601827639",
    "Arn": "arn:aws:iam::908601827639:..."
}
```

**If this fails:**
```powershell
aws configure
# Then provide:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: ap-south-1
# - Default output: json
```

---

### Step 2: Create AWS Resources

Navigate to the project directory and run:

```powershell
cd c:\Users\Shravani_Jawalkar\aws
.\setup-aws-resources.ps1
```

This will automatically create:
1. ✓ SQS Queue named `webproject-UploadsNotificationQueue`
2. ✓ SNS Topic named `webproject-UploadsNotificationTopic`
3. ✓ S3 Bucket for Lambda artifacts (auto-named: `webproject-sam-deployments-XXXXXX`)

**Sample Output:**
```
========================================
Creating AWS Resources for SAM Deployment
========================================

Verifying AWS credentials...
✓ AWS Account ID: 908601827639
✓ Region: ap-south-1

Creating SQS Queue...
✓ SQS Queue created: https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
✓ SQS Queue ARN: arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue

Creating SNS Topic...
✓ SNS Topic created: arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic

Creating S3 Bucket for Lambda Artifacts...
✓ S3 Bucket created: s3://webproject-sam-deployments-123456
✓ S3 Bucket versioning enabled

========================================
Resource Creation Summary
========================================

SQS Queue:
  Name: webproject-UploadsNotificationQueue
  URL:  https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
  ARN:  arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue

SNS Topic:
  Name: webproject-UploadsNotificationTopic
  ARN:  arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic

S3 Bucket:
  Name: webproject-sam-deployments-123456

========================================
Next Steps:
========================================
1. Update samconfig.toml with S3 bucket name:
   s3_bucket = "webproject-sam-deployments-123456"

2. Deploy SAM application:
   sam deploy -t sam-template.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

---

### Step 3: Update samconfig.toml

After running the setup script, update `samconfig.toml`:

Find this line:
```toml
s3_bucket = "webproject-sam-deployments"
```

Replace with the actual bucket name from the script output:
```toml
s3_bucket = "webproject-sam-deployments-123456"
```

---

### Step 4: Deploy SAM Application

Once resources are created, deploy:

```powershell
cd c:\Users\Shravani_Jawalkar\aws
sam deploy -t sam-template.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

Or use guided deployment:
```powershell
sam deploy --guided -t sam-template.yaml
```

---

## Files You Need to Know About

| File | Purpose |
|------|---------|
| `sam-template.yaml` | SAM template defining all Lambda functions and IAM roles |
| `samconfig.toml` | SAM CLI configuration (S3 bucket, stack name, etc.) |
| `setup-aws-resources.ps1` | PowerShell script to create SQS, SNS, and S3 |
| `src/index.js` | Main Lambda function code |
| `src-test/s3-logs-handler.js` | Test Lambda function |
| `SAM-README.md` | Complete SAM documentation |
| `AWS-RESOURCES-SETUP.md` | Detailed AWS resources setup guide |

---

## Quick Command Reference

```powershell
# Check AWS credentials
aws sts get-caller-identity

# Create AWS resources
.\setup-aws-resources.ps1

# Build SAM application
sam build -t sam-template.yaml

# Deploy SAM application
sam deploy -t sam-template.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

# View Lambda logs
sam logs -n UploadsNotificationFunction --stack-name webproject-uploads-notification-stack -t

# Invoke function locally
sam local invoke UploadsNotificationFunction -e events/sqs-event.json

# Get CloudFormation stack info
aws cloudformation describe-stacks --stack-name webproject-uploads-notification-stack --region ap-south-1

# Delete SAM stack (cleanup)
sam delete --stack-name webproject-uploads-notification-stack --region ap-south-1
```

---

## Troubleshooting

### ❌ Error: "Unable to locate credentials"

**Solution:** Configure AWS credentials:
```powershell
aws configure
```

### ❌ Error: "QueueAlreadyExists"

**Solution:** The script will detect and use existing queues automatically. No action needed.

### ❌ Error: "BucketAlreadyExists"

**Solution:** Verify existing bucket details:
```powershell
aws s3 ls
```

### ❌ Error: "Capability IAM role"

**Solution:** Use proper capabilities in deploy command:
```powershell
sam deploy -t sam-template.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

---

## Architecture Overview

```
Web Application (EC2)
       ↓
   [Upload Image]
       ↓
   SQS Queue
   (webproject-UploadsNotificationQueue)
       ↓
Lambda Function
(webproject-uploads-notification-function)
       ↓
   SNS Topic
   (webproject-UploadsNotificationTopic)
       ↓
  Email Recipients
```

---

## Next Phase: Testing

After deployment, you'll:
1. ✓ Access AWS Lambda console to verify deployment
2. ✓ Upload image via web application
3. ✓ Verify email notification is received
4. ✓ Check CloudWatch logs for execution details

---

**Ready to proceed with creating AWS resources?**

Run this command:
```powershell
cd c:\Users\Shravani_Jawalkar\aws
.\setup-aws-resources.ps1
```
