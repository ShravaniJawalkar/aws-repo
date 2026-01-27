const express = require('express');
const axios = require('axios');
const AWS = require('aws-sdk');
const multer = require('multer');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8080;

// Configure AWS SDK
const s3 = new AWS.S3({
  signatureVersion: 'v4'
});

const sqs = new AWS.SQS({
  region: process.env.AWS_REGION || 'ap-south-1'
});

const sns = new AWS.SNS({
  region: process.env.AWS_REGION || 'ap-south-1'
});

// Get configuration from environment variables
const S3_BUCKET = process.env.S3_BUCKET || 'shravani-jawalkar-webproject-bucket';
const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL || 'https://sqs.ap-south-1.amazonaws.com/908601827639/webproject-UploadsNotificationQueue';
const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN || 'arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic';

// EC2 metadata service URLs
const REGION_URL = 'http://169.254.169.254/latest/meta-data/placement/region';
const AZ_URL = 'http://169.254.169.254/latest/meta-data/placement/availability-zone';

// Parse JSON body
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Configure multer for file uploads
const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: (req, file, cb) => {
    // Accept image files only
    const allowedMimes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'), false);
    }
  }
});

// ==========================================
// HTML Template with New Features
// ==========================================

const getHTMLPage = (region, availabilityZone, isError = false) => {
  if (isError) {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AWS Metadata - Error</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container { background: white; border-radius: 20px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); padding: 50px; max-width: 600px; width: 100%; text-align: center; }
        .error-icon { font-size: 80px; color: #e74c3c; margin-bottom: 20px; }
        h1 { color: #2c3e50; margin-bottom: 20px; font-size: 28px; }
        .error-message { background: #ffe6e6; border-left: 4px solid #e74c3c; padding: 20px; border-radius: 8px; color: #c0392b; font-size: 16px; line-height: 1.6; }
        .info { margin-top: 30px; color: #7f8c8d; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="error-icon">⚠️</div>
        <h1>Unable to Fetch EC2 Metadata</h1>
        <div class="error-message"><strong>Error:</strong> ${region}</div>
        <div class="info">This application must run on an AWS EC2 instance to access metadata.</div>
    </div>
</body>
</html>`;
  }
  
  return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Image Upload & Notifications</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .main-container { max-width: 1200px; margin: 0 auto; }
        .header {
            background: white;
            padding: 30px;
            border-radius: 15px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            text-align: center;
        }
        .header h1 { color: #667eea; margin-bottom: 10px; font-size: 32px; }
        .metadata-display {
            background: #f5f7ff;
            padding: 20px;
            border-radius: 10px;
            margin-top: 20px;
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }
        .metadata-item { background: white; padding: 15px; border-radius: 8px; text-align: center; }
        .metadata-label { font-weight: 600; color: #667eea; margin-bottom: 8px; }
        .metadata-value { font-size: 18px; color: #2c3e50; }
        .content-area { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 20px; }
        .card {
            background: white;
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .card h2 { color: #667eea; margin-bottom: 20px; font-size: 20px; }
        .card-section { margin-bottom: 20px; }
        .card-section label { display: block; font-weight: 600; margin-bottom: 8px; color: #2c3e50; }
        .form-group { margin-bottom: 15px; }
        input, textarea { width: 100%; padding: 12px; border: 2px solid #e0e0e0; border-radius: 8px; font-family: inherit; font-size: 14px; }
        input:focus, textarea:focus { outline: none; border-color: #667eea; box-shadow: 0 0 5px rgba(102, 126, 234, 0.2); }
        button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 12px 25px;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
            width: 100%;
        }
        button:hover { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4); }
        button:active { transform: translateY(0); }
        button.secondary { background: #95a5a6; }
        .alert {
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 15px;
            display: none;
        }
        .alert.success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; display: block; }
        .alert.error { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; display: block; }
        .alert.info { background: #d1ecf1; color: #0c5460; border: 1px solid #bee5eb; display: block; }
        .gallery {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        .gallery-item {
            background: #f5f7ff;
            border-radius: 8px;
            padding: 10px;
            text-align: center;
            cursor: pointer;
            transition: transform 0.2s;
        }
        .gallery-item:hover { transform: scale(1.05); }
        .gallery-item img { max-width: 100%; max-height: 100px; border-radius: 5px; }
        .gallery-item-name { font-size: 12px; margin-top: 8px; word-break: break-all; color: #666; }
        .loading { text-align: center; color: #667eea; }
        .delete-btn { background: #e74c3c; width: auto; padding: 8px 12px; font-size: 12px; }
        .delete-btn:hover { box-shadow: 0 5px 15px rgba(231, 76, 60, 0.4); }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
        .card { animation: fadeIn 0.6s ease-out; }
    </style>
</head>
<body>
    <div class="main-container">
        <div class="header">
            <h1>☁️ Image Upload & Notification System</h1>
            <p>Powered by AWS S3, SQS, SNS, and Lambda</p>
            <div class="metadata-display">
                <div class="metadata-item">
                    <div class="metadata-label">🌍 AWS Region</div>
                    <div class="metadata-value">${region}</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">📍 Availability Zone</div>
                    <div class="metadata-value">${availabilityZone}</div>
                </div>
            </div>
        </div>

        <div class="content-area">
            <!-- Upload Card -->
            <div class="card">
                <h2>📤 Upload Image</h2>
                <div id="uploadAlert" class="alert"></div>
                <form id="uploadForm">
                    <div class="form-group">
                        <label for="imageFile">Select Image:</label>
                        <input type="file" id="imageFile" name="file" accept="image/*" required>
                    </div>
                    <button type="submit">Upload Image</button>
                </form>
            </div>

            <!-- Subscribe Card -->
            <div class="card">
                <h2>📧 Email Subscription</h2>
                <div id="subscribeAlert" class="alert"></div>
                <form id="subscribeForm">
                    <div class="form-group">
                        <label for="subscribeEmail">Email Address:</label>
                        <input type="email" id="subscribeEmail" name="email" placeholder="user@example.com" required>
                    </div>
                    <button type="submit">Subscribe for Notifications</button>
                </form>
                <div class="card-section" style="margin-top: 20px;">
                    <label>Unsubscribe:</label>
                    <div class="form-group">
                        <input type="email" id="unsubscribeEmail" name="email" placeholder="user@example.com">
                    </div>
                    <button class="secondary" onclick="unsubscribeEmail()">Unsubscribe</button>
                </div>
            </div>

            <!-- Gallery Card -->
            <div class="card">
                <h2>🖼️ Image Gallery</h2>
                <div id="galleryAlert" class="alert"></div>
                <div id="imageGallery" class="gallery"></div>
                <div id="noImages" style="text-align: center; color: #999; margin-top: 20px; display: none;">
                    No images uploaded yet
                </div>
            </div>
        </div>
    </div>

    <script>
        // Load images on page load
        document.addEventListener('DOMContentLoaded', loadImages);

        // Upload form handler
        document.getElementById('uploadForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const file = document.getElementById('imageFile').files[0];
            if (!file) return;

            const formData = new FormData();
            formData.append('file', file);

            try {
                showAlert('uploadAlert', 'Uploading image...', 'info');
                const response = await fetch('/api/upload', {
                    method: 'POST',
                    body: formData
                });

                if (response.ok) {
                    showAlert('uploadAlert', 'Image uploaded successfully!', 'success');
                    document.getElementById('uploadForm').reset();
                    loadImages();
                } else {
                    const error = await response.json();
                    showAlert('uploadAlert', error.message || 'Upload failed', 'error');
                }
            } catch (error) {
                showAlert('uploadAlert', 'Error: ' + error.message, 'error');
            }
        });

        // Subscribe form handler
        document.getElementById('subscribeForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const email = document.getElementById('subscribeEmail').value;

            try {
                showAlert('subscribeAlert', 'Subscribing...', 'info');
                const response = await fetch('/api/subscribe', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email })
                });

                const data = await response.json();
                if (response.ok) {
                    showAlert('subscribeAlert', data.message || 'Subscription successful! Check your email for confirmation.', 'success');
                    document.getElementById('subscribeEmail').value = '';
                } else {
                    showAlert('subscribeAlert', data.message || 'Subscription failed', 'error');
                }
            } catch (error) {
                showAlert('subscribeAlert', 'Error: ' + error.message, 'error');
            }
        });

        // Unsubscribe handler
        async function unsubscribeEmail() {
            const email = document.getElementById('unsubscribeEmail').value;
            if (!email) {
                showAlert('subscribeAlert', 'Please enter an email address', 'error');
                return;
            }

            try {
                showAlert('subscribeAlert', 'Unsubscribing...', 'info');
                const response = await fetch('/api/unsubscribe', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email })
                });

                const data = await response.json();
                if (response.ok) {
                    showAlert('subscribeAlert', data.message || 'Unsubscribed successfully!', 'success');
                    document.getElementById('unsubscribeEmail').value = '';
                } else {
                    showAlert('subscribeAlert', data.message || 'Unsubscribe failed', 'error');
                }
            } catch (error) {
                showAlert('subscribeAlert', 'Error: ' + error.message, 'error');
            }
        }

        // Load images from gallery
        async function loadImages() {
            try {
                const response = await fetch('/api/images');
                const data = await response.json();
                const gallery = document.getElementById('imageGallery');
                const noImages = document.getElementById('noImages');

                gallery.innerHTML = '';

                if (data.images && data.images.length > 0) {
                    noImages.style.display = 'none';
                    data.images.forEach(imageName => {
                        const item = document.createElement('div');
                        item.className = 'gallery-item';
                        item.innerHTML = \`
                            <img src="/api/images/\${encodeURIComponent(imageName)}" alt="\${imageName}">
                            <div class="gallery-item-name">\${imageName}</div>
                            <button class="delete-btn" onclick="deleteImage('\${imageName}')">Delete</button>
                        \`;
                        gallery.appendChild(item);
                    });
                } else {
                    noImages.style.display = 'block';
                }
            } catch (error) {
                console.error('Error loading images:', error);
                showAlert('galleryAlert', 'Failed to load images', 'error');
            }
        }

        // Delete image
        async function deleteImage(imageName) {
            if (!confirm('Are you sure you want to delete this image?')) return;

            try {
                const response = await fetch(\`/api/delete/\${encodeURIComponent(imageName)}\`, {
                    method: 'DELETE'
                });

                if (response.ok) {
                    showAlert('galleryAlert', 'Image deleted successfully', 'success');
                    loadImages();
                } else {
                    showAlert('galleryAlert', 'Failed to delete image', 'error');
                }
            } catch (error) {
                showAlert('galleryAlert', 'Error: ' + error.message, 'error');
            }
        }

        // Show alert function
        function showAlert(alertId, message, type) {
            const alertEl = document.getElementById(alertId);
            alertEl.textContent = message;
            alertEl.className = 'alert ' + type;
            alertEl.style.display = 'block';

            if (type !== 'error' && type !== 'info') {
                setTimeout(() => {
                    alertEl.style.display = 'none';
                }, 5000);
            }
        }
    </script>
</body>
</html>`;
};

// ==========================================
// API Endpoints - Health Check
// ==========================================

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

// ==========================================
// Main Page with Metadata
// ==========================================

app.get('/', async (req, res) => {
  try {
    // Try to fetch metadata, but use fallback values if unavailable
    let region = process.env.AWS_REGION || 'ap-south-1';
    let availability_zone = 'ap-south-1a';
    
    try {
      const [regionResponse, azResponse] = await Promise.all([
        axios.get(REGION_URL, { timeout: 1000 }),
        axios.get(AZ_URL, { timeout: 1000 })
      ]);
      
      region = regionResponse.data;
      availability_zone = azResponse.data;
      console.log('✓ EC2 metadata fetched successfully');
    } catch (metadataError) {
      console.warn('⚠ EC2 metadata service unavailable, using fallback values');
      console.warn('  Region:', region, '| AZ:', availability_zone);
    }

    res.send(getHTMLPage(region, availability_zone));
  } catch (error) {
    console.error('Error rendering page:', error.message);
    res.status(500).send(getHTMLPage('ap-south-1', 'ap-south-1a', true));
  }
});

// ==========================================
// S3 Image Management API Endpoints
// ==========================================

// Upload image to S3
app.post('/api/upload', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file provided' });
    }

    const fileName = req.file.originalname;
    const fileSize = req.file.size;
    const fileExtension = path.extname(fileName);
    const timestamp = new Date().toISOString();
    const eventId = `upload-${Date.now()}`;

    // Upload to S3
    const params = {
      Bucket: S3_BUCKET,
      Key: fileName,
      Body: req.file.buffer,
      ContentType: req.file.mimetype,
      Metadata: {
        'uploaded-at': timestamp,
        'uploaded-from': 'web-application',
        'file-size': fileSize.toString()
      }
    };

    await s3.upload(params).promise();
    console.log(`✓ Image uploaded to S3: ${fileName}`);

    // Send message to SQS queue (NOT SNS - Lambda will handle SNS)
    const sqsMessage = {
      fileName,
      fileSize,
      fileExtension,
      timestamp,
      eventId,
      description: 'Image uploaded via web application',
      uploadedBy: 'WebApplication'
    };

    const sqsParams = {
      QueueUrl: SQS_QUEUE_URL,
      MessageBody: JSON.stringify(sqsMessage)
    };

    await sqs.sendMessage(sqsParams).promise();
    console.log(`✓ Message sent to SQS: ${eventId}`);

    res.json({ 
      message: 'Image uploaded successfully and sent to notification queue',
      name: fileName,
      eventId
    });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ message: 'Error uploading image: ' + error.message });
  }
});

// List all images
app.get('/api/images', async (req, res) => {
  try {
    const params = {
      Bucket: S3_BUCKET
    };

    const data = await s3.listObjectsV2(params).promise();
    const images = (data.Contents || [])
      .filter(obj => !obj.Key.endsWith('/'))
      .map(obj => obj.Key);

    res.json({ images });
  } catch (error) {
    console.error('List error:', error);
    res.status(500).json({ message: 'Error listing images: ' + error.message });
  }
});

// Display image
app.get('/api/images/:imageName', async (req, res) => {
  try {
    const imageName = req.params.imageName;
    const params = {
      Bucket: S3_BUCKET,
      Key: imageName
    };

    const data = await s3.getObject(params).promise();
    res.set('Content-Type', data.ContentType);
    res.send(data.Body);
  } catch (error) {
    console.error('Get image error:', error);
    res.status(404).json({ message: 'Image not found' });
  }
});

// Download image
app.get('/api/download/:imageName', async (req, res) => {
  try {
    const imageName = req.params.imageName;
    const params = {
      Bucket: S3_BUCKET,
      Key: imageName
    };

    const data = await s3.getObject(params).promise();
    res.set('Content-Disposition', 'attachment; filename=' + imageName);
    res.send(data.Body);
  } catch (error) {
    console.error('Download error:', error);
    res.status(404).json({ message: 'Image not found: ' + error.message });
  }
});

// Get image metadata
app.get('/api/metadata/:imageName', async (req, res) => {
  try {
    const imageName = req.params.imageName;
    const params = {
      Bucket: S3_BUCKET,
      Key: imageName
    };

    const data = await s3.headObject(params).promise();
    res.json({
      name: imageName,
      size: data.ContentLength,
      type: data.ContentType,
      lastModified: data.LastModified,
      etag: data.ETag,
      storageClass: data.StorageClass
    });
  } catch (error) {
    console.error('Metadata error:', error);
    res.status(404).json({ message: 'Image not found: ' + error.message });
  }
});

// Get random image metadata
app.get('/api/random-metadata', async (req, res) => {
  try {
    const params = {
      Bucket: S3_BUCKET
    };

    const data = await s3.listObjectsV2(params).promise();
    const images = (data.Contents || [])
      .filter(obj => !obj.Key.endsWith('/'))
      .map(obj => obj.Key);

    if (images.length === 0) {
      return res.status(404).json({ message: 'No images found' });
    }

    const randomImage = images[Math.floor(Math.random() * images.length)];
    const headParams = {
      Bucket: S3_BUCKET,
      Key: randomImage
    };

    const metadata = await s3.headObject(headParams).promise();
    res.json({
      name: randomImage,
      size: metadata.ContentLength,
      type: metadata.ContentType,
      lastModified: metadata.LastModified,
      etag: metadata.ETag,
      storageClass: metadata.StorageClass
    });
  } catch (error) {
    console.error('Random metadata error:', error);
    res.status(500).json({ message: 'Error fetching random image: ' + error.message });
  }
});

// Delete image
app.delete('/api/delete/:imageName', async (req, res) => {
  try {
    const imageName = req.params.imageName;
    const params = {
      Bucket: S3_BUCKET,
      Key: imageName
    };

    await s3.deleteObject(params).promise();
    res.json({ message: 'Image deleted successfully', name: imageName });
  } catch (error) {
    console.error('Delete error:', error);
    res.status(500).json({ message: 'Error deleting image: ' + error.message });
  }
});

// ==========================================
// SNS Subscription/Unsubscription Endpoints
// ==========================================

// Subscribe email to SNS topic
app.post('/api/subscribe', async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ message: 'Email address is required' });
    }

    const params = {
      TopicArn: SNS_TOPIC_ARN,
      Protocol: 'email',
      Endpoint: email
    };

    const result = await sns.subscribe(params).promise();
    console.log(`✓ Email subscription requested: ${email} (SubscriptionArn: ${result.SubscriptionArn})`);

    res.json({
      message: 'Subscription successful! Please check your email for a confirmation message.',
      email,
      subscriptionArn: result.SubscriptionArn
    });
  } catch (error) {
    console.error('Subscription error:', error);
    res.status(500).json({ message: 'Error subscribing email: ' + error.message });
  }
});

// Unsubscribe email from SNS topic
app.post('/api/unsubscribe', async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ message: 'Email address is required' });
    }

    // List all subscriptions to find the one matching this email
    const params = {
      TopicArn: SNS_TOPIC_ARN
    };

    const subscriptions = await sns.listSubscriptionsByTopic(params).promise();
    const subscription = subscriptions.Subscriptions.find(
      sub => sub.Protocol === 'email' && sub.Endpoint === email
    );

    if (!subscription) {
      return res.status(404).json({ 
        message: 'No active subscription found for this email address',
        email
      });
    }

    // Unsubscribe
    await sns.unsubscribe({ SubscriptionArn: subscription.SubscriptionArn }).promise();
    console.log(`✓ Email unsubscribed: ${email}`);

    res.json({
      message: 'Successfully unsubscribed from notifications',
      email
    });
  } catch (error) {
    console.error('Unsubscription error:', error);
    res.status(500).json({ message: 'Error unsubscribing email: ' + error.message });
  }
});

// ==========================================
// Server Start
// ==========================================

app.listen(PORT, () => {
  console.log(`========================================`);
  console.log(`Server is running on port ${PORT}`);
  console.log(`Access the application at http://localhost:${PORT}`);
  console.log(`========================================`);
  console.log(`S3 Bucket: ${S3_BUCKET}`);
  console.log(`SQS Queue URL: ${SQS_QUEUE_URL}`);
  console.log(`SNS Topic ARN: ${SNS_TOPIC_ARN}`);
  console.log(`========================================`);
});
