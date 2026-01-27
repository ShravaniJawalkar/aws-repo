# Script to deploy Lambda function for image upload notifications using CloudFormation
# Run this script to create the Lambda function with SQS trigger and SNS publishing permissions

param(
    [string]$ProjectName = "webproject",
    [string]$AwsRegion = "ap-south-1",
    [string]$AwsProfile = "user-sns-sqs-profile",
    [string]$AwsAccountId = "908601827639"
)

# Set error action preference to stop on errors
$ErrorActionPreference = "Stop"

# CloudFormation stack settings
$StackName = "$ProjectName-uploads-notification-lambda"
$TemplateFile = "lambda-uploads-notification-template.yaml"

# Resource ARNs
$SqsQueueArn = "arn:aws:sqs:$AwsRegion`:$AwsAccountId`:$ProjectName-UploadsNotificationQueue"
$SqsQueueUrl = "https://sqs.$AwsRegion`.amazonaws.com/$AwsAccountId/$ProjectName-UploadsNotificationQueue"
$SnsTopicArn = "arn:aws:sns:$AwsRegion`:$AwsAccountId`:$ProjectName-UploadsNotificationTopic"

Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host "Deploying Lambda Function: $ProjectName-UploadsNotificationFunction" -ForegroundColor Cyan
Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Stack Name:     $StackName"
Write-Host "Region:         $AwsRegion"
Write-Host "Profile:        $AwsProfile"
Write-Host "SQS Queue:      $SqsQueueArn"
Write-Host "SNS Topic:      $SnsTopicArn"
Write-Host ""

# Check if template file exists
if (-not (Test-Path $TemplateFile)) {
    Write-Host "ERROR: Template file not found: $TemplateFile" -ForegroundColor Red
    exit 1
}

# Step 1: Deploy CloudFormation stack
Write-Host "Step 1: Deploying CloudFormation stack..." -ForegroundColor Yellow

$deployParams = @(
    "cloudformation", "deploy",
    "--template-file", $TemplateFile,
    "--stack-name", $StackName,
    "--region", $AwsRegion,
    "--profile", $AwsProfile,
    "--parameter-overrides",
    "ProjectName=$ProjectName",
    "SQSQueueArn=$SqsQueueArn",
    "SQSQueueUrl=$SqsQueueUrl",
    "SNSTopicArn=$SnsTopicArn",
    "--capabilities", "CAPABILITY_NAMED_IAM",
    "--no-fail-on-empty-changeset"
)

& aws @deployParams

Write-Host ""
Write-Host "Step 2: Retrieving Lambda function details..." -ForegroundColor Yellow
Write-Host ""

# Get Lambda function details from CloudFormation stack
$stackInfo = aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $AwsRegion `
    --profile $AwsProfile `
    | ConvertFrom-Json

$lambdaArn = $stackInfo.Stacks[0].Outputs | Where-Object { $_.OutputKey -eq "LambdaFunctionArn" } | Select-Object -ExpandProperty OutputValue
$lambdaName = $stackInfo.Stacks[0].Outputs | Where-Object { $_.OutputKey -eq "LambdaFunctionName" } | Select-Object -ExpandProperty OutputValue
$eventMappingId = $stackInfo.Stacks[0].Outputs | Where-Object { $_.OutputKey -eq "EventSourceMappingId" } | Select-Object -ExpandProperty OutputValue

Write-Host "===================================================================" -ForegroundColor Green
Write-Host "✓ Deployment Complete!" -ForegroundColor Green
Write-Host "===================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Lambda Function:" -ForegroundColor Cyan
Write-Host "  Name:   $lambdaName"
Write-Host "  ARN:    $lambdaArn"
Write-Host ""
Write-Host "Event Source Mapping:" -ForegroundColor Cyan
Write-Host "  ID:     $eventMappingId"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Test by uploading an image using the web application"
Write-Host "2. Check SQS queue:"
Write-Host "   aws sqs receive-message --queue-url $SqsQueueUrl --region $AwsRegion --profile $AwsProfile"
Write-Host "3. Check Lambda logs:"
Write-Host "   aws logs tail /aws/lambda/$lambdaName --follow --region $AwsRegion --profile $AwsProfile"
Write-Host "4. Verify email notifications in your inbox"
Write-Host ""
