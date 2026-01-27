#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Testing script for SQS/SNS subscription feature
.DESCRIPTION
    Provides various test cases for the subscription feature implementation
.PARAMETER BaseUrl
    Base URL of the web application (default: http://localhost:8080)
#>

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$TestEmail = "test-$(Get-Date -Format 'yyyyMMddHHmmss')@example.com"
)

# Colors for output
$SuccessColor = "Green"
$ErrorColor = "Red"
$InfoColor = "Cyan"
$WarningColor = "Yellow"

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $SuccessColor
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $ErrorColor
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor $InfoColor
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $WarningColor
}

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Uri,
        [string]$Method = "GET",
        [hashtable]$Body = $null
    )
    
    Write-Host ""
    Write-Info "Testing: $Name"
    Write-Info "  URL: $Method $Uri"
    
    try {
        $params = @{
            Uri = $Uri
            Method = $Method
            ContentType = "application/json"
            ErrorAction = "Stop"
        }
        
        if ($Body) {
            $params.Body = $Body | ConvertTo-Json
        }
        
        $response = Invoke-WebRequest @params
        $content = $response.Content | ConvertFrom-Json
        
        Write-Success "Response received (Status: $($response.StatusCode))"
        Write-Info "  Response: $($content | ConvertTo-Json -Depth 2 | Out-String)"
        
        return $content
    }
    catch {
        Write-Error "Request failed: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorBody = $streamReader.ReadToEnd()
            Write-Info "  Error Details: $errorBody"
        }
        return $null
    }
}

# =====================================================================
# START TESTING
# =====================================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor $InfoColor
Write-Host "SQS/SNS Subscription Feature - Test Suite" -ForegroundColor $InfoColor
Write-Host "========================================================" -ForegroundColor $InfoColor
Write-Host ""

Write-Info "Base URL: $BaseUrl"
Write-Info "Test Email: $TestEmail"
Write-Info "Test Start Time: $(Get-Date)"
Write-Host ""

# Test 1: Health Check
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $InfoColor
Write-Info "[Test 1/9] Health Check"
$healthResponse = Test-Endpoint -Name "Health Check" -Uri "$BaseUrl/health"

if ($healthResponse) {
    Write-Success "Application is healthy"
} else {
    Write-Error "Application health check failed. Aborting tests."
    exit 1
}

# Test 2: Get Initial Queue Status
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $InfoColor
Write-Info "[Test 2/9] Get Initial Queue Status"
$queueStatusBefore = Test-Endpoint -Name "Queue Status" -Uri "$BaseUrl/admin/queue-status"

if ($queueStatusBefore) {
    Write-Success "Queue has $($queueStatusBefore.messages.available) messages"
}

# Test 3: List Current Subscriptions
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $InfoColor
Write-Info "[Test 3/9] List Current Subscriptions"
$subscriptions = Test-Endpoint -Name "List Subscriptions" -Uri "$BaseUrl/api/subscriptions"

if ($subscriptions) {
    Write-Success "Found $($subscriptions.count) active subscriptions"
}

# Test 4: Subscribe Email
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $InfoColor
Write-Info "[Test 4/9] Subscribe Email"
$subscribeUrl = "$BaseUrl/api/subscribe?email=$([System.Web.HttpUtility]::UrlEncode($TestEmail))"
$subscribeResponse = Test-Endpoint -Name "Subscribe Email" -Uri $subscribeUrl -Method "POST"

if ($subscribeResponse.success) {
    Write-Success "Email subscription initiated"
    Write-Warning "⚠ User must click confirmation link in email to activate"
    $SubscriptionArn = $subscribeResponse.subscriptionArn
} else {
    Write-Error "Failed to subscribe email"
}

# Test 5: Verify Subscription in List
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $InfoColor
Write-Info "[Test 5/9] Verify Subscription Added"
$subscriptionsAfter = Test-Endpoint -Name "List Subscriptions (After Subscribe)" -Uri "$BaseUrl/api/subscriptions"

if ($subscriptionsAfter -and $subscriptionsAfter.count -gt $subscriptions.count) {
    Write-Success "New subscription added to list"
} else {
    Write-Warning "Subscription count did not increase (might be pending confirmation)"
}

# Test 6: Send Test Message to Queue
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $InfoColor
Write-Info "[Test 6/9] Send Test Message to Queue"
$testMsgResponse = Test-Endpoint -Name "Send Test Message" -Uri "$BaseUrl/admin/send-test-message" -Method "POST"

if ($testMsgResponse.success) {
    Write-Success "Test message sent to queue: $($testMsgResponse.messageId)"
}

# Test 7: Check Queue Status After Message
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $InfoColor
Write-Info "[Test 7/9] Check Queue Status (After Message)"
$queueStatusAfterMsg = Test-Endpoint -Name "Queue Status (After Message)" -Uri "$BaseUrl/admin/queue-status"

if ($queueStatusAfterMsg -and $queueStatusAfterMsg.messages.available -gt $queueStatusBefore.messages.available) {
    Write-Success "Message visible in queue ($($queueStatusAfterMsg.messages.available) messages)"
}

# Test 8: Manually Process Queue
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $InfoColor
Write-Info "[Test 8/9] Manually Process Queue"
$processResponse = Test-Endpoint -Name "Process Queue" -Uri "$BaseUrl/admin/process-queue" -Method "POST"

if ($processResponse.success) {
    Write-Success "Queue processing triggered"
    Write-Info "Messages should be published to SNS"
    
    # Wait a moment for processing
    Start-Sleep -Seconds 2
    
    # Check queue status after processing
    $queueStatusAfterProcess = Test-Endpoint -Name "Queue Status (After Process)" -Uri "$BaseUrl/admin/queue-status"
    if ($queueStatusAfterProcess) {
        Write-Success "Queue processed. Remaining messages: $($queueStatusAfterProcess.messages.available)"
    }
}

# Test 9: Unsubscribe Email (Optional)
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $InfoColor
Write-Info "[Test 9/9] Unsubscribe Email"
Write-Warning "Note: Skipping unsubscribe to keep test email active for monitoring"

# =====================================================================
# TEST SUMMARY
# =====================================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor $InfoColor
Write-Host "Test Summary" -ForegroundColor $InfoColor
Write-Host "========================================================" -ForegroundColor $InfoColor
Write-Host ""

Write-Info "Tests Completed"
Write-Host ""
Write-Info "Next Manual Tests:"
Write-Host "  1. Upload Image Endpoint:"
Write-Host "     POST $BaseUrl/api/upload?fileName=test.jpg&fileSize=1024000"
Write-Host ""
Write-Host "  2. Check Email:"
Write-Host "     - Confirm subscription in $TestEmail"
Write-Host "     - Should receive image upload notification"
Write-Host ""
Write-Host "  3. Monitor Logs:"
Write-Host "     - Check application logs for background worker activity"
Write-Host ""
Write-Info "Troubleshooting:"
Write-Host "  - If no email received: Check AWS SNS subscription status"
Write-Host "  - If queue not processing: Verify background worker is running"
Write-Host "  - If permission errors: Update EC2 IAM role with SQS/SNS permissions"
Write-Host ""
Write-Host "========================================================" -ForegroundColor $InfoColor
Write-Host "End of Test Suite" -ForegroundColor $InfoColor
Write-Host "========================================================" -ForegroundColor $InfoColor
