# Sub-task 2 – Automate EC2 Configuration

## Objective
Create and configure an EC2 instance to automatically serve a static website from S3, then create a custom AMI for replication.

## Prerequisites
- Completed Module 2 (S3 readonly IAM role exists)
- Completed Module 3 (Static website stored in S3)
- AWS CLI configured or AWS Console access
- S3 bucket name with static website files

## Step 1: Launch EC2 Instance with IAM Role

Launch an Amazon EC2 instance using the AWS CLI. Use the Amazon Linux 2 AMI and a `t3.micro` instance type. Attach the S3 read-only IAM role created in Module 2.

Provide a user data script that executes on startup to:
1. Install an Apache web server (`httpd`).
2. Start and enable the `httpd` service.
3. Use the AWS CLI to sync the static website files from your S3 bucket to the web server's document root (`/var/www/html`).

Remember to replace `<your-s3-bucket-name>` with the actual name of your S3 bucket.

**User Data Script:**
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
aws configure --profile user-s3-profile
aws s3 sync s3://shravani-jawalkar-web-project /var/www/html --profile user-s3-profile