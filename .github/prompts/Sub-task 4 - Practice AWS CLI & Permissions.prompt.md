## Sub-task 4: Practice AWS CLI & Permissions

### 1. List all objects in `bucket1`

```sh
aws s3api list-objects-v2 --bucket bucket1
```

#### Filter only S3 object keys using `--query`:

```sh
aws s3api list-objects-v2 --bucket bucket1 --query "Contents[].Key"
```

### 2. Try with different users (from module 2)

#### Upload a new file:

```sh
aws s3 cp myfile.txt s3://bucket1/
```

#### List all objects:

```sh
aws s3 ls s3://bucket1/
```

### 3. Observe results

- Note differences in permissions and access between users.

### 4. Optional: List objects with size in human-readable table

```sh
aws s3api list-objects-v2 --bucket bucket1 \
    --query "Contents[].[Key, Size]" \
    --output table
```
