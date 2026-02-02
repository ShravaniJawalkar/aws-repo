# Setting Up AWS Resources for SAM Deployment

This guide explains how to create the prerequisite AWS resources needed before deploying the SAM application.

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured with valid credentials
3. **AWS Region**: `ap-south-1` (Mumbai)
4. **AWS Account ID**: `908601827639`

## Resources to Create

1. **SQS Queue**: `webproject-UploadsNotificationQueue`
2. **SNS Topic**: `webproject-UploadsNotificationTopic`
3. **S3 Bucket**: For Lambda deployment artifacts

## Step 1: Configure AWS CLI

If you haven't already configured AWS credentials, run:

```powershell
aws configure
```

You'll be prompted for:
- **AWS Access Key ID**: Your AWS access key
- **AWS Secret Access Key**: Your AWS secret key
- **Default region name**: `ap-south-1`
- **Default output format**: `json`

Verify configuration:
```powershell
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "...",
    "Account": "908601827639",
    "Arn": "arn:aws:iam::908601827639:user/..."
}
```

## Step 2: Create AWS Resources

### Option A: Using PowerShell Script (Automated)

Run the provided script:

```powershell
cd c:\Users\Shravani_Jawalkar\aws
.\setup-aws-resources.ps1
```

The script will:
- Create SQS Queue
- Create SNS Topic
- Create S3 Bucket
- Display all resource details

### Option B: Using AWS CLI (Manual)

#### 1. Create SQS Queue

```powershell
$QueueUrl = aws sqs create-queue `
  --queue-name webproject-UploadsNotificationQueue `
  --region ap-south-1 `
  --query 'QueueUrl' `
  --output text

Write-Host "SQS Queue URL: $QueueUrl"

# Get Queue ARN
$QueueArn = aws sqs get-queue-attributes `
  --queue-url $QueueUrl `
  --attribute-names QueueArn `
  --region ap-south-1 `
  --query 'Attributes.QueueArn' `
  --output text

Write-Host "SQS Queue ARN: $QueueArn"
```

#### 2. Create SNS Topic

```powershell
$TopicArn = aws sns create-topic `
  --name webproject-UploadsNotificationTopic `
  --region ap-south-1 `
  --query 'TopicArn' `
  --output text

Write-Host "SNS Topic ARN: $TopicArn"
```

#### 3. Create S3 Bucket

```powershell
$BucketName = "webproject-sam-deployments-$(Get-Random -Minimum 100000 -Maximum 999999)"

aws s3api create-bucket `
  --bucket $BucketName `
  --region ap-south-1 `
  --create-bucket-configuration LocationConstraint=ap-south-1

Write-Host "S3 Bucket: $BucketName"

# Enable versioning
aws s3api put-bucket-versioning `
  --bucket $BucketName `
  --versioning-configuration Status=Enabled `
  --region ap-south-1
```

## Step 3: Update SAM Configuration

Update `samconfig.toml` with your S3 bucket name:

```toml
[default.deploy.parameters]
stack_name = "webproject-uploads-notification-stack"
s3_bucket = "YOUR-S3-BUCKET-NAME"
s3_prefix = "uploads-notification"
region = "ap-south-1"
confirm_changeset = false
capabilities = "CAPABILITY_IAM,CAPABILITY_NAMED_IAM,CAPABILITY_AUTO_EXPAND"
```

Or update the SAM template parameters if needed by modifying `sam-template.yaml`:

```yaml
Parameters:
  SQSQueueArn:
    Default: arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue
  
  SQSQueueUrl:
    Default: https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
  
  SNSTopicArn:
    Default: arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic
```

## Step 4: Verify Resources

Check that all resources were created successfully:

```powershell
# List SQS Queues
aws sqs list-queues --region ap-south-1

# List SNS Topics
aws sns list-topics --region ap-south-1

# List S3 Buckets
aws s3 ls
```

## Step 5: Deploy SAM Application

Now you can proceed with SAM deployment:

```powershell
cd c:\Users\Shravani_Jawalkar\aws
sam build -t sam-template.yaml
sam deploy -t sam-template.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

## Troubleshooting

### Issue: "QueueAlreadyExists"

If you get this error, it means the SQS queue already exists. That's fine - the script will use the existing queue.

**Solution:**
```powershell
$QueueUrl = aws sqs get-queue-url `
  --queue-name webproject-UploadsNotificationQueue `
  --region ap-south-1 `
  --query 'QueueUrl' `
  --output text

aws sqs get-queue-attributes `
  --queue-url $QueueUrl `
  --attribute-names All `
  --region ap-south-1
```

### Issue: "TopicAlimitAlreadyExists"

If SNS topic already exists:

```powershell
aws sns list-topics --region ap-south-1 --query 'Topics[?contains(TopicArn, `webproject-UploadsNotificationTopic`)]'
```

### Issue: "BucketAlreadyExists"

If S3 bucket already exists:

```powershell
aws s3 ls --region ap-south-1
```

## Cleanup

To delete all created resources:

```powershell
# Delete S3 Bucket (must be empty)
aws s3 rm s3://webproject-sam-deployments-XXXXX --recursive
aws s3api delete-bucket --bucket webproject-sam-deployments-XXXXX

# Delete SNS Topic
aws sns delete-topic --topic-arn arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic

# Delete SQS Queue
aws sqs delete-queue --queue-url https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
```

## Resource ARNs and URLs

Once created, you'll have:

| Resource | ARN/URL |
|----------|---------|
| SQS Queue | `arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue` |
| SQS URL | `https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue` |
| SNS Topic | `arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic` |
| S3 Bucket | `s3://webproject-sam-deployments-XXXXX` |

## Next Steps

1. [Deploy SAM Application](SAM-README.md#-deployment--deployment)
2. [Test Locally](SAM-README.md#-local-testing)
3. [Monitor Deployment](SAM-README.md#-monitoring--debugging)
4. [Test End-to-End](SAM-README.md#-manual-testing)
