# Deploy Lambda with Asynchronous Invocation (SQS Trigger)
# This script deploys the Lambda function and configures SQS trigger for notifications

param(
    [string]$ProjectName = "webproject",
    [string]$StackName = "webproject-lambda-notifications",
    [string]$Region = "ap-south-1",
    [string]$Profile = "user-iam-profile",
    [string]$TemplateFile = "lambda-uploads-notification-template.yaml"
)

Write-Host "========================================"
Write-Host "Lambda Async Invocation Deployment"
Write-Host "========================================"
Write-Host ""
Write-Host "Configuration:"
Write-Host "  Project Name: $ProjectName"
Write-Host "  Stack Name: $StackName"
Write-Host "  Region: $Region"
Write-Host "  Profile: $Profile"
Write-Host "  Template: $TemplateFile"
Write-Host ""

# Check if template file exists
if (-not (Test-Path $TemplateFile)) {
    Write-Host "ERROR: Template file not found: $TemplateFile"
    exit 1
}

Write-Host "1. Checking CloudFormation Stack Status..."
Write-Host ""

# Check if stack already exists
try {
    $stackStatus = aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $Region `
        --profile $Profile `
        --output json 2>$null | ConvertFrom-Json

    Write-Host "✓ Stack exists. Status: $($stackStatus.Stacks[0].StackStatus)"
    Write-Host ""
    Write-Host "Stack already exists. Would you like to update it? (y/n)"
    $response = Read-Host
    if ($response -ne "y") {
        Write-Host "Deployment cancelled."
        exit 0
    }
    
    Write-Host ""
    Write-Host "2. Updating CloudFormation Stack..."
    Write-Host ""

    aws cloudformation update-stack `
        --stack-name $StackName `
        --template-body file://$TemplateFile `
        --parameters `
            ParameterKey=ProjectName,ParameterValue=$ProjectName `
            ParameterKey=SQSQueueArn,ParameterValue="arn:aws:sqs:$Region`:908601827639:$ProjectName-UploadsNotificationQueue" `
            ParameterKey=SQSQueueUrl,ParameterValue="https://sqs.$Region`.amazonaws.com/908601827639/$ProjectName-UploadsNotificationQueue" `
            ParameterKey=SNSTopicArn,ParameterValue="arn:aws:sns:$Region`:908601827639:$ProjectName-UploadsNotificationTopic" `
            ParameterKey=LambdaRuntime,ParameterValue=nodejs18.x `
        --capabilities CAPABILITY_NAMED_IAM `
        --region $Region `
        --profile $Profile

    Write-Host "✓ Update initiated"
    Write-Host ""
    
} catch {
    Write-Host "Stack does not exist. Creating new stack..."
    Write-Host ""
    Write-Host "2. Creating CloudFormation Stack..."
    Write-Host ""

    aws cloudformation create-stack `
        --stack-name $StackName `
        --template-body file://$TemplateFile `
        --parameters `
            ParameterKey=ProjectName,ParameterValue=$ProjectName `
            ParameterKey=SQSQueueArn,ParameterValue="arn:aws:sqs:$Region`:908601827639:$ProjectName-UploadsNotificationQueue" `
            ParameterKey=SQSQueueUrl,ParameterValue="https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue" `
            ParameterKey=SNSTopicArn,ParameterValue="arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic" `
            ParameterKey=LambdaRuntime,ParameterValue=nodejs18.x `
        --capabilities CAPABILITY_NAMED_IAM `
        --region $Region `
        --profile $Profile

    Write-Host "✓ Stack creation initiated"
    Write-Host ""
}

Write-Host "3. Waiting for Stack Operation to Complete..."
Write-Host ""

# Wait for stack operation to complete
$maxAttempts = 60
$attempt = 0
$completed = $false

while ($attempt -lt $maxAttempts) {
    try {
        $status = aws cloudformation describe-stacks `
            --stack-name $StackName `
            --region $Region `
            --profile $Profile `
            --query 'Stacks[0].StackStatus' `
            --output text

        Write-Host -NoNewline "`rAttempt $($attempt + 1)/$maxAttempts - Status: $status"
        
        if ($status -match "CREATE_COMPLETE|UPDATE_COMPLETE") {
            Write-Host ""
            Write-Host "✓ Stack operation completed successfully!"
            $completed = $true
            break
        } elseif ($status -match "ROLLBACK|DELETE|FAILED") {
            Write-Host ""
            Write-Host "✗ Stack operation failed. Status: $status"
            exit 1
        }
        
        Start-Sleep -Seconds 5
        $attempt++
    } catch {
        Write-Host "."
        Start-Sleep -Seconds 5
        $attempt++
    }
}

if (-not $completed) {
    Write-Host ""
    Write-Host "✗ Stack operation timed out after $($maxAttempts * 5) seconds"
    exit 1
}

Write-Host ""
Write-Host "4. Retrieving Stack Outputs..."
Write-Host ""

# Get stack outputs
$outputs = aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --profile $Profile `
    --query 'Stacks[0].Outputs' `
    --output json | ConvertFrom-Json

foreach ($output in $outputs) {
    Write-Host "$($output.OutputKey): $($output.OutputValue)"
}

Write-Host ""
Write-Host "5. Verifying Lambda Configuration..."
Write-Host ""

# Get Lambda function info
$lambdaFunction = aws lambda get-function `
    --function-name "$ProjectName-UploadsNotificationFunction" `
    --region $Region `
    --profile $Profile `
    --output json | ConvertFrom-Json

Write-Host "✓ Lambda Function: $($lambdaFunction.Configuration.FunctionName)"
Write-Host "  - ARN: $($lambdaFunction.Configuration.FunctionArn)"
Write-Host "  - Runtime: $($lambdaFunction.Configuration.Runtime)"
Write-Host "  - Memory: $($lambdaFunction.Configuration.MemorySize) MB"
Write-Host "  - Timeout: $($lambdaFunction.Configuration.Timeout) seconds"
Write-Host ""

# Get Event Source Mapping
$eventSourceMapping = aws lambda list-event-source-mappings `
    --function-name "$ProjectName-UploadsNotificationFunction" `
    --region $Region `
    --profile $Profile `
    --output json | ConvertFrom-Json

if ($eventSourceMapping.EventSourceMappings.Count -gt 0) {
    $mapping = $eventSourceMapping.EventSourceMappings[0]
    Write-Host "✓ Event Source Mapping:"
    Write-Host "  - UUID: $($mapping.UUID)"
    Write-Host "  - Source: $($mapping.EventSourceArn)"
    Write-Host "  - State: $($mapping.State)"
    Write-Host "  - Batch Size: $($mapping.BatchSize)"
    Write-Host ""
} else {
    Write-Host "✗ No Event Source Mapping found"
    exit 1
}

Write-Host "6. Summary"
Write-Host ""
Write-Host "✅ Deployment Complete!"
Write-Host ""
Write-Host "Lambda Function: $ProjectName-UploadsNotificationFunction"
Write-Host "SQS Queue: $ProjectName-UploadsNotificationQueue"
Write-Host "SNS Topic: $ProjectName-UploadsNotificationTopic"
Write-Host ""
Write-Host "Next Steps:"
Write-Host "1. Deploy web application to EC2"
Write-Host "2. Subscribe email address via web app /api/subscribe endpoint"
Write-Host "3. Upload images via web app /api/upload endpoint"
Write-Host "4. Verify notification emails are received"
Write-Host ""
Write-Host "For detailed testing steps, see: LAMBDA-ASYNC-DEPLOYMENT-GUIDE.md"
Write-Host ""
Write-Host "========================================"
Write-Host "Deployment Status: SUCCESS"
Write-Host "========================================"
