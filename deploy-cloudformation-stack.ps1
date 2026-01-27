#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Automated CloudFormation deployment script for web application
.DESCRIPTION
    Creates EC2 instance with web application, SQS, and SNS integration
.PARAMETER StackName
    CloudFormation stack name (default: webproject-app-stack)
.PARAMETER ProjectName
    Project name (default: webproject)
.PARAMETER InstanceType
    EC2 instance type (default: t2.micro)
.PARAMETER SSHLocation
    SSH allowed CIDR (default: 0.0.0.0/0)
#>

param(
    [string]$StackName = "webproject-app-stack",
    [string]$ProjectName = "webproject",
    [string]$InstanceType = "t2.micro",
    [string]$SSHLocation = "0.0.0.0/0",
    [string]$SQSQueueURL = "",
    [string]$SNSTopicARN = "",
    [string]$Region = "ap-south-1",
    [string]$Profile = "user-iam-profile"
)

# Colors for output
$SuccessColor = "Green"
$ErrorColor = "Red"
$WarningColor = "Yellow"
$InfoColor = "Cyan"

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $SuccessColor
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $ErrorColor
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor $InfoColor
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $WarningColor
}

# =====================================================================
# START DEPLOYMENT
# =====================================================================

Write-Host "================================================" -ForegroundColor $InfoColor
Write-Host "CloudFormation Web Application Deployment" -ForegroundColor $InfoColor
Write-Host "================================================" -ForegroundColor $InfoColor
Write-Host ""

# Check if AWS CLI is installed
Write-Info "Checking prerequisites..."
$awsVersion = aws --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "AWS CLI is not installed"
    exit 1
}
Write-Success "AWS CLI found: $awsVersion"

# Validate template file
if (-not (Test-Path "cloudformation-web-app-deployment.yaml")) {
    Write-Error "Template file 'cloudformation-web-app-deployment.yaml' not found"
    exit 1
}
Write-Success "Template file found"

# Get SQS and SNS details if not provided
if ([string]::IsNullOrEmpty($SQSQueueURL)) {
    Write-Warning "SQS Queue URL not provided"
    Write-Info "Run .\setup-sqssns-feature.ps1 first to create SQS queue"
    Write-Host ""
    Write-Host "Do you want to continue without SQS/SNS? (y/n): " -NoNewline
    $response = Read-Host
    
    if ($response -ne "y") {
        Write-Info "Please create SQS/SNS first and try again"
        exit 0
    }
}

if ([string]::IsNullOrEmpty($SNSTopicARN)) {
    Write-Warning "SNS Topic ARN not provided"
}

# Validate SSH CIDR format
$cidrPattern = "^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$"
if ($SSHLocation -ne "0.0.0.0/0" -and $SSHLocation -notmatch $cidrPattern) {
    Write-Error "Invalid CIDR format: $SSHLocation"
    exit 1
}
Write-Success "Parameters validated"

# =====================================================================
# CREATE CLOUDFORMATION STACK
# =====================================================================

Write-Host ""
Write-Host "================================================" -ForegroundColor $InfoColor
Write-Host "Creating CloudFormation Stack" -ForegroundColor $InfoColor
Write-Host "================================================" -ForegroundColor $InfoColor
Write-Host ""

Write-Info "Stack Name: $StackName"
Write-Info "Project Name: $ProjectName"
Write-Info "Instance Type: $InstanceType"
Write-Info "SSH Location: $SSHLocation"
Write-Info "Region: $Region"

Write-Host ""
Write-Info "Creating stack (this may take 10-15 minutes)..."

# Build parameters
$Parameters = @(
    "ParameterKey=ProjectName,ParameterValue=$ProjectName"
    "ParameterKey=ProjectInstanceType,ParameterValue=$InstanceType"
    "ParameterKey=SSHLocation,ParameterValue=$SSHLocation"
)

if (![string]::IsNullOrEmpty($SQSQueueURL)) {
    $Parameters += "ParameterKey=SQSQueueURL,ParameterValue=$SQSQueueURL"
}

if (![string]::IsNullOrEmpty($SNSTopicARN)) {
    $Parameters += "ParameterKey=SNSTopicARN,ParameterValue=$SNSTopicARN"
}

# Create stack
$result = aws cloudformation create-stack `
    --stack-name $StackName `
    --template-body file://cloudformation-web-app-deployment.yaml `
    --parameters $Parameters `
    --capabilities CAPABILITY_NAMED_IAM `
    --region $Region `
    --profile $Profile `
    2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create stack"
    Write-Error $result
    exit 1
}

Write-Success "Stack creation initiated"
Write-Info "StackId: $(($result | ConvertFrom-Json).StackId)"

Write-Host ""
Write-Info "Waiting for stack creation to complete..."
Write-Info "This will take approximately 10-15 minutes..."
Write-Host ""

# Wait for stack creation
$maxAttempts = 180
$attempt = 0
$completed = $false

while ($attempt -lt $maxAttempts) {
    $attempt++
    
    $stackStatus = aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $Region `
        --profile $Profile `
        --query 'Stacks[0].StackStatus' `
        --output text `
        2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Error checking stack status: $stackStatus"
        Start-Sleep -Seconds 5
        continue
    }
    
    if ($stackStatus -eq "CREATE_COMPLETE") {
        $completed = $true
        break
    } elseif ($stackStatus -eq "CREATE_FAILED" -or $stackStatus -eq "ROLLBACK_COMPLETE") {
        Write-Error "Stack creation failed: $stackStatus"
        
        # Get failure events
        Write-Host ""
        Write-Info "Stack Events:"
        aws cloudformation describe-stack-events `
            --stack-name $StackName `
            --region $Region `
            --profile $Profile `
            --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[Timestamp,ResourceType,ResourceStatus,ResourceStatusReason]' `
            --output table
        
        exit 1
    }
    
    Write-Host "." -NoNewline -ForegroundColor $InfoColor
    Start-Sleep -Seconds 5
}

Write-Host ""

if ($completed) {
    Write-Success "Stack created successfully!"
} else {
    Write-Error "Stack creation timed out after $($maxAttempts * 5) seconds"
    exit 1
}

# =====================================================================
# GET STACK OUTPUTS
# =====================================================================

Write-Host ""
Write-Host "================================================" -ForegroundColor $InfoColor
Write-Host "Stack Outputs" -ForegroundColor $InfoColor
Write-Host "================================================" -ForegroundColor $InfoColor
Write-Host ""

$outputs = aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --profile $Profile `
    --query 'Stacks[0].Outputs' `
    2>&1 | ConvertFrom-Json

if ($outputs) {
    foreach ($output in $outputs) {
        Write-Info "$($output.OutputKey): $($output.OutputValue)"
    }
} else {
    Write-Warning "Could not retrieve stack outputs"
}

# Extract important values
$instanceIP = aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --profile $Profile `
    --query 'Stacks[0].Outputs[?OutputKey==`InstancePublicIP`].OutputValue' `
    --output text `
    2>&1

$applicationURL = "http://$instanceIP:8080"

# =====================================================================
# DEPLOYMENT SUMMARY
# =====================================================================

Write-Host ""
Write-Host "================================================" -ForegroundColor $SuccessColor
Write-Host "Deployment Complete!" -ForegroundColor $SuccessColor
Write-Host "================================================" -ForegroundColor $SuccessColor
Write-Host ""

Write-Info "Application URL: $applicationURL"
Write-Info "Instance IP: $instanceIP"
Write-Info "Stack Name: $StackName"
Write-Info "Region: $Region"

Write-Host ""
Write-Info "Next Steps:"
Write-Host "1. Wait 2-3 minutes for application to start"
Write-Host "2. Test health check: curl $applicationURL/health"
Write-Host "3. Subscribe email: curl -X POST '$applicationURL/api/subscribe?email=test@example.com'"
Write-Host "4. Check application: curl $applicationURL/"
Write-Host ""

Write-Info "SSH Access:"
Write-Host "ssh -i your-key.pem ec2-user@$instanceIP"
Write-Host ""

Write-Info "View Logs:"
Write-Host "sudo journalctl -u web-app -f"
Write-Host ""

Write-Info "Manage Stack:"
Write-Host "# Update stack:"
Write-Host "aws cloudformation update-stack --stack-name $StackName --use-previous-template"
Write-Host ""
Write-Host "# Delete stack:"
Write-Host "aws cloudformation delete-stack --stack-name $StackName --region $Region --profile $Profile"
Write-Host ""

Write-Success "Setup complete! Access your application at: $applicationURL"

# Save stack details to file
$stackDetails = @{
    StackName = $StackName
    InstanceIP = $instanceIP
    ApplicationURL = $applicationURL
    Region = $Region
    CreatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

$stackDetails | ConvertTo-Json | Out-File -FilePath "$StackName-details.json"
Write-Info "Stack details saved to: $StackName-details.json"

Write-Host ""
Write-Host "================================================" -ForegroundColor $SuccessColor
Write-Host "Ready to deploy! 🚀" -ForegroundColor $SuccessColor
Write-Host "================================================" -ForegroundColor $SuccessColor
