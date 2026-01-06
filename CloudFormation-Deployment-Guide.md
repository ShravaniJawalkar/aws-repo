# CloudFormation Stack Deployment Guide

This guide provides instructions for deploying and managing the web application infrastructure using AWS CloudFormation.

## 📋 Prerequisites

Before deploying the stack, ensure you have:

1. **AWS CLI installed and configured**
   ```powershell
   aws --version
   aws configure list
   ```

2. **Custom AMI ID** from your EC2 module
   - Get it from EC2 Console → AMIs
   - Format: `ami-xxxxxxxxxxxxxxxxx`

3. **Your IP address** for SSH access (optional, defaults to 0.0.0.0/0)
   ```powershell
   (Invoke-WebRequest -Uri "https://api.ipify.org").Content
   ```

4. **Appropriate IAM permissions** to create:
   - VPC, Subnets, Route Tables
   - EC2 instances, Security Groups, Launch Templates
   - Auto Scaling Groups
   - Application Load Balancers
   - S3 Buckets
   - CloudWatch Alarms

---

## 🚀 Deployment Methods

### Method 1: AWS Console (Recommended for Beginners)

1. **Open CloudFormation Console**
   - Go to AWS Console → CloudFormation → Create Stack

2. **Upload Template**
   - Choose "Upload a template file"
   - Select `webproject-infrastructure.yaml`
   - Click "Next"

3. **Specify Stack Details**
   - **Stack name**: `webProject-infrastructure` (or your choice)
   - **Parameters**:
     - `ProjectName`: `webProject` (or customize)
     - `ProjectAMI`: Enter your custom AMI ID (e.g., `ami-0abcd1234efgh5678`)
     - `ProjectInstanceType`: `t2.micro` (free tier)
     - `SSHLocation`: Your IP with /32 (e.g., `203.0.113.45/32`) or `0.0.0.0/0`

4. **Configure Stack Options** (Optional)
   - Add tags if needed
   - Configure advanced options
   - Click "Next"

5. **Review and Create**
   - Review all settings
   - Check "I acknowledge that AWS CloudFormation might create IAM resources"
   - Click "Create stack"

6. **Monitor Creation**
   - Watch the Events tab for progress
   - Wait for status: `CREATE_COMPLETE` (15-20 minutes)

### Method 2: AWS CLI

#### Step 1: Validate Template

```powershell
# Validate the template syntax
aws cloudformation validate-template `
  --template-body file://webproject-infrastructure.yaml `
  --region ap-south-1 `
  --profile user-iam-profile
```

#### Step 2: Create Stack

```powershell
# Deploy the stack
aws cloudformation create-stack `
  --stack-name webProject-infrastructure `
  --template-body file://webproject-infrastructure.yaml `
  --parameters `
    ParameterKey=ProjectName,ParameterValue=webProject `
    ParameterKey=ProjectAMI,ParameterValue=ami-xxxxxxxxxxxxxxxxx `
    ParameterKey=ProjectInstanceType,ParameterValue=t2.micro `
    ParameterKey=SSHLocation,ParameterValue=0.0.0.0/0 `
  --capabilities CAPABILITY_IAM `
  --region ap-south-1 `
  --profile user-iam-profile
```

**Replace:**
- `ami-xxxxxxxxxxxxxxxxx` with your actual AMI ID
- `0.0.0.0/0` with your IP (e.g., `203.0.113.45/32`)

#### Step 3: Monitor Stack Creation

```powershell
# Check stack status
aws cloudformation describe-stacks `
  --stack-name webProject-infrastructure `
  --region ap-south-1 `
  --profile user-iam-profile `
  --query "Stacks[0].StackStatus"

# Watch stack events
aws cloudformation describe-stack-events `
  --stack-name webProject-infrastructure `
  --region ap-south-1 `
  --profile user-iam-profile `
  --max-items 10
```

#### Step 4: Get Stack Outputs

```powershell
# Get all outputs
aws cloudformation describe-stacks `
  --stack-name webProject-infrastructure `
  --region ap-south-1 `
  --profile user-iam-profile `
  --query "Stacks[0].Outputs"

# Get Load Balancer URL
aws cloudformation describe-stacks `
  --stack-name webProject-infrastructure `
  --region ap-south-1 `
  --profile user-iam-profile `
  --query "Stacks[0].Outputs[?OutputKey=='LoadBalancerURL'].OutputValue" `
  --output text
```

---

## 📦 What Gets Created

### Networking (VPC)
- ✅ 1 VPC (`10.0.0.0/16`)
- ✅ 1 Internet Gateway
- ✅ 2 Public Subnets (in different AZs)
- ✅ 1 Public Route Table
- ✅ Route table associations

### Compute (EC2)
- ✅ 1 Launch Template
- ✅ 1 Auto Scaling Group (2-4 instances)
- ✅ 1 Security Group (HTTP, HTTPS, SSH, 8080)
- ✅ EC2 instances with user data

### Load Balancing
- ✅ 1 Application Load Balancer
- ✅ 1 Target Group
- ✅ 1 HTTP Listener (port 80)

### Auto Scaling
- ✅ Scale Up Policy (CPU > 50%)
- ✅ Scale Down Policy (CPU < 30%)
- ✅ CloudWatch Alarms

### Storage
- ✅ 1 S3 Bucket

---

## ✅ Testing the Deployment

### 1. Get Load Balancer URL

**From Console:**
- Go to CloudFormation → Stacks → Your Stack → Outputs
- Copy the `LoadBalancerURL` value

**From CLI:**
```powershell
$LB_URL = aws cloudformation describe-stacks `
  --stack-name webProject-infrastructure `
  --region ap-south-1 `
  --profile user-iam-profile `
  --query "Stacks[0].Outputs[?OutputKey=='LoadBalancerURL'].OutputValue" `
  --output text

Write-Host "Load Balancer URL: $LB_URL"
```

### 2. Test Web Application

```powershell
# Test HTTP access
Invoke-WebRequest -Uri $LB_URL

# Or open in browser
Start-Process $LB_URL
```

Expected response: HTML page with hostname

### 3. Verify Auto Scaling

**Check instances:**
```powershell
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names webProject-AutoScalingGroup `
  --region ap-south-1 `
  --profile user-iam-profile `
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,AvailabilityZone]" `
  --output table
```

### 4. Test Load Balancer Distribution

Refresh the web page multiple times - you should see different hostnames (load balancing between instances).

### 5. Verify S3 Bucket

```powershell
aws s3 ls | Select-String "shravanijawalkar"
```

---

## 🔄 Updating the Stack

### Update via Console

1. Go to CloudFormation → Stacks → Select your stack
2. Click "Update"
3. Choose "Replace current template" or "Use current template"
4. Modify parameters if needed
5. Click "Update stack"

### Update via CLI

```powershell
aws cloudformation update-stack `
  --stack-name webProject-infrastructure `
  --template-body file://webproject-infrastructure.yaml `
  --parameters `
    ParameterKey=ProjectName,ParameterValue=webProject `
    ParameterKey=ProjectAMI,ParameterValue=ami-new-ami-id `
    ParameterKey=ProjectInstanceType,ParameterValue=t2.small `
    ParameterKey=SSHLocation,ParameterValue=0.0.0.0/0 `
  --capabilities CAPABILITY_IAM `
  --region ap-south-1 `
  --profile user-iam-profile
```

---

## 🗑️ Deleting the Stack

### ⚠️ Important: Pre-deletion Steps

1. **Empty S3 Bucket** (required before stack deletion)
   ```powershell
   aws s3 rm s3://shravanijawalkar-webproject-bucket/ --recursive --region ap-south-1 --profile user-iam-profile
   ```

2. **Terminate any manually created instances** (if any)

### Delete via Console

1. Go to CloudFormation → Stacks
2. Select your stack
3. Click "Delete"
4. Confirm deletion
5. Wait for `DELETE_COMPLETE` status

### Delete via CLI

```powershell
# Delete the stack
aws cloudformation delete-stack `
  --stack-name webProject-infrastructure `
  --region ap-south-1 `
  --profile user-iam-profile

# Monitor deletion
aws cloudformation describe-stacks `
  --stack-name webProject-infrastructure `
  --region ap-south-1 `
  --profile user-iam-profile `
  --query "Stacks[0].StackStatus"
```

---

## 🐛 Troubleshooting

### Issue: Stack Creation Failed

**Check events:**
```powershell
aws cloudformation describe-stack-events `
  --stack-name webProject-infrastructure `
  --region ap-south-1 `
  --profile user-iam-profile `
  --query "StackEvents[?ResourceStatus=='CREATE_FAILED'].[LogicalResourceId,ResourceStatusReason]" `
  --output table
```

**Common causes:**
- Invalid AMI ID → Check AMI exists in your region
- Insufficient permissions → Verify IAM role/user permissions
- Resource limits → Check EC2/VPC service quotas
- S3 bucket name already exists → Change bucket name (must be globally unique)

### Issue: Stack Deletion Stuck

**Causes:**
- S3 bucket not empty
- Resources manually modified outside CloudFormation
- ENIs still attached

**Solutions:**
1. Empty S3 bucket manually
2. Delete stuck resources manually via console
3. Force delete: Skip stuck resources (not recommended)

### Issue: Load Balancer Not Accessible

**Verify:**
1. Security group allows HTTP (port 80)
2. Instances are healthy in target group
3. DNS propagation (wait 2-3 minutes)

**Check target health:**
```powershell
aws elbv2 describe-target-health `
  --target-group-arn <target-group-arn> `
  --region ap-south-1 `
  --profile user-iam-profile
```

### Issue: Auto Scaling Not Working

**Check CloudWatch alarms:**
```powershell
aws cloudwatch describe-alarms `
  --alarm-names webProject-CPUAlarmHigh webProject-CPUAlarmLow `
  --region ap-south-1 `
  --profile user-iam-profile
```

**Test scaling manually:**
```powershell
# Increase desired capacity
aws autoscaling set-desired-capacity `
  --auto-scaling-group-name webProject-AutoScalingGroup `
  --desired-capacity 3 `
  --region ap-south-1 `
  --profile user-iam-profile
```

---

## 💰 Cost Estimation

### Approximate Monthly Costs (us-east-1 region):

| Resource | Quantity | Unit Cost | Monthly Cost |
|----------|----------|-----------|--------------|
| EC2 t2.micro | 2-4 instances | $0.0116/hour | ~$17-34 |
| Application Load Balancer | 1 | $0.0225/hour | ~$16.43 |
| Data Transfer (minimal) | 10 GB | $0.09/GB | ~$0.90 |
| S3 Storage (minimal) | 1 GB | $0.023/GB | ~$0.02 |
| CloudWatch (basic) | Included | Free | $0 |

**Total: ~$35-52/month**

### Cost Saving Tips:
1. **Use t3.micro instead of t2.micro** (better performance, similar cost)
2. **Set MinSize=1 in ASG** during testing (saves ~$17/month)
3. **Delete stack when not in use**
4. **Use Spot Instances** for cost savings (requires template modification)
5. **Enable Auto Scaling schedule** (scale down during off-hours)

---

## 📝 Template Customization

### Modify Instance Count

Edit the Auto Scaling Group section:
```yaml
MinSize: '1'      # Change from 1
MaxSize: '4'      # Change from 4
DesiredCapacity: '2'  # Change from 2
```

### Add HTTPS Support

1. **Request SSL Certificate** (AWS Certificate Manager)
2. **Add HTTPS Listener:**
   ```yaml
   HTTPSListener:
     Type: AWS::ElasticLoadBalancingV2::Listener
     Properties:
       DefaultActions:
         - Type: forward
           TargetGroupArn: !Ref ProjectTargetGroup
       LoadBalancerArn: !Ref ProjectLoadBalancer
       Port: 443
       Protocol: HTTPS
       Certificates:
         - CertificateArn: arn:aws:acm:region:account-id:certificate/xxx
   ```

### Change Scaling Thresholds

Edit CloudWatch alarms:
```yaml
# Scale up threshold
Threshold: 50  # Change from 50 to 70 (less aggressive scaling)

# Scale down threshold  
Threshold: 30  # Change from 30 to 20 (more conservative)
```

### Add Additional Subnets

Duplicate subnet resources and change:
- CIDR blocks
- Availability zones
- Names

---

## 🔐 Security Best Practices

1. **Restrict SSH Access**
   - Set `SSHLocation` to your specific IP: `<your-ip>/32`
   - Never use `0.0.0.0/0` in production

2. **Enable VPC Flow Logs**
   - Add VPC Flow Logs resource to template

3. **Use HTTPS**
   - Add SSL certificate and HTTPS listener
   - Redirect HTTP to HTTPS

4. **Enable S3 Encryption**
   - Add server-side encryption to S3 bucket

5. **Use Secrets Manager**
   - Store sensitive data in AWS Secrets Manager
   - Reference in user data

6. **Enable CloudTrail**
   - Track API calls and changes

7. **Tag All Resources**
   - Improves cost tracking and management

---

## 📊 Monitoring

### CloudWatch Dashboards

Create custom dashboard to monitor:
- EC2 CPU utilization
- Load Balancer request count
- Target health status
- Auto Scaling activities

### Set Up Alerts

```powershell
# Create SNS topic for alerts
aws sns create-topic --name webProject-alerts --region ap-south-1 --profile user-iam-profile

# Subscribe email to topic
aws sns subscribe `
  --topic-arn arn:aws:sns:ap-south-1:account-id:webProject-alerts `
  --protocol email `
  --notification-endpoint your-email@example.com `
  --region ap-south-1 `
  --profile user-iam-profile
```

---

## 🎯 Next Steps

1. ✅ Deploy the CloudFormation stack
2. ✅ Test Load Balancer URL
3. ✅ Verify Auto Scaling behavior
4. ✅ Monitor CloudWatch metrics
5. ✅ Configure custom domain (Route 53)
6. ✅ Add SSL certificate (HTTPS)
7. ✅ Implement CI/CD pipeline
8. ✅ Set up monitoring alerts

---

## 📚 Additional Resources

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [CloudFormation Best Practices](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html)
- [Auto Scaling Best Practices](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-best-practices.html)
- [Application Load Balancer Guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)

---

**Your infrastructure is now code! 🎉**
