
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
- Configure the instance with t2.micro instance type
- Select an appropriate key pair for SSH access
- Ensure the instance is launched in the default VPC

### 2. Security Group Configuration
- Create a new security group with the following inbound rules:
    - Allow HTTP (port 80) from anywhere (0.0.0.0/0)
    - Allow HTTPS (port 443) from anywhere (0.0.0.0/0)
    - Allow SSH (port 22) from my current IP address only
- Apply this security group to the EC2 instance

### 3. Dynamic IP Update Script (Optional)
- Write a Windows batch script that:
    - Retrieves the current public IP address
    - Updates the security group SSH rule with the new IP address
    - Accepts parameters: profile name, security group ID, and region
- Write a Unix/bash script that:
    - Retrieves the current public IP address using DNS query
    - Updates the security group SSH rule with the new IP address
    - Accepts parameters: profile name, security group ID, and region

### 4. HTTP Server Installation
- Install an HTTP server (Apache or Nginx) on the EC2 instance
- Configure the HTTP server to start automatically on boot
- Verify the server is running and accessible on port 80

### 5. Static Website Deployment
- Download the static website files from module 3 to the EC2 instance
- Deploy the website to the HTTP server's document root directory
- Set appropriate file permissions for web content

### 6. Verification and Testing
- Test SSH connection to the EC2 instance from your local machine
- Verify HTTP access by visiting the instance's public IP address in a browser
- Confirm the static website is displayed correctly
- Test that the HTTP server restarts automatically after instance reboot

### 7. Windows Firewall Configuration (if applicable)
- Check Windows Firewall settings on local machine
- Ensure outbound connections to EC2 instance are not blocked
- Add exception rules if necessary for SSH and HTTP/HTTPS traffic