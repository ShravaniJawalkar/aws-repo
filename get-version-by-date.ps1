param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$true)]
    [string]$FileName,
    
    [Parameter(Mandatory=$true)]
    [string]$Date
)

# Convert date string to DateTime object
try {
    $targetDate = [DateTime]::Parse($Date)
} catch {
    Write-Error "Invalid date format. Please use format like: 2024-01-15 or 2024-01-15T10:30:00"
    exit 1
}

Write-Host "Finding latest version of '$FileName' in bucket '$BucketName' before $targetDate"

# Get all versions of the object
$versions = aws s3api list-object-versions --bucket $BucketName --prefix $FileName --profile user-s3-profile --output json | ConvertFrom-Json

if (-not $versions.Versions) {
    Write-Error "No versions found for $FileName"
    exit 1
}

# Filter versions before the target date and sort by LastModified
$validVersions = $versions.Versions | Where-Object {
    $versionDate = [DateTime]::Parse($_.LastModified)
    $versionDate -lt $targetDate
} | Sort-Object LastModified -Descending

if ($validVersions.Count -eq 0) {
    Write-Warning "No versions found before $targetDate"
    exit 0
}

# Get the latest version before the date
$latestVersion = $validVersions[0]
$versionId = $latestVersion.VersionId
$lastModified = $latestVersion.LastModified

Write-Host "Found version: $versionId (Last Modified: $lastModified)"

# Download the specific version
$outputFile = "$FileName-version-$versionId.txt"
Write-Host "Downloading to $outputFile..."

aws s3api get-object --bucket $BucketName --key $FileName --version-id $versionId $outputFile --profile user-s3-profile

if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully downloaded version $versionId to $outputFile" -ForegroundColor Green
} else {
    Write-Error "Failed to download the version"
    exit 1
}
