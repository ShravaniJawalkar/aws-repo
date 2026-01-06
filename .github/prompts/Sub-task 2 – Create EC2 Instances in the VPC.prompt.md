You are an expert AWS CloudFormation developer. Your task is to create a new CloudFormation template.

**Objective:**
Create a CloudFormation template to provision EC2 instances and their corresponding Security Groups within an existing VPC infrastructure. The existing infrastructure is defined by a CloudFormation stack created from the `vpc-network-infrastructure.yaml` file.

**Instructions:**

1.  **Use Existing VPC:** All resources must be created within the VPC provisioned by the `vpc-network-infrastructure.yaml` stack. You will need to import values from that stack's outputs, such as `VpcId`, `PublicSubnet1`, `PublicSubnet2`, `PrivateSubnet1`, and `DbSubnet1`.

2.  **Parameters:**
    *   `ProjectName`: A string parameter for naming resources.
    *   `MyIpAddress`: A string parameter for your IP address for SSH access (e.g., `x.x.x.x/32`).
    *   `KeyPairName`: An `AWS::EC2::KeyPair::KeyName` parameter for EC2 instance access.
    *   `VpcStackName`: The name of the stack created from `vpc-network-infrastructure.yaml`, used for importing VPC resources.
    *   `IamRoleStackName`: The name of the stack from Module 3 that created the `ReadAccessRoleS3` role.

3.  **Resource Creation:**

    **A. Security Groups:**
    *   **`<ProjectName>-SecGr1`**:
        *   **Description**: "Allow SSH from my IP"
        *   **Inbound Rule**: Allow TCP traffic on port 22 from the `MyIpAddress` parameter.
    *   **`<ProjectName>-SecGr2`**:
        *   **Description**: "Allow HTTP/S from anywhere"
        *   **Inbound Rules**:
            *   Allow TCP traffic on port 80 from `0.0.0.0/0`.
            *   Allow TCP traffic on port 443 from `0.0.0.0/0`.
    *   **`<ProjectName>-SecGr3`**:
        *   **Description**: "Allow all traffic from instances in this group"
        *   **Inbound Rule**: Allow all traffic (`-1`) from the security group itself (self-referencing).

    **B. EC2 Instances:**
    *   **Bastion Host:**
        *   **Logical ID**: `BastionHost`
        *   **Instance Type**: `t3.micro`
        *   **AMI**: Use a specific Amazon Linux 2 AMI ID.
        *   **Subnet**: `PublicSubnet2` (Imported from `VpcStackName`).
        *   **Security Groups**: Attach `<ProjectName>-SecGr1` and `<ProjectName>-SecGr3`.
        *   **IAM Role**: Attach `ReadAccessRoleS3` (Import its ARN from `IamRoleStackName`).
        *   **Key Pair**: Use the `KeyPairName` parameter.
        *   **Tags**: Name: `<ProjectName>-Bastion`.
    *   **Public Application Instance:**
        *   **Logical ID**: `PublicInstance`
        *   **Instance Type**: `t3.micro`
        *   **AMI**: Use a specific Amazon Linux 2 AMI ID.
        *   **Subnet**: `PublicSubnet1` (Imported from `VpcStackName`).
        *   **Security Groups**: Attach `<ProjectName>-SecGr2` and `<ProjectName>-SecGr3`.
        *   **IAM Role**: Attach `ReadAccessRoleS3` (Import its ARN from `IamRoleStackName`).
        *   **Key Pair**: Use the `KeyPairName` parameter.
        *   **User Data**: Include a script to install a simple web server (e.g., Apache) and create a basic `index.html` page. This simulates the "application developed in Module 5".
        *   **Tags**: Name: `<ProjectName>-Public-Instance`.
    *   **Private Instance:**
        *   **Logical ID**: `PrivateInstance`
        *   **Instance Type**: `t3.micro`
        *   **AMI**: Use a specific Amazon Linux 2 AMI ID.
        *   **Subnet**: `PrivateSubnet1` (Imported from `VpcStackName`).
        *   **Security Groups**: Attach `<ProjectName>-SecGr3`.
        *   **Key Pair**: Use the `KeyPairName` parameter.
        *   **Tags**: Name: `<ProjectName>-Private-Instance`.
    *   **DB Instance:**
        *   **Logical ID**: `DbInstance`
        *   **Instance Type**: `t3.micro`
        *   **AMI**: Use a specific Amazon Linux 2 AMI ID.
        *   **Subnet**: `DbSubnet1` (Imported from `VpcStackName`).
        *   **Security Groups**: Attach `<ProjectName>-SecGr3`.
        *   **Key Pair**: Use the `KeyPairName` parameter.
        *   **Tags**: Name: `<ProjectName>-DB-Instance`.

4.  **Outputs:**
    *   `PublicInstanceUrl`: The public DNS name of the `PublicInstance`, formatted as `http://<PublicDnsName>`.

**Verification Checks (to be performed after deployment):**
*   The application on the public instance is available from anywhere via its public URL.
*   You can SSH into the Bastion Host from your specified IP.
*   From the Bastion Host, you can successfully `ping` and `ssh` into the `PrivateInstance` and `DbInstance`.
*   The `BastionHost` and `PublicInstance` have internet access (e.g., `ping 8.8.8.8`).
*   The `PrivateInstance` has internet access (via the NAT Gateway).
*   The `DbInstance` does **not** have internet access.
*   The `PublicInstance` and `PrivateInstance` can `ping` the `DbInstance`.

Generate the complete CloudFormation YAML template based on these requirements.