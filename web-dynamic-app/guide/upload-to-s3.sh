#!/bin/bash
# Deploy web application to S3 bucket

# Configuration
S3_BUCKET="shravani-jawalkar-webproject-bucket"
AWS_REGION="ap-south-1"
PROFILE="user-iam-profile"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Web Application S3 Upload Script"
echo "========================================"
echo "Bucket: $S3_BUCKET"
echo "Region: $AWS_REGION"
echo "Profile: $PROFILE"
echo "App Dir: $APP_DIR"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed"
    exit 1
fi

# Verify S3 bucket exists
echo "Checking S3 bucket..."
if ! aws s3 ls "s3://$S3_BUCKET" --region "$AWS_REGION" --profile "$PROFILE" 2>&1 | grep -q "NoSuchBucket\|AccessDenied"; then
    echo "✓ S3 bucket exists"
else
    echo "✗ S3 bucket not found or access denied"
    exit 1
fi

# Upload application files
echo ""
echo "Uploading application files..."

# Upload package.json
echo -n "Uploading package.json... "
if aws s3 cp "$APP_DIR/package.json" "s3://$S3_BUCKET/" --region "$AWS_REGION" --profile "$PROFILE" > /dev/null 2>&1; then
    echo "✓"
else
    echo "✗"
    exit 1
fi

# Upload app-s3-enhanced.js
echo -n "Uploading app-s3-enhanced.js... "
if aws s3 cp "$APP_DIR/app-s3-enhanced.js" "s3://$S3_BUCKET/" --region "$AWS_REGION" --profile "$PROFILE" > /dev/null 2>&1; then
    echo "✓"
else
    echo "✗"
    exit 1
fi

# Upload original app.js for reference
echo -n "Uploading app.js... "
if aws s3 cp "$APP_DIR/app.js" "s3://$S3_BUCKET/" --region "$AWS_REGION" --profile "$PROFILE" > /dev/null 2>&1; then
    echo "✓"
else
    echo "✗"
    exit 1
fi

# List uploaded files
echo ""
echo "Uploaded files:"
aws s3 ls "s3://$S3_BUCKET/" --region "$AWS_REGION" --profile "$PROFILE" | grep -E "package.json|app.*js"

echo ""
echo "========================================"
echo "✓ Application uploaded successfully!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Launch EC2 instances using CloudFormation"
echo "2. SSH to EC2 instance"
echo "3. Run the deployment commands from DEPLOYMENT_GUIDE.md"
echo ""
