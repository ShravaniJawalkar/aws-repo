#!/bin/bash

# Quick script to update app on EC2
# Run this via EC2 Instance Connect

cd ~/webapp

# Stop current app
pkill -f "npm start"
sleep 2

# Download updated app
aws s3 cp s3://shravani-jawalkar-webproject-bucket/app-enhanced.js . --region ap-south-1

# Install dependencies again (if needed)
npm install --production

# Set environment variables
export AWS_REGION=ap-south-1
export S3_BUCKET=shravani-jawalkar-webproject-bucket
export SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
export SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic

# Start the app again
nohup npm start > app.log 2>&1 &
sleep 2

echo "✓ App updated and restarted"
ps aux | grep "npm start"
