# Complete Lambda Deployment Instructions - Step by Step

## Prerequisite Status ✅

- ✅ SQS Queue created: `webproject-UploadsNotificationQueue`
- ✅ SNS Topic created: `webproject-UploadsNotificationTopic`
- ✅ Web app code updated - removed background worker
- ✅ Lambda function code ready: `lambda-function/index.js`

---

## STEP-BY-STEP DEPLOYMENT VIA AWS CONSOLE

### Step 1: Open AWS Console
- Go to: https://console.aws.amazon.com
- Region: **ap-south-1**
- Sign in with your AWS account

### Step 2: Create IAM Role for Lambda

1. Navigate to: **IAM → Roles → Create role**
2. Select trusted entity: **AWS service**
3. Service: **Lambda**
4. Click **Next**
5. Add permissions: **Search and select**
   - ✅ `AWSLambdaBasicExecutionRole` (for CloudWatch logs)
   - Click **Next**
6. Role name: **webproject-UploadsNotificationLambdaRole**
7. Click **Create role**
8. **Note the Role ARN** (you'll need this in Step 4)

### Step 3: Add Custom Policies to the Role

1. Go to **IAM → Roles → webproject-UploadsNotificationLambdaRole**
2. Click **Add inline policy**

**Policy 1: SQS Permissions**
- Click **JSON** tab
- Copy and paste:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility"
      ],
      "Resource": "arn:aws:sqs:ap-south-1:908601827639:webproject-UploadsNotificationQueue"
    }
  ]
}
```
- Policy name: **webproject-lambda-sqs-policy**
- Click **Create policy**

**Policy 2: SNS Permissions**
- Click **Add inline policy** again
- Click **JSON** tab
- Copy and paste:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sns:Publish",
      "Resource": "arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic"
    }
  ]
}
```
- Policy name: **webproject-lambda-sns-policy**
- Click **Create policy**

### Step 4: Create Lambda Function

1. Navigate to: **Lambda → Functions → Create function**
2. Fill in:
   - **Function name**: `webproject-UploadsNotificationFunction`
   - **Runtime**: Node.js 18.x
   - **Execution role**: **Use an existing role**
   - **Existing role**: Select `webproject-UploadsNotificationLambdaRole`
3. Click **Create function**

### Step 5: Add Lambda Function Code

1. In the Lambda function page, find the **Code** section
2. You'll see an `index.js` file
3. Replace the entire content with the code from: [lambda-function/index.js](./lambda-function/index.js)
4. Click **Deploy**

### Step 6: Add Environment Variables

1. Go to **Configuration → Environment variables**
2. Click **Edit**
3. Add:
   - **Key**: `SNS_TOPIC_ARN`
   - **Value**: `arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic`
4. Click **Save**

### Step 7: Configure Lambda Settings (Optional but Recommended)

1. Go to **Configuration → General configuration**
2. Click **Edit**
3. Set:
   - **Timeout**: 60 seconds
   - **Memory**: 256 MB
4. Click **Save**

### Step 8: Add SQS Trigger

1. In Lambda function page, click **Add trigger**
2. Select trigger source: **SQS**
3. Configure:
   - **SQS queue**: `webproject-UploadsNotificationQueue`
   - **Batch size**: 10
   - **Batch window**: 5 seconds
   - **Function response types**: ✅ Report batch item failures
   - **Enabled**: ✅ Yes
4. Click **Add**

### Step 9: Verify Deployment

1. Go to Lambda function → **Triggers** tab
2. Verify SQS trigger shows **Enabled**
3. Go to **Code** tab
4. Verify your code is there
5. Go to **Configuration** tab
6. Verify environment variables are set

---

## Testing the Lambda Function

### Test 1: Manual Invocation

1. Go to Lambda function → **Code** tab
2. Create test event:
```json
{
  "Records": [
    {
      "messageId": "test-message-1",
      "body": "{\"eventId\":\"test-1\",\"fileName\":\"test-image.jpg\",\"fileSize\":2048576,\"fileExtension\":\".jpg\",\"description\":\"Test upload\",\"timestamp\":\"2026-01-19T13:00:00Z\",\"uploadedBy\":\"test-user\"}"
    }
  ]
}
```
3. Click **Test**
4. Check execution result

### Test 2: Upload Images via Web App

1. Access your web application
2. **Upload Image 1**:
   - Upload any image
   - Note the response
   - Should return quickly (< 1 second)
3. **Check Results**:
   - Check **CloudWatch Logs** for execution
   - Check your **email inbox** for SNS notification
   - Verify email contains image details
4. **Upload Image 2**:
   - Repeat above steps
   - Verify second email arrives with different image details
5. **Verify Email Contents**:
   - Should show file name
   - Should show file size
   - Should show upload timestamp
   - Should show event ID

### Test 3: Monitor SQS Queue

```powershell
# Check queue depth (should be 0 or very small)
aws sqs get-queue-attributes `
  --queue-url https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue `
  --attribute-names ApproximateNumberOfMessages `
  --region ap-south-1

# Should show: ApproximateNumberOfMessages: 0
```

### Test 4: Check Lambda Logs

```powershell
# View real-time logs
aws logs tail /aws/lambda/webproject-UploadsNotificationFunction --follow --region ap-south-1

# You should see:
# - "Received event:"
# - "Processing Message ID:"
# - "Published to SNS. Message ID:"
```

---

## Troubleshooting Guide

### Issue: Lambda not executing after upload

**Diagnosis**:
```powershell
# Check event source mapping status
aws lambda list-event-source-mappings `
  --function-name webproject-UploadsNotificationFunction `
  --region ap-south-1
```

**Solution**:
- Verify State is "Enabled"
- Check Lambda execution role has SQS permissions
- Check SQS queue URL matches exactly

### Issue: Emails not arriving

**Diagnosis**:
```powershell
# Check SNS subscriptions
aws sns list-subscriptions-by-topic `
  --topic-arn arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic `
  --region ap-south-1
```

**Solution**:
- Verify email subscription status is "Confirmed" (not "PendingConfirmation")
- Check email address is correct
- Look in spam folder
- Check SNS Delivery Status

### Issue: Lambda timeout

**Solution**:
1. Go to Lambda → Configuration → General configuration
2. Increase timeout to 120 seconds
3. Check CloudWatch Logs for actual errors

### Issue: Permission denied errors in logs

**Solution**:
1. Verify Lambda execution role has all three policies attached
2. Check policy Resource ARNs match exactly
3. Verify role is selected correctly in Lambda function

---

## Verification Checklist

- [ ] IAM role created: `webproject-UploadsNotificationLambdaRole`
- [ ] SQS policy attached to role
- [ ] SNS policy attached to role
- [ ] Basic execution policy attached to role
- [ ] Lambda function created: `webproject-UploadsNotificationFunction`
- [ ] Lambda code deployed (index.js)
- [ ] Environment variable set: `SNS_TOPIC_ARN`
- [ ] Lambda timeout set to 60 seconds
- [ ] SQS trigger attached and enabled
- [ ] Manual test invocation successful
- [ ] Image upload #1 successful
  - [ ] Web app response < 1 second
  - [ ] Lambda executed (check logs)
  - [ ] Email #1 received
  - [ ] Email contains image filename
- [ ] Image upload #2 successful
  - [ ] Web app response < 1 second
  - [ ] Lambda executed (check logs)
  - [ ] Email #2 received
  - [ ] Email contains correct filename

---

## Key AWS Console URLs

- Lambda: https://console.aws.amazon.com/lambda/home?region=ap-south-1#/functions
- Lambda Function: https://console.aws.amazon.com/lambda/home?region=ap-south-1#/functions/webproject-UploadsNotificationFunction
- SQS Queue: https://console.aws.amazon.com/sqs/v2/home?region=ap-south-1#/queues/webproject-UploadsNotificationQueue
- SNS Topic: https://console.aws.amazon.com/sns/v3/home?region=ap-south-1#/topics/arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic
- CloudWatch Logs: https://console.aws.amazon.com/logs/home?region=ap-south-1#logsV2:log-groups
- IAM Role: https://console.aws.amazon.com/iam/home#/roles/webproject-UploadsNotificationLambdaRole

---

## Summary

✅ **What's Done**:
1. SQS Queue and SNS Topic created
2. Web application code updated
3. Lambda function code prepared
4. Detailed deployment instructions provided

⏳ **What's Left**:
1. Create Lambda function in AWS console (Steps 2-8 above)
2. Test with image uploads (Testing section above)
3. Verify email notifications work

**Estimated Time**: 15-20 minutes for complete deployment and testing

---

**Created**: January 19, 2026
**Project**: webproject
**Region**: ap-south-1
