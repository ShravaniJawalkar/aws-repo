# Deployment script for Lambda function with SQS trigger
# This script creates the Lambda function and attaches the SQS trigger

$PROJECT_NAME = "webproject"
$AWS_REGION = "ap-south-1"
$AWS_ACCOUNT_ID = "908601827639"
$AWS_PROFILE = "user-iam-profile"

$SQS_QUEUE_ARN = "arn:aws:sqs:$AWS_REGION`:$AWS_ACCOUNT_ID`:$PROJECT_NAME-UploadsNotificationQueue"
$SQS_QUEUE_URL = "https://sqs.$AWS_REGION`.amazonaws.com/$AWS_ACCOUNT_ID/$PROJECT_NAME-UploadsNotificationQueue"
$SNS_TOPIC_ARN = "arn:aws:sns:$AWS_REGION`:$AWS_ACCOUNT_ID`:$PROJECT_NAME-UploadsNotificationTopic"
$LAMBDA_FUNCTION_NAME = "$PROJECT_NAME-UploadsNotificationFunction"
$LAMBDA_ROLE_NAME = "$PROJECT_NAME-UploadsNotificationLambdaRole"

Write-Host "===================================================="
Write-Host "Deploying Lambda Function via AWS CLI"
Write-Host "===================================================="
Write-Host "Function Name: $LAMBDA_FUNCTION_NAME"
Write-Host "Region: $AWS_REGION"
Write-Host "Profile: $AWS_PROFILE"
Write-Host ""

# Step 1: Create IAM Role for Lambda
Write-Host "Step 1: Creating IAM role for Lambda..."
$assume_role_policy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Principal = @{
                Service = "lambda.amazonaws.com"
            }
            Action = "sts:AssumeRole"
        }
    )
} | ConvertTo-Json

try {
    aws iam create-role `
        --role-name $LAMBDA_ROLE_NAME `
        --assume-role-policy-document $assume_role_policy `
        --region $AWS_REGION `
        --profile $AWS_PROFILE | Out-Null
    
    Write-Host "✓ Role created: $LAMBDA_ROLE_NAME"
} catch {
    Write-Host "⚠ Role may already exist, continuing..."
}

Start-Sleep -Seconds 2

# Step 2: Attach SQS read policy to role
Write-Host "Step 2: Attaching SQS read policy..."
$sqs_policy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Action = @(
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "sqs:GetQueueAttributes",
                "sqs:ChangeMessageVisibility"
            )
            Resource = $SQS_QUEUE_ARN
        }
    )
} | ConvertTo-Json

aws iam put-role-policy `
    --role-name $LAMBDA_ROLE_NAME `
    --policy-name "$PROJECT_NAME-lambda-sqs-policy" `
    --policy-document $sqs_policy `
    --region $AWS_REGION `
    --profile $AWS_PROFILE

Write-Host "✓ SQS policy attached"

# Step 3: Attach SNS publish policy to role
Write-Host "Step 3: Attaching SNS publish policy..."
$sns_policy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Action = "sns:Publish"
            Resource = $SNS_TOPIC_ARN
        }
    )
} | ConvertTo-Json

aws iam put-role-policy `
    --role-name $LAMBDA_ROLE_NAME `
    --policy-name "$PROJECT_NAME-lambda-sns-policy" `
    --policy-document $sns_policy `
    --region $AWS_REGION `
    --profile $AWS_PROFILE

Write-Host "✓ SNS policy attached"

# Step 4: Attach basic Lambda execution policy
Write-Host "Step 4: Attaching basic Lambda execution policy..."
aws iam attach-role-policy `
    --role-name $LAMBDA_ROLE_NAME `
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole `
    --region $AWS_REGION `
    --profile $AWS_PROFILE

Write-Host "✓ Basic execution policy attached"

Start-Sleep -Seconds 3

# Step 5: Get the role ARN
Write-Host "Step 5: Getting role ARN..."
$role_arn = aws iam get-role `
    --role-name $LAMBDA_ROLE_NAME `
    --region $AWS_REGION `
    --profile $AWS_PROFILE `
    --query 'Role.Arn' `
    --output text

Write-Host "Role ARN: $role_arn"

# Step 6: Create Lambda function
Write-Host "Step 6: Creating Lambda function..."

$lambda_code = 'const AWS = require("aws-sdk");
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
};'

# Create a ZIP file with the Lambda code
$temp_dir = (New-TemporaryFile).DirectoryName | Split-Path
$zip_file = "$temp_dir\lambda-function.zip"
$js_file = "$temp_dir\index.js"

$lambda_code | Out-File -FilePath $js_file -Encoding UTF8

# Create package.json
$packageJsonFile = Join-Path $temp_dir "package.json"
$package_json = @{
    "name" = "webproject-uploads-notification"
    "version" = "1.0.0"
    "description" = "Lambda function for image upload notifications"
} | ConvertTo-Json | Out-File -FilePath $packageJsonFile -Encoding UTF8

# Create ZIP
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($temp_dir, $zip_file, [System.IO.Compression.CompressionLevel]::Optimal, $false)

Write-Host "Lambda code prepared in: $zip_file"

# Create Lambda function
aws lambda create-function `
    --function-name $LAMBDA_FUNCTION_NAME `
    --runtime nodejs18.x `
    --role $role_arn `
    --handler index.handler `
    --timeout 60 `
    --memory-size 256 `
    --environment "Variables={SNS_TOPIC_ARN=$SNS_TOPIC_ARN}" `
    --zip-file fileb://$zip_file `
    --region $AWS_REGION `
    --profile $AWS_PROFILE

Write-Host "✓ Lambda function created: $LAMBDA_FUNCTION_NAME"

Start-Sleep -Seconds 5

# Step 7: Create SQS Event Source Mapping
Write-Host "Step 7: Creating SQS event source mapping..."
$mapping_response = aws lambda create-event-source-mapping `
    --event-source-arn $SQS_QUEUE_ARN `
    --function-name $LAMBDA_FUNCTION_NAME `
    --enabled `
    --batch-size 10 `
    --maximum-batching-window-in-seconds 5 `
    --function-response-types ReportBatchItemFailures `
    --region $AWS_REGION `
    --profile $AWS_PROFILE `
    | ConvertFrom-Json

$mapping_uuid = $mapping_response.UUID
Write-Host "✓ Event source mapping created: $mapping_uuid"

Write-Host ""
Write-Host "===================================================="
Write-Host "✓ Deployment Complete!"
Write-Host "===================================================="
Write-Host "Lambda Function:  $LAMBDA_FUNCTION_NAME"
Write-Host "Lambda Role:      $LAMBDA_ROLE_NAME"
Write-Host "SQS Queue:        $SQS_QUEUE_URL"
Write-Host "SNS Topic:        $SNS_TOPIC_ARN"
Write-Host "Event Mapping:    $mapping_uuid"
Write-Host ""
Write-Host "Next Steps:"
Write-Host "1. Test by uploading an image using the web application"
Write-Host "2. Check Lambda logs: aws logs tail /aws/lambda/$LAMBDA_FUNCTION_NAME --follow --region $AWS_REGION --profile $AWS_PROFILE"
Write-Host "3. Verify email notifications in your inbox"
Write-Host ""

# Cleanup
$packageJsonPath = Join-Path $temp_dir "package.json"
Remove-Item -Path $js_file, $packageJsonPath, $zip_file -Force -ErrorAction SilentlyContinue
