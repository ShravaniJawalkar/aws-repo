# Web Application S3 Image Management - Quick Start Guide

## What's New

The enhanced web application includes the following S3 image management features:

✅ **Upload Image** - Upload images to S3 bucket with metadata
✅ **Download Image** - Download specific image by name
✅ **Show Image Metadata** - View metadata for a specific image (size, type, last modified, ETag)
✅ **Random Image Metadata** - Get metadata for a randomly selected image
✅ **Delete Image** - Remove images from the bucket
✅ **Image Gallery** - Beautiful gallery view of all images
✅ **EC2 Metadata Display** - Shows current region and availability zone

## Files Included

```
web-dynamic-app/
├── app.js                      # Original EC2 metadata app
├── app-s3-enhanced.js         # NEW: Enhanced with S3 image features
├── package.json               # UPDATED: Added AWS SDK and dependencies
├── upload-to-s3.ps1          # PowerShell script to upload app to S3
├── upload-to-s3.sh           # Bash script to upload app to S3
├── DEPLOYMENT_GUIDE.md       # Detailed deployment instructions
└── QUICK_START.md            # This file
```

## Quick Deployment Steps

### Step 1: Upload Application Files to S3 (One-time setup)

**On Windows (PowerShell):**
```powershell
cd C:\Users\Shravani_Jawalkar\aws\web-dynamic-app
.\upload-to-s3.ps1
```

**On Linux/Mac (Bash):**
```bash
cd /path/to/aws/web-dynamic-app
bash upload-to-s3.sh
```

### Step 2: Update CloudFormation Template

Add IAM role to your CloudFormation template for S3 access:

```powershell
# Update the stack with the template that includes IAM role
aws cloudformation update-stack `
  --stack-name webProject-infrastructure `
  --template-body file://webproject-infrastructure-with-iam.yaml `
  --parameters `
    ParameterKey=ProjectName,ParameterValue=webproject `
    ParameterKey=ProjectAMI,ParameterValue=ami-05fb2447d4d3d2610 `
    ParameterKey=ProjectInstanceType,ParameterValue=t3.micro `
    ParameterKey=SSHLocation,ParameterValue=0.0.0.0/0 `
  --capabilities CAPABILITY_NAMED_IAM `
  --region ap-south-1 `
  --profile user-iam-profile
```

### Step 3: Connect to EC2 Instance

```powershell
# Get the EC2 instance IP
$instance = aws ec2 describe-instances `
  --filters "Name=tag:aws:cloudformation:stack-name,Values=webProject-infrastructure" `
  --query 'Reservations[0].Instances[0]' `
  --region ap-south-1 `
  --profile user-iam-profile | ConvertFrom-Json

Write-Host "Instance IP: $($instance.PublicIpAddress)"
Write-Host "Instance ID: $($instance.InstanceId)"
```

Then SSH to the instance:
```bash
ssh -i web-server.ppk ec2-user@<instance-ip>
```

### Step 4: Deploy Application on EC2

Once connected to the EC2 instance:

```bash
# Create app directory
mkdir -p ~/webapp
cd ~/webapp

# Download application files from S3
aws s3 cp s3://shravani-jawalkar-webproject-bucket/app-s3-enhanced.js . --region ap-south-1
aws s3 cp s3://shravani-jawalkar-webproject-bucket/package.json . --region ap-south-1

# Install Node.js (if not already installed)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
nvm install 18

# Install dependencies
npm install

# Start the application
export S3_BUCKET=shravani-jawalkar-webproject-bucket
npm start
```

### Step 5: Access the Application

```powershell
# Get Load Balancer DNS
$lbDns = aws cloudformation describe-stacks `
  --stack-name webProject-infrastructure `
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' `
  --region ap-south-1 `
  --profile user-iam-profile

Write-Host "Access application at: http://$lbDns"
```

## API Endpoints

All API endpoints are accessible through the web interface:

```
POST   /api/upload              - Upload an image
GET    /api/images              - List all images
GET    /api/images/:name        - Get image for display
GET    /api/download/:name      - Download specific image
GET    /api/metadata/:name      - Get metadata for specific image
GET    /api/random-metadata     - Get metadata for random image
DELETE /api/delete/:name        - Delete specific image
GET    /health                  - Health check
GET    /                        - Main UI
```

## Web UI Features

### Image Operations Panel (Left Side)
- **📤 Upload Image** - Select and upload an image file
- **📥 Download Image** - Download by entering image name
- **📋 Get Image Metadata** - View detailed info about an image
- **🎲 Random Image Metadata** - Get info about a random image
- **🗑️ Delete Image** - Remove an image from S3

### Image Gallery Panel (Right Side)
- **Gallery View** - Thumbnail view of all uploaded images
- **Quick Actions** - Download (📥) or Delete (🗑️) buttons on each thumbnail
- **Metadata Display** - Shows size, type, last modified date, and ETag
- **Status Messages** - Feedback for all operations

## Supported Image Formats

- JPEG (.jpg, .jpeg)
- PNG (.png)
- GIF (.gif)
- WebP (.webp)
- SVG (.svg)
- And all other standard image MIME types

## File Size Limits

- Maximum upload size: 10 MB
- S3 bucket storage: Unlimited

## Security Features

✓ Image file validation (only images allowed)
✓ File size limits to prevent abuse
✓ IAM role-based access to S3 bucket
✓ Metadata confirmation before deletion
✓ HTML/JavaScript sanitization on frontend

## Troubleshooting

### Problem: "Bucket name should not contain uppercase characters"
**Solution:** Ensure your bucket name is all lowercase
- Bucket: `shravani-jawalkar-webproject-bucket` ✓
- Bucket: `Shravani-Jawalkar-webproject-bucket` ✗

### Problem: S3 Access Denied
**Solution:** Verify IAM role has S3 permissions
```powershell
aws iam get-role-policy `
  --role-name <EC2-IAM-Role> `
  --policy-name S3BucketAccess `
  --region ap-south-1 `
  --profile user-iam-profile
```

### Problem: Application won't start
**Solution:** Check the logs
```bash
# On EC2 instance
pm2 logs web-app
```

### Problem: No images showing in gallery
**Solution:** Check S3 bucket
```powershell
aws s3 ls s3://shravani-jawalkar-webproject-bucket/ `
  --region ap-south-1 `
  --profile user-iam-profile
```

## Performance Optimization (Optional)

For production deployments:

1. **Add CloudFront Distribution** - Cache images globally
```powershell
# Add CloudFront in CloudFormation template
CloudFrontDistribution:
  Type: AWS::CloudFront::Distribution
  Properties:
    DistributionConfig:
      Enabled: true
      DefaultRootObject: index.html
      Origins:
        - DomainName: !GetAtt S3Bucket.DomainName
          S3OriginConfig: {}
      DefaultCacheBehavior:
        ViewerProtocolPolicy: redirect-to-https
        TargetOriginId: S3Origin
        ForwardedValues:
          QueryString: false
```

2. **Enable S3 Versioning** - Keep image history
```powershell
aws s3api put-bucket-versioning `
  --bucket shravani-jawalkar-webproject-bucket `
  --versioning-configuration Status=Enabled `
  --region ap-south-1 `
  --profile user-iam-profile
```

3. **Add Image Optimization** - Compress on upload
```javascript
// In app-s3-enhanced.js, add Sharp for image processing
npm install sharp
```

## Monitoring & Logs

### Check Application Logs
```bash
# On EC2 instance with PM2
pm2 logs web-app
pm2 monit  # Real-time monitoring
```

### Monitor S3 Bucket Metrics
```powershell
aws cloudwatch get-metric-statistics `
  --namespace AWS/S3 `
  --metric-name BucketSizeBytes `
  --dimensions Name=BucketName,Value=shravani-jawalkar-webproject-bucket `
  --start-time 2024-01-01T00:00:00Z `
  --end-time 2024-01-31T23:59:59Z `
  --period 86400 `
  --statistics Sum `
  --region ap-south-1 `
  --profile user-iam-profile
```

## What's Different from Original App

| Feature | Original | Enhanced |
|---------|----------|----------|
| EC2 Metadata Display | ✓ | ✓ |
| S3 Image Upload | ✗ | ✓ |
| S3 Image Download | ✗ | ✓ |
| Image Metadata | ✗ | ✓ |
| Random Image Metadata | ✗ | ✓ |
| Delete Images | ✗ | ✓ |
| Image Gallery | ✗ | ✓ |
| Web UI | Simple | Modern & Interactive |

## Dependencies

```json
{
  "express": "^4.18.2",        // Web framework
  "axios": "^1.6.0",           // HTTP client
  "aws-sdk": "^2.1400.0",      // AWS SDK for S3
  "multer": "^1.4.5-lts.1",    // File upload handling
  "dotenv": "^16.3.1"          // Environment variables
}
```

## Next Steps

1. ✅ Upload application files to S3
2. ✅ Update CloudFormation template with IAM role
3. ✅ Deploy stack to AWS
4. ✅ Connect to EC2 instance
5. ✅ Install and start the application
6. ✅ Access via Load Balancer DNS
7. 🔄 Upload test images and verify functionality
8. 📊 Monitor application logs and S3 bucket

## Support

For detailed deployment instructions, see: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

For the original EC2 metadata app, use: `app.js`

For the new S3 image management app, use: `app-s3-enhanced.js`
