# API Documentation: SQS/SNS Subscription Feature

## Base URL
```
http://YOUR_EC2_IP:8080
```

---

## 1. Subscription Management Endpoints

### 1.1 Subscribe Email to Notifications

**Endpoint:** `/api/subscribe`

**Method:** `POST`

**Parameters:**
- `email` (query string or JSON body) - Email address to subscribe

**Request Examples:**

**Via Query String:**
```bash
curl -X POST "http://localhost:8080/api/subscribe?email=user@example.com"
```

**Via PowerShell:**
```powershell
curl -X POST "http://localhost:8080/api/subscribe?email=user@example.com"
```

**Via Request Body (JSON):**
```bash
curl -X POST "http://localhost:8080/api/subscribe" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com"}'
```

**Response (Success - 200):**
```json
{
  "success": true,
  "message": "Subscription pending confirmation. Please check user@example.com for a confirmation email from AWS.",
  "subscriptionArn": "arn:aws:sns:ap-south-1:123456789012:webproject-UploadsNotificationTopic:12345678-1234-1234-1234-123456789012"
}
```

**Response (Error - 400):**
```json
{
  "error": "Valid email is required"
}
```

**Response (Error - 500):**
```json
{
  "error": "Failed to subscribe email",
  "details": "Error message from AWS"
}
```

**Status Codes:**
- `200` - Subscription request accepted (pending confirmation)
- `400` - Invalid email or missing email parameter
- `500` - Server error while processing subscription

**Important Notes:**
- Subscription is **pending** until the user clicks the confirmation link in their email
- AWS SNS sends a confirmation email automatically
- User must confirm within 3 days or subscription expires
- Each email address can only be subscribed once

---

### 1.2 Unsubscribe Email from Notifications

**Endpoint:** `/api/unsubscribe`

**Method:** `POST`

**Parameters:**
- `email` (query string or JSON body) - Email address to unsubscribe

**Request Examples:**

**Via Query String:**
```bash
curl -X POST "http://localhost:8080/api/unsubscribe?email=user@example.com"
```

**Via PowerShell:**
```powershell
curl -X POST "http://localhost:8080/api/unsubscribe?email=user@example.com"
```

**Response (Success - 200):**
```json
{
  "success": true,
  "message": "user@example.com has been unsubscribed from image upload notifications"
}
```

**Response (Error - 404):**
```json
{
  "error": "Email not found in subscriptions"
}
```

**Response (Error - 400):**
```json
{
  "error": "Valid email is required"
}
```

**Status Codes:**
- `200` - Successfully unsubscribed
- `400` - Invalid email
- `404` - Email not found in active subscriptions
- `500` - Server error

**Important Notes:**
- Unsubscription is immediate
- User will not receive further notifications
- Email can be re-subscribed later

---

### 1.3 List All Active Subscriptions

**Endpoint:** `/api/subscriptions`

**Method:** `GET`

**Parameters:** None

**Request Example:**
```bash
curl http://localhost:8080/api/subscriptions
```

**Response (Success - 200):**
```json
{
  "success": true,
  "count": 3,
  "subscriptions": [
    {
      "email": "user1@example.com",
      "protocol": "email",
      "status": "active"
    },
    {
      "email": "user2@example.com",
      "protocol": "email",
      "status": "pending"
    },
    {
      "email": "user3@example.com",
      "protocol": "email",
      "status": "active"
    }
  ]
}
```

**Status Codes:**
- `200` - Success
- `500` - Server error

**Subscription Statuses:**
- `active` - Confirmed, receiving notifications
- `pending` - Awaiting email confirmation
- `unsubscribed` - Not receiving notifications

---

## 2. Image Upload Endpoints

### 2.1 Upload Image and Queue Notification

**Endpoint:** `/api/upload`

**Method:** `POST`

**Parameters:**
- `fileName` (query string or JSON body) - Name of the image file
- `fileSize` (query string or JSON body) - Size of file in bytes
- `description` (optional, query string or JSON body) - Description of the upload

**Request Examples:**

**Via Query String:**
```bash
curl -X POST "http://localhost:8080/api/upload?fileName=vacation.jpg&fileSize=2048576&description=Beach%20photo"
```

**Via PowerShell:**
```powershell
$params = @{
    Uri = "http://localhost:8080/api/upload"
    Method = "POST"
    Body = @{
        fileName = "vacation.jpg"
        fileSize = "2048576"
        description = "Beach photo"
    } | ConvertTo-Json
    ContentType = "application/json"
}
Invoke-WebRequest @params
```

**Response (Success - 201):**
```json
{
  "success": true,
  "message": "Image uploaded successfully. Notification queued.",
  "uploadEvent": {
    "eventId": "550e8400-e29b-41d4-a716-446655440000",
    "fileName": "vacation.jpg",
    "fileSize": 2048576,
    "fileExtension": ".jpg",
    "description": "Beach photo",
    "timestamp": "2024-01-07T10:30:45.123Z",
    "uploadedBy": "web-application"
  },
  "messageId": "8b0b3f0c-1234-5678-9abc-def012345678",
  "downloadUrl": "/api/download/550e8400-e29b-41d4-a716-446655440000/vacation.jpg"
}
```

**Response (Error - 500):**
```json
{
  "error": "Failed to upload image",
  "details": "Error message from AWS SQS"
}
```

**Status Codes:**
- `201` - Image uploaded and notification queued
- `500` - Server error

**Important Notes:**
- Message is added to SQS queue immediately
- Background worker processes it within 30 seconds
- SNS then delivers to all confirmed subscribers
- File extension is automatically extracted from fileName

---

### 2.2 Download Uploaded Image

**Endpoint:** `/api/download/:eventId/:fileName`

**Method:** `GET`

**Parameters:**
- `eventId` (path) - Event ID from upload response
- `fileName` (path) - File name from upload response

**Request Example:**
```bash
curl http://localhost:8080/api/download/550e8400-e29b-41d4-a716-446655440000/vacation.jpg
```

**Response:**
```json
{
  "message": "Download endpoint",
  "eventId": "550e8400-e29b-41d4-a716-446655440000",
  "fileName": "vacation.jpg",
  "note": "This is a placeholder. In production, retrieve from S3."
}
```

**Status Codes:**
- `200` - Success (file content or JSON response)
- `404` - File not found

**Notes:**
- In production, this retrieves from S3 bucket
- Currently returns placeholder response
- Download link is included in SNS notifications

---

## 3. Admin & Management Endpoints

### 3.1 Get Queue Status

**Endpoint:** `/admin/queue-status`

**Method:** `GET`

**Parameters:** None

**Request Example:**
```bash
curl http://localhost:8080/admin/queue-status
```

**Response (Success - 200):**
```json
{
  "success": true,
  "queueUrl": "https://sqs.ap-south-1.amazonaws.com/123456789012/webproject-UploadsNotificationQueue",
  "messages": {
    "available": 5,
    "delayed": 0,
    "notVisible": 2
  },
  "configuration": {
    "visibilityTimeout": "30",
    "messageRetentionPeriod": "345600",
    "receiveMessageWaitTimeSeconds": "20"
  }
}
```

**Message States:**
- `available` - Ready to process
- `delayed` - In retry delay period
- `notVisible` - Currently being processed

---

### 3.2 Manually Process Queue

**Endpoint:** `/admin/process-queue`

**Method:** `POST`

**Parameters:** None

**Request Example:**
```bash
curl -X POST http://localhost:8080/admin/process-queue
```

**Response (Success - 200):**
```json
{
  "success": true,
  "message": "Queue processing triggered"
}
```

**Notes:**
- Automatically triggered every 30 seconds by background worker
- Use this to force immediate processing for testing
- Fetches up to 10 messages per call

---

### 3.3 Send Test Message

**Endpoint:** `/admin/send-test-message`

**Method:** `POST`

**Parameters:** None

**Request Example:**
```bash
curl -X POST http://localhost:8080/admin/send-test-message
```

**Response (Success - 200):**
```json
{
  "success": true,
  "message": "Test message sent to SQS",
  "messageId": "8b0b3f0c-1234-5678-9abc-def012345678",
  "testEvent": {
    "eventId": "550e8400-e29b-41d4-a716-446655440000",
    "fileName": "test-image.jpg",
    "fileSize": 2048576,
    "fileExtension": ".jpg",
    "description": "Test message from admin endpoint",
    "timestamp": "2024-01-07T10:35:20.456Z",
    "uploadedBy": "test-admin"
  }
}
```

**Use Case:**
- Test background processing without real upload
- Verify SNS notifications are working
- Debug message flow through SQS

---

## 4. Health & Information Endpoints

### 4.1 Health Check

**Endpoint:** `/health`

**Method:** `GET`

**Parameters:** None

**Request Example:**
```bash
curl http://localhost:8080/health
```

**Response (Success - 200):**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-07T10:40:15.789Z",
  "features": {
    "subscriptions": true,
    "sqs": true,
    "sns": true,
    "backgroundWorker": true
  }
}
```

---

### 4.2 Root Endpoint (API Documentation)

**Endpoint:** `/`

**Method:** `GET`

**Request Example:**
```bash
curl http://localhost:8080/
```

**Response:** HTML page with API documentation and usage examples

---

## Message Flow & Timing

### Timeline Example

```
1. User calls POST /api/upload (10:00:00)
   └─> Message added to SQS queue

2. Background worker checks queue every 30 seconds
   └─> Next check: 10:00:30

3. Worker processes message (10:00:30)
   └─> Message deleted from SQS
   └─> Published to SNS topic

4. SNS delivers to subscribers
   └─> Email sent immediately (if confirmed)
   └─> Total latency: ~30 seconds

5. Subscriber receives email (10:00:45)
   └─> Contains image metadata and download link
```

---

## SNS Email Notification Format

When a subscriber receives an email notification, it looks like:

```
FROM: AWS Notifications <no-reply@sns.amazonaws.com>
TO: user@example.com
SUBJECT: Image Upload Notification: vacation.jpg

---

IMAGE UPLOAD NOTIFICATION
========================

An image has been successfully uploaded to your web application.

DETAILS:
--------
File Name: vacation.jpg
File Size: 2.0 MB
File Type: .jpg
Upload Time: 2024-01-07T10:00:00.000Z
Description: Beach photo

DOWNLOAD LINK:
--------------
http://YOUR_EC2_IP:8080/api/download/550e8400-e29b.../vacation.jpg

If you no longer wish to receive these notifications, please unsubscribe from this topic.

Thank you!
Web Application Team
```

---

## Message Attributes & Filtering

Messages published to SNS include the following attributes:

```json
{
  "ImageExtension": ".jpg",
  "FileSize": "2048576",
  "EventType": "ImageUpload"
}
```

Subscribers can filter based on these attributes. Example filter policy (PNG files only):

```json
{
  "ImageExtension": [".png"]
}
```

---

## Error Handling

### Validation Errors

**Invalid Email Format:**
```json
{
  "error": "Valid email is required"
}
```

**Invalid File Parameters:**
```json
{
  "error": "Failed to upload image",
  "details": "File name and size are required"
}
```

### AWS Service Errors

**Queue Not Available:**
```json
{
  "error": "Failed to upload image",
  "details": "QueueDoesNotExist: The specified queue does not exist."
}
```

**Permission Denied:**
```json
{
  "error": "Failed to subscribe email",
  "details": "User: arn:aws:iam::... is not authorized to perform: sns:Subscribe"
}
```

---

## Testing Examples

### Complete Workflow Test

```bash
# 1. Subscribe
curl -X POST "http://localhost:8080/api/subscribe?email=test@example.com"

# 2. Check subscriptions
curl http://localhost:8080/api/subscriptions

# 3. Send test message
curl -X POST http://localhost:8080/admin/send-test-message

# 4. Check queue status
curl http://localhost:8080/admin/queue-status

# 5. Process queue
curl -X POST http://localhost:8080/admin/process-queue

# 6. Verify message processed
curl http://localhost:8080/admin/queue-status
```

### Real Upload Workflow

```bash
# 1. Subscribe email
curl -X POST "http://localhost:8080/api/subscribe?email=user@example.com"
# ⚠️ User confirms email by clicking link

# 2. Upload image
curl -X POST "http://localhost:8080/api/upload?fileName=photo.jpg&fileSize=1024000"

# 3. Wait 30 seconds for background worker
sleep 30

# 4. Check email for notification
# Should receive notification with image details and download link
```

---

## Performance Considerations

| Parameter | Value | Notes |
|-----------|-------|-------|
| Background worker interval | 30 seconds | Adjustable in environment |
| Batch size | 10 messages | Max per processing cycle |
| Message visibility timeout | 30 seconds | Time allowed for processing |
| Message retention | 4 days | Unprocessed messages deleted |
| Long polling wait | 20 seconds | Reduces API calls |

---

## Rate Limiting & Quotas

- No rate limiting currently implemented
- AWS SQS: 300 transactions/sec per queue
- AWS SNS: No hard limit on publishes
- Email subscriptions: Limited by AWS SNS quotas

---

## Webhook Integration Example

Subscribe to SNS via webhook:

```bash
curl -X POST "http://localhost:8080/api/subscribe" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "webhook-endpoint",
    "protocol": "https",
    "endpoint": "https://your-server.com/webhook"
  }'
```

Your webhook will receive:

```json
{
  "Type": "Notification",
  "Message": "IMAGE UPLOAD NOTIFICATION\n...",
  "MessageAttributes": {
    "ImageExtension": { "Value": ".jpg" },
    "FileSize": { "Value": "2048576" },
    "EventType": { "Value": "ImageUpload" }
  },
  "Timestamp": "2024-01-07T10:00:30.123Z"
}
```

---

## Troubleshooting

### No Email Received

1. Check subscription status: `GET /api/subscriptions`
2. Verify status is "active" (not "pending")
3. Check AWS SNS email notification settings
4. Look in spam/junk folder
5. Confirm AWS account email settings

### Messages Stuck in Queue

1. Check queue status: `GET /admin/queue-status`
2. Verify background worker is running
3. Check application logs for errors
4. Manually trigger processing: `POST /admin/process-queue`

### Permission Denied Errors

1. Verify EC2 IAM role has correct policies
2. Check role is attached to EC2 instance
3. Verify queue URL and topic ARN are correct
4. Restart application after IAM changes

---

## API Versioning

Current version: **1.0.0**

No versioning prefix in URLs. All endpoints are v1 compatible.

---

## Support

For issues or questions about the API, check:
- Application logs
- AWS CloudWatch
- SNS topic subscription details
- SQS queue attributes

