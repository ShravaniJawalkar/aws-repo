# Initialize RDS Database via AWS Lambda CLI

param(
    [Parameter(Mandatory=$false)]
    [string]$Profile = "user-iam-profile",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "ap-south-1"
)

Write-Host "RDS Database Initialization via Lambda" -ForegroundColor Green

$DbHost = "webproject-database.c14e66sq09ij.ap-south-1.rds.amazonaws.com"
$DbUser = "admin"
$DbPassword = "PasswordwebProject2024'"
$DbName = "webproject"

$LambdaFunctionName = "temp-init-webproject-db"
$RoleArn = "arn:aws:iam::908601827639:role/webproject-DataConsistencyFunction-Role"
$ZipFile = "temp-db-init.zip"
$IndexFile = "index.js"
$VpcId = "vpc-04304d2648a6d0753"
$SubnetIds = "subnet-03f16fceda3f36dec,subnet-0f16a48da72abda1e"
$SecurityGroupId = "sg-06be32af49a07ede4"

Write-Host "[1/4] Creating Lambda function code..." -ForegroundColor Yellow

# Create index.js 
$IndexContent = @'
const mysql = require('mysql2/promise');

exports.handler = async (event) => {
    const dbConfig = {
        host: 'webproject-database.c14e66sq09ij.ap-south-1.rds.amazonaws.com',
        user: 'admin',
        password: 'Passwordwebproject2024\'',
        waitForConnections: true,
        connectionLimit: 1,
        queueLimit: 0
    };

    try {
        console.log('Connecting to RDS...');
        const connection = await mysql.createConnection(dbConfig);
        
        console.log('Creating database...');
        await connection.query('CREATE DATABASE IF NOT EXISTS webproject');
        console.log('Database created');
        
        console.log('Creating table...');
        await connection.query(`CREATE TABLE IF NOT EXISTS webproject.image_uploads (
          id INT AUTO_INCREMENT PRIMARY KEY,
          fileName VARCHAR(255) NOT NULL UNIQUE,
          fileSize BIGINT,
          fileExtension VARCHAR(10),
          uploadedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          description TEXT,
          uploadedBy VARCHAR(100),
          INDEX idx_fileName (fileName)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
        console.log('Table created');
        
        await connection.end();
        
        return {
            statusCode: 200,
            body: 'Database and table created successfully'
        };
    } catch (error) {
        console.error('Error:', error.message);
        return {
            statusCode: 500,
            body: error.message
        };
    }
};
'@

$IndexContent | Out-File -FilePath $IndexFile -Encoding UTF8
Write-Host "  - Lambda code created" -ForegroundColor Gray

Write-Host "[2/4] Creating package.json..." -ForegroundColor Yellow

$PackageContent = @'
{
  "name": "db-init",
  "version": "1.0.0",
  "dependencies": {
    "mysql2": "^3.6.0"
  }
}
'@

$PackageContent | Out-File -FilePath "package.json" -Encoding UTF8
Write-Host "  - package.json created" -ForegroundColor Gray

Write-Host "[3/4] Installing dependencies and creating package..." -ForegroundColor Yellow

npm install --quiet 2>&1 | Out-Null
Write-Host "  - Dependencies installed" -ForegroundColor Gray

if (Test-Path $ZipFile) {
    Remove-Item $ZipFile -Force
}

Compress-Archive -Path $IndexFile, "node_modules", "package.json" -DestinationPath $ZipFile -Force
Write-Host "  - Deployment package created" -ForegroundColor Gray

Write-Host "[4/4] Deploying and executing Lambda..." -ForegroundColor Yellow

aws lambda create-function --function-name $LambdaFunctionName --runtime nodejs18.x --role $RoleArn --handler index.handler --zip-file fileb://$ZipFile --timeout 60 --memory-size 256 --region $Region --profile $Profile --vpc-config SubnetIds=$SubnetIds,SecurityGroupIds=$SecurityGroupId 2>&1 | Out-Null

Write-Host "  - Lambda function created" -ForegroundColor Gray
Write-Host "  - Waiting for Lambda to initialize (90 seconds)..." -ForegroundColor Gray

$waitTime = 0
$maxWait = 90
while ($waitTime -lt $maxWait) {
    $status = aws lambda get-function --function-name $LambdaFunctionName --region $Region --profile $Profile --query 'Configuration.State' --output text 2>&1
    if ($status -eq "Active") {
        Write-Host "  - Lambda is now Active" -ForegroundColor Green
        break
    }
    Write-Host "  - Status: $status, waiting..." -ForegroundColor Gray
    Start-Sleep -Seconds 10
    $waitTime += 10
}

Write-Host ""
Write-Host "Invoking Lambda function..." -ForegroundColor Cyan

aws lambda invoke --function-name $LambdaFunctionName --region $Region --profile $Profile --log-type Tail response.json

$Response = Get-Content response.json
Write-Host ""
Write-Host "Response:" -ForegroundColor Green
$Response

Write-Host ""
Write-Host "Cleaning up..." -ForegroundColor Yellow

aws lambda delete-function --function-name $LambdaFunctionName --region $Region --profile $Profile 2>&1 | Out-Null
Remove-Item $IndexFile, "package.json", $ZipFile, "response.json" -Force -ErrorAction SilentlyContinue

Write-Host "Complete! Database initialized." -ForegroundColor Green
