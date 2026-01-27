# EC2 Application Deployment Guide

## 📋 Overview

Your web application has been packaged and uploaded to S3. Now you need to:
1. SSH into the EC2 instance
2. Download the app from S3
3. Install dependencies
4. Configure environment variables
5. Start the application

---

## 🔑 EC2 Instance Details

**Instance IDs** (2 instances running):
- Instance 1: `i-09d61d31fa58f6ab9`
  - Public IP: `13.233.143.33`
  - Private IP: `10.0.11.245`

- Instance 2: `i-072603fb777637839`
  - Public IP: `43.204.130.136`
  - Private IP: `10.0.12.91`

**Region**: `ap-south-1` (Mumbai)
**S3 Bucket**: `shravani-jawalkar-webproject-bucket`
**App File**: `webproject-app.zip`

---

## Step 1: Connect to EC2 Instance via SSH

### Option A: From Windows (PowerShell)

```powershell
# First, find your private key file (.pem)
$keyPath = "C:\path\to\your-key.pem"  # Update with your actual key path

# Connect to Instance 1
ssh -i $keyPath ec2-user@13.233.143.33

# OR Connect to Instance 2
ssh -i $keyPath ec2-user@43.204.130.136
```

### Option B: From Linux/Mac

```bash
# Set key permissions
chmod 400 /path/to/your-key.pem

# Connect to Instance 1
ssh -i /path/to/your-key.pem ec2-user@13.233.143.33

# OR Connect to Instance 2
ssh -i /path/to/your-key.pem ec2-user@43.204.130.136
```

### Option C: Using AWS Systems Manager (No SSH key needed)

```powershell
# Connect using AWS Systems Manager
aws ssm start-session `
  --target i-09d61d31fa58f6ab9 `
  --region ap-south-1 `
  --profile user-iam-profile
```

---

## Step 2: On EC2 Instance - Download and Deploy App

Once connected to EC2, run these commands:

```bash
# Create app directory
mkdir -p /home/ec2-user/webproject
cd /home/ec2-user/webproject

# Download app from S3
aws s3 cp s3://shravani-jawalkar-webproject-bucket/webproject-app.zip . --region ap-south-1

# Unzip the application
unzip -o webproject-app.zip

# List files to verify
ls -la
```

---

## Step 3: Install Node.js Dependencies

```bash
# Check if npm is installed (should be on AMI)
npm --version

# Install application dependencies
npm install

# Verify Express is installed
npm list express
```

---

## Step 4: Configure Environment Variables

Create a `.env` file with your AWS credentials and configuration:

```bash
# Create environment file
cat > /home/ec2-user/webproject/.env << 'EOF'
# AWS Configuration
AWS_REGION=ap-south-1
AWS_ACCESS_KEY_ID=<your-access-key>
AWS_SECRET_ACCESS_KEY=<your-secret-key>

# SQS Configuration
SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
SQS_QUEUE_ARN=arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue

# SNS Configuration
SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639/webproject-UploadsNotificationTopic

# S3 Configuration
S3_BUCKET_NAME=shravani-jawalkar-webproject-bucket

# Application Configuration
PORT=3000
NODE_ENV=production
EOF
```

**OR** Set environment variables directly:

```bash
export AWS_REGION=ap-south-1
export AWS_ACCESS_KEY_ID=<your-access-key>
export AWS_SECRET_ACCESS_KEY=<your-secret-key>
export SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
export SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639/webproject-UploadsNotificationTopic
export S3_BUCKET_NAME=shravani-jawalkar-webproject-bucket
export PORT=3000
export NODE_ENV=production
```

---

## Step 5: Start the Application

### Option A: Simple Start (for testing)

```bash
npm start
```

Output should show:
```
Server is running on http://localhost:3000
```

### Option B: Background with PM2 (Production)

```bash
# Install PM2 globally
sudo npm install -g pm2

# Start app with PM2
pm2 start app-enhanced.js --name "webproject-app"

# Make it restart on reboot
pm2 startup
pm2 save

# Check status
pm2 status
```

### Option C: Run as Service (Using nohup)

```bash
# Start in background
nohup npm start > app.log 2>&1 &

# Check if running
ps aux | grep node

# View logs
tail -f app.log
```

---

## ✅ Verification Steps

### 1. Check App is Running

```bash
# Check process
ps aux | grep node

# Check port 3000
netstat -tulpn | grep 3000
# OR
lsof -i :3000
```

### 2. Test Locally on EC2

```bash
# Test health endpoint
curl http://localhost:3000

# Should return HTML response
```

### 3. Test from Your Local Machine

```powershell
# Test from Windows
curl.exe "http://13.233.143.33:3000"
# OR
(Invoke-WebRequest -Uri "http://13.233.143.33:3000").Content
```

### 4. Check Application Logs

```bash
# View recent logs
tail -100 app.log

# Or if using PM2
pm2 logs webproject-app
```

---

## 🔒 Security Configuration

### Update Security Group

The security group should allow:
- Port 3000 (Application)
- Port 80 (HTTP redirect)
- Port 443 (HTTPS)

```powershell
# Get security group ID from CloudFormation outputs
aws cloudformation describe-stacks `
  --stack-name webproject-infrastructure `
  --region ap-south-1 `
  --profile user-iam-profile `
  --query "Stacks[0].Outputs[?OutputKey=='SecurityGroupId'].OutputValue" `
  --output text
```

### Authorize Port 3000

```powershell
$sgId = "sg-016ef650e21d0368d"  # Replace with actual SG ID

aws ec2 authorize-security-group-ingress `
  --group-id $sgId `
  --protocol tcp `
  --port 3000 `
  --cidr 0.0.0.0/0 `
  --region ap-south-1 `
  --profile user-iam-profile
```

---

## 🌐 Access the Application

After deployment, access your app:

- **Direct**: `http://13.233.143.33:3000`
- **Load Balancer**: `http://webproject-LoadBalancer-1658324737.ap-south-1.elb.amazonaws.com`

---

## 🧪 Test Upload Functionality

1. Navigate to `http://<public-ip>:3000/upload`
2. Select an image
3. Fill in details
4. Click "Upload Image"
5. Check:
   - Response time (should be <100ms)
   - CloudWatch Logs for Lambda execution
   - Email for SNS notification

---

## 📊 Monitor Application

### Check CloudWatch Logs

```bash
# From EC2 or local machine
aws logs tail /aws/lambda/webproject-UploadsNotificationFunction --follow --region ap-south-1

# Check Lambda metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=webproject-UploadsNotificationFunction \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --region ap-south-1
```

### Check SQS Queue Depth

```bash
aws sqs get-queue-attributes \
  --queue-url "https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue" \
  --attribute-names ApproximateNumberOfMessages \
  --region ap-south-1
```

---

## 🐛 Troubleshooting

### Port Already in Use

```bash
# Find process using port 3000
lsof -i :3000

# Kill process
kill -9 <PID>
```

### Node Modules Not Found

```bash
# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install
```

### AWS Credentials Not Working

```bash
# Check if credentials are set
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY

# Or check credential file
cat ~/.aws/credentials
```

### Permission Denied on key.pem

```bash
# Fix permissions
chmod 400 ~/.aws/webproject-key.pem
```

---

## 📝 Complete Deployment Checklist

- [ ] SSH to EC2 instance
- [ ] Create `/home/ec2-user/webproject` directory
- [ ] Download `webproject-app.zip` from S3
- [ ] Unzip the application
- [ ] Run `npm install`
- [ ] Create `.env` file with AWS credentials
- [ ] Start application (`npm start` or `pm2 start`)
- [ ] Test health endpoint (`curl http://localhost:3000`)
- [ ] Access from browser (`http://<public-ip>:3000`)
- [ ] Test upload functionality
- [ ] Monitor logs
- [ ] Verify emails received

---

## 🎉 Success!

Once the application is running on EC2:
1. Upload 2+ images
2. Verify instant response (<100ms)
3. Check Lambda logs
4. Receive SNS emails

Your deployment is complete! ✅
