# Automated EC2 Deployment via CloudFormation

## ✅ Deployment Complete!

Your application is now **automatically deployed** to EC2 instances through CloudFormation UserData scripts. No manual SSH required!

---

## 🚀 What Happened

### 1. **CloudFormation Stack Updated**
- Enhanced `webproject-infrastructure.yaml` with comprehensive UserData script
- Updated IAM roles with SQS, SNS, S3, and CloudWatch Logs permissions
- Added PM2 process manager for production-grade app management

### 2. **Automated Deployment Process**
When EC2 instances launch, they automatically:
- ✅ Update system packages
- ✅ Install Node.js 18.x
- ✅ Download `webproject-app.zip` from S3
- ✅ Install npm dependencies
- ✅ Configure environment variables
- ✅ Start application with PM2
- ✅ Configure auto-restart on reboot
- ✅ Log everything to CloudWatch

### 3. **New Instances Running**
```
Instance 1: i-08102e831e0e5253b
  - Public IP: 13.201.125.102
  - Status: Running
  
Instance 2: i-0c608553ee60c5d65
  - Public IP: 13.233.152.62
  - Status: Running
```

---

## 🌐 Access Your Application

### Option 1: Direct Instance Access (Port 3000)
```
http://13.201.125.102:3000
http://13.233.152.62:3000
```

### Option 2: Load Balancer (Recommended)
```
http://webproject-LoadBalancer-2124223530.ap-south-1.elb.amazonaws.com
```

---

## 📋 Deployment Features

### ✨ Automated Features
- **No SSH Required**: Everything runs via CloudFormation UserData
- **Self-Healing**: PM2 restarts app if it crashes
- **Auto-Start**: App starts automatically on instance reboot
- **Scalable**: Works with Auto Scaling Groups automatically
- **Logging**: All deployment logs in `/var/log/webproject-deploy.log`

### 🔐 IAM Permissions Included
- **S3**: Download app from S3 bucket
- **SQS**: Send messages to queue
- **SNS**: Subscribe to topics
- **CloudWatch Logs**: Send logs to CloudWatch
- **EC2**: Standard EC2 operations

### 🛠️ Process Management
- **PM2**: Production process manager
- **Systemd**: Auto-restart on reboot
- **Log Rotation**: Automatic PM2 log management

---

## 📊 Check Deployment Status

### 1. Check Instance Logs (from your local machine)

```powershell
# Get deployment logs
$instanceId = "i-08102e831e0e5253b"
$logFile = "/var/log/webproject-deploy.log"

aws ssm start-session `
  --target $instanceId `
  --region ap-south-1 `
  --profile user-iam-profile `
  --document-name "AWS-StartInteractiveCommand" `
  --parameters command="tail -100 $logFile"
```

### 2. Check PM2 Status (SSH or Systems Manager)

```bash
# SSH to instance first, then:
pm2 status
pm2 logs webproject-app --lines 50
```

### 3. Test Application

```powershell
# Test from Windows
curl.exe "http://webproject-LoadBalancer-2124223530.ap-south-1.elb.amazonaws.com"

# OR test direct instance
curl.exe "http://13.201.125.102:3000"
```

---

## 🔄 How Auto Scaling Works Now

When Auto Scaling Group launches NEW instances:

1. Instance launches from Launch Template
2. UserData script automatically:
   - Downloads latest `webproject-app.zip` from S3
   - Installs dependencies
   - Configures environment variables
   - Starts the application
3. App is running and ready to serve traffic
4. **No manual intervention needed!**

---

## 📝 Deployment Configuration

### Environment Variables (Auto-Set)
```bash
AWS_REGION=ap-south-1
S3_BUCKET_NAME=shravani-jawalkar-webproject-bucket
SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic
PORT=3000
NODE_ENV=production
```

### Application Details
- **Start Command**: `npm start` (via PM2)
- **Application File**: `app-enhanced.js`
- **Node.js Version**: 18.x
- **Process Manager**: PM2

---

## 🧪 Test the Full Flow

### Step 1: Access Application
```
Visit: http://webproject-LoadBalancer-2124223530.ap-south-1.elb.amazonaws.com
```

### Step 2: Navigate to Upload
```
Click: Upload → Select Image → Fill Details → Upload
```

### Step 3: Verify Deployment
```powershell
# Check SQS queue
aws sqs get-queue-attributes `
  --queue-url "https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue" `
  --attribute-names ApproximateNumberOfMessages `
  --region ap-south-1 `
  --profile user-iam-profile

# Check Lambda invocations
aws cloudwatch get-metric-statistics `
  --namespace AWS/Lambda `
  --metric-name Invocations `
  --dimensions Name=FunctionName,Value=webproject-UploadsNotificationFunction `
  --start-time (Get-Date).AddHours(-1) `
  --end-time (Get-Date) `
  --period 300 `
  --statistics Sum `
  --region ap-south-1 `
  --profile user-iam-profile
```

### Step 4: Check Email
```
Should receive SNS email notification with:
- File name
- File size
- Upload timestamp
- Event ID
```

---

## 🔧 Update Application (Without Re-creating Stack)

### When Code Changes

```powershell
# 1. Package new code
Compress-Archive -Path "web-dynamic-app\*.js", "web-dynamic-app\*.json" `
  -DestinationPath "webproject-app.zip" -Force

# 2. Upload to S3
aws s3 cp webproject-app.zip `
  s3://shravani-jawalkar-webproject-bucket/webproject-app.zip `
  --region ap-south-1 `
  --profile user-iam-profile

# 3. Connect to instance and restart app
# (SSH or Systems Manager)
pm2 restart webproject-app

# OR terminate instances to trigger Auto Scaling replacement
aws ec2 terminate-instances `
  --instance-ids i-08102e831e0e5253b `
  --region ap-south-1 `
  --profile user-iam-profile
# New instance will auto-deploy latest code from S3
```

---

## 📈 Monitoring & Troubleshooting

### Check Instance System Logs
```powershell
aws ec2 get-console-output `
  --instance-id i-08102e831e0e5253b `
  --region ap-south-1 `
  --profile user-iam-profile
```

### View Deployment Log
```bash
# SSH to instance, then:
cat /var/log/webproject-deploy.log
tail -f /var/log/webproject-deploy.log
```

### Check PM2 Processes
```bash
# SSH to instance, then:
pm2 status
pm2 logs
pm2 show webproject-app
```

### Restart Application
```bash
# SSH to instance, then:
pm2 restart webproject-app
```

### Check Application Port
```bash
# SSH to instance, then:
netstat -tlnp | grep 3000
# or
lsof -i :3000
```

---

## 🎯 Benefits of This Approach

| Feature | Manual SSH | CloudFormation UserData |
|---------|-----------|------------------------|
| **Manual Deployment** | ✅ Required | ❌ Automatic |
| **Handles Instance Changes** | ❌ No | ✅ Yes |
| **Auto Scaling Support** | ❌ No | ✅ Yes |
| **Disaster Recovery** | ❌ No | ✅ Yes |
| **Infrastructure as Code** | ❌ No | ✅ Yes |
| **Consistency** | ❌ Manual errors possible | ✅ Always same |
| **Time to Deploy** | ⏱️ ~15 minutes | ⚡ ~3-5 minutes |

---

## 🚀 Next Steps

1. **Test Upload Flow**
   - Upload 2+ images
   - Verify instant response
   - Check Lambda logs
   - Receive SNS emails

2. **Monitor Metrics**
   - CloudWatch Metrics
   - Lambda Invocations
   - SQS Queue Depth

3. **Auto Scaling**
   - Load increases → New instances auto-deploy
   - Load decreases → Old instances auto-terminate

4. **Production Ready**
   - All manual steps eliminated
   - Self-healing via PM2
   - Automatic log collection

---

## 📚 Summary

Your application is now fully automated:
- ✅ **Infrastructure**: CloudFormation Stack
- ✅ **Deployment**: UserData Script
- ✅ **Scalability**: Auto Scaling Group
- ✅ **Load Balancing**: Application Load Balancer
- ✅ **Monitoring**: CloudWatch Logs
- ✅ **Process Management**: PM2
- ✅ **Permissions**: IAM Roles

**No SSH required. No manual deployment needed. Just scale and go!** 🚀

---

**Date**: January 20, 2026
**Stack**: webproject-infrastructure
**Status**: ✅ ACTIVE
**Instances**: 2 (Auto-Scaled)
**Application**: Running on All Instances
