# PowerShell script to deploy EC2 web application

param(
    [string]$StackName = "webproject-web-app-stack",
    [string]$InstanceType = "t3.micro",
    [string]$SSHLocation = "0.0.0.0/0",
    [string]$AwsRegion = "ap-south-1",
    [string]$AwsProfile = "user-ec2-profile",
    [string]$AwsStackProfile = "user-iam-profile",
    [string]$ProjectName = "webproject",
    [string]$KeyValuePair = "KeyName=web-server.pem"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "EC2 Web Application Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set AWS profile
$env:AWS_PROFILE=$AwsStackProfile

# Verify credentials
Write-Host "Verifying AWS credentials..." -ForegroundColor Yellow
try {
    $identity = aws sts get-caller-identity --region $AwsRegion --profile $AwsStackProfile | ConvertFrom-Json
    $AccountId = $identity.Account
    Write-Host "✓ AWS Account ID: $AccountId" -ForegroundColor Green
    Write-Host "✓ Region: $AwsRegion" -ForegroundColor Green
} catch {
    Write-Host "✗ Error: AWS credentials not configured" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Preparing deployment parameters..." -ForegroundColor Yellow

# SQS Queue URL and SNS Topic ARN
$SqsQueueUrl = "https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue"
$SnsTopicArn = "arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic"

Write-Host "✓ SQS Queue URL: $SqsQueueUrl" -ForegroundColor Green
Write-Host "✓ SNS Topic ARN: $SnsTopicArn" -ForegroundColor Green
Write-Host ""

Write-Host "Deploying EC2 stack..." -ForegroundColor Yellow
Write-Host "Stack Name: $StackName" -ForegroundColor Cyan
Write-Host "Instance Type: $InstanceType" -ForegroundColor Cyan
Write-Host ""

# Create CloudFormation stack
try {
    aws cloudformation create-stack `
        --stack-name $StackName `
        --template-body file://cloudformation-web-app-clean.yaml `
        --parameters `
            ParameterKey=ProjectName,ParameterValue=$ProjectName `
            ParameterKey=ProjectInstanceType,ParameterValue=$InstanceType `
            ParameterKey=SSHLocation,ParameterValue=$SSHLocation `
            ParameterKey=SQSQueueURL,ParameterValue=$SqsQueueUrl `
            ParameterKey=SNSTopicARN,ParameterValue=$SnsTopicArn `
            ParameterKey=KeyName,ParameterValue=web-server `
        --region $AwsRegion  --profile $AwsStackProfile `
        --capabilities CAPABILITY_NAMED_IAM
    
    Write-Host "✓ Stack creation initiated" -ForegroundColor Green
    Write-Host ""
    
    # Wait for stack creation
    Write-Host "Waiting for stack creation to complete (this may take 3-5 minutes)..." -ForegroundColor Yellow
    $stackStatus = aws cloudformation wait stack-create-complete `
        --stack-name $StackName `
        --region $AwsRegion --profile $AwsStackProfile
    
    Write-Host "✓ Stack creation completed" -ForegroundColor Green
    
} catch {
    if ($_.Exception.Message -like "*AlreadyExistsException*") {
        Write-Host "! Stack already exists" -ForegroundColor Yellow
    } else {
        Write-Host "✗ Error creating stack: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Retrieving Stack Outputs" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get stack outputs
try {
    $stackOutputs = aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $AwsRegion --profile $AwsStackProfile `
        --query 'Stacks[0].Outputs' | ConvertFrom-Json
    
    # Extract outputs
    $InstanceId = ($stackOutputs | Where-Object { $_.OutputKey -eq "InstanceId" }).OutputValue
    $InstancePublicIP = ($stackOutputs | Where-Object { $_.OutputKey -eq "InstancePublicIP" }).OutputValue
    $ApplicationURL = ($stackOutputs | Where-Object { $_.OutputKey -eq "ApplicationURL" }).OutputValue
    $SSHCommand = ($stackOutputs | Where-Object { $_.OutputKey -eq "SSHCommand" }).OutputValue
    
    Write-Host "Instance Information:" -ForegroundColor White
    Write-Host "  Instance ID: $InstanceId" -ForegroundColor Cyan
    Write-Host "  Public IP:   $InstancePublicIP" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Web Application:" -ForegroundColor White
    Write-Host "  URL: http://$InstancePublicIP`:8080" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "SSH Access:" -ForegroundColor White
    Write-Host "  Command: ssh -i your-key.pem ec2-user@$InstancePublicIP" -ForegroundColor Cyan
    Write-Host ""
    
} catch {
    Write-Host "✗ Error retrieving outputs: $_" -ForegroundColor Red
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Wait 2-3 minutes for application startup" -ForegroundColor White
Write-Host "2. Access web app: http://$InstancePublicIP`:8080" -ForegroundColor White
Write-Host "3. Subscribe to email notifications" -ForegroundColor White
Write-Host "4. Test image upload flow" -ForegroundColor White
Write-Host ""
Write-Host "Test Commands:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Subscribe:" -ForegroundColor Cyan
Write-Host "  curl -X POST `"http://$InstancePublicIP`:8080/api/subscribe?email=your-email@example.com`"" -ForegroundColor White
Write-Host ""
Write-Host "Upload Image:" -ForegroundColor Cyan
Write-Host "  curl -X POST `"http://$InstancePublicIP`:8080/api/upload?fileName=test.jpg&fileSize=2048576`"" -ForegroundColor White
Write-Host ""
Write-Host "Process Queue:" -ForegroundColor Cyan
Write-Host "  curl -X POST `"http://$InstancePublicIP`:8080/admin/process-queue`"" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
