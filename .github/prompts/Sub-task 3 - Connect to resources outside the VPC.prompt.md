# Sub-task 3 - Connect to resources outside the VPC

The DB instance doesn't have access to the Internet and can reach only resources inside the VPC. Let's create a VPC Endpoint to provide access to the S3 bucket. You can use the bucket that was created in Module 4: S3.

Attach the `ReadAccessRoleS3` Role from Module 3: IAM.

## Create a VPC Endpoint:

1.  **Name**: `<ProjectName>-VPC-Endpoint`
2.  **Type**: Gateway. Endpoints of this type are used to send traffic to Amazon S3 or DynamoDB using private IP addresses.
3.  **VPC**: Choose the `<ProjectName>-Network` VPC.
4.  **Route Table**: Choose the `<ProjectName>-DbSubnet-A` Route Table.

## Verify Connectivity

Verify that the DB instance has access to the S3 bucket. You can connect to the instance using SSH (e.g., through the bastion host) and try to download a file or list all objects from the bucket using the AWS CLI.

Example command:
`aws s3 ls s3://<your-bucket-name>`

---

**NOTE:** Be aware of the costs for a VPC Endpoint, which can be around $0.30 per day. Remember to remove it if you are not actively using it.

---

## :warning: Pay Attention - It can save your budget!

It's time to stop here and review the resources created in the previous modules. Starting from the next module, you won't need most of the resources created so far. You will only need the policies and roles from **Module 3: IAM** and the custom AMI with the web application from **Module 5: EC2**.

In the next module, you will create a new AWS architecture that will be developed and expanded. To save your budget, you should **remove all other resources now**.

Let's review the resources created in previous modules that should be deleted:

### Module 4: S3
-   `bucket1` with the static website.
-   `bucket2` used for replication.

### Module 5: EC2
-   All EC2 instances.
-   Associated Security Groups.
-   EBS volumes.
-   Elastic IPs (ensure they are released).
-   Elastic Load Balancer.
-   Auto Scaling Group.

### Module 6: VPC
-   1 VPC.
-   1 Internet Gateway.
-   4 Subnets (2 public, 1 private, 1 DB subnet).
-   3 Route Tables (1 public, 1 private, 1 DB Route Table).
-   1 NAT Gateway.
-   1 VPC Endpoint.
-   1 Elastic IP Address.
-   4 EC2 Instances (1 bastion host, 1 public instance, 1 private instance, 1 DB instance).
-   3 Security Groups.