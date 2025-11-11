#!/bin/bash
# get-version-by-date.sh

BUCKET="bucket2"
KEY="file1.txt"
DATE_THRESHOLD="2024-01-15T00:00:00.000Z"

VERSION_ID=$(aws s3api list-object-versions \
    --bucket "$BUCKET" \
    --prefix "$KEY" \
    --query "Versions[?LastModified<='$DATE_THRESHOLD'] | [0].VersionId" \
    --output text)

if [ "$VERSION_ID" != "None" ]; then
    aws s3api get-object --bucket "$BUCKET" --key "$KEY" --version-id "$VERSION_ID" output-file.txt
    echo "Downloaded version: $VERSION_ID"
else
    echo "No version found before $DATE_THRESHOLD"
fi