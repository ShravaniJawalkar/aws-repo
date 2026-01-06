# Host Static Website on S3

Deploy your static website to Amazon S3 with public access and optional custom domain support.

## Prerequisites

- AWS Account with appropriate permissions
- Static website files (HTML, CSS, JavaScript, images, etc.)
- AWS CLI configured (optional, for CLI method)

---

## Task Overview

You will:
1. Create an S3 bucket for website hosting
2. Configure bucket for static website hosting
3. Upload your website files
4. Set appropriate permissions for public access
5. Access your website via S3 URL
6. (Optional) Configure custom domain with Route 53

---

## Step 1: Create S3 Bucket

### AWS Console:
1. Go to **S3 Console** → **Buckets** → **Create bucket**
2. Configure:
   - **Bucket name**: `static-website-bucket` (must be globally unique)
     - For custom domain: Use your domain name (e.g., `www.example.com`)
   - **AWS Region**: Choose your preferred region
   - **Block Public Access settings**: 
     - ⚠️ **UNCHECK** "Block all public access"
     - Acknowledge the warning (required for public website)
   - Leave other settings as default
3. Click **Create bucket**

### AWS CLI:
```bash
aws s3 mb s3://static-website-bucket --region ap-south-1 --profile user-s3-profile
```

---

## Step 2: Enable Static Website Hosting

### AWS Console:
1. Select your bucket → **Properties** tab
2. Scroll to **Static website hosting** section
3. Click **Edit**
4. Configure:
   - **Static website hosting**: Enable
   - **Hosting type**: Host a static website
   - **Index document**: `index.html`
   - **Error document**: `error.html` (optional, but recommended)
5. Click **Save changes**
6. **Note the Endpoint URL** (e.g., `http://<bucket-name>.s3-website-<region>.amazonaws.com`)

### AWS CLI:
```bash
aws s3 website s3://static-website-bucket/ \
  --index-document index.html \
  --error-document error.html
```

---

## Step 3: Upload Website Files

### AWS Console:
1. Select your bucket → **Objects** tab
2. Click **Upload**
3. Click **Add files** or **Add folder**
4. Select all your website files (ensure `index.html` is in the root)
5. Click **Upload**

### AWS CLI:
```bash
# Upload all files from your website directory
aws s3 sync ./static-website/ s3://static-website-bucket/ --acl public-read

# Or upload specific files
aws s3 cp index.html s3://static-website-bucket/ --acl public-read
aws s3 cp styles.css s3://static-website-bucket/ --acl public-read
```

### PowerShell:
```powershell
# Upload entire directory
aws s3 sync .\static-website\ s3://static-website-bucket/ --acl public-read

# Upload with metadata for proper content types
aws s3 sync .\static-website\ s3://static-website-bucket/ `
  --acl public-read `
  --exclude "*" `
  --include "*.html" `
  --content-type "text/html"
```

---

## Step 4: Configure Bucket Policy for Public Access

You need to add a bucket policy to allow public read access to your website files.

### AWS Console:
1. Select your bucket → **Permissions** tab
2. Scroll to **Bucket policy** section
3. Click **Edit**
4. Paste the following policy (replace `<your-bucket-name>`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::static-website-bucket/*"
    }
  ]
}
```

5. Click **Save changes**

### AWS CLI:
```bash
# Create policy file first (bucket-website-policy.json)
aws s3api put-bucket-policy \
  --bucket <your-bucket-name> \
  --policy file://bucket-website-policy.json
```

---

## Step 5: Test Your Website

### Access Methods:

1. **S3 Website Endpoint** (from Step 2):
   ```
   http://<bucket-name>.s3-website-<region>.amazonaws.com
   ```

2. **Direct S3 URL**:
   ```
   https://<bucket-name>.s3.amazonaws.com/index.html
   ```

### Verification Checklist:
- ✅ Homepage loads correctly
- ✅ CSS and JavaScript files load properly
- ✅ Images display correctly
- ✅ Internal links work
- ✅ Error page displays for non-existent pages (test with `/nonexistent.html`)

---

## Step 6 (Optional): Configure Custom Domain

If you want to use your own domain (e.g., `www.example.com`):

### Prerequisites:
- Domain registered (via Route 53 or external registrar)
- Bucket name MUST match your domain name exactly

### Configure Route 53:

1. Go to **Route 53** → **Hosted zones**
2. Select your domain or create a hosted zone
3. Click **Create record**
4. Configure:
   - **Record name**: `www` (or leave blank for apex domain)
   - **Record type**: A
   - **Alias**: Yes
   - **Route traffic to**: 
     - Choose "Alias to S3 website endpoint"
     - Select your region
     - Select your bucket
5. Click **Create records**

### DNS Propagation:
- Wait 5-60 minutes for DNS changes to propagate
- Test with: `nslookup www.example.com`

---

## Step 7 (Optional): Enable HTTPS with CloudFront

S3 website endpoints don't support HTTPS by default. To enable HTTPS:

### Create CloudFront Distribution:

1. Go to **CloudFront** → **Create distribution**
2. Configure:
   - **Origin domain**: Your S3 website endpoint (not the bucket name!)
   - **Name**: Leave as default
   - **Viewer protocol policy**: Redirect HTTP to HTTPS
   - **Allowed HTTP methods**: GET, HEAD
   - **Default root object**: `index.html`
   - **Custom SSL certificate**: Request/import certificate via ACM (optional)
3. Click **Create distribution**
4. Wait for deployment (10-15 minutes)
5. Access via: `https://<distribution-id>.cloudfront.net`

---

## Cost Estimation

### S3 Storage:
- **Storage**: ~$0.023 per GB/month (Standard storage)
- **Requests**: ~$0.0004 per 1,000 GET requests
- **Data Transfer**: First 100GB/month out to internet: $0.09/GB

### Example for a small website:
- 100 MB website + 10,000 monthly visits
- **Cost**: ~$0.50 - $2.00/month

### CloudFront (if used):
- **Data Transfer**: First 1TB/month: $0.085/GB
- **Requests**: $0.0075 per 10,000 HTTP/HTTPS requests
- Often cheaper than direct S3 for high-traffic sites

---

## File Structure Best Practices

```
static-website/
├── index.html          # Required: Homepage
├── error.html          # Recommended: Error page
├── about.html
├── contact.html
├── styles.css
├── scripts.js
├── images/
│   ├── logo.png
│   └── banner.jpg
└── assets/
    ├── fonts/
    └── icons/
```

### Important Notes:
- All links should be relative or absolute paths
- File names are case-sensitive
- Use lowercase and hyphens (e.g., `about-us.html`)
- Ensure proper file permissions

---

## Updating Your Website

### To update files:

**AWS Console:**
1. Go to your bucket
2. Select file(s) to update
3. Click **Upload** → Replace existing files

**AWS CLI:**
```bash
# Sync changes (uploads new/modified files only)
aws s3 sync ./static-website/ s3://<your-bucket-name>/ --acl public-read --delete

# Single file update
aws s3 cp index.html s3://<your-bucket-name>/index.html --acl public-read
```

### Clear Browser Cache:
- If changes don't appear, clear browser cache or use incognito mode
- For CloudFront, create an invalidation: `/*`

---

## Security Best Practices

1. **Use CloudFront** for HTTPS and DDoS protection
2. **Enable Versioning** to protect against accidental deletions
3. **Enable Logging** to track access patterns
4. **Use IAM Policies** to restrict bucket management access
5. **Regular Backups** of your website files
6. **Content Security Policy** headers (via CloudFront functions)

---

## Troubleshooting

### Issue: 403 Forbidden Error
**Causes:**
- Bucket policy not configured correctly
- Block public access is enabled
- Object ACLs are not set to public-read

**Solutions:**
- Verify bucket policy allows `s3:GetObject` for `*` principal
- Check Block Public Access settings are disabled
- Ensure files have public-read ACL

### Issue: 404 Not Found
**Causes:**
- File doesn't exist
- Wrong file path
- Case-sensitivity mismatch

**Solutions:**
- Verify file exists in bucket with exact name
- Check file paths in HTML (use relative paths)
- Ensure index.html is in the root directory

### Issue: CSS/JS Not Loading
**Causes:**
- Wrong MIME type
- CORS issues
- Wrong file path

**Solutions:**
- Set correct `Content-Type` when uploading
- Check browser console for errors
- Verify file paths in HTML

### Issue: Website Endpoint Not Working
**Causes:**
- Static website hosting not enabled
- Wrong region in URL

**Solutions:**
- Enable static website hosting in bucket properties
- Use correct endpoint format: `http://<bucket>.s3-website-<region>.amazonaws.com`

---

## Cleanup (To Avoid Charges)

### To delete the website:

1. **Empty the bucket** (required before deletion):
   ```bash
   aws s3 rm s3://<your-bucket-name>/ --recursive
   ```

2. **Delete the bucket**:
   ```bash
   aws s3 rb s3://<your-bucket-name>
   ```

3. **Delete CloudFront distribution** (if created):
   - Disable distribution first
   - Wait for status change
   - Then delete

4. **Remove Route 53 records** (if configured)

---

## Summary Checklist

- [ ] Create S3 bucket with unique name
- [ ] Disable "Block all public access"
- [ ] Enable static website hosting
- [ ] Upload website files (including index.html)
- [ ] Configure bucket policy for public read access
- [ ] Test website using S3 endpoint URL
- [ ] (Optional) Configure custom domain with Route 53
- [ ] (Optional) Enable HTTPS with CloudFront
- [ ] Document your website URL
- [ ] Set up monitoring/logging if needed

---

## Quick Command Reference

```powershell
# Create bucket
aws s3 mb s3://my-website-bucket --region us-east-1

# Enable website hosting
aws s3 website s3://my-website-bucket/ --index-document index.html --error-document error.html

# Upload files
aws s3 sync .\static-website\ s3://my-website-bucket/ --acl public-read

# Set bucket policy
aws s3api put-bucket-policy --bucket my-website-bucket --policy file://bucket-policy.json

# List bucket contents
aws s3 ls s3://my-website-bucket/

# Remove all files
aws s3 rm s3://my-website-bucket/ --recursive

# Delete bucket
aws s3 rb s3://my-website-bucket
```

---

**Your static website is now live on S3! 🎉**

**Website URL**: `http://<your-bucket-name>.s3-website-<region>.amazonaws.com`
