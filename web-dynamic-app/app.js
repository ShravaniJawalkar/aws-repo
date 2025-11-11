const express = require('express');
const axios = require('axios');

const app = express();
const PORT = 8080;

// EC2 metadata service URLs
const REGION_URL = 'http://169.254.169.254/latest/meta-data/placement/region';
const AZ_URL = 'http://169.254.169.254/latest/meta-data/placement/availability-zone';

// HTML template for the UI
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
    <title>AWS EC2 Metadata</title>
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
            max-width: 700px;
            width: 100%;
        }
        
        .header {
            text-align: center;
            margin-bottom: 40px;
        }
        
        .header h1 {
            color: #2c3e50;
            font-size: 32px;
            margin-bottom: 10px;
        }
        
        .header p {
            color: #7f8c8d;
            font-size: 16px;
        }
        
        .aws-logo {
            font-size: 60px;
            margin-bottom: 20px;
        }
        
        .metadata-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 20px;
            color: white;
            box-shadow: 0 10px 30px rgba(102, 126, 234, 0.3);
        }
        
        .metadata-item {
            margin-bottom: 25px;
        }
        
        .metadata-item:last-child {
            margin-bottom: 0;
        }
        
        .metadata-label {
            font-size: 14px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
            opacity: 0.9;
            margin-bottom: 8px;
        }
        
        .metadata-value {
            font-size: 24px;
            font-weight: bold;
            background: rgba(255, 255, 255, 0.2);
            padding: 15px 20px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.3);
        }
        
        .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 2px solid #ecf0f1;
        }
        
        .footer p {
            color: #95a5a6;
            font-size: 14px;
        }
        
        .refresh-btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 12px 30px;
            border-radius: 25px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            margin-top: 15px;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .refresh-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        
        .refresh-btn:active {
            transform: translateY(0);
        }
        
        @keyframes fadeIn {
            from {
                opacity: 0;
                transform: translateY(20px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        
        .container {
            animation: fadeIn 0.6s ease-out;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="aws-logo">☁️</div>
            <h1>AWS EC2 Instance Metadata</h1>
            <p>Real-time information from your EC2 instance</p>
        </div>
        
        <div class="metadata-card">
            <div class="metadata-item">
                <div class="metadata-label">🌍 AWS Region</div>
                <div class="metadata-value">${region}</div>
            </div>
            
            <div class="metadata-item">
                <div class="metadata-label">📍 Availability Zone</div>
                <div class="metadata-value">${availabilityZone}</div>
            </div>
        </div>
        
        <div class="footer">
            <p>Instance metadata retrieved successfully</p>
            <button class="refresh-btn" onclick="location.reload()">🔄 Refresh</button>
        </div>
    </div>
</body>
</html>
  `;
};

// Health check endpoint for load balancer
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

// Root endpoint
app.get('/', async (req, res) => {
  try {
    // Fetch region and availability zone from EC2 metadata service
    const [regionResponse, azResponse] = await Promise.all([
      axios.get(REGION_URL, { timeout: 2000 }),
      axios.get(AZ_URL, { timeout: 2000 })
    ]);

    const region = regionResponse.data;
    const availability_zone = azResponse.data;

    // Return HTML page with metadata
    res.send(getHTMLPage(region, availability_zone));
  } catch (error) {
    // Handle errors (e.g., not running on EC2, timeout, etc.)
    console.error('Error fetching EC2 metadata:', error.message);
    
    const errorMessage = 'Unable to fetch EC2 metadata. This application must run on an EC2 instance.';
    res.status(500).send(getHTMLPage(errorMessage, '', true));
  }
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
  console.log(`Access the application at http://localhost:${PORT}`);
});
