# Sub-Task 2: Lambda with Synchronous Invocation - Data Consistency Function

## Overview

Create a Lambda function that validates data consistency between RDS database and S3 bucket. The function can be invoked via:
1. **EventBridge Scheduled Rule** (every 5 minutes)
2. **API Gateway** (synchronous HTTP endpoint)
3. **Web Application** (custom endpoint in Node.js app)

All invocations are logged with distinguishable `detail-type` to track invocation sources.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  EventBridge (Scheduled)    API Gateway     Web App         │
│         │                        │              │           │
│         └────────────────────────┴──────────────┘           │
│                                 │                          │
│                    ┌────────────▼────────────┐             │
│                    │  Lambda Function        │             │
│                    │  (VPC Enabled)          │             │
│                    └────────────┬─────────┬──┘             │
│                                 │         │                │
│                    ┌────────────▼──┐  ┌──▼──────────────┐ │
│                    │  RDS Database  │  │  S3 Bucket     │ │
│                    │ (MySQL)        │  │ (VPC Endpoint) │ │
│                    └────────────────┘  └────────────────┘ │
│                                                             │
│  VPC: vpc-04304d2648a6d0753                               │
│  Region: ap-south-1                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Lambda Function
- **File**: `lambda-function/data-consistency.js`
- **Runtime**: Node.js 18.x
- **Memory**: 512 MB
- **Timeout**: 60 seconds
- **VPC**: Deployed in same VPC as RDS for secure DB access

**Key Features**:
- Database connection pool initialized outside handler (best practices)
- Queries RDS for image metadata
- Lists objects from S3 bucket
- Validates consistency
- Returns detailed report with mismatches

### 2. VPC Endpoint for S3
- **Type**: Gateway VPC Endpoint
- **Service**: Amazon S3
- **Purpose**: Secure, private communication between Lambda and S3
- **No charge for data transfer** through VPC endpoint

### 3. Security Groups
- **Lambda SG**: Allows outbound to RDS (port 3306) and HTTPS (443)
- **RDS SG**: Updated to allow inbound from Lambda SG

### 4. IAM Roles & Policies
- **Basic Lambda Execution**: CloudWatch Logs + VPC ENI management
- **S3 Read Policy**: ListBucket + GetObject
- **RDS Access Policy**: rds-db:connect for database authentication

### 5. EventBridge Rule
- **Schedule**: Every 5 minutes (`rate(5 minutes)`)
- **Detail-Type**: `"scheduled"`
- **Target**: Lambda function

### 6. API Gateway
- **Endpoint**: `/consistency` (POST)
- **Detail-Type**: `"api-gateway"`
- **Type**: REST API with Lambda proxy integration

### 7. Web Application Endpoint
- **Path**: `/api/check-consistency` (POST)
- **Detail-Type**: `"web-application"`
- **Type**: Node.js Express endpoint

---

## Deployment Steps

### Step 1: Prepare Lambda Code

```bash
cd lambda-function

# Install dependencies
npm install --prefix . --save aws-sdk mysql2

# Create deployment package
zip -r data-consistency-lambda.zip data-consistency.js node_modules/

# Upload to temporary S3 bucket
aws s3 cp data-consistency-lambda.zip s3://webproject-temp-lambda/
```

### Step 2: Update CloudFormation Template

Modify `lambda-data-consistency-template.yaml`:

```yaml
- Update VPC ID: vpc-04304d2648a6d0753
- Update Subnet IDs: subnet-03f16fceda3f36dec,subnet-0f16a48da72abda1e
- Update DB Security Group: sg-06be32af49a07ede4
- Update DB Password: Set in deployment
```

### Step 3: Deploy Lambda Stack

```bash
# Add RDS SG rule to allow Lambda access
aws ec2 authorize-security-group-ingress \
  --group-id sg-06be32af49a07ede4 \
  --protocol tcp \
  --port 3306 \
  --source-group <LAMBDA_SG_ID> \
  --region ap-south-1

# Deploy CloudFormation stack
aws cloudformation create-stack \
  --stack-name webproject-data-consistency-lambda \
  --template-body file://lambda-data-consistency-template.yaml \
  --parameters \
    ParameterKey=DBPassword,ParameterValue=your_db_password \
    ParameterKey=VpcId,ParameterValue=vpc-04304d2648a6d0753 \
    ParameterKey=SubnetIds,ParameterValue="subnet-03f16fceda3f36dec,subnet-0f16a48da72abda1e" \
    ParameterKey=DBSecurityGroupId,ParameterValue=sg-06be32af49a07ede4 \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-south-1
```

### Step 4: Add Web App Endpoint

Update `web-dynamic-app/app-enhanced.js` to add:

```javascript
// Invoke data consistency Lambda
app.post('/api/check-consistency', async (req, res) => {
  try {
    const lambda = new AWS.Lambda({ region: process.env.AWS_REGION });
    const result = await lambda.invoke({
      FunctionName: 'webproject-DataConsistencyFunction',
      InvocationType: 'RequestResponse',  // Synchronous
      Payload: JSON.stringify({
        source: 'web-application',
        detailType: 'web-application',
        detail: {
          invocationType: 'Web Application endpoint'
        }
      })
    }).promise();

    const responsePayload = JSON.parse(result.Payload);
    res.json(responsePayload);
  } catch (error) {
    console.error('Error invoking Lambda:', error);
    res.status(500).json({ error: error.message });
  }
});
```

### Step 5: Update Web App UI

Add button to web app for consistency checks:

```html
<button onclick="checkConsistency()">Check Data Consistency</button>
```

JavaScript:

```javascript
async function checkConsistency() {
  try {
    const response = await fetch('/api/check-consistency', { method: 'POST' });
    const result = await response.json();
    console.log('Consistency Result:', result);
    // Display results in modal or alert
  } catch (error) {
    console.error('Error:', error);
  }
}
```

---

## Testing

### Test 1: Verify Scheduled Invocation

```bash
# Check EventBridge rule status
aws events describe-rule --name webproject-data-consistency-scheduled

# Monitor CloudWatch logs
aws logs tail /aws/lambda/webproject-DataConsistencyFunction --follow

# Look for: "📌 Invocation Source: aws.events"
# Look for: "📌 Detail Type: scheduled"
```

### Test 2: Test API Gateway Invocation

```bash
# Get API endpoint from CloudFormation outputs
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name webproject-data-consistency-lambda \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayEndpoint`].OutputValue' \
  --output text)

# Invoke API
curl -X POST ${API_ENDPOINT} \
  -H "Content-Type: application/json" \
  -d '{"source": "api-gateway", "detailType": "api-gateway"}'

# Check logs for: "📌 Detail Type: api-gateway"
```

### Test 3: Test Web App Invocation

```bash
# Call web app endpoint
curl -X POST http://webproject-LoadBalancer-418397374.ap-south-1.elb.amazonaws.com/api/check-consistency

# Check logs for: "📌 Detail Type: web-application"
```

### Test 4: Verify Log Distinction

```bash
# Get logs with source filtering
aws logs filter-log-events \
  --log-group-name /aws/lambda/webproject-DataConsistencyFunction \
  --filter-pattern "[SCHEDULED]" \
  --query 'events[].message'

# Should show logs prefixed with [SCHEDULED], [API-GATEWAY], [WEB-APPLICATION]
```

---

## Environment Variables

```bash
DB_HOST=webproject-database.c14e66sq09ij.ap-south-1.rds.amazonaws.com
DB_USER=admin
DB_PASSWORD=<your_password>
DB_NAME=webproject
S3_BUCKET=shravani-jawalkar-webproject-bucket
AWS_REGION=ap-south-1
```

---

## CloudWatch Log Patterns

The Lambda logs with source distinction:

```
[SCHEDULED] Consistency Check Result:
[SCHEDULED] Is Consistent: ✓ YES
[SCHEDULED] All data is consistent between DB and S3

---

[API-GATEWAY] Consistency Check Result:
[API-GATEWAY] Is Consistent: ✗ NO
[API-GATEWAY] ⚠️  Missing in S3 (1):
[API-GATEWAY]   - image.jpg (ID: 123)

---

[WEB-APPLICATION] Consistency Check Result:
[WEB-APPLICATION] Is Consistent: ✓ YES
```

---

## Database Setup

The Lambda expects an `image_uploads` table. Create it:

```sql
CREATE TABLE IF NOT EXISTS image_uploads (
  id INT AUTO_INCREMENT PRIMARY KEY,
  fileName VARCHAR(255) NOT NULL UNIQUE,
  fileSize BIGINT,
  fileExtension VARCHAR(10),
  uploadedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  description TEXT,
  uploadedBy VARCHAR(100)
);
```

---

## Best Practices Implemented

✅ **Connection Pool Outside Handler**: Database pool initialized at module level for connection reuse
✅ **VPC Deployment**: Lambda in same VPC as RDS for secure communication
✅ **VPC Endpoint**: S3 access through private VPC endpoint (no internet traversal)
✅ **IAM Least Privilege**: Minimal permissions for each resource
✅ **Proper Logging**: Distinguishable logs for each invocation source
✅ **Error Handling**: Comprehensive error handling with detailed logs
✅ **Resource Cleanup**: Connection release in finally block

---

## Troubleshooting

### Lambda Cannot Connect to RDS

**Solution**: Check security group rules:
```bash
aws ec2 describe-security-groups --group-ids sg-06be32af49a07ede4 --query 'SecurityGroups[0].IpPermissions'
```

Ensure Lambda SG has inbound rule for port 3306.

### Lambda Cannot Access S3

**Solution**: Check S3 VPC endpoint policy and Lambda IAM role permissions:
```bash
aws s3api list-objects-v2 --bucket shravani-jawalkar-webproject-bucket
```

### Scheduled Rule Not Triggering

**Solution**: Check EventBridge rule status:
```bash
aws events describe-rule --name webproject-data-consistency-scheduled
```

Ensure `State` is `ENABLED`.

---

## Monitoring

### CloudWatch Metrics

```bash
# Get Lambda invocation count
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=webproject-DataConsistencyFunction \
  --start-time 2026-01-21T00:00:00Z \
  --end-time 2026-01-21T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

### CloudWatch Alarms (Optional)

Create alarm for Lambda errors:
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name DataConsistencyLambdaErrors \
  --alarm-description "Alert when Lambda has errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold
```

---

## Cost Estimation

- **Lambda**: ~$0.20/month (1 invocation every 5 minutes)
- **S3 VPC Endpoint**: ~$0.01/hour = ~$7/month
- **RDS**: Existing instance cost
- **CloudWatch Logs**: ~$0.50/GB ingested

---

**Status**: Ready for Deployment  
**Last Updated**: 2026-01-21  
**Next**: Deploy stack and test all 3 invocation sources
