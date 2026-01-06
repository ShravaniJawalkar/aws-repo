# Test upload script for S3 image management API
$lbUrl = "http://webproject-loadbalancer-157806005.ap-south-1.elb.amazonaws.com"
$testImagePath = "C:\Users\Shravani_Jawalkar\aws\test-image\test.jpg"

Write-Host "=== S3 Image Upload Test ===" -ForegroundColor Cyan

# 1. Verify file exists
if (!(Test-Path $testImagePath)) {
    Write-Host "✗ File not found: $testImagePath" -ForegroundColor Red
    exit 1
}

$fileSize = (Get-Item $testImagePath).Length
Write-Host "✓ File found: $testImagePath ($fileSize bytes)" -ForegroundColor Green

# 2. Test health endpoint
Write-Host "`n[1/3] Testing health endpoint..."
try {
    $health = Invoke-WebRequest "$lbUrl/health" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✓ Health: $($health.Content)" -ForegroundColor Green
} catch {
    Write-Host "✗ Health check failed: $_" -ForegroundColor Red
    exit 1
}

# 3. Upload file
Write-Host "`n[2/3] Uploading file..."
try {
    $form = @{
        file = Get-Item -Path $testImagePath
    }
    
    $response = Invoke-WebRequest -Uri "$lbUrl/api/upload" `
        -Method POST `
        -Form $form `
        -TimeoutSec 10 `
        -ErrorAction Stop
    
    Write-Host "✓ Upload successful!" -ForegroundColor Green
    Write-Host $response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 5
} catch {
    Write-Host "✗ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 4. Verify upload in S3
Write-Host "`n[3/3] Verifying in S3..."
Start-Sleep -Seconds 2

try {
    $images = Invoke-WebRequest "$lbUrl/api/images" -TimeoutSec 5 -ErrorAction Stop
    $imageList = $images.Content | ConvertFrom-Json
    
    if ($imageList.images -contains "test.jpg") {
        Write-Host "✓ Image found in S3 bucket!" -ForegroundColor Green
        Write-Host "Total images: $($imageList.images.Count)"
        Write-Host "Files: $($imageList.images -join ', ')"
    } else {
        Write-Host "✗ Image not found in S3" -ForegroundColor Yellow
        Write-Host "Available files: $($imageList.images -join ', ')"
    }
} catch {
    Write-Host "✗ Failed to list images: $_" -ForegroundColor Red
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
