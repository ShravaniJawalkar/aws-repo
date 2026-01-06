You are an expert in AWS and Terraform.

Your task is to create the necessary Terraform configuration to deploy a load-balanced, auto-scaling web application on AWS.

**Assumptions:**

*   A deployable application artifact (e.g., a `.zip` file) has already been built and uploaded to an S3 bucket. The application runs a web server on port 8080.
*   The application has an endpoint that returns the AWS Region and Availability Zone it's running in.
*   A base Amazon Linux 2 AMI ID is available.
*   The default VPC and its subnets will be used.

**Requirements:**

1.  **IAM Role for EC2:** Create an IAM role and instance profile for the EC2 instances. This role must grant permissions to:
    *   Read from the S3 bucket containing the application artifact.
    *   Describe EC2 instances/regions to get metadata (for the application endpoint).

2.  **Security Groups:**
    *   Create a security group for the Load Balancer that allows inbound HTTP traffic from anywhere (`0.0.0.0/0`).
    *   Create a security group for the EC2 instances that allows inbound traffic on port 8080 only from the Load Balancer's security group.

3.  **User Data Script:** Create a `user_data` script that will be executed on instance launch. This script must:
    *   Install a runtime for the application (e.g., Node.js).
    *   Download the application artifact from the specified S3 bucket.
    *   Unzip and run the application. The application should be configured to start automatically on boot (e.g., using `systemd`).

4.  **Launch Template:** Create an EC2 Launch Template that specifies:
    *   The base AMI ID.
    *   An appropriate instance type (e.g., `t2.micro`).
    *   The IAM instance profile.
    *   The EC2 security group.
    *   The `user_data` script.

5.  **Application Load Balancer (ALB):**
    *   Create an ALB, a target group, and a listener.
    *   The ALB should be internet-facing and use the security group created for it.
    *   The target group should be configured for the default VPC, use the HTTP protocol on port 8080, and have a health check path of `/`.
    *   The listener should listen for HTTP traffic on port 80 and forward it to the target group.

6.  **Auto Scaling Group (ASG):**
    *   Create an ASG using the Launch Template.
    *   Configure it to run in at least two subnets of the default VPC.
    *   Set the desired capacity to 2, minimum size to 2, and maximum size to 3.
    *   Attach the ALB's target group to the ASG.

7.  **Scaling Policy:**
    *   Create an ASG scaling policy to scale out (add an instance) when the average CPU utilization exceeds 50%.

Please provide a single Terraform file (`main.tf`) that accomplishes all of the above. Use variables for the S3 bucket name, artifact name, and base AMI ID.