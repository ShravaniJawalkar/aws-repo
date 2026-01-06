const express = require('express');
const axios = require('axios');
const AWS = require('aws-sdk');
const multer = require('multer');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 8080;

// Configure AWS SDK
const s3 = new AWS.S3({
  signatureVersion: 'v4'
});

// Get S3 bucket name from environment or use default
const S3_BUCKET = process.env.S3_BUCKET || 'shravani-jawalkar-webproject-bucket';

// EC2 metadata service URLs
const REGION_URL = 'http://169.254.169.254/latest/meta-data/placement/region';
const AZ_URL = 'http://169.254.169.254/latest/meta-data/placement/availability-zone';

// Configure multer for file uploads
const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: (req, file, cb) => {
    // Accept image files only
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  }
});

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static('public'));

// ==========================================
// HTML UI Template
// ==========================================
const getHTMLPage = (region, availabilityZone, isError = false) => {
  if (isError) {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AWS Web App - Error</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            padding: 50px;
            max-width: 600px;
            width: 100%;
            text-align: center;
        }
        
        .error-icon {
            font-size: 80px;
            color: #e74c3c;
            margin-bottom: 20px;
        }
        
        h1 {
            color: #2c3e50;
            margin-bottom: 20px;
            font-size: 28px;
        }
        
        .error-message {
            background: #ffe6e6;
            border-left: 4px solid #e74c3c;
            padding: 20px;
            border-radius: 8px;
            color: #c0392b;
            font-size: 16px;
            line-height: 1.6;
        }
        
        .info {
            margin-top: 30px;
            color: #7f8c8d;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="error-icon">⚠️</div>
        <h1>Unable to Fetch EC2 Metadata</h1>
        <div class="error-message">
            <strong>Error:</strong> ${region}
        </div>
        <div class="info">
            This application must run on an AWS EC2 instance to access metadata.
        </div>
    </div>
</body>
</html>
    `;
  }

  return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AWS Web App - Image Management</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .nav-header {
            max-width: 1200px;
            margin: 0 auto 30px;
            background: white;
            border-radius: 15px;
            padding: 20px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .nav-header h1 {
            color: #2c3e50;
            font-size: 24px;
        }
        
        .metadata-badges {
            display: flex;
            gap: 15px;
            flex-wrap: wrap;
        }
        
        .badge {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 8px 15px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        
        .main-container {
            max-width: 1200px;
            margin: 0 auto;
            display: grid;
            grid-template-columns: 1fr 2fr;
            gap: 30px;
        }
        
        .card {
            background: white;
            border-radius: 15px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
        }
        
        .card h2 {
            color: #2c3e50;
            margin-bottom: 20px;
            font-size: 20px;
            border-bottom: 2px solid #667eea;
            padding-bottom: 15px;
        }
        
        .section {
            margin-bottom: 30px;
        }
        
        .section:last-child {
            margin-bottom: 0;
        }
        
        .section h3 {
            color: #34495e;
            font-size: 16px;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .form-group {
            margin-bottom: 15px;
        }
        
        label {
            display: block;
            color: #34495e;
            font-weight: 600;
            margin-bottom: 8px;
            font-size: 14px;
        }
        
        input[type="text"],
        input[type="file"] {
            width: 100%;
            padding: 12px;
            border: 1px solid #ecf0f1;
            border-radius: 8px;
            font-size: 14px;
            transition: border-color 0.3s;
        }
        
        input[type="text"]:focus,
        input[type="file"]:focus {
            outline: none;
            border-color: #667eea;
        }
        
        button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
            font-size: 14px;
            width: 100%;
        }
        
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        
        button:active {
            transform: translateY(0);
        }
        
        .images-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
            gap: 15px;
        }
        
        .image-card {
            background: #f8f9fa;
            border-radius: 10px;
            overflow: hidden;
            transition: transform 0.3s;
            cursor: pointer;
        }
        
        .image-card:hover {
            transform: translateY(-5px);
        }
        
        .image-thumbnail {
            width: 100%;
            height: 120px;
            object-fit: cover;
            background: #ecf0f1;
        }
        
        .image-info {
            padding: 10px;
            text-align: center;
        }
        
        .image-name {
            font-size: 12px;
            color: #34495e;
            font-weight: 600;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        
        .btn-group {
            display: flex;
            gap: 10px;
            margin-top: 10px;
        }
        
        .btn-group button {
            flex: 1;
            padding: 8px 12px;
            font-size: 12px;
        }
        
        .alert {
            padding: 12px 15px;
            border-radius: 8px;
            margin-bottom: 15px;
            font-size: 14px;
        }
        
        .alert-success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        .alert-error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .loading {
            display: none;
            text-align: center;
            color: #667eea;
            font-weight: 600;
        }
        
        .metadata-item {
            background: #f8f9fa;
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 10px;
        }
        
        .metadata-label {
            font-size: 12px;
            color: #7f8c8d;
            font-weight: 600;
            text-transform: uppercase;
            margin-bottom: 5px;
        }
        
        .metadata-value {
            font-size: 16px;
            color: #2c3e50;
            font-weight: bold;
        }
        
        @media (max-width: 768px) {
            .main-container {
                grid-template-columns: 1fr;
            }
            
            .nav-header {
                flex-direction: column;
                gap: 15px;
                text-align: center;
            }
            
            .metadata-badges {
                justify-content: center;
            }
        }
    </style>
</head>
<body>
    <div class="nav-header">
        <h1>☁️ AWS Web Application</h1>
        <div class="metadata-badges">
            <div class="badge">🌍 Region: ${region}</div>
            <div class="badge">📍 AZ: ${availabilityZone}</div>
        </div>
    </div>
    
    <div class="main-container">
        <!-- Left Panel: Operations -->
        <div class="card">
            <h2>🖼️ Image Operations</h2>
            
            <!-- Upload Section -->
            <div class="section">
                <h3>📤 Upload Image</h3>
                <form id="uploadForm">
                    <div class="form-group">
                        <label for="imageFile">Select Image:</label>
                        <input type="file" id="imageFile" required accept="image/*">
                    </div>
                    <button type="submit">Upload Image</button>
                </form>
            </div>
            
            <!-- Download Section -->
            <div class="section">
                <h3>📥 Download Image</h3>
                <div class="form-group">
                    <label for="downloadName">Image Name:</label>
                    <input type="text" id="downloadName" placeholder="e.g., photo.jpg">
                </div>
                <button onclick="downloadImage()">Download Image</button>
            </div>
            
            <!-- Metadata Section -->
            <div class="section">
                <h3>📋 Get Image Metadata</h3>
                <div class="form-group">
                    <label for="metadataName">Image Name:</label>
                    <input type="text" id="metadataName" placeholder="e.g., photo.jpg">
                </div>
                <button onclick="getImageMetadata()">Get Metadata</button>
            </div>
            
            <!-- Random Metadata Section -->
            <div class="section">
                <h3>🎲 Random Image Metadata</h3>
                <button onclick="getRandomImageMetadata()">Get Random Image</button>
            </div>
            
            <!-- Delete Section -->
            <div class="section">
                <h3>🗑️ Delete Image</h3>
                <div class="form-group">
                    <label for="deleteName">Image Name:</label>
                    <input type="text" id="deleteName" placeholder="e.g., photo.jpg">
                </div>
                <button onclick="deleteImage()" style="background: linear-gradient(135deg, #e74c3c 0%, #c0392b 100%);">Delete Image</button>
            </div>
        </div>
        
        <!-- Right Panel: Gallery & Results -->
        <div class="card">
            <h2>🖼️ Image Gallery</h2>
            <div id="alertContainer"></div>
            <div id="loadingSpinner" class="loading">Loading images...</div>
            <div id="imageGallery" class="images-grid"></div>
            <div id="metadataDisplay" style="margin-top: 20px;"></div>
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
                showLoading(true);
                const response = await fetch('/api/upload', {
                    method: 'POST',
                    body: formData
                });
                
                if (response.ok) {
                    showAlert('Image uploaded successfully!', 'success');
                    document.getElementById('uploadForm').reset();
                    loadImages();
                } else {
                    const error = await response.json();
                    showAlert(error.message || 'Upload failed', 'error');
                }
            } catch (error) {
                showAlert('Error uploading image: ' + error.message, 'error');
            } finally {
                showLoading(false);
            }
        });
        
        async function loadImages() {
            try {
                showLoading(true);
                const response = await fetch('/api/images');
                const data = await response.json();
                
                if (response.ok) {
                    displayImages(data.images || []);
                } else {
                    showAlert(data.message || 'Failed to load images', 'error');
                }
            } catch (error) {
                showAlert('Error loading images: ' + error.message, 'error');
            } finally {
                showLoading(false);
            }
        }
        
        function displayImages(images) {
            const gallery = document.getElementById('imageGallery');
            
            if (images.length === 0) {
                gallery.innerHTML = '<p style="grid-column: 1/-1; text-align: center; color: #95a5a6;">No images yet. Upload one to get started!</p>';
                return;
            }
            
            gallery.innerHTML = images.map(img => \`
                <div class="image-card">
                    <img src="/api/images/\${img}" alt="\${img}" class="image-thumbnail" onclick="getImageMetadata('\${img}')">
                    <div class="image-info">
                        <div class="image-name" title="\${img}">\${img}</div>
                        <div class="btn-group">
                            <button onclick="downloadImage('\${img}')" style="padding: 5px;">📥</button>
                            <button onclick="deleteImage('\${img}')" style="padding: 5px; background: linear-gradient(135deg, #e74c3c 0%, #c0392b 100%);">🗑️</button>
                        </div>
                    </div>
                </div>
            \`).join('');
        }
        
        async function downloadImage(name = null) {
            const imageName = name || document.getElementById('downloadName').value.trim();
            if (!imageName) {
                showAlert('Please enter an image name', 'error');
                return;
            }
            
            try {
                window.location.href = '/api/download/' + encodeURIComponent(imageName);
            } catch (error) {
                showAlert('Error downloading image: ' + error.message, 'error');
            }
        }
        
        async function getImageMetadata(name = null) {
            const imageName = name || document.getElementById('metadataName').value.trim();
            if (!imageName) {
                showAlert('Please enter an image name', 'error');
                return;
            }
            
            try {
                showLoading(true);
                const response = await fetch('/api/metadata/' + encodeURIComponent(imageName));
                const data = await response.json();
                
                if (response.ok) {
                    displayMetadata(data);
                } else {
                    showAlert(data.message || 'Image not found', 'error');
                }
            } catch (error) {
                showAlert('Error fetching metadata: ' + error.message, 'error');
            } finally {
                showLoading(false);
            }
        }
        
        async function getRandomImageMetadata() {
            try {
                showLoading(true);
                const response = await fetch('/api/random-metadata');
                const data = await response.json();
                
                if (response.ok) {
                    showAlert('Random image: ' + data.name, 'success');
                    displayMetadata(data);
                } else {
                    showAlert(data.message || 'No images available', 'error');
                }
            } catch (error) {
                showAlert('Error fetching random metadata: ' + error.message, 'error');
            } finally {
                showLoading(false);
            }
        }
        
        async function deleteImage(name = null) {
            const imageName = name || document.getElementById('deleteName').value.trim();
            if (!imageName) {
                showAlert('Please enter an image name', 'error');
                return;
            }
            
            if (!confirm('Are you sure you want to delete ' + imageName + '?')) return;
            
            try {
                showLoading(true);
                const response = await fetch('/api/delete/' + encodeURIComponent(imageName), {
                    method: 'DELETE'
                });
                
                if (response.ok) {
                    showAlert('Image deleted successfully!', 'success');
                    document.getElementById('deleteName').value = '';
                    loadImages();
                } else {
                    const data = await response.json();
                    showAlert(data.message || 'Delete failed', 'error');
                }
            } catch (error) {
                showAlert('Error deleting image: ' + error.message, 'error');
            } finally {
                showLoading(false);
            }
        }
        
        function displayMetadata(metadata) {
            const display = document.getElementById('metadataDisplay');
            display.innerHTML = \`
                <div style="background: #f8f9fa; padding: 15px; border-radius: 8px;">
                    <h3 style="margin-bottom: 15px; color: #2c3e50;">📊 Image Metadata</h3>
                    <div class="metadata-item">
                        <div class="metadata-label">Name</div>
                        <div class="metadata-value">\${metadata.name}</div>
                    </div>
                    <div class="metadata-item">
                        <div class="metadata-label">Size</div>
                        <div class="metadata-value">\${formatBytes(metadata.size)}</div>
                    </div>
                    <div class="metadata-item">
                        <div class="metadata-label">Last Modified</div>
                        <div class="metadata-value">\${new Date(metadata.lastModified).toLocaleString()}</div>
                    </div>
                    <div class="metadata-item">
                        <div class="metadata-label">MIME Type</div>
                        <div class="metadata-value">\${metadata.contentType}</div>
                    </div>
                </div>
            \`;
        }
        
        function formatBytes(bytes) {
            if (bytes === 0) return '0 Bytes';
            const k = 1024;
            const sizes = ['Bytes', 'KB', 'MB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
        }
        
        function showAlert(message, type) {
            const container = document.getElementById('alertContainer');
            const alert = document.createElement('div');
            alert.className = 'alert alert-' + type;
            alert.textContent = message;
            container.innerHTML = '';
            container.appendChild(alert);
            
            setTimeout(() => {
                alert.remove();
            }, 5000);
        }
        
        function showLoading(show) {
            document.getElementById('loadingSpinner').style.display = show ? 'block' : 'none';
        }
    </script>
</body>
</html>
  `;
};

// ==========================================
// API Endpoints
// ==========================================

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

// Root endpoint with UI
app.get('/', async (req, res) => {
  try {
    const [regionResponse, azResponse] = await Promise.all([
      axios.get(REGION_URL, { timeout: 2000 }),
      axios.get(AZ_URL, { timeout: 2000 })
    ]);

    const region = regionResponse.data;
    const availability_zone = azResponse.data;
    res.send(getHTMLPage(region, availability_zone));
  } catch (error) {
    console.error('Error fetching EC2 metadata:', error.message);
    const errorMessage = 'Unable to fetch EC2 metadata. This application must run on an EC2 instance.';
    res.status(500).send(getHTMLPage(errorMessage, '', true));
  }
});

// ==========================================
// S3 Image API Endpoints
// ==========================================

// Upload image to S3
app.post('/api/upload', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file provided' });
    }

    const fileName = req.file.originalname;
    const params = {
      Bucket: S3_BUCKET,
      Key: fileName,
      Body: req.file.buffer,
      ContentType: req.file.mimetype,
      Metadata: {
        'uploaded-at': new Date().toISOString(),
        'uploaded-from': 'web-application'
      }
    };

    await s3.upload(params).promise();
    res.json({ message: 'Image uploaded successfully', name: fileName });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ message: 'Error uploading image: ' + error.message });
  }
});

// List all images in S3 bucket
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

// Download image from S3
app.get('/api/download/:imageName', async (req, res) => {
  try {
    const imageName = req.params.imageName;
    const params = {
      Bucket: S3_BUCKET,
      Key: imageName
    };

    const data = await s3.getObject(params).promise();
    res.set('Content-Type', data.ContentType);
    res.set('Content-Disposition', 'attachment; filename=' + imageName);
    res.send(data.Body);
  } catch (error) {
    console.error('Download error:', error);
    res.status(404).json({ message: 'Image not found: ' + error.message });
  }
});

// Get image (display)
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

// Get metadata for specific image
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
      contentType: data.ContentType,
      lastModified: data.LastModified,
      etag: data.ETag,
      storageClass: data.StorageClass
    });
  } catch (error) {
    console.error('Metadata error:', error);
    res.status(404).json({ message: 'Image not found: ' + error.message });
  }
});

// Get metadata for random image
app.get('/api/random-metadata', async (req, res) => {
  try {
    const listParams = {
      Bucket: S3_BUCKET
    };

    const listData = await s3.listObjectsV2(listParams).promise();
    const images = (listData.Contents || [])
      .filter(obj => !obj.Key.endsWith('/'))
      .map(obj => obj.Key);

    if (images.length === 0) {
      return res.status(404).json({ message: 'No images available' });
    }

    const randomImage = images[Math.floor(Math.random() * images.length)];
    const headParams = {
      Bucket: S3_BUCKET,
      Key: randomImage
    };

    const headData = await s3.headObject(headParams).promise();
    res.json({
      name: randomImage,
      size: headData.ContentLength,
      contentType: headData.ContentType,
      lastModified: headData.LastModified,
      etag: headData.ETag,
      storageClass: headData.StorageClass
    });
  } catch (error) {
    console.error('Random metadata error:', error);
    res.status(500).json({ message: 'Error fetching random image: ' + error.message });
  }
});

// Delete image from S3
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
// Server Start
// ==========================================
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
  console.log(`Access the application at http://localhost:${PORT}`);
  console.log(`S3 Bucket: ${S3_BUCKET}`);
});
