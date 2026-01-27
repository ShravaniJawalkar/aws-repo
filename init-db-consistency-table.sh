#!/bin/bash

# Database Initialization Script for Data Consistency Lambda
# Creates the image_uploads table needed by the consistency checker

DB_HOST="webproject-database.c14e66sq09ij.ap-south-1.rds.amazonaws.com"
DB_USER="admin"
DB_PASSWORD="$1"
DB_NAME="webproject"

if [ -z "$DB_PASSWORD" ]; then
    echo "Usage: $0 <db_password>"
    exit 1
fi

echo "Initializing database for Data Consistency Lambda..."

# Create database if not exists
mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;" 2>/dev/null

# Create image_uploads table
mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME <<EOF
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

-- Show table status
SHOW TABLES;
DESCRIBE image_uploads;
EOF

echo "✓ Database initialization complete"
