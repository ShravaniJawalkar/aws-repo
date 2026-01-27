# Deploy Lambda function via AWS CLI for image upload notifications

$PROJECT_NAME = "webproject"
$AWS_REGION = "ap-south-1"
$AWS_ACCOUNT_ID = "908601827639"
$AWS_PROFILE = "user-iam-profile"

$SQS_QUEUE_ARN = "arn:aws:sqs:${AWS_REGION}:${AWS_ACCOUNT_ID}:${PROJECT_NAME}-UploadsNotificationQueue"
$SQS_QUEUE_URL = "https://sqs.${AWS_REGION}.amazonaws.com/${AWS_ACCOUNT_ID}/${PROJECT_NAME}-UploadsNotificationQueue"
$SNS_TOPIC_ARN = "arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:${PROJECT_NAME}-UploadsNotificationTopic"
$LAMBDA_FUNCTION_NAME = "${PROJECT_NAME}-UploadsNotificationFunction"
$LAMBDA_ROLE_NAME = "${PROJECT_NAME}-UploadsNotificationLambdaRole"

Write-Host "===== Deploying Lambda Function ====="
Write-Host "Function: $LAMBDA_FUNCTION_NAME"
Write-Host "Region: $AWS_REGION"
Write-Host ""

# Step 1: Create IAM Role
Write-Host "[1] Creating IAM role..."
$asumePolicyContent = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@

$asumePolicyFile = "$env:TEMP\assume-role-policy.json"
$asumePolicyContent | Out-File -FilePath $asumePolicyFile -Encoding UTF8

try {
    aws iam create-role --role-name $LAMBDA_ROLE_NAME --assume-role-policy-document file://$asumePolicyFile --region $AWS_REGION --profile $AWS_PROFILE 2>&1 | Out-Null
    Write-Host "OK: Role created"
} catch {
    Write-Host "Note: Role may already exist"
}

Start-Sleep -Seconds 2

# Step 2: Attach SQS Policy
Write-Host "[2] Attaching SQS policy..."
$sqsPolicyContent = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility"
      ],
      "Resource": "$SQS_QUEUE_ARN"
    }
  ]
}
"@

$sqsPolicyFile = "$env:TEMP\sqs-policy.json"
$sqsPolicyContent | Out-File -FilePath $sqsPolicyFile -Encoding UTF8

aws iam put-role-policy --role-name $LAMBDA_ROLE_NAME --policy-name "${PROJECT_NAME}-lambda-sqs-policy" --policy-document file://$sqsPolicyFile --region $AWS_REGION --profile $AWS_PROFILE
Write-Host "OK: SQS policy attached"

# Step 3: Attach SNS Policy
Write-Host "[3] Attaching SNS policy..."
$snsPolicyContent = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sns:Publish",
      "Resource": "$SNS_TOPIC_ARN"
    }
  ]
}
"@

$snsPolicyFile = "$env:TEMP\sns-policy.json"
$snsPolicyContent | Out-File -FilePath $snsPolicyFile -Encoding UTF8

aws iam put-role-policy --role-name $LAMBDA_ROLE_NAME --policy-name "${PROJECT_NAME}-lambda-sns-policy" --policy-document file://$snsPolicyFile --region $AWS_REGION --profile $AWS_PROFILE
Write-Host "OK: SNS policy attached"

# Step 4: Attach Basic Lambda Execution Policy
Write-Host "[4] Attaching basic execution policy..."
aws iam attach-role-policy --role-name $LAMBDA_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole --region $AWS_REGION --profile $AWS_PROFILE
Write-Host "OK: Basic execution policy attached"

Start-Sleep -Seconds 3

# Step 5: Get Role ARN
Write-Host "[5] Getting role ARN..."
$role_arn = aws iam get-role --role-name $LAMBDA_ROLE_NAME --region $AWS_REGION --profile $AWS_PROFILE --query 'Role.Arn' --output text
Write-Host "Role ARN: $role_arn"

# Step 6: Create Lambda Function
Write-Host "[6] Creating Lambda function..."

$lambdaCodeContent = @'
const AWS = require("aws-sdk");
const sns = new AWS.SNS({ region: "ap-south-1" });
const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN;

exports.handler = async (event, context) => {
  console.log("Received event:", JSON.stringify(event, null, 2));
  const results = { successCount: 0, failureCount: 0, processedMessages: [] };

  if (!event.Records || event.Records.length === 0) {
    return { statusCode: 200, body: JSON.stringify({ message: "No records", results }) };
  }

  for (const record of event.Records) {
    try {
      console.log(`Processing Message ID: ${record.messageId}`);
      let uploadEvent = JSON.parse(record.body);
      if (!uploadEvent || !uploadEvent.fileName) throw new Error("Invalid upload event");
      
      const fileExtension = uploadEvent.fileExtension || ".unknown";
      const fileSize = uploadEvent.fileSize || 0;
      const fileSizeMB = (fileSize / (1024 * 1024)).toFixed(2);
      
      const notificationMessage = `Image Upload Notification\n==========================\n\nFile Name:     ${uploadEvent.fileName}\nFile Size:     ${fileSizeMB} MB\nExtension:     ${fileExtension}\nDescription:   ${uploadEvent.description || "No description"}\nUploaded By:   ${uploadEvent.uploadedBy || "System"}\nTimestamp:     ${uploadEvent.timestamp || new Date().toISOString()}\nEvent ID:      ${uploadEvent.eventId || "N/A"}\n\nThis is an automated notification from your Image Upload Service.`;
      
      console.log(`Publishing notification for: ${uploadEvent.fileName}`);
      const publishResult = await sns.publish({
        TopicArn: SNS_TOPIC_ARN,
        Subject: `Image Upload Notification: ${uploadEvent.fileName}`,
        Message: notificationMessage,
        MessageAttributes: {
          ImageExtension: { StringValue: fileExtension, DataType: "String" },
          FileSize: { StringValue: fileSize.toString(), DataType: "Number" },
          EventType: { StringValue: "ImageUpload", DataType: "String" }
        }
      }).promise();
      
      results.successCount++;
      results.processedMessages.push({
        messageId: record.messageId,
        status: "success",
        snsMessageId: publishResult.MessageId,
        fileName: uploadEvent.fileName
      });
    } catch (error) {
      console.error(`Error: ${error.message}`);
      results.failureCount++;
      results.processedMessages.push({
        messageId: record.messageId,
        status: "failed",
        reason: error.message
      });
      throw error;
    }
  }

  return {
    statusCode: results.failureCount === 0 ? 200 : 207,
    body: JSON.stringify({ message: `Processed ${event.Records.length} messages`, results })
  };
};
'@

$tempDir = $env:TEMP
$jsFile = "$tempDir\index.js"
$lambdaCodeContent | Out-File -FilePath $jsFile -Encoding UTF8

$packageJsonContent = @"
{
  "name": "webproject-uploads-notification",
  "version": "1.0.0",
  "description": "Lambda function for image upload notifications"
}
"@

$packageJsonFile = "$tempDir\package.json"
$packageJsonContent | Out-File -FilePath $packageJsonFile -Encoding UTF8

# Create ZIP file
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipFile = "$tempDir\lambda-function.zip"
if (Test-Path $zipFile) { Remove-Item $zipFile }
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipFile, [System.IO.Compression.CompressionLevel]::Optimal, $false)

Write-Host "Lambda code prepared: $zipFile"

# Check if function already exists
$functionExists = aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --region $AWS_REGION --profile $AWS_PROFILE 2>&1 | Select-String "ResourceNotFoundException"

if ($functionExists) {
    # Create Lambda function
    aws lambda create-function --function-name $LAMBDA_FUNCTION_NAME --runtime nodejs18.x --role $role_arn --handler index.handler --timeout 60 --memory-size 256 --environment "Variables={SNS_TOPIC_ARN=$SNS_TOPIC_ARN}" --zip-file fileb://$zipFile --region $AWS_REGION --profile $AWS_PROFILE
    Write-Host "OK: Lambda function created"
} else {
    # Update existing function
    aws lambda update-function-code --function-name $LAMBDA_FUNCTION_NAME --zip-file fileb://$zipFile --region $AWS_REGION --profile $AWS_PROFILE
    Write-Host "OK: Lambda function updated"
}

Start-Sleep -Seconds 5

# Step 7: Create Event Source Mapping
Write-Host "[7] Creating SQS event source mapping..."
$mappingJson = aws lambda create-event-source-mapping --event-source-arn $SQS_QUEUE_ARN --function-name $LAMBDA_FUNCTION_NAME --enabled --batch-size 10 --maximum-batching-window-in-seconds 5 --function-response-types ReportBatchItemFailures --region $AWS_REGION --profile $AWS_PROFILE 2>&1

if ($mappingJson -match "EventSourceMappingArn") {
    $mapping = $mappingJson | ConvertFrom-Json
    $mapping_uuid = $mapping.UUID
    Write-Host "OK: Event source mapping created: $mapping_uuid"
} else {
    Write-Host "Note: Event source mapping may already exist or failed"
    Write-Host "Response: $mappingJson"
}

Write-Host ""
Write-Host "===== Deployment Complete ====="
Write-Host "Function: $LAMBDA_FUNCTION_NAME"
Write-Host "Role: $LAMBDA_ROLE_NAME"
Write-Host "SQS Queue: $SQS_QUEUE_URL"
Write-Host "SNS Topic: $SNS_TOPIC_ARN"
Write-Host ""
Write-Host "Next: Upload images to test!"
