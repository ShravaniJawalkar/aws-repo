# Verify S3 Connectivity from DB Instance

This guide helps you verify that the DB instance can access S3 through the VPC Endpoint.

## Prerequisites
- VPC Endpoint created and attached to the DB subnet route table
- ReadAccessRoleS3 IAM role attached to the DB instance
- SSH access to the DB instance (via Bastion host)

## Step 1: Connect to DB Instance via Bastion Host

First, connect to your Bastion host, then from there connect to the DB instance:

### Connect to Bastion Host:
```bash
ssh -i web-server.pem ec2-user@<bastion-host-public-ip>
```

### From Bastion, connect to DB Instance:
```bash
ssh -i web-server.pem ec2-user@<db-instance-private-ip>
```

## Step 2: Verify AWS CLI is installed

Once connected to the DB instance, check if AWS CLI is available:

```bash
aws --version
```

If not installed, you can install it:

**Amazon Linux 2:**
```bash
sudo yum install aws-cli -y
```

**Ubuntu:**
```bash
sudo apt-get update
sudo apt-get install awscli -y
```

## Step 3: Test S3 Access

Test listing objects in your S3 bucket:

```bash
# List all buckets (to verify general S3 access)
aws s3 ls

# List objects in a specific bucket
aws s3 ls s3://<your-bucket-name>/

# Try to download a file
aws s3 cp s3://<your-bucket-name>/<filename> ./
```

## Step 4: Verify VPC Endpoint is being used

Check that traffic is going through the VPC Endpoint (not the internet):

```bash
# Check the route table
aws ec2 describe-route-tables --region <your-region>

# Verify VPC Endpoint
aws ec2 describe-vpc-endpoints --region <your-region>
```

## Expected Results

✅ **Success Indicators:**
- `aws s3 ls` command returns list of buckets
- `aws s3 ls s3://<bucket-name>` shows bucket contents
- File downloads successfully
- No "Access Denied" or connection timeout errors

❌ **Failure Indicators:**
- "Unable to locate credentials" - IAM role not attached properly
- "Access Denied" - IAM role permissions insufficient
- Connection timeout - VPC Endpoint not configured or route table not updated
- "Could not connect to the endpoint URL" - Network configuration issue

## Troubleshooting

### Issue: Unable to locate credentials
**Solution:** Verify the IAM role is attached to the instance:
```bash
curl http://169.254.169.254/latest/meta-data/iam/info
```

### Issue: Access Denied
**Solution:** Check the IAM role has the correct S3 read permissions:
```bash
aws iam get-role-policy --role-name ReadAccessRoleS3 --policy-name <policy-name>
```

### Issue: Connection timeout
**Solution:** 
1. Verify VPC Endpoint exists and is in "available" state
2. Check the route table associated with DB subnet has route to S3 via VPC Endpoint
3. Verify security group allows outbound traffic

## Cost Consideration

⚠️ **Important:** VPC Gateway Endpoints for S3 are **FREE**. There's no hourly charge for Gateway endpoints (unlike Interface endpoints). However, remember to clean up resources after testing to avoid charges for other resources like:
- NAT Gateway (~$0.045/hour)
- EC2 instances
- Elastic IPs (if not attached to running instances)

## Alternative: Using VPC Endpoint via AWS Console

To verify VPC Endpoint in AWS Console:
1. Go to **VPC Dashboard** → **Endpoints**
2. Find your endpoint (`<ProjectName>-VPC-Endpoint`)
3. Check **Status** is "Available"
4. Verify **Route Tables** tab shows your DB subnet route table
5. Check **Policy** tab to ensure it allows S3 access

---

**Next Steps:** After verification, review and delete resources as mentioned in the module to save costs.
