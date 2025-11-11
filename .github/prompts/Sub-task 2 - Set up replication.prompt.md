# Sub-task 2 - Set up replication

## Steps

1. **Enable versioning for bucket1**
    - Navigate to bucket1 in the S3 console
    - Go to Properties tab
    - Enable Bucket Versioning

2. **Create bucket2**
    - Create a new S3 bucket with the following naming requirements:
      - Must begin with a letter
      - Must include your full name
      - Must NOT contain uppercase characters
      - Example: `shravani-jawalkar-replication-bucket`
    - This bucket will be referred to as 'bucket2'

3. **Enable cross-region replication**
    - In bucket1, navigate to the Management tab
    - Create a replication rule
    - Select bucket2 as the destination
    - **Important:** Create a new IAM role when prompted (existing roles may not work properly)

4. **Upload a test file**
    - Upload a new file to bucket1

5. **Verify replication**
    - Check bucket2 for the uploaded file
    - Note: Most objects replicate within 15 minutes, but replication may occasionally take longer
