# Direct RDS Database Initialization using AWS RDS Data API

param(
    [string]$Profile = "user-iam-profile",
    [string]$Region = "ap-south-1"
)

Write-Host "Initializing RDS database via Data API..." -ForegroundColor Green

$DbResourceArn = "arn:aws:rds:ap-south-1:908601827639:db:webproject-database"

# Create secret for database credentials
Write-Host "[1/2] Creating database credentials secret..." -ForegroundColor Yellow

$SecretJson = '{
    "username": "admin",
    "password": "PasswordwebProject2024'"
}'

aws secretsmanager create-secret --name webproject-db-secret --secret-string $SecretJson --region $Region --profile $Profile 2>&1 | Out-Null

$SecretArn = aws secretsmanager describe-secret --secret-id webproject-db-secret --region $Region --profile $Profile --query ARN --output text

Write-Host "  Secret ARN: $SecretArn" -ForegroundColor Green

# Execute SQL commands
Write-Host "[2/2] Executing database initialization SQL..." -ForegroundColor Yellow

$CreateDbSql = "CREATE DATABASE IF NOT EXISTS webproject"
$CreateTableSql = "CREATE TABLE IF NOT EXISTS webproject.image_uploads (id INT AUTO_INCREMENT PRIMARY KEY, fileName VARCHAR(255) NOT NULL UNIQUE, fileSize BIGINT, fileExtension VARCHAR(10), uploadedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP, description TEXT, uploadedBy VARCHAR(100), INDEX idx_fileName (fileName)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

Write-Host "  - Creating database..." -ForegroundColor Gray
aws rds-data execute-statement --resource-arn $DbResourceArn --secret-arn $SecretArn --sql $CreateDbSql --database mysql --region $Region --profile $Profile 2>&1 | Out-Null

Write-Host "  - Creating table..." -ForegroundColor Gray
aws rds-data execute-statement --resource-arn $DbResourceArn --secret-arn $SecretArn --sql $CreateTableSql --database webproject --region $Region --profile $Profile 2>&1 | Out-Null

Write-Host ""
Write-Host "Done! Database initialized successfully." -ForegroundColor Green
