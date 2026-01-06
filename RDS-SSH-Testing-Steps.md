# Step-by-Step Guide: Test RDS Connection from EC2

## STEP 1: Connect to EC2 Instance via SSH

Open PowerShell and run:
```powershell
ssh -i web-server.ppk ec2-user@<PUBLIC_IP>
```

Replace `<PUBLIC_IP>` with your EC2 instance's public IP (get it from the output above).

---

## STEP 2: Once Connected to EC2, Install MySQL Client

```bash
sudo yum install -y mysql80
```

---

## STEP 3: Test RDS Connectivity

Run this command to test the connection:
```bash
mysql -h <RDS_ENDPOINT> -P 3306 -u admin -pPasswordwebProject2024 -e "SELECT 1 as connection_test;"
```

Replace `<RDS_ENDPOINT>` with your RDS endpoint (from outputs above).

Expected output:
```
+------------------+
| connection_test  |
+------------------+
|        1         |
+------------------+
```

---

## STEP 4: Verify IAM Role is Attached to EC2

```bash
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

Expected output: Role name like `webProject-EC2-S3-Read-Role`

---

## STEP 5: Test S3 Access from EC2 (Using IAM Role)

```bash
aws s3 ls s3://shravani-jawalkar-webproject-bucket/ --region ap-south-1
```

This proves the EC2 instance can access S3 using IAM role (no credentials needed).

---

## STEP 6: Create Database and Table for Image Metadata

```bash
mysql -h <RDS_ENDPOINT> -P 3306 -u admin -pPasswordwebProject2024 << 'EOF'
CREATE DATABASE IF NOT EXISTS imagedb;

USE imagedb;

CREATE TABLE IF NOT EXISTS image_metadata (
    id INT AUTO_INCREMENT PRIMARY KEY,
    filename VARCHAR(255) NOT NULL UNIQUE,
    size_bytes INT,
    content_type VARCHAR(100),
    upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    s3_key VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);

SHOW TABLES;
DESCRIBE image_metadata;
EOF
```

---

## STEP 7: Insert Sample Image Metadata

```bash
mysql -h <RDS_ENDPOINT> -P 3306 -u admin -pPasswordwebProject2024 imagedb << 'EOF'
INSERT INTO image_metadata (filename, size_bytes, content_type, s3_key, description) VALUES
('test.jpg', 6912, 'image/jpeg', 'test.jpg', 'Test image uploaded via web app'),
('city.jpg', 5000, 'image/jpeg', 'city.jpg', 'City landscape'),
('landscape.jpg', 7500, 'image/jpeg', 'landscape.jpg', 'Beautiful landscape');

SELECT * FROM image_metadata;
EOF
```

---

## STEP 8: Query Image Metadata

```bash
mysql -h <RDS_ENDPOINT> -P 3306 -u admin -pPasswordwebProject2024 imagedb -e \
  "SELECT id, filename, size_bytes, content_type, upload_date FROM image_metadata;"
```

---

## STEP 9: Optional - Set Up IAM Database Authentication

### Create IAM DB User:

```bash
mysql -h <RDS_ENDPOINT> -P 3306 -u admin -pPasswordwebProject2024 imagedb << 'EOF'
CREATE USER IF NOT EXISTS 'iamdb_user' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
GRANT ALL PRIVILEGES ON imagedb.* TO 'iamdb_user'@'%';
FLUSH PRIVILEGES;
SELECT User FROM mysql.user WHERE User='iamdb_user';
EOF
```

### Test IAM Authentication:

```bash
TOKEN=$(aws rds generate-db-auth-token \
  --hostname <RDS_ENDPOINT> \
  --port 3306 \
  --region ap-south-1 \
  --username iamdb_user)

mysql -h <RDS_ENDPOINT> -P 3306 -u iamdb_user \
  --ssl-ca=/etc/ssl/certs/ca-bundle.crt \
  --ssl-mode=VERIFY_IDENTITY \
  -e "SELECT 'IAM Authentication Successful!' as result;" \
  --password="$TOKEN" \
  imagedb
```

---

## STEP 10: Verify AWS Credentials Provider Chain

On EC2, run:
```bash
# Check current AWS credentials (should use IAM role)
aws sts get-caller-identity

# Expected output shows the IAM role ARN
```

---

## Key Points Verified:

✅ EC2 instance has IAM role attached (no hardcoded credentials)  
✅ EC2 can connect to RDS (RDS in private subnets, EC2 can reach it)  
✅ EC2 uses AWS credentials provider chain (IAM role via metadata service)  
✅ S3 access works through IAM permissions  
✅ RDS database and metadata table created  
✅ Optional: IAM database authentication configured  

---

## Cleanup

To avoid extra charges, delete the stack when done:
```powershell
aws cloudformation delete-stack `
  --stack-name webProject-infrastructure `
  --region ap-south-1 `
  --profile user-iam-profile
```

