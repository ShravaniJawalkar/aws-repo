# AWS Credentials Configuration Guide

## Problem
You're getting this error:
```
Error: Unable to locate credentials
```

This means AWS credentials are not configured properly. You need to set them up before you can use AWS CLI or SAM.

## Solution

### Option 1: Interactive Configuration (Recommended)

Run this command in PowerShell:

```powershell
aws configure
```

You'll be prompted for:
```
AWS Access Key ID [None]: YOUR_ACCESS_KEY_ID
AWS Secret Access Key [None]: YOUR_SECRET_ACCESS_KEY
Default region name [None]: ap-south-1
Default output format [None]: json
```

**Where to get these values:**
1. Go to [AWS IAM Console](https://console.aws.amazon.com/iam/)
2. Click on your username → Security Credentials
3. Under "Access keys for use with the AWS API" → Create New Access Key
4. Copy the Access Key ID and Secret Access Key

### Option 2: Environment Variables

Set environment variables in PowerShell:

```powershell
$env:AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY_ID"
$env:AWS_SECRET_ACCESS_KEY="YOUR_SECRET_ACCESS_KEY"
$env:AWS_DEFAULT_REGION="ap-south-1"
```

To make it permanent, add to your PowerShell profile:

```powershell
# Edit PowerShell profile
notepad $PROFILE

# Add these lines:
$env:AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY_ID"
$env:AWS_SECRET_ACCESS_KEY="YOUR_SECRET_ACCESS_KEY"
$env:AWS_DEFAULT_REGION="ap-south-1"

# Save and reload profile
. $PROFILE
```

### Option 3: AWS Credentials File

Create file: `~/.aws/credentials`

**On Windows**, this is: `C:\Users\YourUsername\.aws\credentials`

Content:
```
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY

[default]
region = ap-south-1
```

Create file: `~/.aws/config`

**On Windows**, this is: `C:\Users\YourUsername\.aws\config`

Content:
```
[default]
region = ap-south-1
output = json
```

## Verification

After configuring, verify with:

```powershell
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

If you see this output, credentials are configured correctly!

## Next Steps

Once credentials are verified:

1. Create AWS resources:
```powershell
cd c:\Users\Shravani_Jawalkar\aws
.\setup-aws-resources.ps1
```

2. Deploy SAM application:
```powershell
sam deploy -t sam-template.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

## Troubleshooting

### Still getting "Unable to locate credentials"?

Check these:

```powershell
# Check if credentials file exists
Test-Path $env:USERPROFILE\.aws\credentials

# Check if AWS CLI can find credentials
aws configure list

# Check environment variables
Get-ChildItem env:AWS*

# Try explicit configuration
aws configure --profile default
```

### Wrong region?

Verify region is set to `ap-south-1`:

```powershell
aws configure get region
```

If wrong, update:
```powershell
aws configure set region ap-south-1
```

### Access Denied errors?

Your AWS user needs these minimum permissions:
- CloudFormation
- Lambda
- IAM
- SQS
- SNS
- S3
- CloudWatch Logs

Contact your AWS administrator if you lack permissions.
