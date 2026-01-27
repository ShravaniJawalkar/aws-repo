# EC2 Application Deployment - Manual Instructions

Since automated SSH deployment encountered security group restrictions, follow these manual steps to deploy the application.

## Quick Summary

- **EC2 Instance IP:** 3.110.142.62  
- **Instance ID:** i-0b5539c0d4d75db39  
- **S3 Location:** s3://shravani-jawalkar-webproject-bucket/  
- **Application Files:** app-enhanced.js, package.json  
- **App Directory:** ~/webapp  

## Method 1: Via AWS Console EC2 Connect (Recommended)

### Step 1: Access EC2 Connect in AWS Console

1. Go to **EC2 Dashboard** → **Instances**
2. Find instance: `i-0b5539c0d4d75db39`
3. Select it and click **Connect** (top button)
4. Choose **EC2 Instance Connect** tab
5. Click **Connect** (opens browser terminal)

### Step 2: Run Deployment Commands

Once connected, paste these commands:

```bash
# Create app directory
mkdir -p ~/webapp
cd ~/webapp

# Download app from S3
aws s3 cp s3://shravani-jawalkar-webproject-bucket/app-enhanced.js . --region ap-south-1
aws s3 cp s3://shravani-jawalkar-webproject-bucket/package.json . --region ap-south-1

# Check Node.js version
node --version

# If Node.js not installed or version < 18:
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs

# Install npm dependencies
npm install --production

# Set environment variables
export AWS_REGION=ap-south-1
export S3_BUCKET=shravani-jawalkar-webproject-bucket
export SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
export SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic

# Start the application
npm start
```

### Expected Output

```
========================================
Server is running on port 8080
Access the application at http://localhost:8080
========================================
S3 Bucket: shravani-jawalkar-webproject-bucket
SQS Queue URL: https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
SNS Topic ARN: arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic
========================================
```

### Step 3: Keep Application Running

To keep the app running after closing the terminal:

**Option A: Run in Background (via nohup)**

```bash
# Exit the current npm start with Ctrl+C
# Then run:

cd ~/webapp
nohup npm start > app.log 2>&1 &
sleep 2
ps aux | grep "npm start"
```

**Option B: Create SystemD Service**

```bash
sudo tee /etc/systemd/system/webapp.service > /dev/null <<EOF
[Unit]
Description=Web Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/webapp
Environment="AWS_REGION=ap-south-1"
Environment="S3_BUCKET=shravani-jawalkar-webproject-bucket"
Environment="SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue"
Environment="SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic"
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable webapp
sudo systemctl start webapp
sudo systemctl status webapp
```

---

## Method 2: Using AWS Systems Manager Session Manager

### Step 1: Check Instance Has Correct IAM Role

```bash
# Your instance needs AmazonSSMManagedInstanceCore role
# Check in AWS Console → EC2 → Instance → Security → IAM Instance Profile
```

### Step 2: Start Session Manager

```bash
aws ssm start-session --target i-0b5539c0d4d75db39 --region ap-south-1 --profile user-iam-profile
```

### Step 3: Run Commands (Same as Method 1 Step 2)

---

## Method 3: Via SSH (If Security Group Updated)

```bash
ssh -i web-server.ppk ec2-user@3.110.142.62

# Then follow steps from Method 1 Step 2
```

---

## Verify Application is Running

### Via Load Balancer URL

```bash
# Open in browser or curl:
curl http://webproject-LoadBalancer-418397374.ap-south-1.elb.amazonaws.com/health

# Expected response:
# {"status":"healthy"}
```

### Check Application Logs

```bash
# If running in foreground: Ctrl+C to stop

# If running in background:
tail -f ~/webapp/app.log

# Or check if process is running:
ps aux | grep "npm start"
```

### Check Port 8080 Listening

```bash
netstat -tlnp | grep 8080
# or
ss -tlnp | grep 8080
```

---

## Troubleshooting

### Problem: Node.js not installed

**Solution:**
```bash
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs
node --version  # Should be v18.x
```

### Problem: npm install fails

**Solution:**
```bash
# Clear npm cache
npm cache clean --force

# Try install again
npm install --production --verbose
```

### Problem: Application crashes on startup

**Check logs:**
```bash
cat ~/webapp/app.log
# or if running in foreground, check terminal output
```

**Common causes:**
- S3 bucket not accessible
- SQS queue URL incorrect
- SNS topic ARN incorrect
- Port 8080 already in use

### Problem: Cannot access via Load Balancer

**Check:**
```bash
# 1. Is app running?
ps aux | grep "npm start"

# 2. Is port 8080 listening?
netstat -tlnp | grep 8080

# 3. Check application logs
tail -f ~/webapp/app.log

# 4. Try localhost
curl http://localhost:8080/health
```

---

## Access Application

Once running successfully:

### Via Load Balancer (Recommended)
- **URL:** http://webproject-LoadBalancer-418397374.ap-south-1.elb.amazonaws.com
- **Health Check:** http://webproject-LoadBalancer-418397374.ap-south-1.elb.amazonaws.com/health

### Via EC2 Direct (if needed)
- **URL:** http://3.110.142.62:8080
- **Note:** This bypasses the load balancer

---

## Next Steps

Once application is running and responding:

1. Access the web UI
2. Test subscription endpoint
3. Upload images
4. Verify Lambda processing
5. Check for notification emails

---

## Support Commands

```bash
# View application logs in real-time
tail -f ~/webapp/app.log

# Check AWS CLI configuration
aws sts get-caller-identity

# List S3 objects
aws s3 ls s3://shravani-jawalkar-webproject-bucket/

# Check SQS queue
aws sqs get-queue-url --queue-name webproject-UploadsNotificationQueue --region ap-south-1

# Check SNS topic
aws sns list-topics --region ap-south-1
```

---

**Status:** Ready for Manual Deployment  
**Date:** 2026-01-21  
**Next:** After app is running, proceed with end-to-end testing
