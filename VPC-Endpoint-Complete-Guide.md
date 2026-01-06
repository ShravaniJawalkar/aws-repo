# Sub-task 3: Connect to Resources Outside the VPC - Complete Guide

This guide provides step-by-step instructions to enable S3 access from your DB instance using a VPC Endpoint.

## Overview

The DB instance is in a private subnet without Internet access. To allow it to access S3, we'll:
1. Create a VPC Gateway Endpoint for S3
2. Attach the ReadAccessRoleS3 IAM role to the DB instance
3. Verify connectivity

## Prerequisites

- VPC with DB subnet created (from Module 6)
- ReadAccessRoleS3 IAM role created (from Module 3)
- S3 bucket created (from Module 4)
- DB instance running in the private DB subnet
- Bastion host for SSH access to the DB instance

---

## Method 1: AWS Management Console (Recommended for Beginners)

### Step 1: Create VPC Endpoint

1. Open **AWS Console** → **VPC** → **Endpoints**
2. Click **Create Endpoint**
3. Configure:
   - **Name tag**: `<ProjectName>-VPC-Endpoint`
   - **Service category**: AWS services
   - **Services**: Search and select `com.amazonaws.<region>.s3` (Type: Gateway)
   - **VPC**: Select your `<ProjectName>-Network` VPC
   - **Route tables**: Select the `<ProjectName>-DbSubnet-A` route table
   - **Policy**: Leave as "Full access" (or customize if needed)
4. Click **Create endpoint**

### Step 2: Attach IAM Role to DB Instance

1. Open **AWS Console** → **EC2** → **Instances**
2. Select your DB instance
3. Click **Actions** → **Security** → **Modify IAM role**
4. Select `ReadAccessRoleS3` from the dropdown
5. Click **Update IAM role**

### Step 3: Verify the Setup

See the "Verification Steps" section below.

---

## Method 2: AWS CLI (For Automation)

### Prerequisites for CLI
- AWS CLI installed and configured
- Appropriate AWS credentials with permissions

### Step 1: Set Variables

Edit the scripts and replace placeholders:
- `<YourProjectName>` → Your project name
- `<your-region>` → Your AWS region (e.g., us-east-1, ap-south-1)

### Step 2: Create VPC Endpoint

Run the PowerShell script:
```powershell
.\create-vpc-endpoint.ps1
```

Or manually:
```powershell
# Replace variables
$PROJECT_NAME = "YourProjectName"
$REGION = "your-region"

# Get VPC ID
$VPC_ID = aws ec2 describe-vpcs `
  --filters "Name=tag:Name,Values=$PROJECT_NAME-Network" `
  --query "Vpcs[0].VpcId" `
  --output text `
  --region $REGION

# Get Route Table ID
$ROUTE_TABLE_ID = aws ec2 describe-route-tables `
  --filters "Name=tag:Name,Values=$PROJECT_NAME-DbSubnet-A" `
  --query "RouteTables[0].RouteTableId" `
  --output text `
  --region $REGION

# Create VPC Endpoint
aws ec2 create-vpc-endpoint `
  --vpc-id $VPC_ID `
  --service-name "com.amazonaws.$REGION.s3" `
  --route-table-ids $ROUTE_TABLE_ID `
  --tag-specifications "ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=$PROJECT_NAME-VPC-Endpoint}]" `
  --region $REGION
```

### Step 3: Attach IAM Role

Run the PowerShell script:
```powershell
.\attach-iam-role-db.ps1
```

---

## Verification Steps

### 1. Connect to DB Instance

You'll need to connect through the Bastion host since the DB instance is in a private subnet.

**Step 1: Copy the key to Bastion (if not already done):**
```powershell
scp -i web-server.pem web-server.pem ec2-user@<bastion-public-ip>:~/
```

**Step 2: Connect to Bastion:**
```powershell
ssh -i web-server.pem ec2-user@<bastion-public-ip>
```

**Step 3: From Bastion, connect to DB instance:**
```bash
chmod 400 web-server.pem
ssh -i web-server.pem ec2-user@<db-private-ip>
```

### 2. Test S3 Access

Once connected to the DB instance:

```bash
# Verify IAM role is attached
curl http://169.254.169.254/latest/meta-data/iam/info

# List all S3 buckets
aws s3 ls

# List objects in your bucket
aws s3 ls s3://<your-bucket-name>/

# Download a test file
aws s3 cp s3://<your-bucket-name>/file1.txt ./test-download.txt

# Verify the download
cat test-download.txt
```

### 3. Expected Output

✅ **Successful connection should show:**
- IAM role information from metadata endpoint
- List of S3 buckets
- List of objects in the bucket
- Successfully downloaded file

❌ **If you encounter errors:**
- "Unable to locate credentials" → IAM role not attached
- "Access Denied" → Check IAM role permissions
- Timeout → Check VPC Endpoint and route table configuration

---

## Understanding VPC Endpoints

### What is a VPC Endpoint?

A VPC Endpoint enables private connectivity between your VPC and supported AWS services without requiring:
- Internet Gateway
- NAT Device
- VPN Connection
- AWS Direct Connect

### Types of VPC Endpoints:

1. **Gateway Endpoints** (Free):
   - For Amazon S3 and DynamoDB
   - Uses route table entries
   - No hourly charges or data processing charges

2. **Interface Endpoints** (Paid):
   - For other AWS services
   - Uses ENI (Elastic Network Interface)
   - Has hourly charges (~$7.50/month per endpoint)

### How it Works:

```
DB Instance (Private Subnet)
    ↓
Route Table with VPC Endpoint Route
    ↓
VPC Gateway Endpoint
    ↓
Amazon S3 (via AWS Private Network)
```

---

## Cost Analysis

### VPC Gateway Endpoint for S3:
- **Creation**: Free
- **Hourly charge**: Free
- **Data transfer**: Free (within same region)
- **Cross-region data transfer**: Standard S3 rates apply

### Important Note:
The module documentation mentions $0.30/day cost, but that's for **Interface Endpoints**. Gateway Endpoints for S3 are actually **FREE**! However, you should still clean up other resources to avoid charges.

---

## Resource Cleanup (Important!)

As mentioned in the module, it's time to clean up resources to save costs:

### Resources to Delete:

#### Module 4: S3
- `bucket1` (static website)
- `bucket2` (replication bucket)

#### Module 5: EC2
- All EC2 instances (except keep the custom AMI)
- Security Groups (unused)
- EBS volumes (if detached)
- Elastic IPs (release unused)
- Load Balancer
- Auto Scaling Group

#### Module 6: VPC
- 1 VPC Endpoint (this one)
- 1 NAT Gateway (expensive!)
- 1 Elastic IP for NAT
- 4 EC2 Instances (Bastion, Public, Private, DB)
- 3 Security Groups
- Internet Gateway
- Route Tables (associated resources)
- Subnets (4 total)
- VPC

### Resources to KEEP:
- IAM Roles and Policies from Module 3
- Custom AMI with web application from Module 5

### Deletion Order (Important):

1. Terminate EC2 instances first
2. Delete Load Balancer and Auto Scaling Group
3. Delete NAT Gateway and wait for deletion
4. Release Elastic IPs
5. Delete VPC Endpoint
6. Delete VPC (this will clean up subnets, route tables, IGW)
7. Delete S3 buckets (empty them first)
8. Delete unused Security Groups
9. Delete unattached EBS volumes

---

## Quick Reference Commands

### Check VPC Endpoint Status:
```powershell
aws ec2 describe-vpc-endpoints --region <region>
```

### Check IAM Role on Instance:
```bash
# From the DB instance
curl http://169.254.169.254/latest/meta-data/iam/info
```

### Test S3 Access:
```bash
aws s3 ls s3://<bucket-name>/
```

### Delete VPC Endpoint:
```powershell
aws ec2 delete-vpc-endpoints --vpc-endpoint-ids <endpoint-id> --region <region>
```

---

## Troubleshooting Guide

### Problem: Cannot connect to DB instance
**Solution:** Ensure Bastion host is running and you're using the correct private IP

### Problem: IAM role not working
**Solution:** Wait 1-2 minutes after attaching the role for it to propagate

### Problem: S3 access denied
**Solution:** Verify the ReadAccessRoleS3 role has the correct S3 permissions

### Problem: VPC Endpoint not working
**Solution:** Check the route table is correctly associated with the DB subnet

### Problem: High AWS costs
**Solution:** Delete the NAT Gateway immediately if not in use (most expensive resource)

---

## Summary

You've successfully:
1. ✅ Created a VPC Gateway Endpoint for S3 access
2. ✅ Attached ReadAccessRoleS3 IAM role to the DB instance
3. ✅ Verified S3 connectivity from the private DB instance

The DB instance can now access S3 privately without internet access, using AWS's internal network via the VPC Endpoint.

**Next:** Clean up resources to save costs before moving to the next module!
