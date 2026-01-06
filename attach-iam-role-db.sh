#!/bin/bash

# Script to attach ReadAccessRoleS3 IAM Role to DB instance
# Replace the placeholders with your actual values

PROJECT_NAME="<YourProjectName>"
REGION="<your-region>"
IAM_ROLE_NAME="ReadAccessRoleS3"

# Get DB Instance ID
DB_INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*DB*" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text \
  --region $REGION)

echo "DB Instance ID: $DB_INSTANCE_ID"

# Get IAM Instance Profile ARN
INSTANCE_PROFILE_ARN=$(aws iam get-instance-profile \
  --instance-profile-name $IAM_ROLE_NAME \
  --query "InstanceProfile.Arn" \
  --output text)

echo "Instance Profile ARN: $INSTANCE_PROFILE_ARN"

# Check if instance already has an IAM role
CURRENT_PROFILE=$(aws ec2 describe-instances \
  --instance-ids $DB_INSTANCE_ID \
  --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" \
  --output text \
  --region $REGION)

if [ "$CURRENT_PROFILE" != "None" ]; then
  echo "Instance already has an IAM role attached: $CURRENT_PROFILE"
  echo "Replacing with new role..."
  aws ec2 replace-iam-instance-profile-association \
    --iam-instance-profile Name=$IAM_ROLE_NAME \
    --association-id $(aws ec2 describe-iam-instance-profile-associations \
      --filters "Name=instance-id,Values=$DB_INSTANCE_ID" \
      --query "IamInstanceProfileAssociations[0].AssociationId" \
      --output text \
      --region $REGION) \
    --region $REGION
else
  echo "Attaching IAM role to instance..."
  aws ec2 associate-iam-instance-profile \
    --instance-id $DB_INSTANCE_ID \
    --iam-instance-profile Name=$IAM_ROLE_NAME \
    --region $REGION
fi

echo "IAM Role attached successfully!"
