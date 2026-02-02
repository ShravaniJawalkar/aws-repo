# Manual EC2 Deployment Script

param(
    [string]$InstanceName = "webproject-instance",
    [string]$InstanceType = "t3.micro",
    [string]$AwsRegion = "ap-south-1"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "EC2 Instance Manual Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set AWS profile to one with EC2 permissions
$env:AWS_PROFILE="user-ec2-profile"

Write-Host "Verifying AWS credentials..." -ForegroundColor Yellow
try {
    $identity = aws sts get-caller-identity --region $AwsRegion | ConvertFrom-Json
    Write-Host "✓ AWS Account: $($identity.Account)" -ForegroundColor Green
} catch {
    Write-Host "✗ Error: Credentials issue" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Getting latest Amazon Linux 2 AMI..." -ForegroundColor Yellow

# Get latest Amazon Linux 2 AMI
$AMI_ID = aws ec2 describe-images `
    --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" `
    --owners amazon `
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' `
    --output text `
    --region $AwsRegion

Write-Host "✓ AMI ID: $AMI_ID" -ForegroundColor Green

Write-Host ""
Write-Host "Creating security group..." -ForegroundColor Yellow

# Create security group
try {
    $SG_Result = aws ec2 create-security-group `
        --group-name "$InstanceName-sg" `
        --description "Security group for $InstanceName" `
        --region $AwsRegion | ConvertFrom-Json
    
    $SG_ID = $SG_Result.GroupId
    Write-Host "✓ Security Group: $SG_ID" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*InvalidGroup.Duplicate*") {
        Write-Host "! Security group already exists" -ForegroundColor Yellow
        $SG_ID = aws ec2 describe-security-groups `
            --filters "Name=group-name,Values=$InstanceName-sg" `
            --query 'SecurityGroups[0].GroupId' `
            --output text `
            --region $AwsRegion
        Write-Host "✓ Using existing SG: $SG_ID" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Adding security group rules..." -ForegroundColor Yellow

# Add security group rules
$rules = @(
    @{ FromPort = 22; ToPort = 22; Description = "SSH" },
    @{ FromPort = 80; ToPort = 80; Description = "HTTP" },
    @{ FromPort = 443; ToPort = 443; Description = "HTTPS" },
    @{ FromPort = 8080; ToPort = 8080; Description = "Application" }
)

foreach ($rule in $rules) {
    try {
        aws ec2 authorize-security-group-ingress `
            --group-id $SG_ID `
            --protocol tcp `
            --port $rule.FromPort `
            --cidr 0.0.0.0/0 `
            --region $AwsRegion | Out-Null
        Write-Host "✓ Added rule: $($rule.Description) (port $($rule.FromPort))" -ForegroundColor Green
    } catch {
        if ($_.Exception.Message -like "*InvalidPermission.Duplicate*") {
            Write-Host "! Rule already exists: $($rule.Description)" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "Launching EC2 Instance..." -ForegroundColor Yellow

# User data script for application
$UserData = @"
#!/bin/bash
set -e

# Update system
yum update -y
yum install -y git curl wget

# Install Node.js 18
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Create application directory
mkdir -p /var/www/web-dynamic-app
cd /var/www/web-dynamic-app

# Create package.json
cat > package.json << 'EOF'
{
  "name": "web-dynamic-app",
  "version": "1.0.0",
  "main": "app.js",
  "dependencies": {
    "express": "^4.18.0",
    "aws-sdk": "^2.1400.0",
    "uuid": "^9.0.0",
    "axios": "^1.4.0",
    "dotenv": "^16.0.0"
  },
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js"
  }
}
EOF

# Create .env file
cat > .env << 'EOF'
AWS_REGION=ap-south-1
PORT=8080
SQS_QUEUE_URL=https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue
SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic
WORKER_INTERVAL_MS=30000
SQS_BATCH_SIZE=10
LOG_LEVEL=info
EOF

# Create app.js
cat > app.js << 'APPEOF'
const express = require('express');
const aws = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 8080;

const sqs = new aws.SQS({ region: 'ap-south-1' });
const sns = new aws.SNS({ region: 'ap-south-1' });

const QUEUE_URL = process.env.SQS_QUEUE_URL || '';
const TOPIC_ARN = process.env.SNS_TOPIC_ARN || '';

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.post('/api/subscribe', async (req, res) => {
  try {
    const email = req.query.email || req.body.email;
    if (!email || !isValidEmail(email)) {
      return res.status(400).json({ error: 'Valid email required' });
    }
    const result = await sns.subscribe({
      TopicArn: TOPIC_ARN,
      Protocol: 'email',
      Endpoint: email
    }).promise();
    res.status(200).json({
      success: true,
      message: 'Subscription pending. Check email for confirmation.',
      subscriptionArn: result.SubscriptionArn
    });
  } catch (error) {
    console.error('Subscription error:', error);
    res.status(500).json({ error: 'Failed to subscribe', details: error.message });
  }
});

app.post('/api/unsubscribe', async (req, res) => {
  try {
    const email = req.query.email || req.body.email;
    if (!email || !isValidEmail(email)) {
      return res.status(400).json({ error: 'Valid email required' });
    }
    const subscriptions = await sns.listSubscriptionsByTopic({ TopicArn: TOPIC_ARN }).promise();
    const subscription = subscriptions.Subscriptions.find(
      sub => sub.Protocol === 'email' && sub.Endpoint === email
    );
    if (!subscription) {
      return res.status(404).json({ error: 'Email not found' });
    }
    await sns.unsubscribe({ SubscriptionArn: subscription.SubscriptionArn }).promise();
    res.status(200).json({ success: true, message: 'Unsubscribed successfully' });
  } catch (error) {
    console.error('Unsubscription error:', error);
    res.status(500).json({ error: 'Failed to unsubscribe', details: error.message });
  }
});

app.get('/api/subscriptions', async (req, res) => {
  try {
    const subscriptions = await sns.listSubscriptionsByTopic({ TopicArn: TOPIC_ARN }).promise();
    res.status(200).json({
      success: true,
      count: subscriptions.Subscriptions.length,
      subscriptions: subscriptions.Subscriptions
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to list subscriptions', details: error.message });
  }
});

app.post('/api/upload', async (req, res) => {
  try {
    const fileName = req.body.fileName || req.query.fileName || 'image.jpg';
    const fileSize = req.body.fileSize || req.query.fileSize || '1024000';
    const uploadEvent = {
      eventId: uuidv4(),
      fileName: fileName,
      fileSize: parseInt(fileSize),
      fileExtension: getFileExtension(fileName),
      description: req.body.description || req.query.description || 'No description',
      timestamp: new Date().toISOString(),
      uploadedBy: 'web-application'
    };
    const sqsResult = await sqs.sendMessage({
      QueueUrl: QUEUE_URL,
      MessageBody: JSON.stringify(uploadEvent),
      MessageAttributes: {
        ImageExtension: { StringValue: uploadEvent.fileExtension, DataType: 'String' },
        EventType: { StringValue: 'ImageUpload', DataType: 'String' }
      }
    }).promise();
    res.status(201).json({
      success: true,
      message: 'Image uploaded. Notification queued.',
      messageId: sqsResult.MessageId
    });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ error: 'Failed to upload', details: error.message });
  }
});

app.post('/admin/process-queue', async (req, res) => {
  try {
    const messages = await sqs.receiveMessage({
      QueueUrl: QUEUE_URL,
      MaxNumberOfMessages: 10
    }).promise();
    
    if (!messages.Messages) {
      return res.status(200).json({ processed: 0 });
    }
    
    let processed = 0;
    for (const message of messages.Messages) {
      try {
        const event = JSON.parse(message.Body);
        await sns.publish({
          TopicArn: TOPIC_ARN,
          Subject: 'Image Upload: ' + event.fileName,
          Message: formatMessage(event)
        }).promise();
        await sqs.deleteMessage({
          QueueUrl: QUEUE_URL,
          ReceiptHandle: message.ReceiptHandle
        }).promise();
        processed++;
      } catch (err) {
        console.error('Error processing message:', err);
      }
    }
    res.status(200).json({ success: true, processed });
  } catch (error) {
    res.status(500).json({ error: 'Queue processing failed', details: error.message });
  }
});

app.get('/admin/queue-status', async (req, res) => {
  try {
    const attrs = await sqs.getQueueAttributes({
      QueueUrl: QUEUE_URL,
      AttributeNames: ['All']
    }).promise();
    res.status(200).json({
      available: parseInt(attrs.Attributes.ApproximateNumberOfMessages),
      delayed: parseInt(attrs.Attributes.ApproximateNumberOfMessagesDelayed)
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to get queue status' });
  }
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/', (req, res) => {
  res.send(`
    <html>
    <head><title>Web Application</title></head>
    <body style="font-family: Arial; padding: 20px;">
      <h1>Web Application - SQS/SNS</h1>
      <h2>Available Endpoints:</h2>
      <ul>
        <li>POST /api/subscribe?email=user@example.com</li>
        <li>POST /api/unsubscribe?email=user@example.com</li>
        <li>GET /api/subscriptions</li>
        <li>POST /api/upload?fileName=image.jpg&fileSize=1024000</li>
        <li>GET /health</li>
        <li>GET /admin/queue-status</li>
        <li>POST /admin/process-queue</li>
      </ul>
    </body>
    </html>
  `);
});

function formatMessage(event) {
  return \`
Image Upload Notification
========================
File: \${event.fileName}
Size: \${(event.fileSize / 1024 / 1024).toFixed(2)} MB
Time: \${event.timestamp}
Description: \${event.description}
  \`.trim();
}

function isValidEmail(email) {
  return /^[^\\s@]+@[^\\s@]+\\.[^\\s@]+\$/.test(email);
}

function getFileExtension(fileName) {
  return fileName.substring(fileName.lastIndexOf('.')).toLowerCase();
}

const server = app.listen(PORT, () => {
  console.log(\`App listening on port \${PORT}\`);
  console.log(\`SQS: \${QUEUE_URL}\`);
  console.log(\`SNS: \${TOPIC_ARN}\`);
});

process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});
APPEOF

# Install dependencies
npm install

# Create systemd service
sudo bash -c 'cat > /etc/systemd/system/web-app.service << EOF
[Unit]
Description=Web Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/var/www/web-dynamic-app
ExecStart=/usr/bin/node /var/www/web-dynamic-app/app.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF'

# Start service
systemctl daemon-reload
systemctl enable web-app
systemctl start web-app

echo "Application deployment complete"
"@

# Convert to base64 for AWS
$UserDataBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($UserData))

# Launch instance
try {
    $InstanceResult = aws ec2 run-instances `
        --image-id $AMI_ID `
        --instance-type $InstanceType `
        --security-group-ids $SG_ID `
        --user-data $UserData `
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$InstanceName}]" `
        --region $AwsRegion | ConvertFrom-Json
    
    $INSTANCE_ID = $InstanceResult.Instances[0].InstanceId
    Write-Host "✓ Instance launched: $INSTANCE_ID" -ForegroundColor Green
} catch {
    Write-Host "✗ Error launching instance: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Waiting for instance to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Get instance details
$InstanceDetails = aws ec2 describe-instances `
    --instance-ids $INSTANCE_ID `
    --region $AwsRegion | ConvertFrom-Json

$PublicIP = $InstanceDetails.Reservations[0].Instances[0].PublicIpAddress
$PrivateIP = $InstanceDetails.Reservations[0].Instances[0].PrivateIpAddress
$State = $InstanceDetails.Reservations[0].Instances[0].State.Name

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "EC2 Instance Details" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Instance ID:      $INSTANCE_ID" -ForegroundColor Cyan
Write-Host "Instance Type:    $InstanceType" -ForegroundColor Cyan
Write-Host "State:            $State" -ForegroundColor Cyan
Write-Host "Public IP:        $PublicIP" -ForegroundColor Cyan
Write-Host "Private IP:       $PrivateIP" -ForegroundColor Cyan
Write-Host "Security Group:   $SG_ID" -ForegroundColor Cyan
Write-Host ""
Write-Host "Web Application:" -ForegroundColor White
Write-Host "  URL: http://$PublicIP`:8080" -ForegroundColor Cyan
Write-Host ""
Write-Host "SSH Command:" -ForegroundColor White
Write-Host "  ssh -i your-key.pem ec2-user@$PublicIP" -ForegroundColor Cyan
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment in progress..." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Application will be ready in 2-3 minutes." -ForegroundColor Yellow
Write-Host "Monitor progress with:" -ForegroundColor Yellow
Write-Host "  ssh -i your-key.pem ec2-user@$PublicIP" -ForegroundColor Cyan
Write-Host "  sudo tail -f /var/log/cloud-init-output.log" -ForegroundColor Cyan
Write-Host ""
Write-Host "Once ready, test with:" -ForegroundColor Yellow
Write-Host "  curl http://$PublicIP`:8080/health" -ForegroundColor Cyan
Write-Host ""
