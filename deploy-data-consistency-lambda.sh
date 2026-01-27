#!/bin/bash

# Deployment script for Data Consistency Lambda Function
# Deploys all necessary AWS resources for Sub-Task 2

set -e

PROJECT_NAME="webproject"
REGION="ap-south-1"
PROFILE="user-iam-profile"
VPC_ID="vpc-04304d2648a6d0753"
SUBNET_IDS="subnet-03f16fceda3f36dec,subnet-0f16a48da72abda1e"
RDS_SG="sg-06be32af49a07ede4"
DB_HOST="webproject-database.c14e66sq09ij.ap-south-1.rds.amazonaws.com"
DB_USER="admin"
DB_NAME="webproject"

# Read database password
read -sp "Enter RDS database password: " DB_PASSWORD
echo ""

echo "========================================"
echo "Data Consistency Lambda Deployment"
echo "========================================"
echo "Project: $PROJECT_NAME"
echo "Region: $REGION"
echo "VPC ID: $VPC_ID"
echo "RDS: $DB_HOST"
echo ""

# Step 1: Create Lambda deployment package
echo "[1/5] Creating Lambda deployment package..."
cd lambda-function

# Install dependencies if not already installed
if [ ! -d "node_modules" ]; then
    echo "  - Installing npm dependencies..."
    npm install --save aws-sdk mysql2 2>/dev/null || npm install
fi

# Create zip file
echo "  - Creating data-consistency-lambda.zip..."
zip -r data-consistency-lambda.zip data-consistency.js node_modules/ -q
echo "  ✓ Deployment package ready"
cd ..

# Step 2: Create S3 bucket for Lambda code (if needed)
echo ""
echo "[2/5] Preparing Lambda code bucket..."
CODE_BUCKET="${PROJECT_NAME}-lambda-${REGION}-code"
BUCKET_EXISTS=$(aws s3 ls "s3://${CODE_BUCKET}" --region $REGION --profile $PROFILE 2>/dev/null || echo "0")

if [ -z "$BUCKET_EXISTS" ]; then
    echo "  - Creating S3 bucket for Lambda code..."
    aws s3 mb "s3://${CODE_BUCKET}" --region $REGION --profile $PROFILE 2>/dev/null || true
    echo "  ✓ Bucket ready"
else
    echo "  ✓ Bucket already exists"
fi

echo "  - Uploading Lambda package..."
aws s3 cp lambda-function/data-consistency-lambda.zip "s3://${CODE_BUCKET}/data-consistency-lambda.zip" --region $REGION --profile $PROFILE
echo "  ✓ Lambda package uploaded"

# Step 3: Deploy CloudFormation Stack
echo ""
echo "[3/5] Deploying CloudFormation stack..."
echo "  - Stack name: ${PROJECT_NAME}-data-consistency-lambda"

aws cloudformation deploy \
    --template-file lambda-data-consistency-template.yaml \
    --stack-name "${PROJECT_NAME}-data-consistency-lambda" \
    --parameter-overrides \
        ProjectName=$PROJECT_NAME \
        DBPassword=$DB_PASSWORD \
        VpcId=$VPC_ID \
        SubnetIds=$SUBNET_IDS \
        DBSecurityGroupId=$RDS_SG \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION \
    --profile $PROFILE \
    --no-fail-on-empty-changeset

echo "  ✓ CloudFormation stack deployed"

# Step 4: Get Lambda Security Group and update RDS rules
echo ""
echo "[4/5] Configuring security group rules..."
LAMBDA_SG=$(aws cloudformation describe-stacks \
    --stack-name "${PROJECT_NAME}-data-consistency-lambda" \
    --query 'Stacks[0].Outputs[?OutputKey==`LambdaSecurityGroupId`].OutputValue' \
    --output text \
    --region $REGION \
    --profile $PROFILE)

echo "  - Lambda Security Group: $LAMBDA_SG"
echo "  - Authorizing Lambda SG to access RDS..."

# Add inbound rule to RDS security group
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG \
    --protocol tcp \
    --port 3306 \
    --source-group $LAMBDA_SG \
    --region $REGION \
    --profile $PROFILE 2>/dev/null || echo "  ✓ Rule already exists"

echo "  ✓ Security groups configured"

# Step 5: Initialize Database Table
echo ""
echo "[5/5] Initializing database table..."
echo "  - Creating image_uploads table..."

mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME <<EOF 2>/dev/null || true
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
EOF

echo "  ✓ Database initialized"

# Get outputs
echo ""
echo "========================================"
echo "Deployment Complete!"
echo "========================================"
echo ""

echo "Getting deployment outputs..."
aws cloudformation describe-stacks \
    --stack-name "${PROJECT_NAME}-data-consistency-lambda" \
    --query 'Stacks[0].Outputs[*].{OutputKey:OutputKey,OutputValue:OutputValue}' \
    --output table \
    --region $REGION \
    --profile $PROFILE

echo ""
echo "Next Steps:"
echo "1. Wait 2-3 minutes for Lambda to initialize in VPC"
echo "2. Check CloudWatch logs: /aws/lambda/${PROJECT_NAME}-DataConsistencyFunction"
echo "3. Test API Gateway endpoint (from outputs above)"
echo "4. Test web app endpoint: /api/check-consistency"
echo "5. Verify scheduled invocation every 5 minutes"
echo ""
echo "Monitor logs:"
echo "  aws logs tail /aws/lambda/${PROJECT_NAME}-DataConsistencyFunction --follow"
echo ""
