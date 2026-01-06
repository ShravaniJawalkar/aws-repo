# Troubleshooting: MySQL Client Installation Failed

## Diagnostic: What's Available on Your EC2?

Run these on EC2 to check:

```bash
# Check Python version
python3 --version

# Check pip
pip3 --version

# Check if pip3 can install packages
pip3 list | head -10

# Check available commands
which python3
which pip3
```

---

## SIMPLEST SOLUTION: Python Built-in Approach

If `pip3 install pymysql` fails, try downloading PyMySQL directly:

```bash
# Method 1: Download and extract
cd /tmp
wget https://files.pythonhosted.org/packages/pymysql/pymysql-1.0.2-py3-none-any.whl 2>/dev/null || curl -O https://files.pythonhosted.org/packages/pymysql/pymysql-1.0.2-py3-none-any.whl
pip3 install pymysql-1.0.2-py3-none-any.whl

# Method 2: Use --break-system-packages (if pip is restricted)
pip3 install --break-system-packages pymysql

# Method 3: Install from git
pip3 install git+https://github.com/PyMySQL/PyMySQL.git
```

---

## Alternative: AWS CLI Method (No Client Needed!)

If MySQL client AND Python packages fail, use **AWS RDS Proxy** or **AWS Lambda**:

```bash
# Just verify RDS is reachable via security group
# This proves connectivity without needing MySQL client

aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=webProject-DB-SecGr" \
  --region ap-south-1 \
  --query 'SecurityGroups[0].IpPermissions'
```

---

## Nuclear Option: Create a Python Script WITHOUT External Dependencies

```bash
# Create minimal connection test (no external packages)
cat > test_connectivity.sh << 'EOF'
#!/bin/bash

# Get RDS endpoint from CloudFormation
RDS_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name webProject-infrastructure \
  --region ap-south-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`DBEndpoint`].OutputValue' \
  --output text)

echo "Testing connectivity to RDS: $RDS_ENDPOINT"

# Test with nc (netcat) - doesn't require MySQL client
nc -zv -w 5 $RDS_ENDPOINT 3306

if [ $? -eq 0 ]; then
  echo "✓ RDS is reachable on port 3306"
else
  echo "✗ RDS is NOT reachable"
fi
EOF

chmod +x test_connectivity.sh
./test_connectivity.sh
```

---

## Check if the Problem is the EC2 AMI

```bash
# What distro is this?
cat /etc/os-release

# Is it actually Amazon Linux 2?
grep -i "amazon" /etc/os-release

# Check yum repositories
yum repolist all
```

---

## Last Resort: Check if RDS is Even Ready

The RDS instance might still be creating. Check status:

```powershell
# On your LOCAL machine (Windows), not EC2:
aws rds describe-db-instances \
  --db-instance-identifier webproject-database \
  --region ap-south-1 \
  --profile user-iam-profile \
  --query 'DBInstances[0].{Status:DBInstanceStatus, Engine:Engine, Class:DBInstanceClass}'
```

If status is `creating` → **Wait 5-10 more minutes**

---

## Verify IAM Role & S3 Access Instead

If all MySQL approaches fail, at least verify the core infrastructure:

```bash
# 1. Verify IAM role is attached
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
# Should return role name

# 2. Test S3 access (proves IAM role works)
aws s3 ls s3://shravani-jawalkar-webproject-bucket/ --region ap-south-1

# 3. Check if MySQL/PyMySQL can be installed at all
python3 -m pip install --upgrade pip --user
```

---

## ABSOLUTE LAST OPTION: Skip MySQL, Use Node.js Instead

The application is already running Node.js. Add database integration directly:

```bash
# SSH to EC2
ssh -i web-server.ppk ec2-user@<PUBLIC_IP>

# Navigate to app
cd /home/ec2-user/webapp

# Install MySQL npm package
npm install mysql2

# Create test script
cat > test_db.js << 'EOF'
const mysql = require('mysql2/promise');

(async () => {
  const connection = await mysql.createConnection({
    host: process.env.RDS_ENDPOINT || 'webproject-database.xxxxx.ap-south-1.rds.amazonaws.com',
    user: 'admin',
    password: 'PasswordwebProject2024',
    database: 'mysql'
  });

  try {
    const [rows] = await connection.execute('SELECT 1 as test');
    console.log('✓ RDS Connection Successful:', rows);
  } catch (err) {
    console.log('✗ Error:', err.message);
  }
  connection.end();
})();
EOF

# Run it
node test_db.js
```

---

## SUMMARY: Try in This Order

1. ✅ Check if Python/pip work: `pip3 --version`
2. ✅ Try PyMySQL: `pip3 install pymysql`
3. ✅ If fails: Try `pip3 install --break-system-packages pymysql`
4. ✅ If still fails: Test RDS connectivity with netcat: `nc -zv -w 5 <RDS_ENDPOINT> 3306`
5. ✅ If all fails: Check RDS is ready (status: available, not creating)
6. ✅ Last resort: Use Node.js (already on EC2)

Let me know which step fails and what exact error message you get!

