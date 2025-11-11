#!/bin/bash

# Script: manage_ebs_volume.sh
# Purpose: Automate EBS volume creation, attachment, data writing, detachment, and re-attachment between EC2 instances
# Usage: ./manage_ebs_volume.sh <instance-1-id> <instance-2-id> <key-file-path> [profile-name]

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check arguments
if [ $# -lt 3 ]; then
    print_error "Usage: $0 <instance-1-id> <instance-2-id> <key-file-path> [profile-name]"
    exit 1
fi

INSTANCE_1_ID=$1
INSTANCE_2_ID=$2
KEY_FILE=$3
PROFILE=${4:-"default"}

# Set AWS CLI profile option
if [ "$PROFILE" != "default" ]; then
    AWS_PROFILE_OPT="--profile $PROFILE"
else
    AWS_PROFILE_OPT=""
fi

# Validate key file exists
if [ ! -f "$KEY_FILE" ]; then
    print_error "Key file not found: $KEY_FILE"
    exit 1
fi

# Validate key file permissions
chmod 400 "$KEY_FILE"

print_status "Starting EBS volume management script..."
print_status "Instance 1: $INSTANCE_1_ID"
print_status "Instance 2: $INSTANCE_2_ID"
print_status "Key File: $KEY_FILE"
print_status "AWS Profile: $PROFILE"

# Step 1: Get Availability Zone of instance-1
print_status "Step 1: Getting Availability Zone of instance-1..."
AZ=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_1_ID \
    $AWS_PROFILE_OPT \
    --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' \
    --output text)

if [ -z "$AZ" ] || [ "$AZ" == "None" ]; then
    print_error "Failed to get Availability Zone for instance $INSTANCE_1_ID"
    exit 1
fi

print_status "Instance 1 is in Availability Zone: $AZ"

# Step 2: Create EBS Volume
print_status "Step 2: Creating 1 GiB gp2 EBS volume in $AZ..."
VOLUME_ID=$(aws ec2 create-volume \
    --availability-zone $AZ \
    --size 1 \
    --volume-type gp2 \
    --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=EBS-Test-Volume},{Key=Purpose,Value=Testing}]" \
    $AWS_PROFILE_OPT \
    --query 'VolumeId' \
    --output text)

if [ -z "$VOLUME_ID" ]; then
    print_error "Failed to create EBS volume"
    exit 1
fi

print_status "EBS Volume created: $VOLUME_ID"

# Wait for volume to be available
print_status "Waiting for volume to be available..."
aws ec2 wait volume-available --volume-ids $VOLUME_ID $AWS_PROFILE_OPT
print_status "Volume is now available"

# Step 3: Attach volume to instance-1
print_status "Step 3: Attaching volume to instance-1 ($INSTANCE_1_ID)..."
aws ec2 attach-volume \
    --volume-id $VOLUME_ID \
    --instance-id $INSTANCE_1_ID \
    --device /dev/sdf \
    $AWS_PROFILE_OPT > /dev/null

# Wait for attachment
print_status "Waiting for volume to attach..."
sleep 5
aws ec2 wait volume-in-use --volume-ids $VOLUME_ID $AWS_PROFILE_OPT
print_status "Volume attached successfully"

# Step 4: Get public IP of instance-1
print_status "Step 4: Getting public IP of instance-1..."
INSTANCE_1_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_1_ID \
    $AWS_PROFILE_OPT \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

if [ -z "$INSTANCE_1_IP" ] || [ "$INSTANCE_1_IP" == "None" ]; then
    print_error "Failed to get public IP for instance-1"
    exit 1
fi

print_status "Instance-1 Public IP: $INSTANCE_1_IP"

# Wait a bit for the device to be recognized by the OS
print_status "Waiting for device to be recognized by the OS..."
sleep 10

# Step 5: Format, mount, write data on instance-1
print_status "Step 5: Formatting and writing data to volume on instance-1..."

# Check if device exists
ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ec2-user@$INSTANCE_1_IP "ls -l /dev/xvdf" || {
    print_warning "Device /dev/xvdf not found, checking for /dev/nvme1n1..."
    DEVICE=$(ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ec2-user@$INSTANCE_1_IP "lsblk -o NAME,SIZE | grep '1G' | head -1 | awk '{print \"/dev/\" \$1}'")
    print_status "Using device: $DEVICE"
}

# Set device path (use /dev/xvdf as default, modern instances may use nvme)
DEVICE_PATH="/dev/xvdf"

print_status "Executing commands on instance-1 via SSH..."
ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ec2-user@$INSTANCE_1_IP << 'EOF'
    set -e
    echo "Checking for attached device..."
    
    # Determine the actual device name
    if [ -e /dev/xvdf ]; then
        DEVICE=/dev/xvdf
    elif [ -e /dev/nvme1n1 ]; then
        DEVICE=/dev/nvme1n1
    else
        echo "ERROR: Could not find attached volume device"
        exit 1
    fi
    
    echo "Using device: $DEVICE"
    
    # Format the volume
    echo "Formatting volume with ext4 filesystem..."
    sudo mkfs -t ext4 $DEVICE
    
    # Create mount point
    echo "Creating mount point /data..."
    sudo mkdir -p /data
    
    # Mount the volume
    echo "Mounting volume to /data..."
    sudo mount $DEVICE /data
    
    # Write test file
    echo "Creating test.txt file..."
    echo "EBS test file" | sudo tee /data/test.txt > /dev/null
    
    # Verify file was created
    echo "Verifying file contents..."
    cat /data/test.txt
    
    # Unmount the volume
    echo "Unmounting volume..."
    sudo umount /data
    
    echo "Operations on instance-1 completed successfully!"
EOF

print_status "Data written and volume unmounted on instance-1"

# Step 6: Detach volume from instance-1
print_status "Step 6: Detaching volume from instance-1..."
aws ec2 detach-volume \
    --volume-id $VOLUME_ID \
    $AWS_PROFILE_OPT > /dev/null

print_status "Waiting for volume to be available..."
aws ec2 wait volume-available --volume-ids $VOLUME_ID $AWS_PROFILE_OPT
print_status "Volume detached successfully"

# Step 7: Attach volume to instance-2
print_status "Step 7: Attaching volume to instance-2 ($INSTANCE_2_ID)..."
aws ec2 attach-volume \
    --volume-id $VOLUME_ID \
    --instance-id $INSTANCE_2_ID \
    --device /dev/sdf \
    $AWS_PROFILE_OPT > /dev/null

# Wait for attachment
print_status "Waiting for volume to attach..."
sleep 5
aws ec2 wait volume-in-use --volume-ids $VOLUME_ID $AWS_PROFILE_OPT
print_status "Volume attached successfully to instance-2"

# Step 8: Get public IP of instance-2
print_status "Step 8: Getting public IP of instance-2..."
INSTANCE_2_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_2_ID \
    $AWS_PROFILE_OPT \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

if [ -z "$INSTANCE_2_IP" ] || [ "$INSTANCE_2_IP" == "None" ]; then
    print_error "Failed to get public IP for instance-2"
    exit 1
fi

print_status "Instance-2 Public IP: $INSTANCE_2_IP"

# Wait for device to be recognized
print_status "Waiting for device to be recognized by the OS..."
sleep 10

# Step 9: Mount and verify data on instance-2
print_status "Step 9: Mounting volume and verifying data on instance-2..."

ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ec2-user@$INSTANCE_2_IP << 'EOF'
    set -e
    echo "Checking for attached device..."
    
    # Determine the actual device name
    if [ -e /dev/xvdf ]; then
        DEVICE=/dev/xvdf
    elif [ -e /dev/nvme1n1 ]; then
        DEVICE=/dev/nvme1n1
    else
        echo "ERROR: Could not find attached volume device"
        exit 1
    fi
    
    echo "Using device: $DEVICE"
    
    # Create mount point
    echo "Creating mount point /data..."
    sudo mkdir -p /data
    
    # Mount the volume
    echo "Mounting volume to /data..."
    sudo mount $DEVICE /data
    
    # Verify file exists
    echo "Checking if test.txt exists..."
    if [ ! -f /data/test.txt ]; then
        echo "ERROR: test.txt not found!"
        sudo umount /data
        exit 1
    fi
    
    # Verify file content
    echo "Verifying file content..."
    CONTENT=$(cat /data/test.txt)
    EXPECTED="EBS test file"
    
    if [ "$CONTENT" == "$EXPECTED" ]; then
        echo "SUCCESS: File content verified!"
        echo "Content: $CONTENT"
    else
        echo "ERROR: File content mismatch!"
        echo "Expected: $EXPECTED"
        echo "Got: $CONTENT"
        sudo umount /data
        exit 1
    fi
    
    # Unmount the volume
    echo "Unmounting volume..."
    sudo umount /data
    
    echo "Verification on instance-2 completed successfully!"
EOF

print_status "Data verified successfully on instance-2"

# Summary
echo ""
echo "=========================================="
print_status "EBS Volume Management Completed Successfully!"
echo "=========================================="
print_status "Volume ID: $VOLUME_ID"
print_status "Volume was created, attached to instance-1, formatted, data written,"
print_status "detached, re-attached to instance-2, and data verified."
echo "=========================================="
echo ""
print_warning "Note: The EBS volume ($VOLUME_ID) is still attached to instance-2."
print_warning "To clean up, you can:"
echo "  1. Detach the volume: aws ec2 detach-volume --volume-id $VOLUME_ID $AWS_PROFILE_OPT"
echo "  2. Delete the volume: aws ec2 delete-volume --volume-id $VOLUME_ID $AWS_PROFILE_OPT"
echo ""

exit 0
