# Deployment script for Data Consistency Lambda Function (Windows PowerShell)
# Deploys all necessary AWS resources for Sub-Task 2

param(
    [Parameter(Mandatory=$false)]
    [string]$Profile = "user-iam-profile",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "ap-south-1"
)

$ProjectName = "webproject"
$VpcId = "vpc-04304d2648a6d0753"
$SubnetIds = "subnet-03f16fceda3f36dec,subnet-0f16a48da72abda1e"
$RdsSecurityGroup = "sg-06be32af49a07ede4"
$DbHost = "webproject-database.c14e66sq09ij.ap-south-1.rds.amazonaws.com"
$DbUser = "admin"
$DbName = "webproject"

Write-Host "========================================" -ForegroundColor Green
Write-Host "Data Consistency Lambda Deployment" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Project: $ProjectName" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "VPC ID: $VpcId" -ForegroundColor Cyan
Write-Host "RDS: $DbHost" -ForegroundColor Cyan
Write-Host ""

# Step 1: Get database password
$DbPassword = Read-Host "Enter RDS database password" -AsSecureString
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($DbPassword))

# Step 2: Create Lambda deployment package
Write-Host "[1/5] Creating Lambda deployment package..." -ForegroundColor Yellow

$LambdaDir = "lambda-function"
$ZipName = "data-consistency-lambda.zip"

Push-Location $LambdaDir

# Check if node_modules exists, if not install dependencies
if (-not (Test-Path "node_modules")) {
    Write-Host "  - Installing npm dependencies..." -ForegroundColor Gray
    npm install --save aws-sdk mysql2 2>&1 | Out-Null
}

# Create zip file using PowerShell (Windows-compatible)
Write-Host "  - Creating $ZipName..." -ForegroundColor Gray

# Remove old zip if exists
if (Test-Path $ZipName) {
    Remove-Item $ZipName -Force
}

# Create new zip
Compress-Archive -Path "data-consistency.js", "node_modules", "package.json" -DestinationPath $ZipName -Force

if (Test-Path $ZipName) {
    $ZipSize = (Get-Item $ZipName).Length / 1MB
    Write-Host "  ✓ Deployment package ready ($('{0:N2}' -f $ZipSize) MB)" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to create zip file" -ForegroundColor Red
    Pop-Location
    exit 1
}

Pop-Location

# Step 3: Prepare Lambda code bucket
Write-Host ""
Write-Host "[2/5] Preparing Lambda code bucket..." -ForegroundColor Yellow

$CodeBucket = "shravani-jawalkar-webproject-bucket"

try {
    $BucketExists = aws s3 ls "s3://$CodeBucket" --region $Region --profile $Profile 2>&1 | Select-Object -First 1
    if (-not $BucketExists) {
        Write-Host "  - Creating S3 bucket for Lambda code..." -ForegroundColor Gray
        aws s3 mb "s3://$CodeBucket" --region $Region --profile $Profile 2>&1 | Out-Null
    }
    Write-Host "  ✓ Bucket ready" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ Using existing bucket or error occurred" -ForegroundColor Yellow
}

# Upload Lambda package
Write-Host "  - Uploading Lambda package..." -ForegroundColor Gray
aws s3 cp "$LambdaDir\$ZipName" "s3://$CodeBucket/$ZipName" --region $Region --profile $Profile

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Lambda package uploaded" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to upload Lambda package" -ForegroundColor Red
    exit 1
}

# Step 4: Deploy CloudFormation Stack
Write-Host ""
Write-Host "[3/5] Deploying CloudFormation stack..." -ForegroundColor Yellow
Write-Host "  - Stack name: $ProjectName-data-consistency-lambda-v2" -ForegroundColor Gray

$StackName = "$ProjectName-data-consistency-lambda-v2"

try {
    aws cloudformation deploy `
        --template-file lambda-data-consistency-template.yaml `
        --stack-name $StackName `
        --parameter-overrides `
            ProjectName=$ProjectName `
            DBPassword=$PlainPassword `
            VpcId=$VpcId `
            SubnetIds=$SubnetIds `
            DBSecurityGroupId=$RdsSecurityGroup `
        --capabilities CAPABILITY_NAMED_IAM `
        --region $Region `
        --profile $Profile `
        --no-fail-on-empty-changeset

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ CloudFormation stack deployed" -ForegroundColor Green
    } else {
        Write-Host "  ✗ CloudFormation deployment failed" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ✗ Error deploying stack: $_" -ForegroundColor Red
    exit 1
}

# Step 5: Get Lambda Security Group and update RDS rules
Write-Host ""
Write-Host "[4/5] Configuring security group rules..." -ForegroundColor Yellow

try {
    $LambdaSg = aws cloudformation describe-stacks `
        --stack-name $StackName `
        --query 'Stacks[0].Outputs[?OutputKey==`LambdaSecurityGroupId`].OutputValue' `
        --output text `
        --region $Region `
        --profile $Profile

    Write-Host "  - Lambda Security Group: $LambdaSg" -ForegroundColor Gray
    Write-Host "  - Authorizing Lambda SG to access RDS..." -ForegroundColor Gray

    # Add inbound rule to RDS security group
    aws ec2 authorize-security-group-ingress `
        --group-id $RdsSecurityGroup `
        --protocol tcp `
        --port 3306 `
        --source-group $LambdaSg `
        --region $Region `
        --profile $Profile 2>&1 | Out-Null

    Write-Host "  ✓ Security groups configured" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ Security group rule may already exist or error occurred" -ForegroundColor Yellow
}

# Step 6: Initialize Database Table
Write-Host ""
Write-Host "[5/5] Initializing database table..." -ForegroundColor Yellow
Write-Host "  - Creating image_uploads table..." -ForegroundColor Gray

try {
    # SQL script
    $SqlScript = @"
CREATE TABLE IF NOT EXISTS image_uploads (
  id INT AUTO_INCREMENT PRIMARY KEY,
  fileName VARCHAR(255) NOT NULL UNIQUE,
  fileSize BIGINT,
  fileExtension VARCHAR(10),
  uploadedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  description TEXT,
  uploadedBy VARCHAR(100),
  INDEX idx_fileName (fileName)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
"@

    # Create database first
    $SqlScript | mysql -h $DbHost -u $DbUser -p$PlainPassword 2>&1 | Out-Null
    
    # Create table
    $SqlScript | mysql -h $DbHost -u $DbUser -p$PlainPassword $DbName 2>&1 | Out-Null
    
    Write-Host "  ✓ Database initialized" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ Database initialization may have completed or error occurred" -ForegroundColor Yellow
}

# Get deployment outputs
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Getting deployment outputs..." -ForegroundColor Cyan

aws cloudformation describe-stacks `
    --stack-name $StackName `
    --query 'Stacks[0].Outputs[*].{OutputKey:OutputKey,OutputValue:OutputValue}' `
    --output table `
    --region $Region `
    --profile $Profile

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Green
Write-Host "1. Wait 2-3 minutes for Lambda to initialize in VPC" -ForegroundColor Gray
Write-Host "2. Check CloudWatch logs: /aws/lambda/$ProjectName-DataConsistencyFunction" -ForegroundColor Gray
Write-Host "3. Test API Gateway endpoint (from outputs above)" -ForegroundColor Gray
Write-Host "4. Test web app endpoint: /api/check-consistency" -ForegroundColor Gray
Write-Host "5. Verify scheduled invocation every 5 minutes" -ForegroundColor Gray
Write-Host ""

Write-Host "Monitor logs:" -ForegroundColor Green
Write-Host "  aws logs tail /aws/lambda/$ProjectName-DataConsistencyFunction --follow --region $Region" -ForegroundColor Gray
Write-Host ""

# Cleanup
Remove-Variable PlainPassword -Force
Write-Host "✓ Deployment complete!" -ForegroundColor Green
