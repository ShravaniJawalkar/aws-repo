You are an expert in AWS Infrastructure as Code. Your task is to generate a complete and runnable code file that provisions the AWS networking infrastructure described below.

Use `<ProjectName>` as a placeholder for the project name in all resource names. The generated code should be well-structured and follow best practices for the chosen IaC tool.

### AWS Networking Infrastructure Requirements:

1.  **VPC (Virtual Private Cloud)**
    *   **Name:** `<ProjectName>-Network`
    *   **CIDR Block:** `10.0.0.0/16`

2.  **Internet Gateway (IGW)**
    *   **Name:** `<ProjectName>-IGW`
    *   **Attachment:** Attach to the `<ProjectName>-Network` VPC.

3.  **Subnets**
    *   **Public Subnet A:**
        *   **Name:** `<ProjectName>-PublicSubnet-A`
        *   **Availability Zone:** The first available AZ in the region.
        *   **CIDR Block:** `10.0.11.0/24`
        *   **Configuration:** Enable auto-assignment of public IPv4 addresses.
    *   **Public Subnet B:**
        *   **Name:** `<ProjectName>-PublicSubnet-B`
        *   **Availability Zone:** The second available AZ in the region.
        *   **CIDR Block:** `10.0.21.0/24`
        *   **Configuration:** Enable auto-assignment of public IPv4 addresses.
    *   **Private Subnet A:**
        *   **Name:** `<ProjectName>-PrivateSubnet-A`
        *   **Availability Zone:** The first available AZ in the region.
        *   **CIDR Block:** `10.0.12.0/24`
    *   **DB Subnet A:**
        *   **Name:** `<ProjectName>-DbSubnet-A`
        *   **Availability Zone:** The first available AZ in the region.
        *   **CIDR Block:** `10.0.13.0/24`

4.  **Route Tables & Associations**
    *   **Public Route Table:**
        *   **Name:** `<ProjectName>-PublicRouteTable`
        *   **VPC:** `<ProjectName>-Network`
        *   **Routes:**
            *   A default route (`0.0.0.0/0`) pointing to the `<ProjectName>-IGW`.
        *   **Associations:** Associate with `<ProjectName>-PublicSubnet-A` and `<ProjectName>-PublicSubnet-B`.
    *   **Private Route Table A:**
        *   **Name:** `<ProjectName>-PrivateRouteTable-A`
        *   **VPC:** `<ProjectName>-Network`
        *   **Associations:** Associate with `<ProjectName>-PrivateSubnet-A`.
    *   **DB Route Table:**
        *   **Name:** `<ProjectName>-DbRouteTable`
        *   **VPC:** `<ProjectName>-Network`
        *   **Associations:** Associate with `<ProjectName>-DbSubnet-A`.

5.  **NAT Gateway & Elastic IP**
    *   **Elastic IP:**
        *   Allocate a new Elastic IP for the NAT Gateway.
    *   **NAT Gateway:**
        *   **Name:** `<ProjectName>-NatGateway-A`
        *   **Subnet:** Place in `<ProjectName>-PublicSubnet-A`.
        *   **Connectivity:** Associate the allocated Elastic IP.
    *   **Route Update:**
        *   Add a new route (`0.0.0.0/0`) to `<ProjectName>-PrivateRouteTable-A` that points to the `<ProjectName>-NatGateway-A`.