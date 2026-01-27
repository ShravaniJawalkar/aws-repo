# Upload Web Application to S3 for EC2 Deployment
# This script uploads the enhanced web app files to S3 bucket

param(
    [string]$AppDir = "web-dynamic-app",
    [string]$BucketName = "shravani-jawalkar-webproject-bucket",
    [string]$Region = "ap-south-1",
    [string]$Profile = "user-iam-profile"
)

Write-Host "========================================"
Write-Host "Web Application S3 Upload"
Write-Host "========================================"
Write-Host ""
Write-Host "Configuration:"
Write-Host "  App Directory: $AppDir"
Write-Host "  S3 Bucket: $BucketName"
Write-Host "  Region: $Region"
Write-Host "  Profile: $Profile"
Write-Host ""

# Check if app directory exists
if (-not (Test-Path $AppDir)) {
    Write-Host "ERROR: App directory not found: $AppDir"
    exit 1
}

# Check if bucket exists
Write-Host "1. Checking S3 Bucket..."
Write-Host ""

try {
    $bucketExists = aws s3 ls "s3://$BucketName" `
        --region $Region `
        --profile $Profile `
        2>$null

    Write-Host "✓ S3 Bucket exists: $BucketName"
    Write-Host ""
} catch {
    Write-Host "✗ S3 Bucket not found or access denied: $BucketName"
    exit 1
}

Write-Host "2. Uploading Application Files..."
Write-Host ""

# Files to upload
$files = @(
    "package.json",
    "app-enhanced.js",
    "app.js"
)

$uploadedCount = 0
$failedCount = 0

foreach ($file in $files) {
    $filePath = Join-Path $AppDir $file
    
    if (-not (Test-Path $filePath)) {
        Write-Host "⚠ File not found (skipping): $file"
        continue
    }
    
    try {
        Write-Host "Uploading $file..."
        
        aws s3 cp $filePath "s3://$BucketName/$file" `
            --region $Region `
            --profile $Profile `
            --quiet
        
        Write-Host "  ✓ Uploaded"
        $uploadedCount++
    } catch {
        Write-Host "  ✗ Failed to upload"
        $failedCount++
    }
}

Write-Host ""
Write-Host "3. Verifying Uploads..."
Write-Host ""

# List uploaded files
$s3Files = aws s3 ls "s3://$BucketName/" `
    --region $Region `
    --profile $Profile | Select-String "(package.json|app.*js)"

if ($s3Files) {
    Write-Host "✓ Uploaded files:"
    $s3Files | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "✗ No files found in S3 bucket"
    exit 1
}

Write-Host ""
Write-Host "4. Summary"
Write-Host ""

if ($uploadedCount -gt 0) {
    Write-Host "✅ Upload Complete!"
    Write-Host "  Files uploaded: $uploadedCount"
    if ($failedCount -gt 0) {
        Write-Host "  Files failed: $failedCount"
    }
    Write-Host ""
    Write-Host "Next Steps:"
    Write-Host "1. SSH to EC2 instance"
    Write-Host "2. Create application directory: mkdir -p ~/webapp && cd ~/webapp"
    Write-Host "3. Download from S3: aws s3 cp s3://$BucketName/app-enhanced.js ."
    Write-Host "4. Download from S3: aws s3 cp s3://$BucketName/package.json ."
    Write-Host "5. Install dependencies: npm install"
    Write-Host "6. Set environment variables:"
    Write-Host "   export AWS_REGION=$Region"
    Write-Host "   export S3_BUCKET=$BucketName"
    Write-Host "   export SQS_QUEUE_URL=https://sqs.$Region.amazonaws.com/908601827639/webproject-UploadsNotificationQueue"
    Write-Host "   export SNS_TOPIC_ARN=arn:aws:sns:$Region:908601827639:webproject-UploadsNotificationTopic"
    Write-Host "7. Start application: npm start"
    Write-Host ""
    Write-Host "========================================"
    Write-Host "Upload Status: SUCCESS"
    Write-Host "========================================"
} else {
    Write-Host "✗ No files were uploaded"
    exit 1
}
