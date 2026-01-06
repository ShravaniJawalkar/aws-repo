# Configuration & Setup Examples

## Environment Configuration

### EC2 Instance Environment Variables

```bash
# Set in .bashrc or .profile for permanent configuration
export NODE_ENV=production
export PORT=8080
export S3_BUCKET=shravani-jawalkar-webproject-bucket
export AWS_REGION=ap-south-1

# Optional: Custom logging
export LOG_LEVEL=info
```

### .env File (if using dotenv)

```env
# Server Configuration
NODE_ENV=production
PORT=8080

# AWS Configuration
S3_BUCKET=shravani-jawalkar-webproject-bucket
AWS_REGION=ap-south-1

# Application Configuration
MAX_FILE_SIZE=10485760
ALLOWED_MIME_TYPES=image/*
```

## AWS Configuration

### IAM Role Policy for S3 Access

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3BucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::shravani-jawalkar-webproject-bucket",
        "arn:aws:s3:::shravani-jawalkar-webproject-bucket/*"
      ]
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

### S3 Bucket Configuration

```bash
# Enable versioning (optional)
aws s3api put-bucket-versioning \
  --bucket shravani-jawalkar-webproject-bucket \
  --versioning-configuration Status=Enabled \
  --region ap-south-1 \
  --profile user-iam-profile

# Enable public read (if needed)
aws s3api put-bucket-policy \
  --bucket shravani-jawalkar-webproject-bucket \
  --policy file://bucket-policy.json \
  --region ap-south-1 \
  --profile user-iam-profile

# Configure CORS (if needed)
aws s3api put-bucket-cors \
  --bucket shravani-jawalkar-webproject-bucket \
  --cors-configuration file://cors-config.json \
  --region ap-south-1 \
  --profile user-iam-profile
```

## Docker Configuration (Optional)

### Dockerfile

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application
COPY app-s3-enhanced.js .

# Set environment
ENV NODE_ENV=production
ENV PORT=8080

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

# Start application
CMD ["node", "app-s3-enhanced.js"]
```

### Docker Compose

```yaml
version: '3.8'

services:
  web-app:
    build: .
    ports:
      - "8080:8080"
    environment:
      NODE_ENV: production
      PORT: 8080
      S3_BUCKET: shravani-jawalkar-webproject-bucket
      AWS_REGION: ap-south-1
    restart: always
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s
```

## PM2 Configuration

### ecosystem.config.js

```javascript
module.exports = {
  apps: [{
    name: 'web-app',
    script: './app-s3-enhanced.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 8080,
      S3_BUCKET: 'shravani-jawalkar-webproject-bucket',
      AWS_REGION: 'ap-south-1'
    },
    error_file: '~/.pm2/logs/web-app-error.log',
    out_file: '~/.pm2/logs/web-app-out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    max_restarts: 10,
    min_uptime: '10s'
  }]
};
```

### Start with PM2

```bash
# Start with config file
pm2 start ecosystem.config.js

# Start and save for auto-restart
pm2 startup
pm2 save

# Monitor
pm2 monit

# View logs
pm2 logs web-app

# Restart
pm2 restart web-app

# Stop
pm2 stop web-app

# Delete
pm2 delete web-app
```

## Nginx Configuration (Optional - for reverse proxy)

### /etc/nginx/sites-available/web-app

```nginx
upstream web_app {
    server localhost:8080;
    keepalive 32;
}

server {
    listen 80;
    server_name your-domain.com;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL Configuration
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Proxy configuration
    location / {
        proxy_pass http://web_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # File upload size limit
    client_max_body_size 10M;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json;
    gzip_min_length 1000;
}
```

## CloudFormation Template Updates

### Add IAM Role to Template

```yaml
Resources:
  # IAM Role for EC2 to access S3
  EC2S3Role:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: 'sts:AssumeRole'
      Policies:
        - PolicyName: S3BucketAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 's3:GetObject'
                  - 's3:PutObject'
                  - 's3:DeleteObject'
                  - 's3:ListBucket'
                Resource:
                  - !Sub 'arn:aws:s3:::${S3BucketName}'
                  - !Sub 'arn:aws:s3:::${S3BucketName}/*'

  # Instance Profile
  EC2InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Roles:
        - !Ref EC2S3Role

  # Update Launch Template to include IAM profile
  ProjectLaunchTemplate:
    Type: AWS::EC2::LaunchTemplate
    Properties:
      LaunchTemplateName: !Sub '${ProjectName}-LaunchTemplate'
      LaunchTemplateData:
        ImageId: !Ref ProjectAMI
        InstanceType: !Ref ProjectInstanceType
        IamInstanceProfile:
          Arn: !GetAtt EC2InstanceProfile.Arn
        SecurityGroupIds:
          - !Ref ProjectSecurityGroup
        UserData:
          Fn::Base64: !Sub |
            #!/bin/bash
            set -e
            yum update -y
            
            # Install Node.js
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
            export NVM_DIR="$HOME/.nvm"
            source "$NVM_DIR/nvm.sh"
            nvm install 18
            
            # Create app directory
            mkdir -p /home/ec2-user/webapp
            cd /home/ec2-user/webapp
            
            # Download app from S3
            aws s3 cp s3://${S3BucketName}/app-s3-enhanced.js . --region ${AWS::Region}
            aws s3 cp s3://${S3BucketName}/package.json . --region ${AWS::Region}
            
            # Install dependencies
            npm install
            
            # Install PM2 globally
            npm install -g pm2
            
            # Start application
            export S3_BUCKET=${S3BucketName}
            export AWS_REGION=${AWS::Region}
            pm2 start app-s3-enhanced.js --name "web-app"
            pm2 startup
            pm2 save
```

## Monitoring Configuration

### CloudWatch Alarms

```bash
# CPU Alarm (high)
aws cloudwatch put-metric-alarm \
  --alarm-name web-app-cpu-high \
  --alarm-description "Alert when CPU exceeds 70%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 70 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions "arn:aws:sns:ap-south-1:ACCOUNT_ID:topic-name"

# Disk Space Alarm
aws cloudwatch put-metric-alarm \
  --alarm-name web-app-disk-high \
  --alarm-description "Alert when disk usage exceeds 80%" \
  --metric-name DiskSpaceUtilization \
  --namespace Custom/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

### CloudWatch Logs Configuration

```bash
# Create log group
aws logs create-log-group \
  --log-group-name /aws/ec2/web-app \
  --region ap-south-1

# Create log stream
aws logs create-log-stream \
  --log-group-name /aws/ec2/web-app \
  --log-stream-name app-logs \
  --region ap-south-1
```

## Application Configuration for Production

### Production-Ready settings in app-s3-enhanced.js

```javascript
// Add to app-s3-enhanced.js for production

// 1. Rate limiting
const rateLimit = require('express-rate-limit');
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: 'Too many requests, please try again later'
});
app.use('/api/', limiter);

// 2. Security headers
const helmet = require('helmet');
app.use(helmet());

// 3. CORS configuration
const cors = require('cors');
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS || '*',
  credentials: true
}));

// 4. Request logging
const morgan = require('morgan');
app.use(morgan('combined'));

// 5. Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});
```

## Testing Configuration

### Jest Configuration (jest.config.js)

```javascript
module.exports = {
  testEnvironment: 'node',
  coverageDirectory: './coverage',
  testMatch: ['**/__tests__/**/*.js', '**/?(*.)+(spec|test).js'],
  collectCoverageFrom: [
    'app-s3-enhanced.js',
    '!node_modules/**'
  ]
};
```

### Example Tests

```javascript
// test/api.test.js
const request = require('supertest');
const app = require('../app-s3-enhanced');

describe('API Endpoints', () => {
  test('GET /health returns healthy status', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);
    
    expect(response.body).toEqual({ status: 'healthy' });
  });

  test('GET /api/images returns array', async () => {
    const response = await request(app)
      .get('/api/images')
      .expect(200);
    
    expect(Array.isArray(response.body.images)).toBe(true);
  });
});
```

## Performance Tuning

### Node.js Optimization

```javascript
// Add to app startup
const cluster = require('cluster');
const os = require('os');

if (cluster.isMaster) {
  const numCPUs = os.cpus().length;
  
  // Fork workers
  for (let i = 0; i < numCPUs; i++) {
    cluster.fork();
  }
  
  cluster.on('exit', (worker) => {
    console.log(`Worker ${worker.process.pid} died`);
    cluster.fork();
  });
} else {
  app.listen(PORT);
}
```

### Database Connection Pooling (if using database)

```javascript
// Connection pooling for RDS
const pool = new aws.RDS.DBProxy({
  poolSize: 10,
  maxIdleTime: 900,
  maxConnections: 100
});
```

## Backup & Recovery

### S3 Bucket Backup

```bash
# Enable versioning
aws s3api put-bucket-versioning \
  --bucket shravani-jawalkar-webproject-bucket \
  --versioning-configuration Status=Enabled \
  --region ap-south-1 \
  --profile user-iam-profile

# Enable MFA delete (requires root account)
aws s3api put-bucket-versioning \
  --bucket shravani-jawalkar-webproject-bucket \
  --versioning-configuration Status=Enabled,MFADelete=Enabled \
  --region ap-south-1 \
  --mfa "arn:aws:iam::ACCOUNT_ID:mfa/device-name 123456"

# Configure lifecycle policy
aws s3api put-bucket-lifecycle-configuration \
  --bucket shravani-jawalkar-webproject-bucket \
  --lifecycle-configuration file://lifecycle-policy.json \
  --region ap-south-1 \
  --profile user-iam-profile
```

### Backup Script

```bash
#!/bin/bash
# backup-s3.sh

BUCKET="shravani-jawalkar-webproject-bucket"
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR
aws s3 sync s3://$BUCKET $BACKUP_DIR/backup_$DATE
echo "Backup completed to $BACKUP_DIR/backup_$DATE"
```

---

Use these configurations as a reference for setting up your production environment with proper security, monitoring, and performance optimization.
