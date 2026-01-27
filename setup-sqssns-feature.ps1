#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Quick setup script for SQS/SNS subscription feature
.DESCRIPTION
    This script automates the creation and setup of AWS SQS queue and SNS topic
    for the image upload notification system.
.PARAMETER ProjectName
    The project name (default: webproject)
.PARAMETER Region
    AWS region (default: ap-south-1)
.PARAMETER Profile
    AWS profile to use (default: user-iam-profile)
#>

param(
    [string]$ProjectName = "webproject",
    [string]$Region = "ap-south-1",
    [string]$Profile = "user-iam-profile"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "SQS/SNS Subscription Feature Setup" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create SQS Queue
Write-Host "[1/5] Creating SQS Queue..." -ForegroundColor Yellow
$QueueUrl = aws sqs create-queue `
  --queue-name "$ProjectName-UploadsNotificationQueue" `
  --region $Region `
  --profile $Profile `
  --query 'QueueUrl' `
  --output text

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ SQS Queue created: $QueueUrl" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to create SQS Queue" -ForegroundColor Red
    exit 1
}

# Step 2: Get Queue ARN
Write-Host "[2/5] Getting Queue ARN..." -ForegroundColor Yellow
$QueueArn = aws sqs get-queue-attributes `
  --queue-url $QueueUrl `
  --attribute-names QueueArn `
  --region $Region `
  --profile $Profile `
  --query 'Attributes.QueueArn' `
  --output text

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Queue ARN: $QueueArn" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to get Queue ARN" -ForegroundColor Red
    exit 1
}

# Step 3: Create SNS Topic
Write-Host "[3/5] Creating SNS Topic..." -ForegroundColor Yellow
$TopicArn = aws sns create-topic `
  --name "$ProjectName-UploadsNotificationTopic" `
  --region $Region `
  --profile $Profile `
  --query 'TopicArn' `
  --output text

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ SNS Topic created: $TopicArn" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to create SNS Topic" -ForegroundColor Red
    exit 1
}

# Step 4: Subscribe SQS to SNS
Write-Host "[4/5] Subscribing SQS Queue to SNS Topic..." -ForegroundColor Yellow
$SubscriptionArn = aws sns subscribe `
  --topic-arn $TopicArn `
  --protocol sqs `
  --notification-endpoint $QueueArn `
  --region $Region `
  --profile $Profile `
  --query 'SubscriptionArn' `
  --output text

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ SQS subscribed to SNS: $SubscriptionArn" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to subscribe SQS to SNS" -ForegroundColor Red
    exit 1
}

# Step 5: Set SQS Queue Policy
Write-Host "[5/5] Configuring SQS Queue Policy..." -ForegroundColor Yellow

# Get AWS Account ID
$AccountId = aws sts get-caller-identity `
  --region $Region `
  --profile $Profile `
  --query 'Account' `
  --output text

# Validate variables before creating policy
if ([string]::IsNullOrEmpty($QueueArn) -or [string]::IsNullOrEmpty($TopicArn)) {
    Write-Host "✗ Failed: QueueArn or TopicArn is empty" -ForegroundColor Red
    Write-Host "  QueueArn: $QueueArn"
    Write-Host "  TopicArn: $TopicArn"
    exit 1
}

# Create policy document as a properly formatted JSON string
$PolicyJson = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "$QueueArn",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "$TopicArn"
        }
      }
    }
  ]
}
"@

# Create attributes JSON file with the policy as a properly escaped string
$AttributesFile = "temp-attributes-$([datetime]::Now.Ticks).json"

# Escape the policy JSON for inclusion in attributes JSON
$EscapedPolicy = $PolicyJson -replace '\\', '\\' -replace '"', '\"' -replace "`n", " " -replace "`r", ""

# Create the attributes JSON
$AttributesJson = "{`"Policy`": `"$EscapedPolicy`"}"

# Write to file
$AttributesJson | Out-File -FilePath $AttributesFile -Encoding UTF8 -NoNewline

# Debug: Show the file content
Write-Host "Debug: Attributes file content:" -ForegroundColor Gray
Get-Content $AttributesFile
Write-Host ""

# Apply policy from file
aws sqs set-queue-attributes `
  --queue-url $QueueUrl `
  --attributes file://$AttributesFile `
  --region $Region `
  --profile $Profile

# Cleanup
Remove-Item -Path $AttributesFile -Force

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ SQS Queue Policy configured" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to configure Queue Policy" -ForegroundColor Red
    exit 1
}

# Save configuration to file
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Configuration Saved" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$Config = @"
# AWS SQS/SNS Configuration
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

PROJECT_NAME=webproject
AWS_REGION=$Region
AWS_PROFILE=$Profile

# SQS Configuration
SQS_QUEUE_NAME=webproject-UploadsNotificationQueue
SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
SQS_QUEUE_ARN=arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue

# SNS Configuration
SNS_TOPIC_NAME=webproject-UploadsNotificationTopic
SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic

# Subscription
SNS_SQS_SUBSCRIPTION_ARN=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic:1e8ebe25-0dae-4af8-af56-2446ddb08b62

# AWS Account
AWS_ACCOUNT_ID=908601827639
"@

$ConfigFile = "aws-sqssns-config.env"
$Config | Out-File -FilePath $ConfigFile -Encoding UTF8

Write-Host "Configuration saved to: $ConfigFile" -ForegroundColor Green
Write-Host ""
Write-Host "Environment Variables:" -ForegroundColor Cyan
Write-Host "  SQS_QUEUE_URL=$QueueUrl"
Write-Host "  SNS_TOPIC_ARN=$TopicArn"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Update your Node.js app.js with the Queue URL and Topic ARN"
Write-Host "2. Install dependencies: npm install"
Write-Host "3. Set environment variables from $ConfigFile"
Write-Host "4. Start your application: npm start"
Write-Host ""
Write-Host "Testing:" -ForegroundColor Yellow
Write-Host "  - Subscribe: curl -X POST 'http://localhost:8080/api/subscribe?email=test@example.com'"
Write-Host "  - Upload: curl -X POST 'http://localhost:8080/api/upload?fileName=test.jpg&fileSize=1024000'"
Write-Host "  - Check status: curl http://localhost:8080/admin/queue-status"
Write-Host ""
