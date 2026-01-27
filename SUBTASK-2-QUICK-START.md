# Sub-Task 2: Lambda Synchronous Invocation - Quick Start Guide

## 📋 What This Task Implements

Create a **Lambda function** that validates data consistency between **RDS database** and **S3 bucket**. The function can be triggered via:
1. **Scheduled**: EventBridge every 5 minutes
2. **API Gateway**: HTTP POST endpoint
3. **Web App**: Custom endpoint in Node.js application

All invocations are logged with source distinction in CloudWatch.

---

## 🎯 Quick Start (5 Steps)

### Step 1: Review Architecture
- **File**: [SUBTASK-2-IMPLEMENTATION-SUMMARY.md](SUBTASK-2-IMPLEMENTATION-SUMMARY.md)
- **Time**: 5 minutes
- **What**: Understand the architecture and components

### Step 2: Deploy Infrastructure
- **File**: `deploy-data-consistency-lambda.sh`
- **Command**: `./deploy-data-consistency-lambda.sh`
- **Time**: 10-15 minutes
- **What**: Deploys all AWS resources via CloudFormation

```bash
chmod +x deploy-data-consistency-lambda.sh
./deploy-data-consistency-lambda.sh
```

When prompted, enter your RDS database password.

### Step 3: Integrate with Web App
- **File**: `web-dynamic-app/app-enhanced.js`
- **Time**: 5 minutes
- **What**: Add `/api/check-consistency` endpoint

See [WEB_APP_INTEGRATION.md](#web-app-integration) for code.

### Step 4: Restart Web App
```bash
cd ~/webapp
pkill -f "npm start"
sleep 2
npm start
```

### Step 5: Test All 3 Invocation Sources
- **Time**: 10 minutes
- **Commands**: See [Testing](#testing) section below

---

## 📁 Project Files

### Core Implementation
```
lambda-function/
  ├── data-consistency.js           # Lambda function code
  └── package-consistency.json      # Dependencies (aws-sdk, mysql2)

lambda-data-consistency-template.yaml  # CloudFormation IaC
```

### Deployment
```
deploy-data-consistency-lambda.sh    # Main deployment script
init-db-consistency-table.sh         # Database initialization
```

### Documentation
```
SUBTASK-2-IMPLEMENTATION-SUMMARY.md  # Complete technical guide
DATA-CONSISTENCY-LAMBDA-GUIDE.md     # Detailed deployment guide
```

---

## 🔧 Architecture Overview

```
┌─────────────────────────────────────────────┐
│  EventBridge (5 min)  API Gateway  Web App  │
│         │                │            │     │
│         └────────────────┴────────────┘     │
│                    │                       │
│         ┌──────────▼──────────┐            │
│         │  Lambda Function    │            │
│         │  VPC-Enabled        │            │
│         └──────────┬──────────┘            │
│                    │                       │
│         ┌──────────┴──────────┐            │
│         ▼                     ▼            │
│      RDS DB              S3 Bucket         │
│    (via SG)        (via VPC Endpoint)      │
│                                             │
│  VPC: vpc-04304d2648a6d0753                │
│  Region: ap-south-1                        │
└─────────────────────────────────────────────┘
```

---

## 🚀 Deployment Steps

### Prerequisites Check
```bash
# Check Node.js
node --version  # v14+ required

# Check MySQL
mysql --version

# Check AWS CLI
aws --version
```

### Run Deployment
```bash
cd ~/aws

chmod +x deploy-data-consistency-lambda.sh
./deploy-data-consistency-lambda.sh

# When prompted: Enter RDS database password
```

### Monitor Progress
```bash
# In another terminal, watch CloudFormation progress
aws cloudformation describe-stacks \
  --stack-name webproject-data-consistency-lambda \
  --query 'Stacks[0].StackStatus' \
  --region ap-south-1 \
  --watch
```

Expected status progression:
- `CREATE_IN_PROGRESS` → `CREATE_COMPLETE`

### Get Deployment Outputs
```bash
aws cloudformation describe-stacks \
  --stack-name webproject-data-consistency-lambda \
  --query 'Stacks[0].Outputs' \
  --output table \
  --region ap-south-1
```

Outputs will include:
- `LambdaFunctionName`: `webproject-DataConsistencyFunction`
- `ApiGatewayEndpoint`: Your HTTP endpoint
- `S3VPCEndpointId`: VPC Endpoint for S3
- `LambdaSecurityGroupId`: Security group for Lambda

---

## 🔗 Web App Integration

### Add Endpoint to Express App

Edit `web-dynamic-app/app-enhanced.js`:

```javascript
// Add after other imports
const AWS = require('aws-sdk');

// Add this endpoint after other routes
app.post('/api/check-consistency', async (req, res) => {
  try {
    console.log('[WEB-APP] Invoking DataConsistencyFunction Lambda...');
    
    const lambda = new AWS.Lambda({ 
      region: process.env.AWS_REGION || 'ap-south-1' 
    });
    
    const result = await lambda.invoke({
      FunctionName: 'webproject-DataConsistencyFunction',
      InvocationType: 'RequestResponse',  // Synchronous
      Payload: JSON.stringify({
        source: 'web-application',
        detailType: 'web-application',
        detail: {
          invocationType: 'Web Application endpoint',
          timestamp: new Date().toISOString()
        }
      })
    }).promise();

    const responsePayload = JSON.parse(result.Payload);
    console.log('[WEB-APP] Lambda response received');
    
    res.json(responsePayload);
  } catch (error) {
    console.error('[WEB-APP] Error invoking Lambda:', error.message);
    res.status(500).json({ 
      error: error.message,
      consistency: { isConsistent: false }
    });
  }
});
```

### Add UI Button

Add HTML button to the consistency check section:

```html
<div id="consistencySection" class="card">
  <h3>🔍 Data Consistency Check</h3>
  <p>Verify that database records match S3 objects</p>
  
  <button class="primary" onclick="checkConsistency()">
    Check Data Consistency
  </button>
  
  <div id="consistencyAlert" class="alert"></div>
</div>
```

### Add JavaScript Handler

```javascript
async function checkConsistency() {
  try {
    showAlert('consistencyAlert', 'Checking data consistency...', 'info');
    
    const response = await fetch('/api/check-consistency', { 
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });
    
    const result = await response.json();
    
    if (result.consistency.isConsistent) {
      showAlert('consistencyAlert', 
        `✓ Data is consistent!\n\nMatched Images: ${result.consistency.totalDBImages}`, 
        'success');
    } else {
      let message = '✗ Data inconsistency found!\n\n';
      if (result.consistency.missingInS3.length > 0) {
        message += `Missing in S3: ${result.consistency.missingInS3.length}\n`;
      }
      if (result.consistency.orphanedInS3.length > 0) {
        message += `Orphaned in S3: ${result.consistency.orphanedInS3.length}\n`;
      }
      showAlert('consistencyAlert', message, 'error');
    }
  } catch (error) {
    showAlert('consistencyAlert', '❌ Error: ' + error.message, 'error');
  }
}
```

### Upload and Restart

```bash
# Upload updated app to S3
aws s3 cp web-dynamic-app/app-enhanced.js s3://shravani-jawalkar-webproject-bucket/ \
  --profile user-s3-profile

# Restart app on EC2 (via EC2 Instance Connect)
cd ~/webapp
pkill -f "npm start"
sleep 2
nohup npm start > app.log 2>&1 &
```

---

## 🧪 Testing

### Test 1: Scheduled Invocation (EventBridge - every 5 minutes)

```bash
# Monitor CloudWatch logs
aws logs tail /aws/lambda/webproject-DataConsistencyFunction --follow

# Look for these log lines:
# 📌 Invocation Source: aws.events
# 📌 Detail Type: scheduled
# [SCHEDULED] Consistency Check Result:

# Wait 5 minutes to see automated invocation
```

### Test 2: API Gateway Invocation (Synchronous HTTP)

```bash
# Get API endpoint
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name webproject-data-consistency-lambda \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayEndpoint`].OutputValue' \
  --output text \
  --region ap-south-1)

# Call API
curl -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "source": "api-gateway",
    "detailType": "api-gateway"
  }'

# Check logs for:
# 📌 Detail Type: api-gateway
# [API-GATEWAY] Consistency Check Result:
```

### Test 3: Web App Invocation (Synchronous via Node.js)

```bash
# Call web app endpoint
curl -X POST http://webproject-LoadBalancer-418397374.ap-south-1.elb.amazonaws.com/api/check-consistency \
  -H "Content-Type: application/json"

# OR click "Check Data Consistency" button in web UI

# Check logs for:
# 📌 Detail Type: web-application
# [WEB-APPLICATION] Consistency Check Result:
```

### Test 4: Verify Log Distinction

```bash
# Filter logs by [SCHEDULED]
aws logs filter-log-events \
  --log-group-name /aws/lambda/webproject-DataConsistencyFunction \
  --filter-pattern "[SCHEDULED]" \
  --region ap-south-1

# Filter logs by [API-GATEWAY]
aws logs filter-log-events \
  --log-group-name /aws/lambda/webproject-DataConsistencyFunction \
  --filter-pattern "[API-GATEWAY]" \
  --region ap-south-1

# Filter logs by [WEB-APPLICATION]
aws logs filter-log-events \
  --log-group-name /aws/lambda/webproject-DataConsistencyFunction \
  --filter-pattern "[WEB-APPLICATION]" \
  --region ap-south-1
```

---

## 📊 Example Log Output

```
==================================================
📌 Invocation Source: aws.events
📌 Detail Type: scheduled
📌 Timestamp: 2026-01-21T12:00:00.000Z
📌 Request ID: 12345abc
==================================================

[DB] Querying image records from database...
✓ Found 3 images in database

[S3] Querying objects from S3 bucket...
✓ Found 3 images in S3 bucket

[VALIDATION] Checking data consistency...

[SCHEDULED] Consistency Check Result:
[SCHEDULED] Is Consistent: ✓ YES
[SCHEDULED] Total Matched: 3
[SCHEDULED] Total Inconsistencies: 0
[SCHEDULED] ✓ All data is consistent between DB and S3

==================================================
```

---

## 🐛 Troubleshooting

### Lambda Cannot Connect to RDS

**Symptom**: Lambda invocation fails with "Error connecting to database"

**Solution**:
```bash
# Check Lambda security group has outbound rule to RDS
aws ec2 describe-security-groups \
  --group-ids <LAMBDA_SG_ID> \
  --query 'SecurityGroups[0].IpPermissionsEgress'
```

Must have rule: Protocol=TCP, Port=3306, CIDR=10.0.0.0/16

### Lambda Cannot Access S3

**Symptom**: Lambda fails with "Access Denied" for S3

**Solution**:
```bash
# Verify IAM policy on Lambda role
aws iam get-role-policy \
  --role-name webproject-DataConsistencyFunction-Role \
  --policy-name webproject-lambda-s3-read-policy
```

### Scheduled Rule Not Firing

**Symptom**: EventBridge rule not triggering Lambda

**Solution**:
```bash
# Check rule is enabled
aws events describe-rule --name webproject-data-consistency-scheduled

# Should show: "State": "ENABLED"

# Check targets
aws events list-targets-by-rule --rule webproject-data-consistency-scheduled
```

### API Gateway Endpoint Errors

**Symptom**: 502 Bad Gateway or endpoint not found

**Solution**:
```bash
# Verify API Gateway deployment
aws apigateway get-rest-apis \
  --query 'items[?name==`webproject-data-consistency-api`]'

# Check stage
aws apigateway get-stage \
  --rest-api-id <API_ID> \
  --stage-name prod
```

---

## 📈 Monitoring

### CloudWatch Metrics

```bash
# Get Lambda invocation count (last hour)
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=webproject-DataConsistencyFunction \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --region ap-south-1
```

### CloudWatch Alarms (Optional)

```bash
# Create alarm for Lambda errors
aws cloudwatch put-metric-alarm \
  --alarm-name DataConsistencyLambdaErrors \
  --alarm-description "Alert on Lambda errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=FunctionName,Value=webproject-DataConsistencyFunction \
  --region ap-south-1
```

---

## 🔐 Security Features

✅ **VPC Deployment**: Lambda in same VPC as RDS  
✅ **VPC Endpoint**: S3 access without internet traversal  
✅ **Security Groups**: Restrictive ingress/egress rules  
✅ **IAM Least Privilege**: Minimal permissions granted  
✅ **Connection Pooling**: Efficient DB access  
✅ **Error Handling**: Comprehensive exception handling  
✅ **Audit Logging**: Detailed CloudWatch logs with source tracking  

---

## 📚 Additional Resources

- [Complete Implementation Guide](SUBTASK-2-IMPLEMENTATION-SUMMARY.md)
- [Detailed Deployment Guide](DATA-CONSISTENCY-LAMBDA-GUIDE.md)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [EventBridge Documentation](https://docs.aws.amazon.com/eventbridge/)
- [API Gateway Documentation](https://docs.aws.amazon.com/apigateway/)

---

## ✅ Completion Checklist

- [ ] Review architecture and components
- [ ] Run `./deploy-data-consistency-lambda.sh`
- [ ] Wait for CloudFormation stack to complete
- [ ] Get API Gateway endpoint from outputs
- [ ] Add `/api/check-consistency` endpoint to web app
- [ ] Upload updated app to S3
- [ ] Restart web app
- [ ] Test scheduled invocation (wait 5 minutes)
- [ ] Test API Gateway endpoint
- [ ] Test web app endpoint
- [ ] Verify log distinction in CloudWatch
- [ ] Confirm all 3 invocation types working

---

**Status**: Ready to Deploy  
**Last Updated**: 2026-01-21  
**Next**: Run `./deploy-data-consistency-lambda.sh`
