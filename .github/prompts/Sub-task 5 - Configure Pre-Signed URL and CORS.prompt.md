# Sub-task 5 - Configure Pre-Signed URL and CORS

## Objectives
- Verify public access blocking for bucket2
- Share files using pre-signed URLs with time expiration
- Configure CORS to allow bucket1 website to access bucket2 resources

---

## Step 1: Verify Public Access Block for Bucket2

1. Navigate to **S3 Console** → Select **bucket2**
2. Go to **Permissions** tab
3. Under **Block public access (bucket settings)**, verify all options are **enabled**:
    - ✅ Block all public access
    - ✅ Block public access to buckets and objects granted through new ACLs
    - ✅ Block public access to buckets and objects granted through any ACLs
    - ✅ Block public access to buckets and objects granted through new public bucket or access point policies
    - ✅ Block public and cross-account access to buckets and objects through any public bucket or access point policies

---

## Step 2: Generate Pre-Signed URL

### Using AWS CLI:
```bash
aws s3 presign s3://bucket2/your-file.jpg --expires-in 300
```
*Note: `--expires-in` is in seconds (300 = 5 minutes)*

### Using AWS Console:
1. Navigate to **bucket2** → Select the file
2. Click **Actions** → **Share with a presigned URL**
3. Set expiration time (e.g., 5 minutes)
4. Click **Create presigned URL**
5. Copy the generated URL

---

## Step 3: Test Pre-Signed URL

1. **Before expiration**: Open the pre-signed URL in browser → File should be accessible
2. **After expiration**: Wait for the defined time to pass → Refresh URL → Should receive `Access Denied` error

---

## Step 4: Add JavaScript to Static Website (Bucket1)

Add the following code to your `index.html` in bucket1:

```html
<!DOCTYPE html>
<html>
<head>
     <title>CORS Demo</title>
</head>
<body>
     <h1>Loading Resource from Bucket2</h1>
     <div id="Quote"></div>

     <script>
          window.onload = function () {
                readJsonFile('https://shravani-jawalkar-replication-bucket.s3.ap-south-1.amazonaws.com/file1.txt', function (QuoteJson) {
                     let QuoteObj = JSON.parse(QuoteJson);
                     document.getElementById("Quote").innerHTML =
                          "<i>" + QuoteObj.message + "</i>"
                });
          }

          function readJsonFile(file, callback) {
                let rawFile = new XMLHttpRequest();
                rawFile.overrideMimeType("application/json");
                rawFile.open("GET", file, true);
                rawFile.onreadystatechange = function () {
                     if (rawFile.readyState === 4 && rawFile.status === 200) {
                          callback(rawFile.responseText);
                     }
                }
                rawFile.send(null);
          }
     </script>
</body>
</html>
```

---

## Step 5: Configure CORS on Bucket2

1. Navigate to **bucket2** → **Permissions** tab
2. Scroll to **Cross-origin resource sharing (CORS)**
3. Click **Edit** and add the following CORS configuration:

```json
[
     {
          "AllowedHeaders": ["*"],
          "AllowedMethods": ["GET"],
          "AllowedOrigins": ["http://bucket1.s3-website-us-east-1.amazonaws.com"],
          "ExposeHeaders": []
     }
]
```

*Replace the `AllowedOrigins` URL with your actual bucket1 static website endpoint*

4. Click **Save changes**

---

## Step 6: Verify CORS Configuration

1. Open your static website from bucket1
2. Check browser console (F12) for any CORS errors
3. Verify that the resource from bucket2 loads successfully
4. The content should display on the page without CORS errors

---

## Expected Results

✅ Bucket2 has public access blocked  
✅ Pre-signed URL works before expiration  
✅ Pre-signed URL fails after expiration  
✅ Static website successfully loads resources from bucket2 via CORS  
