# PowerShell Script to create VPC Endpoint for S3 access
# Replace the placeholders with your actual values

$PROJECT_NAME = "<YourProjectName>"
$REGION = "<your-region>"  # e.g., us-east-1, ap-south-1, etc.

# Get VPC ID
$VPC_ID = aws ec2 describe-vpcs `
  --filters "Name=tag:Name,Values=$PROJECT_NAME-Network" `
  --query "Vpcs[0].VpcId" `
  --output text `
  --region $REGION

Write-Host "VPC ID: $VPC_ID"

# Get DB Subnet Route Table ID
$ROUTE_TABLE_ID = aws ec2 describe-route-tables `
  --filters "Name=tag:Name,Values=$PROJECT_NAME-DbSubnet-A" `
  --query "RouteTables[0].RouteTableId" `
  --output text `
  --region $REGION

Write-Host "Route Table ID: $ROUTE_TABLE_ID"

# Create VPC Endpoint
$VPC_ENDPOINT_ID = aws ec2 create-vpc-endpoint `
  --vpc-id $VPC_ID `
  --service-name "com.amazonaws.$REGION.s3" `
  --route-table-ids $ROUTE_TABLE_ID `
  --tag-specifications "ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=$PROJECT_NAME-VPC-Endpoint}]" `
  --query "VpcEndpoint.VpcEndpointId" `
  --output text `
  --region $REGION

Write-Host "VPC Endpoint created: $VPC_ENDPOINT_ID"
