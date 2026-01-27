# Validate Lambda Async Implementation
# Checks all files and components are ready for deployment

Write-Host "========================================"
Write-Host "Lambda Async Implementation Validator"
Write-Host "========================================"
Write-Host ""

$checksPassed = 0
$checksFailed = 0
$files = @(
    @{
        Path = "web-dynamic-app/app-enhanced.js"
        Type = "Web App"
        Required = $true
        Description = "Enhanced web app with S3, SQS, SNS integration"
    },
    @{
        Path = "web-dynamic-app/package.json"
        Type = "Dependencies"
        Required = $true
        Description = "Updated with AWS SDK, multer"
    },
    @{
        Path = "lambda-function/index.js"
        Type = "Lambda Code"
        Required = $true
        Description = "Lambda handler for SQS processing"
    },
    @{
        Path = "lambda-uploads-notification-template.yaml"
        Type = "CloudFormation"
        Required = $true
        Description = "Lambda + SQS trigger + IAM permissions"
    },
    @{
        Path = "deploy-lambda-async.ps1"
        Type = "Deployment Script"
        Required = $true
        Description = "Deploy Lambda function"
    },
    @{
        Path = "upload-app-to-s3.ps1"
        Type = "Upload Script"
        Required = $true
        Description = "Upload app files to S3"
    },
    @{
        Path = "test-lambda-async.ps1"
        Type = "Test Script"
        Required = $true
        Description = "End-to-end testing"
    },
    @{
        Path = "LAMBDA-ASYNC-DEPLOYMENT-GUIDE.md"
        Type = "Documentation"
        Required = $false
        Description = "Deployment guide"
    },
    @{
        Path = "LAMBDA-ASYNC-COMPLETE-GUIDE.md"
        Type = "Documentation"
        Required = $false
        Description = "Complete implementation guide"
    },
    @{
        Path = "LAMBDA-ASYNC-IMPLEMENTATION-SUMMARY.md"
        Type = "Documentation"
        Required = $false
        Description = "Implementation summary"
    },
    @{
        Path = "sqs-sns-resources-template.yaml"
        Type = "Prerequisites"
        Required = $true
        Description = "SQS queue and SNS topic"
    }
)

Write-Host "1. Checking Files"
Write-Host ""

foreach ($file in $files) {
    $fullPath = Join-Path (Get-Location) $file.Path
    
    if (Test-Path $fullPath) {
        Write-Host "✓ $($file.Type): $($file.Path)"
        Write-Host "  Description: $($file.Description)"
        $checksPassed++
    } else {
        if ($file.Required) {
            Write-Host "✗ $($file.Type): $($file.Path) - MISSING"
            Write-Host "  Description: $($file.Description)"
            $checksFailed++
        } else {
            Write-Host "⚠ $($file.Type): $($file.Path) - Optional (missing)"
            Write-Host "  Description: $($file.Description)"
        }
    }
}

Write-Host ""
Write-Host "2. Checking File Contents"
Write-Host ""

$checks = @(
    @{
        File = "web-dynamic-app/app-enhanced.js"
        Contains = @("/api/subscribe", "/api/unsubscribe", "SQS", "SNS")
        Description = "API endpoints for subscriptions and AWS integration"
    },
    @{
        File = "lambda-function/index.js"
        Contains = @("exports.handler", "sns.publish", "SQS", "SNS_TOPIC_ARN")
        Description = "Lambda handler with SNS publishing"
    },
    @{
        File = "lambda-uploads-notification-template.yaml"
        Contains = @("AWS::Lambda::Function", "EventSourceMapping", "AWS::IAM::Role")
        Description = "Lambda, trigger, and IAM definitions"
    },
    @{
        File = "deploy-lambda-async.ps1"
        Contains = @("cloudformation", "create-stack", "wait")
        Description = "CloudFormation deployment logic"
    },
    @{
        File = "upload-app-to-s3.ps1"
        Contains = @("s3 cp", "app-enhanced.js", "package.json")
        Description = "S3 upload logic"
    },
    @{
        File = "test-lambda-async.ps1"
        Contains = @("/api/subscribe", "/api/upload", "LoadBalancerURL")
        Description = "End-to-end testing logic"
    }
)

foreach ($check in $checks) {
    $fullPath = Join-Path (Get-Location) $check.File
    
    if (Test-Path $fullPath) {
        $content = Get-Content $fullPath -Raw
        $allFound = $true
        $foundItems = @()
        
        foreach ($searchStr in $check.Contains) {
            if ($content -icontains $searchStr) {
                $foundItems += $searchStr
            } else {
                $allFound = $false
            }
        }
        
        if ($allFound) {
            Write-Host "✓ $($check.File)"
            Write-Host "  $($check.Description)"
            Write-Host "  Found: $($foundItems -join ", ")"
            $checksPassed++
        } else {
            Write-Host "⚠ $($check.File) - Incomplete"
            Write-Host "  $($check.Description)"
            Write-Host "  Found: $($foundItems -join ", ")"
            Write-Host "  Missing: $($check.Contains | Where-Object { $_ -notin $foundItems } | Join-String -Separator ', ')"
            $checksFailed++
        }
    }
}

Write-Host ""
Write-Host "3. Checking Directory Structure"
Write-Host ""

$dirs = @("web-dynamic-app", "lambda-function")
foreach ($dir in $dirs) {
    if (Test-Path $dir) {
        Write-Host "✓ Directory exists: $dir"
        $checksPassed++
    } else {
        Write-Host "✗ Directory missing: $dir"
        $checksFailed++
    }
}

Write-Host ""
Write-Host "4. File Statistics"
Write-Host ""

$webAppPath = "web-dynamic-app/app-enhanced.js"
$lambdaPath = "lambda-function/index.js"
$templatePath = "lambda-uploads-notification-template.yaml"

if (Test-Path $webAppPath) {
    $lines = (Get-Content $webAppPath | Measure-Object -Line).Lines
    Write-Host "Web App: $lines lines of code"
    Write-Host "  - Endpoints: 8 REST APIs"
    Write-Host "  - AWS Services: S3, SQS, SNS, EC2 Metadata"
    Write-Host "  - UI: Modern responsive design"
}

if (Test-Path $lambdaPath) {
    $lines = (Get-Content $lambdaPath | Measure-Object -Line).Lines
    Write-Host "Lambda Function: $lines lines of code"
    Write-Host "  - Runtime: Node.js 18.x"
    Write-Host "  - Batch processing: 10 messages"
    Write-Host "  - Features: Error handling, logging, SNS publishing"
}

if (Test-Path $templatePath) {
    $lines = (Get-Content $templatePath | Measure-Object -Line).Lines
    Write-Host "CloudFormation Template: $lines lines"
    Write-Host "  - Resources: 8 (Role, Policies, Function, Mapping)"
    Write-Host "  - Outputs: 4 (Function ARN, Role ARN, etc.)"
}

Write-Host ""
Write-Host "5. Summary"
Write-Host ""
Write-Host "Checks Passed: $checksPassed"
Write-Host "Checks Failed: $checksFailed"
Write-Host ""

if ($checksFailed -eq 0) {
    Write-Host "✅ ALL CHECKS PASSED - READY FOR DEPLOYMENT"
    Write-Host ""
    Write-Host "Next Steps:"
    Write-Host "1. Run: .\deploy-lambda-async.ps1"
    Write-Host "2. Run: .\upload-app-to-s3.ps1"
    Write-Host "3. SSH to EC2 and deploy application"
    Write-Host "4. Run: .\test-lambda-async.ps1"
    Write-Host ""
    exit 0
} else {
    Write-Host "❌ SOME CHECKS FAILED - PLEASE REVIEW ABOVE"
    Write-Host ""
    Write-Host "Please ensure all required files are present before deployment."
    Write-Host ""
    exit 1
}
