
Header:
    description: "Sub-task 1 - Create and Deploy a Static Website to AWS S3
    mode: Agent
    model: claude-3-5-sonnet
    tools: ["AWS CLI", "S3 API"]
Body:
# Sub-task 1: Create and Deploy a Static Website to AWS S3

## Overview
Create a lightweight static website and deploy it to an AWS S3 bucket with static website hosting enabled.

## Requirements

### 1. Create a Static Website

Your static website should meet the following criteria:

- **Content**: Include a couple of interlinked HTML files OR a single HTML page with CSS styles
- **Lightweight**: Avoid heavy media resources (large images, animations, videos)
- **Static Only**: No runtime environment required (no JVM, Node.js, etc.)
- **No Backend**: Frontend only - no server-side components needed

> **Note**: This is a foundational task. You'll build a fully functioning web application in modules 3-8.

### 2. Create an S3 Bucket (bucket1)

Create an S3 bucket following these naming conventions:

- Must begin with a **letter**
- Must include your **full name**
- **No uppercase characters** allowed
- Choose a **generic name** for reusability in future web application development

**Example**: `shravani-jawalkar-web-project`

### 3. Upload Website to S3

Upload your static website files to bucket1:

```bash
aws s3 cp <local-directory> s3://shravani-jawalkar-web-project/ --recursive --profile user-s3-profile
```

- Use **AWS CLI** for the upload process
- Use a **named profile** `user-s3-profile` with appropriate permissions from the previous module

**Example command**:
```bash
aws s3 cp <local-directory> s3://shravani-jawalkar-web-project/ --recursive --profile user-s3-profile
```

### 4. Enable Static Website Hosting

- Enable static website hosting on bucket1
```bash
aws s3 website s3://shravani-jawalkar-web-project/ --index-document index.html --error-document error.html --profile user-s3-profile
```
- Configure the index document (e.g., `index.html`)
- Configure error document if needed (e.g., `error.html`)

### 5. Configure Public Access

```bash
Make your website publicly accessible:

1. **Grant Required Permissions**: Ensure your user has permissions to access AWS Access Analyzer
2. **Add Bucket Policy**: Apply an appropriate bucket policy to allow public read access to website content
3. **Verify Access**: Your website should be accessible via the S3 website endpoint

**Example bucket policy**:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::<bucket1-name>/*"
        }
    ]
}
```

## Deliverables

- ✅ Lightweight static website (HTML/CSS files)
- ✅ S3 bucket created with proper naming conventions
- ✅ Website files uploaded via AWS CLI
- ✅ Static website hosting enabled
- ✅ Website accessible via S3 website endpoint
