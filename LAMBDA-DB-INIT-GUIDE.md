# Step-by-Step Guide: Create Lambda Function to Initialize Database

## STEP 1: Create the Lambda Function Code

### 1.1 Create `index.js`
Create a new file named `index.js` with this code:

```javascript
const mysql = require('mysql2/promise');

exports.handler = async (event) => {
    const dbConfig = {
        host: 'webproject-database.c14e66sq09ij.ap-south-1.rds.amazonaws.com',
        user: 'admin',
        password: 'Passwordwebproject2024\'',
        waitForConnections: true,
        connectionLimit: 1,
        queueLimit: 0
    };

    try {
        console.log('Connecting to RDS...');
        const connection = await mysql.createConnection(dbConfig);
        
        console.log('Creating database...');
        await connection.query('CREATE DATABASE IF NOT EXISTS webproject');
        console.log('✓ Database created');
        
        console.log('Creating table...');
        await connection.query(`CREATE TABLE IF NOT EXISTS webproject.image_uploads (
          id INT AUTO_INCREMENT PRIMARY KEY,
          fileName VARCHAR(255) NOT NULL UNIQUE,
          fileSize BIGINT,
          fileExtension VARCHAR(10),
          uploadedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          description TEXT,
          uploadedBy VARCHAR(100),
          INDEX idx_fileName (fileName)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
        console.log('✓ Table created');
        
        await connection.end();
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: 'Database and table initialized successfully',
                database: 'webproject',
                table: 'image_uploads'
            })
        };
    } catch (error) {
        console.error('Error:', error.message);
        return {
            statusCode: 500,
            body: JSON.stringify({
                error: error.message
            })
        };
    }
};
```

### 1.2 Create `package.json`
Create a file named `package.json` with this content:

```json
{
  "name": "db-init",
  "version": "1.0.0",
  "dependencies": {
    "mysql2": "^3.6.0"
  }
}
```

---

## STEP 2: Create Deployment Package

Run these commands in your terminal:

```powershell
# Navigate to your project directory
cd C:\Users\Shravani_Jawalkar\aws

# Install dependencies
npm install

# Create ZIP file (Windows PowerShell)
Compress-Archive -Path index.js, node_modules, package.json -DestinationPath db-init-lambda.zip -Force
```

This creates `db-init-lambda.zip` containing all necessary files.

---

## STEP 3: Create Lambda Function via AWS CLI

Run this command in PowerShell:

```powershell
$RoleArn = "arn:aws:iam::908601827639:role/webproject-DataConsistencyFunction-Role"
$SubnetIds = "subnet-03f16fceda3f36dec,subnet-0f16a48da72abda1e"
$SecurityGroupId = "sg-06be32af49a07ede4"

aws lambda create-function `
    --function-name init-webproject-db `
    --runtime nodejs18.x `
    --role $RoleArn `
    --handler index.handler `
    --zip-file fileb://db-init-lambda.zip `
    --timeout 60 `
    --memory-size 256 `
    --region ap-south-1 `
    --profile user-iam-profile `
    --vpc-config SubnetIds=$SubnetIds,SecurityGroupIds=$SecurityGroupId
```

**Expected Output:**
```
{
    "FunctionName": "init-webproject-db",
    "FunctionArn": "arn:aws:lambda:ap-south-1:908601827639:function:init-webproject-db",
    "Runtime": "nodejs18.x",
    "Handler": "index.handler",
    ...
}
```

---

## STEP 4: Wait for Lambda to be Ready

Lambda takes time to initialize when in a VPC. Wait 90 seconds then check status:

```powershell
aws lambda get-function `
    --function-name init-webproject-db `
    --region ap-south-1 `
    --profile user-iam-profile `
    --query 'Configuration.State' `
    --output text
```

Wait until the output shows `Active`.

---

## STEP 5: Invoke the Lambda Function

Once it shows Active, invoke it:

```powershell
aws lambda invoke `
    --function-name init-webproject-db `
    --region ap-south-1 `
    --profile user-iam-profile `
    --log-type Tail `
    response.json

# View the response
Get-Content response.json
```

**Expected Response:**
```json
{
    "statusCode": 200,
    "body": "{\"message\":\"Database and table initialized successfully\",\"database\":\"webproject\",\"table\":\"image_uploads\"}"
}
```

---

## STEP 6: View Lambda Logs

Check CloudWatch logs to see execution details:

```powershell
aws logs tail /aws/lambda/init-webproject-db `
    --region ap-south-1 `
    --profile user-iam-profile `
    --follow
```

You should see:
```
✓ Connecting to RDS...
✓ Database created
✓ Table created
```

---

## STEP 7: Clean Up (Optional)

After confirming the database was created, delete the Lambda function:

```powershell
aws lambda delete-function `
    --function-name init-webproject-db `
    --region ap-south-1 `
    --profile user-iam-profile
```

---

## STEP 8: Verify Database Creation

Update your data-consistency Lambda to use the database. The Lambda should now connect successfully to the `webproject` database with the `image_uploads` table.

Your current data-consistency Lambda has this configuration in `data-consistency.js`:
```javascript
const dbConfig = {
  host: 'webproject-database.c14e66sq09ij.ap-south-1.rds.amazonaws.com',
  user: 'admin',
  password: "Passwordwebproject2024'",
  database: 'webproject',
  ...
};
```

This will now work!

---

## Troubleshooting

**Issue: Lambda stuck in "Pending" state**
- This is normal for VPC Lambda functions. Wait up to 2 minutes.

**Issue: Connection timeout**
- Verify security groups allow MySQL (port 3306) communication
- Check RDS is in the same VPC as Lambda

**Issue: Authentication failed**
- Verify password: `Passwordwebproject2024'`
- Check username: `admin`
- Ensure RDS instance accepts connections

**Issue: "Unknown database 'webproject'"**
- Lambda didn't execute successfully
- Check logs in CloudWatch
- Ensure Lambda completed without errors

---
