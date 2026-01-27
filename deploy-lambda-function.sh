#!/bin/bash

# Script to deploy Lambda function for image upload notifications
# This creates the Lambda function with SQS trigger and SNS publishing permissions

set -e

# Configuration
PROJECT_NAME="webproject"
AWS_REGION="ap-south-1"
AWS_ACCOUNT_ID="908601827639"
AWS_PROFILE="user-sns-sqs-profile"

# CloudFormation stack settings
STACK_NAME="${PROJECT_NAME}-uploads-notification-lambda"
TEMPLATE_FILE="lambda-uploads-notification-template.yaml"

# Resource ARNs
SQS_QUEUE_ARN="arn:aws:sqs:${AWS_REGION}:${AWS_ACCOUNT_ID}:${PROJECT_NAME}-UploadsNotificationQueue"
SQS_QUEUE_URL="https://sqs.${AWS_REGION}.amazonaws.com/${AWS_ACCOUNT_ID}/${PROJECT_NAME}-UploadsNotificationQueue"
SNS_TOPIC_ARN="arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:${PROJECT_NAME}-UploadsNotificationTopic"

echo "==================================================================="
echo "Deploying Lambda Function: ${PROJECT_NAME}-UploadsNotificationFunction"
echo "==================================================================="
echo "Stack Name:     ${STACK_NAME}"
echo "Region:         ${AWS_REGION}"
echo "Profile:        ${AWS_PROFILE}"
echo "SQS Queue:      ${SQS_QUEUE_ARN}"
echo "SNS Topic:      ${SNS_TOPIC_ARN}"
echo ""

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "ERROR: Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Deploy or update CloudFormation stack
echo "Step 1: Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file "$TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" \
    --parameter-overrides \
        ProjectName="$PROJECT_NAME" \
        SQSQueueArn="$SQS_QUEUE_ARN" \
        SQSQueueUrl="$SQS_QUEUE_URL" \
        SNSTopicArn="$SNS_TOPIC_ARN" \
    --capabilities CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset

echo ""
echo "Step 2: Waiting for stack to complete..."
aws cloudformation wait stack-create-complete \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" 2>/dev/null || \
aws cloudformation wait stack-update-complete \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" 2>/dev/null || true

echo ""
echo "Step 3: Retrieving Lambda function details..."
LAMBDA_ARN=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" \
    --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionArn`].OutputValue' \
    --output text)

LAMBDA_NAME=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" \
    --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionName`].OutputValue' \
    --output text)

EVENT_MAPPING_ID=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" \
    --query 'Stacks[0].Outputs[?OutputKey==`EventSourceMappingId`].OutputValue' \
    --output text)

echo ""
echo "==================================================================="
echo "✓ Deployment Complete!"
echo "==================================================================="
echo "Lambda Function:"
echo "  Name:   $LAMBDA_NAME"
echo "  ARN:    $LAMBDA_ARN"
echo ""
echo "Event Source Mapping:"
echo "  ID:     $EVENT_MAPPING_ID"
echo "  Status: Check with: aws lambda get-event-source-mapping --uuid $EVENT_MAPPING_ID --region $AWS_REGION --profile $AWS_PROFILE"
echo ""
echo "Next Steps:"
echo "1. Test by uploading an image using the web application"
echo "2. Check SQS queue: aws sqs receive-message --queue-url $SQS_QUEUE_URL --region $AWS_REGION --profile $AWS_PROFILE"
echo "3. Check Lambda logs: aws logs tail /aws/lambda/$LAMBDA_NAME --follow --region $AWS_REGION --profile $AWS_PROFILE"
echo "4. Verify email notifications in your inbox"
echo ""
