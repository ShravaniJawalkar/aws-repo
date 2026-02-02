# Script to create prerequisite AWS resources for SAM deployment
# This script creates:
# 1. SQS Queue: webproject-UploadsNotificationQueue
# 2. SNS Topic: webproject-UploadsNotificationTopic
# 3. S3 Bucket for Lambda deployment artifacts

param(
    [string]$AwsRegion = "ap-south-1",
    [string]$ProjectName = "webproject",
    [string]$S3BucketName = "webproject-sam-deployments-$(Get-Random -Minimum 100000 -Maximum 999999)",
    [string]$AwsProfile = "user-iam-profile"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Creating AWS Resources for SAM Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# First, verify credentials
Write-Host "Verifying AWS credentials..." -ForegroundColor Yellow
try {
    $identity = aws sts get-caller-identity --region $AwsRegion  --profile $AwsProfile | ConvertFrom-Json
    $AccountId = $identity.Account
    Write-Host "✓ AWS Account ID: $AccountId" -ForegroundColor Green
    Write-Host "✓ Region: $AwsRegion" -ForegroundColor Green
} catch {
    Write-Host "✗ Error: AWS credentials not configured" -ForegroundColor Red
    Write-Host "Please run: aws configure" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Creating SQS Queue..." -ForegroundColor Yellow

# Create SQS Queue
$SqsQueueName = "$ProjectName-UploadsNotificationQueue"
try {
    $sqsResult = aws sqs create-queue `
        --queue-name $SqsQueueName `
        --region $AwsRegion  --profile $AwsProfile | ConvertFrom-Json
    
    $SqsQueueUrl = $sqsResult.QueueUrl
    Write-Host "✓ SQS Queue created: $SqsQueueUrl" -ForegroundColor Green
    
    # Get queue ARN
    $SqsAttributes = aws sqs get-queue-attributes `
        --queue-url $SqsQueueUrl `
        --attribute-names QueueArn `
        --region $AwsRegion  --profile $AwsProfile | ConvertFrom-Json
    
    $SqsQueueArn = $SqsAttributes.Attributes.QueueArn
    Write-Host "✓ SQS Queue ARN: $SqsQueueArn" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*QueueAlreadyExists*") {
        Write-Host "! SQS Queue already exists" -ForegroundColor Yellow
        $sqsResult = aws sqs get-queue-url `
            --queue-name $SqsQueueName `
            --region $AwsRegion  --profile $AwsProfile | ConvertFrom-Json
        $SqsQueueUrl = $sqsResult.QueueUrl
        
        $SqsAttributes = aws sqs get-queue-attributes `
            --queue-url $SqsQueueUrl `
            --attribute-names QueueArn `
            --region $AwsRegion  --profile $AwsProfile | ConvertFrom-Json
        
        $SqsQueueArn = $SqsAttributes.Attributes.QueueArn
        Write-Host "✓ Using existing SQS Queue: $SqsQueueUrl" -ForegroundColor Green
    } else {
        Write-Host "✗ Error creating SQS Queue: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Creating SNS Topic..." -ForegroundColor Yellow

# Create SNS Topic
$SnsTopicName = "$ProjectName-UploadsNotificationTopic"
try {
    $snsResult = aws sns create-topic `
        --name $SnsTopicName `
        --region $AwsRegion  --profile $AwsProfile | ConvertFrom-Json
    
    $SnsTopicArn = $snsResult.TopicArn
    Write-Host "✓ SNS Topic created: $SnsTopicArn" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*AlreadyExists*") {
        Write-Host "! SNS Topic already exists" -ForegroundColor Yellow
        $snsTopics = aws sns list-topics --region $AwsRegion  --profile $AwsProfile | ConvertFrom-Json
        $SnsTopicArn = $snsTopics.Topics | Where-Object { $_.TopicArn -like "*$SnsTopicName*" } | Select-Object -ExpandProperty TopicArn
        Write-Host "✓ Using existing SNS Topic: $SnsTopicArn" -ForegroundColor Green
    } else {
        Write-Host "✗ Error creating SNS Topic: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Creating S3 Bucket for Lambda Artifacts..." -ForegroundColor Yellow

# Create S3 Bucket
$FinalBucketName = $S3BucketName.ToLower()
try {
    if ($AwsRegion -eq "us-east-1") {
        aws s3api create-bucket `
            --bucket $FinalBucketName `
            --region $AwsRegion  --profile $AwsProfile
    } else {
        aws s3api create-bucket `
            --bucket $FinalBucketName `
            --region $AwsRegion  --profile $AwsProfile `
            --create-bucket-configuration LocationConstraint=$AwsRegion
    }
    Write-Host "✓ S3 Bucket created: s3://$FinalBucketName" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*BucketAlreadyExists*" -or $_.Exception.Message -like "*BucketAlreadyOwnedByYou*") {
        Write-Host "! S3 Bucket already exists" -ForegroundColor Yellow
        Write-Host "✓ Using S3 Bucket: s3://$FinalBucketName" -ForegroundColor Green
    } else {
        Write-Host "✗ Error creating S3 Bucket: $_" -ForegroundColor Red
        exit 1
    }
}

# Enable versioning on S3 bucket
try {
    aws s3api put-bucket-versioning `
        --bucket $FinalBucketName `
        --versioning-configuration Status=Enabled `
        --region $AwsRegion  --profile $AwsProfile
    Write-Host "✓ S3 Bucket versioning enabled" -ForegroundColor Green
} catch {
    Write-Host "! Warning: Could not enable versioning: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Resource Creation Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "SQS Queue:" -ForegroundColor White
Write-Host "  Name: $SqsQueueName" -ForegroundColor White
Write-Host "  URL:  $SqsQueueUrl" -ForegroundColor White
Write-Host "  ARN:  $SqsQueueArn" -ForegroundColor White
Write-Host ""
Write-Host "SNS Topic:" -ForegroundColor White
Write-Host "  Name: $SnsTopicName" -ForegroundColor White
Write-Host "  ARN:  $SnsTopicArn" -ForegroundColor White
Write-Host ""
Write-Host "S3 Bucket:" -ForegroundColor White
Write-Host "  Name: $FinalBucketName" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. Update samconfig.toml with S3 bucket name:" -ForegroundColor Yellow
Write-Host "   s3_bucket = `"$FinalBucketName`"" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Deploy SAM application:" -ForegroundColor Yellow
Write-Host "   sam deploy -t sam-template.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM" -ForegroundColor Cyan
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
