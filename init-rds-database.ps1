# Initialize webproject database using RDS Query Editor
# This script uses AWS CLI to execute SQL commands on RDS

param(
    [string]$Region = "ap-south-1",
    [string]$Profile = "user-iam-profile",
    [string]$DbInstanceId = "webproject-database",
    [string]$DbUser = "admin",
    [string]$DbPassword = "PasswordwebProject2024'",
    [string]$DbName = "webproject"
)

Write-Host "Initializing RDS database..." -ForegroundColor Green
Write-Host "Instance: $DbInstanceId" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host ""

# First, let's test connection using AWS Secrets Manager approach
# Create a temp lambda function that initializes the DB

$LambdaFunctionCode = @'
const mysql = require('mysql2/promise');

exports.handler = async (event) => {
    const dbConfig = {
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        waitForConnections: true,
        connectionLimit: 1,
        queueLimit: 0
    };

    try {
        const connection = await mysql.createConnection(dbConfig);
        
        // Create database
        await connection.query(`CREATE DATABASE IF NOT EXISTS webproject`);
        console.log('✓ Database created');
        
        // Create table
        await connection.query(`
            CREATE TABLE IF NOT EXISTS webproject.image_uploads (
              id INT AUTO_INCREMENT PRIMARY KEY,
              fileName VARCHAR(255) NOT NULL UNIQUE,
              fileSize BIGINT,
              fileExtension VARCHAR(10),
              uploadedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              description TEXT,
              uploadedBy VARCHAR(100),
              INDEX idx_fileName (fileName)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
        console.log('✓ Table created');
        
        await connection.end();
        
        return {
            statusCode: 200,
            body: JSON.stringify('Database initialized successfully')
        };
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify(`Error: ${error.message}`)
        };
    }
};
'@

Write-Host "Alternative approach: Use the SQL script directly in AWS Console" -ForegroundColor Yellow
Write-Host ""
Write-Host "Steps:" -ForegroundColor Green
Write-Host "1. Go to AWS RDS Console" -ForegroundColor Gray
Write-Host "2. Click on 'webproject-database' instance" -ForegroundColor Gray
Write-Host "3. Click 'Query Editor' tab" -ForegroundColor Gray
Write-Host "4. Paste and run the following SQL commands:" -ForegroundColor Gray
Write-Host ""

$SqlCommands = @"
-- Create database
CREATE DATABASE IF NOT EXISTS webproject;

-- Create table
CREATE TABLE IF NOT EXISTS webproject.image_uploads (
  id INT AUTO_INCREMENT PRIMARY KEY,
  fileName VARCHAR(255) NOT NULL UNIQUE,
  fileSize BIGINT,
  fileExtension VARCHAR(10),
  uploadedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  description TEXT,
  uploadedBy VARCHAR(100),
  INDEX idx_fileName (fileName)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Verify
SHOW DATABASES;
USE webproject;
SHOW TABLES;
DESCRIBE image_uploads;
"@

Write-Host $SqlCommands -ForegroundColor Cyan
Write-Host ""
Write-Host "After executing these SQL commands, your Lambda should work!" -ForegroundColor Green
