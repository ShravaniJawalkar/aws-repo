
Header:
    description: "This prompt list outlines the steps to allocate and configure EC2 resources for hosting a static website, including instance creation, security group setup, HTTP server installation, and verification."
    mode: Agent
    model: Claude Sonnet 4.5
    tools: [aws-cli, bash, windows-batch]
Body:
# Sub-task 1 – Allocate EC2 Resources

## Prompt List for EC2 Instance Setup and Configuration

### 1. EC2 Instance Creation
- Create a Linux-based EC2 instance using a free-tier eligible AMI (Amazon Linux 2 or Ubuntu)
- Configure the instance with t3.micro instance type
- Select an appropriate key pair for SSH access
- Ensure the instance is launched in the default VPC

### 2. Security Group Configuration
- Create a new security group with the following inbound rules:
    - Allow HTTP (port 80) from anywhere (0.0.0.0/0)
    - Allow HTTPS (port 443) from anywhere (0.0.0.0/0)
    - Allow SSH (port 22) from my current IP address only
- Apply this security group to the EC2 instance

### 3. Dynamic IP Update Script (Windows AWS CLI)
- Write a Windows batch script that:
    - Retrieves the current public IP address using: `curl -s https://api.ipify.org`
    - Formats the IP with /32 CIDR notation for the security group rule
    - Revokes the old SSH rule from the security group using: `aws ec2 revoke-security-group-ingress`
    - Adds a new SSH rule with the updated IP using: `aws ec2 authorize-security-group-ingress`
    - Accepts parameters: AWS profile name, security group ID, and region
    - Example command structure:
        ```batch
        aws ec2 authorize-security-group-ingress --group-id sg-xxxxx --protocol tcp --port 22 --cidr %MY_IP%/32 --profile your-profile --region us-east-1
        ```
- Alternative Unix/bash script (for WSL or Linux):
    - Retrieves the current public IP address using: `dig +short myip.opendns.com @resolver1.opendns.com`
    - Updates the security group SSH rule with the new IP address
    - Accepts parameters: profile name, security group ID, and region

- Connect to the EC2 instance via SSH using the key pair and PuTTY (Windows SSH client)
- Install an HTTP server (Apache or Nginx) on the EC2 instance:
    - **For Amazon Linux 2/Amazon Linux 2023:**
        ```bash
        sudo yum update -y
        sudo yum install -y httpd
        sudo systemctl start httpd
        sudo systemctl enable httpd
        ```
    - **For Ubuntu:**
        ```bash
        sudo apt update -y
        sudo apt install -y apache2
        sudo systemctl start apache2
        sudo systemctl enable apache2
        ```
    - **For Nginx (alternative):**
        ```bash
        # Amazon Linux
        sudo amazon-linux-extras install nginx1 -y
        sudo systemctl start nginx
        sudo systemctl enable nginx
        
        # Ubuntu
        sudo apt install -y nginx
        sudo systemctl start nginx
        sudo systemctl enable nginx
        ```
- Configure the HTTP server to start automatically on boot (handled by `systemctl enable` command above)
- Verify the server is running and accessible on port 80:
    ```bash
    sudo systemctl status httpd  # or apache2/nginx
    curl http://localhost
    ```
- **Using AWS CLI (Windows) to execute commands remotely via SSM Session Manager:**
    ```batch
    aws ssm send-command ^
        --instance-ids "i-xxxxx" ^
        --document-name "AWS-RunShellScript" ^
        --parameters "commands=['sudo yum install -y httpd','sudo systemctl start httpd','sudo systemctl enable httpd']" ^
        --profile your-profile ^
        --region us-east-1
    ```
    Note: Requires SSM agent installed and IAM role attached to EC2 instance
- **Check command execution status:**
    ```batch
    aws ssm list-command-invocations ^
        --command-id "command-id-from-above" ^
        --details ^
        --profile your-profile ^
        --region us-east-1
    ```

### 5. Static Website Deployment
- Download the static website files from module 3 to the EC2 instance
- Deploy the website to the HTTP server's document root directory
- Set appropriate file permissions for web content
- **Using Windows AWS CLI to deploy static website:**
    - **Option 1: Using S3 as intermediate storage (recommended):**
        ```batch
        REM Upload local website files to S3 bucket
        aws s3 cp ./website-files s3://your-bucket-name/website/ --recursive --profile your-profile --region us-east-1
        
        REM Use SSM to download files from S3 to EC2 instance
        aws ssm send-command ^
            --instance-ids "i-xxxxx" ^
            --document-name "AWS-RunShellScript" ^
            --parameters "commands=['sudo aws s3 sync s3://your-bucket-name/website/ /var/www/html/','sudo chown -R apache:apache /var/www/html/','sudo chmod -R 755 /var/www/html/']" ^
            --profile your-profile ^
            --region us-east-1
        ```
    - **Option 2: Using SCP from Windows (requires PuTTY's pscp.exe):**
        ```batch
        REM Copy files to EC2 instance
        pscp -i C:\path\to\key.ppk -r C:\path\to\website-files\* ec2-user@ec2-xx-xx-xx-xx.compute.amazonaws.com:/tmp/
        
        REM Then SSH and move files to document root
        plink -i C:\path\to\key.ppk ec2-user@ec2-xx-xx-xx-xx.compute.amazonaws.com "sudo mv /tmp/* /var/www/html/ && sudo chown -R apache:apache /var/www/html/ && sudo chmod -R 755 /var/www/html/"
        ```
    - **Option 3: Direct SSM Session Manager file transfer:**
        ```batch
        REM Start SSM session and transfer files
        aws ssm start-session --target "i-xxxxx" --profile your-profile --region us-east-1
        
        REM Within the session, use base64 encoding for file transfer (for small files)
        REM Or install AWS CLI on EC2 and pull from S3
        ```
    - **Verify deployment:**
        ```batch
        aws ssm send-command ^
            --instance-ids "i-xxxxx" ^
            --document-name "AWS-RunShellScript" ^
            --parameters "commands=['ls -la /var/www/html/','curl http://localhost']" ^
            --profile your-profile ^
            --region us-east-1
        ```


### 6. Verification and Testing

- Verify HTTP access by visiting the instance's public IP address in a browser
    - **Get the EC2 instance's public IP address:**
        ```batch
        aws ec2 describe-instances ^
            --instance-ids "i-xxxxx" ^
            --query "Reservations[0].Instances[0].PublicIpAddress" ^
            --output text ^
            --profile your-profile ^
            --region us-east-1
        ```
    - **Troubleshooting if website is not accessible:**
        - SSH into the EC2 instance and verify Apache is running:
            ```bash
            sudo systemctl status httpd
            sudo netstat -tulpn | grep :80
            ```
        - Check if files are in the correct location (`/var/www/html/`):
            ```bash
            ls -la /var/www/html/
            ```
        - Ensure correct permissions:
            ```bash
            sudo chown -R apache:apache /var/www/html/
            sudo chmod -R 755 /var/www/html/
            sudo chmod 644 /var/www/html/*.html
            ```
        - Verify security group allows inbound HTTP (port 80) from 0.0.0.0/0:
            ```batch
            aws ec2 describe-security-groups --group-ids sg-xxxxx --profile your-profile --region us-east-1
            ```
        - Check Apache error logs:
            ```bash
            sudo tail -f /var/log/httpd/error_log
            ```
        - Test locally on EC2 instance:
            ```bash
            curl http://localhost
            curl http://127.0.0.1
            ```
    - Open a web browser and navigate to: `http://<public-ip-address>`
    - You should see your static website or the default HTTP server test page
    - **Alternative: Test from command line:**
        ```batch
        curl http://<public-ip-address>
        ```
- Confirm the static website is displayed correctly
- Test that the HTTP server restarts automatically after instance reboot

### 7. Windows Firewall Configuration (if applicable)
- Check Windows Firewall settings on local machine
- Ensure outbound connections to EC2 instance are not blocked
- Add exception rules if necessary for SSH and HTTP/HTTPS traffic