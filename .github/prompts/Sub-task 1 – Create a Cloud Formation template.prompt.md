# Sub-task 1 – Create and Deploy a CloudFormation Template via AWS CLI

## Objective
Create a comprehensive AWS CloudFormation template and deploy it using AWS CLI commands to provision a complete infrastructure stack including networking, compute, and load balancing resources.

## Context
You have previously created these resources manually in earlier modules. Now you need to codify the infrastructure as a CloudFormation template and deploy it using AWS CLI.

## Prerequisites
- AWS CLI installed and configured with appropriate credentials
- IAM permissions to create CloudFormation stacks and all required resources
- Custom AMI ID from previous EC2 module

## Requirements

### Parameters
Define the following parameters in your template:
- `<ProjectName>-AMI`: AMI ID for your custom EC2 instance (from EC2 module)
- `<ProjectName>-InstanceType`: EC2 instance type (use free-tier eligible type)

### Resources to Create

#### 1. S3 Bucket
- **Resource Type**: `AWS::S3::Bucket`
- **Naming Requirements**:
  - Must be lowercase only
  - Must include your full name
  - Must begin with a letter

#### 2. VPC
- **Resource Type**: `AWS::EC2::VPC`
- **Name Tag**: `<ProjectName>-Network`
- **CIDR Block**: `10.0.0.0/16`

#### 3. Internet Gateway
- **Resource Type**: `AWS::EC2::InternetGateway`
- **Name Tag**: `<ProjectName>-InternetGateway`
- **Attachment**: Use `AWS::EC2::VPCGatewayAttachment` to attach to `<ProjectName>-Network` VPC

#### 4. Public Subnets
**Subnet A:**
- **Resource Type**: `AWS::EC2::Subnet`
- **Name Tag**: `<ProjectName>-PublicSubnet-A`
- **CIDR Block**: `10.0.11.0/24`
- **Availability Zone**: Use `Fn::GetAZs` function
- **VPC**: Assign to `<ProjectName>-Network`

**Subnet B:**
- **Resource Type**: `AWS::EC2::Subnet`
- **Name Tag**: `<ProjectName>-PublicSubnet-B`
- **CIDR Block**: `10.0.12.0/24`
- **Availability Zone**: Use `Fn::GetAZs` function
- **VPC**: Assign to `<ProjectName>-Network`

#### 5. Public Routing
- **Route Table**:
  - **Resource Type**: `AWS::EC2::RouteTable`
  - **Name Tag**: `<ProjectName>-PublicRouteTable`
  - **VPC**: Assign to `<ProjectName>-Network`
  
- **Route**:
  - **Resource Type**: `AWS::EC2::Route`
  - **Dependencies**: Must be created after Internet Gateway
  - **Attach**: `<ProjectName>-PublicRouteTable` and `<ProjectName>-InternetGateway`
  - **Destination CIDR**: `0.0.0.0/0`
  
- **Subnet Associations**:
  - **Resource Type**: `AWS::EC2::SubnetRouteTableAssociation`
  - Associate both `<ProjectName>-PublicSubnet-A` and `<ProjectName>-PublicSubnet-B` with the route table

#### 6. Security Group
- **Resource Type**: `AWS::EC2::SecurityGroup`
- **Name Tag**: `<ProjectName>-SecGr1`
- **VPC**: Assign to `<ProjectName>-Network`
- **Ingress Rules** (use `AWS::EC2::SecurityGroupIngress`):
  - HTTP (port 80) from anywhere (`0.0.0.0/0`)
  - HTTPS (port 443) from anywhere (`0.0.0.0/0`)
  - SSH (port 22) from your IP address only
  - *Optional*: Add custom port if your application requires it (e.g., TCP 8080 for backend)

#### 7. Launch Template
- **Resource Type**: `AWS::EC2::LaunchTemplate`
- **Name Tag**: `<ProjectName>-LaunchTemplate`
- **Configuration**:
  - Use `<ProjectName>-AMI` parameter for AMI ID
  - Use `<ProjectName>-InstanceType` parameter for instance type
  - Assign `<ProjectName>-SecGr1` security group

#### 8. Auto Scaling Group
- **Resource Type**: `AWS::AutoScaling::AutoScalingGroup`
- **Name Tag**: `<ProjectName>-AutoScalingGroup`
- **Configuration**:
  - Use `<ProjectName>-LaunchTemplate`
  - Assign to subnets: `<ProjectName>-PublicSubnet-A` and `<ProjectName>-PublicSubnet-B`
  - **Scaling Policy**: Scale out when CPU usage exceeds 50%

#### 9. Application Load Balancer
- **Load Balancer**:
  - **Resource Type**: `AWS::ElasticLoadBalancingV2::LoadBalancer`
  - **Name Tag**: `<ProjectName>-LoadBalancer`
  - **Subnets**: Assign `<ProjectName>-PublicSubnet-A` and `<ProjectName>-PublicSubnet-B`
  
- **Target Group**:
  - **Resource Type**: `AWS::ElasticLoadBalancingV2::TargetGroup`
  - Configure health checks and target port
  
- **Listener**:
  - **Resource Type**: `AWS::ElasticLoadBalancingV2::Listener`
  - Configure protocol and forward actions to target group

## AWS CLI Deployment Steps

### Step 1: Validate the Template

#### Validation Commands

**1. Syntax Validation**
```powershell
# Validate CloudFormation template syntax
aws cloudformation validate-template `
  --template-body file://path/to/your-template.yaml
```

**Expected Output:**
- If valid: Returns template description, parameters, and outputs
- If invalid: Returns error messages with line numbers

**2. Check Template Format**
```powershell
# Ensure template is valid JSON or YAML
# For YAML templates, verify no syntax errors
aws cloudformation validate-template `
  --template-body file://path/to/your-template.yaml `
  --region us-east-1
```

**3. Verify Parameter Values**
```powershell
# Verify all parameters are defined before deployment
# Required parameters:
# - <ProjectName>-AMI: Valid AMI ID in your region
# - <ProjectName>-InstanceType: Free-tier eligible (t2.micro, t3.micro)

# Test with parameter validation
$params = @(
    @{ParameterKey="ProjectName-AMI"; ParameterValue="ami-05fb2447d4d3d2610"}
    @{ParameterKey="ProjectName-InstanceType"; ParameterValue="t3.micro"}
)
```

**4. Check for IAM Permissions**
```powershell
# Verify you have required permissions for:
# - CloudFormation
# - EC2, VPC, Subnets, Route Tables
# - Security Groups
# - Load Balancing
# - Auto Scaling
# - S3 buckets

aws iam get-user
aws iam list-user-policies --user-name your-username
```

**5. Verify Resource Naming**
- S3 Bucket: Lowercase only, includes full name, starts with letter
- All resources: Use consistent naming pattern `<ProjectName>-ResourceType`
- VPC CIDR: `10.0.0.0/16`
- Subnets: `10.0.11.0/24` and `10.0.12.0/24` (no overlap)

**6. Check Availability Zones**
```powershell
# Verify AZs available in your region
aws ec2 describe-availability-zones `
  --region us-east-1
```

---

### Step 2: Deploy the CloudFormation Stack

#### Pre-Deployment Checklist
- [ ] Template syntax is valid
- [ ] All parameters are available (AMI ID, Instance Type)
- [ ] IAM permissions are configured
- [ ] S3 bucket naming requirements are met
- [ ] No resource conflicts in your AWS account

#### Deployment Commands

**1. Create Stack**
```powershell
# Deploy the CloudFormation stack
aws cloudformation create-stack `
  --stack-name <ProjectName>-Infrastructure `
  --template-body file://path/to/your-template.yaml `
  --parameters `
    ParameterKey=ProjectName-AMI,ParameterValue=ami-05fb2447d4d3d2610 `
    ParameterKey=ProjectName-InstanceType,ParameterValue=t3.micro `
  --capabilities CAPABILITY_IAM `
  --region us-east-1
```

**Expected Output:**
```json
{
  "StackId": "arn:aws:cloudformation:us-east-1:123456789012:stack/<ProjectName>-Infrastructure/12345678-1234-1234-1234-123456789012"
}
```

**2. Monitor Stack Creation**
```powershell
# Wait for stack to complete (options: CREATE_COMPLETE, CREATE_FAILED, ROLLBACK_COMPLETE)
aws cloudformation wait stack-create-complete `
  --stack-name <ProjectName>-Infrastructure `
  --region us-east-1

# Check current stack status
aws cloudformation describe-stacks `
  --stack-name <ProjectName>-Infrastructure `
  --region us-east-1 `
  --query 'Stacks[0].[StackName,StackStatus,CreationTime]' `
  --output table
```

**3. Validate Stack Creation**
```powershell
# Get stack events to check for errors
aws cloudformation describe-stack-events `
  --stack-name <ProjectName>-Infrastructure `
  --region us-east-1 `
  --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]' `
  --output table
```

**4. Retrieve Stack Outputs**
```powershell
# Get outputs like Load Balancer DNS, VPC ID, etc.
aws cloudformation describe-stacks `
  --stack-name <ProjectName>-Infrastructure `
  --region us-east-1 `
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' `
  --output table
```

#### Post-Deployment Validation

**1. Verify VPC and Subnets**
```powershell
aws ec2 describe-vpcs `
  --filters "Name=tag:Name,Values=<ProjectName>-Network" `
  --region us-east-1 `
  --output table

aws ec2 describe-subnets `
  --filters "Name=tag:Name,Values=<ProjectName>-PublicSubnet-*" `
  --region us-east-1 `
  --output table
```

**2. Verify EC2 Instances**
```powershell
aws ec2 describe-instances `
  --filters "Name=tag:aws:cloudformation:stack-name,Values=<ProjectName>-Infrastructure" `
  --region us-east-1 `
  --output table
```

**3. Verify Load Balancer**
```powershell
aws elbv2 describe-load-balancers `
  --region us-east-1 `
  --query 'LoadBalancers[*].[LoadBalancerName,DNSName,State.Code]' `
  --output table
```

**4. Verify Security Groups**
```powershell
aws ec2 describe-security-groups `
  --filters "Name=tag:Name,Values=<ProjectName>-SecGr1" `
  --region us-east-1 `
  --output table
```

**5. Verify S3 Bucket**
```powershell
aws s3 ls | grep <ProjectName>-bucket
```

---

### Step 3: Troubleshooting (If Deployment Fails)

**Check Stack Failure Reason**
```powershell
aws cloudformation describe-stack-resources `
  --stack-name <ProjectName>-Infrastructure `
  --region us-east-1 `
  --query 'StackResources[?ResourceStatus==`CREATE_FAILED`]' `
  --output table
```

**Rollback Stack**
```powershell
aws cloudformation delete-stack `
  --stack-name <ProjectName>-Infrastructure `
  --region us-east-1
```

**Check CloudFormation Logs**
```powershell
# View detailed events
aws cloudformation describe-stack-events `
  --stack-name <ProjectName>-Infrastructure `
  --region us-east-1 | Select-Object -ExpandProperty StackEvents
```

