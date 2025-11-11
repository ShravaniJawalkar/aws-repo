Header:
    description: "Sub-task 3 - Play with versioning"
    mode: Agent
    model: claude-3-5-sonnet
    tools: ["AWS CLI", "S3 API"]
body:

# Sub-task 3 - Play with versioning

## Objective
Demonstrate S3 versioning capabilities by uploading files, creating multiple versions, and retrieving specific versions using AWS CLI.

## Steps

### 1. Upload Initial Files to Bucket
```bash
# Upload 2-3 files to bucket2
aws s3 cp file1.txt s3://bucket2/file1.txt
aws s3 cp file2.txt s3://bucket2/file2.txt
aws s3 cp file3.txt s3://bucket2/file3.txt
```

### 2. Modify and Re-upload Files
```bash
# Make changes to file1.txt locally, then re-upload
aws s3 cp file1.txt s3://bucket2/file1.txt

# Make additional changes and upload again to create more versions
aws s3 cp file1.txt s3://bucket2/file1.txt
```

### 3. Get Latest Version of a Specific File
```bash
# Download the latest version
aws s3 cp s3://bucket2/file1.txt ./file1-latest.txt

# List all versions of a file
aws s3api list-object-versions --bucket bucket2 --prefix file1.txt
```

### 4. Optional: Script to Get Latest Version Before a Given Date

#### Bash Script
```bash
# See full script: get-version-by-date.sh
# Usage: ./get-version-by-date.sh bucket2 file1.txt 2024-01-15
```

Or reference as a relative link:
```markdown
See [get-version-by-date.ps1](../get-version-by-date.ps1) for the complete script.
```

## Verification
- Check version history in S3 console or using `aws s3api list-object-versions`
- Verify downloaded files contain expected content