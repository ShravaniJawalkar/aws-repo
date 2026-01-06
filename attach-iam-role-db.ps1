# PowerShell Script to attach ReadAccessRoleS3 IAM Role to DB instance
# Replace the placeholders with your actual values

$PROJECT_NAME = "<YourProjectName>"
$REGION = "<your-region>"
$IAM_ROLE_NAME = "ReadAccessRoleS3"

# Get DB Instance ID
$DB_INSTANCE_ID = aws ec2 describe-instances `
  --filters "Name=tag:Name,Values=*DB*" "Name=instance-state-name,Values=running" `
  --query "Reservations[0].Instances[0].InstanceId" `
  --output text `
  --region $REGION

Write-Host "DB Instance ID: $DB_INSTANCE_ID"

# Get IAM Instance Profile ARN
$INSTANCE_PROFILE_ARN = aws iam get-instance-profile `
  --instance-profile-name $IAM_ROLE_NAME `
  --query "InstanceProfile.Arn" `
  --output text

Write-Host "Instance Profile ARN: $INSTANCE_PROFILE_ARN"

# Check if instance already has an IAM role
$CURRENT_PROFILE = aws ec2 describe-instances `
  --instance-ids $DB_INSTANCE_ID `
  --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" `
  --output text `
  --region $REGION

if ($CURRENT_PROFILE -ne "None" -and $CURRENT_PROFILE -ne "") {
  Write-Host "Instance already has an IAM role attached: $CURRENT_PROFILE"
  Write-Host "Replacing with new role..."
  
  $ASSOCIATION_ID = aws ec2 describe-iam-instance-profile-associations `
    --filters "Name=instance-id,Values=$DB_INSTANCE_ID" `
    --query "IamInstanceProfileAssociations[0].AssociationId" `
    --output text `
    --region $REGION
  
  aws ec2 replace-iam-instance-profile-association `
    --iam-instance-profile "Name=$IAM_ROLE_NAME" `
    --association-id $ASSOCIATION_ID `
    --region $REGION
} else {
  Write-Host "Attaching IAM role to instance..."
  aws ec2 associate-iam-instance-profile `
    --instance-id $DB_INSTANCE_ID `
    --iam-instance-profile "Name=$IAM_ROLE_NAME" `
    --region $REGION
}

Write-Host "IAM Role attached successfully!"
