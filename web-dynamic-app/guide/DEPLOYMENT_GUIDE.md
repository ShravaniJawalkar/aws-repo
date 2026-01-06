# Web Application with S3 Image Management - Deployment Guide

## Overview
This guide covers deploying the enhanced web application that includes S3 image management functionality with the following features:
- Upload images to S3
- Download images by name
- View image metadata (size, type, last modified)
- View random image metadata
- Delete images
- Gallery view of all images

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **EC2 Instance** running the CloudFormation stack
3. **S3 Bucket** created (the CloudFormation template creates this)
4. **IAM Role** with S3 access attached to EC2 instance

## Step 1: Update CloudFormation Template

The template should include:
- EC2 IAM instance profile with S3 bucket access permissions
- Security group allowing HTTP/HTTPS/SSH
- Launch template with the web application

### Add to your CloudFormation template:

```yaml
# IAM Role for EC2 to access S3
EC2S3Role:
  Type: AWS::IAM::Role
  Properties:
    AssumeRolePolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Principal:
            Service: ec2.amazonaws.com
          Action: 'sts:AssumeRole'
    Policies:
      - PolicyName: S3BucketAccess
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
            - Effect: Allow
              Action:
                - 's3:GetObject'
                - 's3:PutObject'
                - 's3:DeleteObject'
                - 's3:ListBucket'
              Resource:
                - !Sub 'arn:aws:s3:::${S3BucketName}'
                - !Sub 'arn:aws:s3:::${S3BucketName}/*'

EC2InstanceProfile:
  Type: AWS::IAM::InstanceProfile
  Properties:
    Roles:
      - !Ref EC2S3Role

# Add InstanceProfile to Launch Template:
ProjectLaunchTemplate:
  Type: AWS::EC2::LaunchTemplate
  Properties:
    LaunchTemplateData:
      IamInstanceProfile:
        Arn: !GetAtt EC2InstanceProfile.Arn
      # ... rest of template
```

## Step 2: Deploy Stack

```powershell
# Update stack with IAM role
aws cloudformation update-stack `
  --stack-name webProject-infrastructure `
  --template-body file://webproject-infrastructure.yaml `
  --parameters `
    ParameterKey=ProjectName,ParameterValue=webproject `
    ParameterKey=ProjectAMI,ParameterValue=ami-05fb2447d4d3d2610 `
    ParameterKey=ProjectInstanceType,ParameterValue=t3.micro `
    ParameterKey=SSHLocation,ParameterValue=0.0.0.0/0 `
  --capabilities CAPABILITY_NAMED_IAM `
  --region ap-south-1 `
  --profile user-iam-profile

# Wait for update to complete
aws cloudformation wait stack-update-complete `
  --stack-name webProject-infrastructure `
  --region ap-south-1 `
  --profile user-iam-profile
```

## Step 3: Connect to EC2 Instance

```powershell
# Get instance details
$instance = aws ec2 describe-instances `
  --filters "Name=tag:aws:cloudformation:stack-name,Values=webProject-infrastructure" `
  --query 'Reservations[0].Instances[0]' `
  --region ap-south-1 `
  --profile user-iam-profile | ConvertFrom-Json

$publicIp = $instance.PublicIpAddress
Write-Host "Public IP: $publicIp"

# Connect via SSH (Linux/Mac)
ssh -i "web-server.ppk" ec2-user@$publicIp

# Or use Session Manager (if configured)
aws ssm start-session --target $instance.InstanceId --region ap-south-1 --profile user-iam-profile
```

## Step 4: Deploy Web Application on EC2

Once connected to the EC2 instance:

```bash
# Navigate to app directory (or create one)
cd /home/ec2-user
mkdir -p webapp
cd webapp

# Copy the application files to EC2
# Option 1: Using git
git clone <your-repo-url> .

# Option 2: Using S3
aws s3 cp s3://shravani-jawalkar-webproject-bucket/app-s3-enhanced.js . --region ap-south-1
aws s3 cp s3://shravani-jawalkar-webproject-bucket/package.json . --region ap-south-1

# Install Node.js and npm (if not installed via AMI)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
nvm install 18
nvm use 18

# Install dependencies
npm install

# Set environment variable for S3 bucket
export S3_BUCKET=shravani-jawalkar-webproject-bucket

# Start the application
npm start
# Or use PM2 for production
npm install -g pm2
pm2 start app-s3-enhanced.js --name "web-app"
pm2 startup
pm2 save
```

## Step 5: Configure Auto Scaling Group User Data

Update your CloudFormation template's Launch Template User Data:

```yaml
ProjectLaunchTemplate:
  Type: AWS::EC2::LaunchTemplate
  Properties:
    LaunchTemplateData:
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash
          set -e
          
          # Update system
          yum update -y
          
          # Install Node.js
          curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
          export NVM_DIR="$HOME/.nvm"
          source "$NVM_DIR/nvm.sh"
          nvm install 18
          
          # Create application directory
          mkdir -p /home/ec2-user/webapp
          cd /home/ec2-user/webapp
          
          # Copy application from S3
          aws s3 cp s3://${S3BucketName}/app-s3-enhanced.js . --region ${AWS::Region}
          aws s3 cp s3://${S3BucketName}/package.json . --region ${AWS::Region}
          
          # Install dependencies
          npm install
          
          # Install PM2
          npm install -g pm2
          
          # Start application
          export S3_BUCKET=${S3BucketName}
          pm2 start app-s3-enhanced.js --name "web-app"
          pm2 startup
          pm2 save
          
          # Optional: Enable auto-restart on reboot
          systemctl enable pm2-ec2-user
```

## Step 6: Upload Application Files to S3

Before deploying, upload the application files to your S3 bucket:

```powershell
# Navigate to the app directory
cd C:\Users\Shravani_Jawalkar\aws\web-dynamic-app

# Upload application files to S3
aws s3 cp app-s3-enhanced.js s3://shravani-jawalkar-webproject-bucket/ --region ap-south-1 --profile user-iam-profile
aws s3 cp package.json s3://shravani-jawalkar-webproject-bucket/ --region ap-south-1 --profile user-iam-profile
```

## Step 7: Test the Application

### Access the web interface:

```powershell
# Get Load Balancer DNS
$lbDns = aws cloudformation describe-stacks `
  --stack-name webProject-infrastructure `
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' `
  --region ap-south-1 `
  --profile user-iam-profile | ConvertFrom-Json

Write-Host "Access at: $lbDns"
```

### Test API endpoints:

```powershell
$lbUrl = "http://your-load-balancer-dns"

# Upload an image
$imagePath = "C:\path\to\image.jpg"
$fileBytes = [System.IO.File]::ReadAllBytes($imagePath)
$fileName = [System.IO.Path]::GetFileName($imagePath)

Invoke-WebRequest `
  -Uri "$lbUrl/api/upload" `
  -Method POST `
  -InFile $imagePath

# List all images
Invoke-WebRequest "$lbUrl/api/images" | Select-Object -ExpandProperty Content

# Get image metadata
Invoke-WebRequest "$lbUrl/api/metadata/image-name.jpg" | Select-Object -ExpandProperty Content

# Get random image metadata
Invoke-WebRequest "$lbUrl/api/random-metadata" | Select-Object -ExpandProperty Content

# Download image
Invoke-WebRequest -Uri "$lbUrl/api/download/image-name.jpg" -OutFile "C:\downloaded-image.jpg"

# Delete image
Invoke-WebRequest "$lbUrl/api/delete/image-name.jpg" -Method DELETE
```

## Step 8: Verify S3 Bucket Access

```powershell
# List objects in S3 bucket
aws s3 ls s3://shravani-jawalkar-webproject-bucket/ `
  --region ap-south-1 `
  --profile user-iam-profile

# Check object metadata
aws s3api head-object `
  --bucket shravani-jawalkar-webproject-bucket `
  --key image-name.jpg `
  --region ap-south-1 `
  --profile user-iam-profile
```

## Troubleshooting

### S3 Access Denied Errors
- Verify EC2 IAM role has S3 permissions
- Check bucket policy allows access from the IAM role
- Verify bucket name matches in application

### Application not running
```bash
# SSH to EC2 instance
# Check PM2 logs
pm2 logs web-app

# Check Node.js installation
node --version
npm --version

# Restart application
pm2 restart web-app
```

### S3 Bucket not found
- Verify bucket name in S3_BUCKET environment variable
- Check bucket exists in the same region
- Verify bucket name format (lowercase, no uppercase)

## Features

✅ **Upload Image** - Upload images to S3 bucket
✅ **Download Image** - Download specific image by name
✅ **Image Metadata** - View metadata for specific image (size, type, date)
✅ **Random Metadata** - Get metadata for random image
✅ **Delete Image** - Remove image from bucket
✅ **Image Gallery** - View all images in gallery format
✅ **AWS Metadata** - Display EC2 region and availability zone

## File Structure

```
web-dynamic-app/
├── app.js                 # Original metadata-only version
├── app-s3-enhanced.js    # Enhanced version with S3 features
├── package.json          # Node.js dependencies
└── DEPLOYMENT_GUIDE.md   # This file
```

## Security Considerations

1. **IAM Permissions**: Limit S3 bucket access to specific bucket
2. **File Upload Validation**: Only accept image files
3. **File Size Limits**: 10MB limit on uploads
4. **CORS**: Configure CORS on S3 bucket if needed
5. **SSL/TLS**: Use HTTPS in production (configure on ALB)

## Next Steps

1. Add authentication/authorization
2. Implement image resizing/optimization
3. Add metadata tags to images
4. Implement image search functionality
5. Add CloudFront distribution for faster access
