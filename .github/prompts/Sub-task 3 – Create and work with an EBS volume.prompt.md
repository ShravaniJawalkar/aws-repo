# Prompt for Sub-task 3: Create and work with an EBS volume

You are an expert AWS DevOps engineer. Your task is to generate a bash script that automates the process of creating, attaching, writing to, detaching, and re-attaching an Amazon EBS volume between two EC2 instances.

## Context

- Two EC2 instances are already running from previous sub-tasks.
- You have the instance IDs for both instances (`instance-1` and `instance-2`).
- You have SSH access to both instances using a key pair.
- The script should use the AWS CLI and standard shell commands (like `ssh`).

## Requirements

Provide a step-by-step guide to perform the following actions manually using the AWS Management Console and SSH.

1.  **Find Instance Details**:
    -   Navigate to the EC2 console and find the Availability Zone for `instance-1`. You will need this to create the EBS volume in the same AZ.
    -   Note the Public IP addresses for both `instance-1` and `instance-2` to connect via SSH.

2.  **Create an EBS Volume**:
    -   In the EC2 console, go to **Elastic Block Store** > **Volumes**.
    -   Click **Create volume**.
    -   Set **Volume type** to `General Purpose SSD (gp2)`.
    -   Set **Size** to `1` GiB.
    -   Select the same **Availability Zone** as `instance-1`.
    -   Add a tag to name the volume (e.g., Key: `Name`, Value: `MyTestVolume`).
    -   Click **Create volume** and wait for its status to become `available`.

3.  **Attach to First Instance (`instance-1`)**:
    -   Select the new volume, then click **Actions** > **Attach volume**.
    -   Choose `instance-1` from the instance list.
    -   Set the **Device name** to `/dev/sdf`.
    -   Click **Attach volume** and wait for the volume's state to become `in-use`.

4.  **Write Data from First Instance**:
    -   Connect to `instance-1` using SSH.
    -   Format the new volume (which appears as `/dev/xvdf` inside the instance): `sudo mkfs -t ext4 /dev/xvdf`
    -   Create a mount point: `sudo mkdir /data`
    -   Mount the volume: `sudo mount /dev/xvdf /data`
    -   Create a test file: `echo "EBS test file" | sudo tee /data/test.txt`
    -   Unmount the volume: `sudo umount /data`

5.  **Detach from First Instance**:
    -   In the EC2 console, select the volume.
    -   Click **Actions** > **Detach volume** and confirm.
    -   Wait for the volume's status to return to `available`.

6.  **Attach to Second Instance (`instance-2`)**:
    -   Select the same volume, then click **Actions** > **Attach volume**.
    -   Choose `instance-2` from the instance list.
    -   Set the **Device name** to `/dev/sdf`.
    -   Click **Attach volume** and wait for the state to become `in-use`.

7.  **Verify Data on Second Instance**:
    -   Connect to `instance-2` using SSH.
    -   Create a mount point: `sudo mkdir /data`
    -   Mount the volume: `sudo mount /dev/xvdf /data`
    -   Verify the file's content: `cat /data/test.txt`
    -   The output should be "EBS test file".
