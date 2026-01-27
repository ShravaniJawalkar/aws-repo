# Initialize Database via SQL Commands
# This script creates the webproject database and tables

param(
    [string]$DbHost = "webproject-database.c14e66sq09ij.ap-south-1.rds.amazonaws.com",
    [string]$DbUser = "admin",
    [string]$DbPassword = "Passwordwebproject2024'",
    [string]$DbName = "webproject"
)

Write-Host "Creating database and tables on RDS..." -ForegroundColor Green

# Create a SQL file with the initialization commands
$SqlFile = "init-db.sql"

@"
CREATE DATABASE IF NOT EXISTS $DbName;
USE $DbName;

CREATE TABLE IF NOT EXISTS image_uploads (
  id INT AUTO_INCREMENT PRIMARY KEY,
  fileName VARCHAR(255) NOT NULL UNIQUE,
  fileSize BIGINT,
  fileExtension VARCHAR(10),
  uploadedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  description TEXT,
  uploadedBy VARCHAR(100),
  INDEX idx_fileName (fileName)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SHOW TABLES;
"@ | Out-File -FilePath $SqlFile -Encoding UTF8

Write-Host "SQL file created: $SqlFile" -ForegroundColor Cyan

# Try using mysql if available, otherwise provide instructions
try {
    # Attempt to run mysql command
    $mysqlCmd = "mysql -h $DbHost -u $DbUser -p$DbPassword < $SqlFile"
    Write-Host "Attempting to execute: $mysqlCmd" -ForegroundColor Yellow
    Invoke-Expression $mysqlCmd
    Write-Host "✓ Database initialization complete" -ForegroundColor Green
    Remove-Item $SqlFile
} catch {
    Write-Host "⚠ MySQL client not found. Please install MySQL client or use AWS RDS console." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative: Use AWS Secrets Manager with a Lambda function or RDS console directly." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "SQL commands to execute manually:" -ForegroundColor Yellow
    Get-Content $SqlFile
}
