# S3 Image Management API Reference

## Base URL
```
http://<load-balancer-dns>
```

## Endpoints

### 1. Upload Image
Upload an image file to the S3 bucket.

**Endpoint:** `POST /api/upload`

**Request:**
```
Content-Type: multipart/form-data

Form Data:
  - file: <image file>
```

**cURL Example:**
```bash
curl -X POST http://localhost:8080/api/upload \
  -F "file=@/path/to/image.jpg"
```

**PowerShell Example:**
```powershell
$filePath = "C:\path\to\image.jpg"
$fileBytes = [System.IO.File]::ReadAllBytes($filePath)

Invoke-WebRequest `
  -Uri "http://localhost:8080/api/upload" `
  -Method POST `
  -InFile $filePath
```

**JavaScript Example:**
```javascript
const formData = new FormData();
formData.append('file', fileInput.files[0]);

fetch('/api/upload', {
  method: 'POST',
  body: formData
})
.then(res => res.json())
.then(data => console.log(data));
```

**Response (Success):**
```json
{
  "message": "Image uploaded successfully",
  "name": "photo.jpg"
}
```

**Response (Error):**
```json
{
  "message": "Error uploading image: File too large"
}
```

---

### 2. List All Images
Get a list of all images in the S3 bucket.

**Endpoint:** `GET /api/images`

**Request:**
```
No parameters required
```

**cURL Example:**
```bash
curl http://localhost:8080/api/images
```

**PowerShell Example:**
```powershell
Invoke-WebRequest -Uri "http://localhost:8080/api/images" | 
  Select-Object -ExpandProperty Content | 
  ConvertFrom-Json
```

**JavaScript Example:**
```javascript
fetch('/api/images')
  .then(res => res.json())
  .then(data => console.log(data.images));
```

**Response (Success):**
```json
{
  "images": [
    "photo1.jpg",
    "landscape.png",
    "vacation.jpg"
  ]
}
```

**Response (Error):**
```json
{
  "message": "Error listing images: Access denied"
}
```

---

### 3. Download Image
Download a specific image file from the S3 bucket.

**Endpoint:** `GET /api/download/:imageName`

**Request:**
```
URL Parameter:
  - imageName: Name of the image (URL encoded)
```

**cURL Example:**
```bash
curl -o downloaded-photo.jpg \
  http://localhost:8080/api/download/photo.jpg
```

**PowerShell Example:**
```powershell
Invoke-WebRequest `
  -Uri "http://localhost:8080/api/download/photo.jpg" `
  -OutFile "C:\downloaded-photo.jpg"
```

**JavaScript Example:**
```javascript
const link = document.createElement('a');
link.href = '/api/download/photo.jpg';
link.download = 'photo.jpg';
link.click();
```

**Response (Success):**
- Binary image file content
- Headers:
  - `Content-Type`: Image MIME type
  - `Content-Disposition`: attachment; filename=photo.jpg

**Response (Error):**
```json
{
  "message": "Image not found: NoSuchKey"
}
```

---

### 4. Get Image Metadata
Get detailed metadata for a specific image.

**Endpoint:** `GET /api/metadata/:imageName`

**Request:**
```
URL Parameter:
  - imageName: Name of the image (URL encoded)
```

**cURL Example:**
```bash
curl http://localhost:8080/api/metadata/photo.jpg | jq
```

**PowerShell Example:**
```powershell
Invoke-WebRequest `
  -Uri "http://localhost:8080/api/metadata/photo.jpg" | 
  Select-Object -ExpandProperty Content | 
  ConvertFrom-Json | Format-List
```

**JavaScript Example:**
```javascript
fetch('/api/metadata/photo.jpg')
  .then(res => res.json())
  .then(metadata => {
    console.log(`Size: ${metadata.size} bytes`);
    console.log(`Type: ${metadata.contentType}`);
    console.log(`Last Modified: ${metadata.lastModified}`);
  });
```

**Response (Success):**
```json
{
  "name": "photo.jpg",
  "size": 2048576,
  "contentType": "image/jpeg",
  "lastModified": "2024-01-15T10:30:45.000Z",
  "etag": "\"5d41402abc4b2a76b9719d911017c592\"",
  "storageClass": "STANDARD"
}
```

**Response (Error):**
```json
{
  "message": "Image not found: NoSuchKey"
}
```

---

### 5. Get Random Image Metadata
Get metadata for a randomly selected image from the bucket.

**Endpoint:** `GET /api/random-metadata`

**Request:**
```
No parameters required
```

**cURL Example:**
```bash
curl http://localhost:8080/api/random-metadata | jq
```

**PowerShell Example:**
```powershell
Invoke-WebRequest -Uri "http://localhost:8080/api/random-metadata" | 
  Select-Object -ExpandProperty Content | 
  ConvertFrom-Json
```

**JavaScript Example:**
```javascript
fetch('/api/random-metadata')
  .then(res => res.json())
  .then(metadata => {
    console.log(`Random image: ${metadata.name}`);
    console.log(`Size: ${formatBytes(metadata.size)}`);
  });
```

**Response (Success):**
```json
{
  "name": "vacation.jpg",
  "size": 3145728,
  "contentType": "image/jpeg",
  "lastModified": "2024-01-10T15:20:10.000Z",
  "etag": "\"abc123def456ghi789jkl\"",
  "storageClass": "STANDARD"
}
```

**Response (Error):**
```json
{
  "message": "No images available"
}
```

---

### 6. Delete Image
Delete a specific image from the S3 bucket.

**Endpoint:** `DELETE /api/delete/:imageName`

**Request:**
```
URL Parameter:
  - imageName: Name of the image to delete (URL encoded)
```

**cURL Example:**
```bash
curl -X DELETE http://localhost:8080/api/delete/photo.jpg
```

**PowerShell Example:**
```powershell
Invoke-WebRequest `
  -Uri "http://localhost:8080/api/delete/photo.jpg" `
  -Method DELETE
```

**JavaScript Example:**
```javascript
fetch('/api/delete/photo.jpg', {
  method: 'DELETE'
})
.then(res => res.json())
.then(data => console.log(data.message));
```

**Response (Success):**
```json
{
  "message": "Image deleted successfully",
  "name": "photo.jpg"
}
```

**Response (Error):**
```json
{
  "message": "Error deleting image: Access denied"
}
```

---

### 7. Display Image
Get an image for display in HTML (not as download).

**Endpoint:** `GET /api/images/:imageName`

**Request:**
```
URL Parameter:
  - imageName: Name of the image (URL encoded)
```

**HTML Example:**
```html
<img src="/api/images/photo.jpg" alt="Photo">
```

**JavaScript Example:**
```javascript
const img = new Image();
img.src = '/api/images/photo.jpg';
document.body.appendChild(img);
```

**Response (Success):**
- Binary image file content
- Header: `Content-Type`: Image MIME type

**Response (Error):**
- HTTP 404: Image not found

---

### 8. Health Check
Check if the application is running.

**Endpoint:** `GET /health`

**Request:**
```
No parameters required
```

**cURL Example:**
```bash
curl http://localhost:8080/health
```

**PowerShell Example:**
```powershell
Invoke-WebRequest -Uri "http://localhost:8080/health" | 
  Select-Object -ExpandProperty Content
```

**Response:**
```json
{
  "status": "healthy"
}
```

---

### 9. Main UI
Access the web interface with all features.

**Endpoint:** `GET /`

**Response:**
- HTML page with interactive UI for all image operations

---

## Error Handling

### Common HTTP Status Codes

| Status | Meaning | Example Response |
|--------|---------|------------------|
| 200 | Success | `{"message": "Image uploaded successfully"}` |
| 400 | Bad Request | `{"message": "No file provided"}` |
| 404 | Not Found | `{"message": "Image not found"}` |
| 500 | Server Error | `{"message": "Error uploading image: ..."}` |

### Error Response Format
```json
{
  "message": "Description of what went wrong"
}
```

---

## Request Examples by Language

### Python
```python
import requests

# Upload image
with open('photo.jpg', 'rb') as f:
    files = {'file': f}
    response = requests.post('http://localhost:8080/api/upload', files=files)
    print(response.json())

# List images
response = requests.get('http://localhost:8080/api/images')
print(response.json()['images'])

# Get metadata
response = requests.get('http://localhost:8080/api/metadata/photo.jpg')
print(response.json())

# Download image
response = requests.get('http://localhost:8080/api/download/photo.jpg')
with open('downloaded.jpg', 'wb') as f:
    f.write(response.content)

# Delete image
response = requests.delete('http://localhost:8080/api/delete/photo.jpg')
print(response.json())
```

### Node.js
```javascript
const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');

const baseURL = 'http://localhost:8080';

// Upload image
async function uploadImage(filePath) {
  const form = new FormData();
  form.append('file', fs.createReadStream(filePath));
  const response = await axios.post(`${baseURL}/api/upload`, form);
  console.log(response.data);
}

// List images
async function listImages() {
  const response = await axios.get(`${baseURL}/api/images`);
  console.log(response.data.images);
}

// Get metadata
async function getMetadata(imageName) {
  const response = await axios.get(`${baseURL}/api/metadata/${imageName}`);
  console.log(response.data);
}

// Download image
async function downloadImage(imageName, outputPath) {
  const response = await axios.get(`${baseURL}/api/download/${imageName}`, {
    responseType: 'stream'
  });
  response.data.pipe(fs.createWriteStream(outputPath));
}

// Delete image
async function deleteImage(imageName) {
  const response = await axios.delete(`${baseURL}/api/delete/${imageName}`);
  console.log(response.data);
}
```

### Java
```java
import okhttp3.*;
import java.io.File;

public class ImageClient {
    private static final String BASE_URL = "http://localhost:8080";
    private static final OkHttpClient client = new OkHttpClient();

    // Upload image
    public static void uploadImage(String filePath) throws Exception {
        File file = new File(filePath);
        RequestBody fileBody = RequestBody.create(file, MediaType.parse("image/*"));
        RequestBody requestBody = new MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart("file", file.getName(), fileBody)
            .build();

        Request request = new Request.Builder()
            .url(BASE_URL + "/api/upload")
            .post(requestBody)
            .build();

        try (Response response = client.newCall(request).execute()) {
            System.out.println(response.body().string());
        }
    }

    // List images
    public static void listImages() throws Exception {
        Request request = new Request.Builder()
            .url(BASE_URL + "/api/images")
            .get()
            .build();

        try (Response response = client.newCall(request).execute()) {
            System.out.println(response.body().string());
        }
    }
}
```

---

## Rate Limiting & Quotas

Currently, there are no rate limits configured. For production, consider adding:

```javascript
const rateLimit = require("express-rate-limit");

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use("/api/", limiter);
```

---

## CORS Configuration

If accessing from a different domain, configure CORS in the application:

```javascript
const cors = require('cors');

app.use(cors({
  origin: 'https://yourdomain.com',
  credentials: true
}));
```

---

## Authentication (Optional)

To add authentication, implement a middleware:

```javascript
app.use('/api/', authenticateToken);

function authenticateToken(req, res, next) {
  const token = req.headers['authorization'];
  // Verify token
  next();
}
```

---

## Testing the API

### Using Postman

1. Create a new collection
2. Add requests for each endpoint
3. Set up environment variables for `baseURL`
4. Run tests

### Using Thunder Client (VS Code)

1. Install Thunder Client extension
2. Create new requests for each endpoint
3. Test with different parameters

### Using AWS CLI

```bash
# List images
aws s3 ls s3://shravani-jawalkar-webproject-bucket/

# Get object metadata
aws s3api head-object \
  --bucket shravani-jawalkar-webproject-bucket \
  --key photo.jpg

# Upload via CLI
aws s3 cp photo.jpg s3://shravani-jawalkar-webproject-bucket/

# Download via CLI
aws s3 cp s3://shravani-jawalkar-webproject-bucket/photo.jpg .

# Delete via CLI
aws s3 rm s3://shravani-jawalkar-webproject-bucket/photo.jpg
```
