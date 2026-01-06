# Application Architecture & Data Flow

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS Cloud Environment                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              Application Load Balancer (ALB)                 │  │
│  │  - Distributes HTTP traffic                                 │  │
│  │  - Health checks (port 8080/health)                         │  │
│  │  - Port 80/443 → Port 8080 (instances)                      │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              │                                       │
│         ┌────────────────────┼────────────────────┐                │
│         │                    │                    │                │
│    ┌────▼─────┐        ┌────▼─────┐        ┌────▼─────┐           │
│    │  EC2     │        │  EC2     │        │  EC2     │  ...      │
│    │Instance1 │        │Instance2 │        │Instance3 │           │
│    │(Running  │        │(Running  │        │(Running  │           │
│    │Node.js   │        │Node.js   │        │Node.js   │           │
│    │App)      │        │App)      │        │App)      │           │
│    │          │        │          │        │          │           │
│    │Port 8080 │        │Port 8080 │        │Port 8080 │           │
│    └────┬─────┘        └────┬─────┘        └────┬─────┘           │
│         │                   │                   │                  │
│         └───────────────────┼───────────────────┘                 │
│                             │                                      │
│                  ┌──────────▼──────────┐                          │
│                  │    S3 Bucket        │                          │
│                  │ (Image Storage)     │                          │
│                  │                     │                          │
│                  │ - photo1.jpg        │                          │
│                  │ - landscape.png     │                          │
│                  │ - vacation.jpg      │                          │
│                  │ - ... (unlimited)   │                          │
│                  └─────────────────────┘                          │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │        Auto Scaling Group (1-4 instances)                   │  │
│  │ - Scales based on CPU utilization                           │  │
│  │ - Min: 1, Max: 4, Desired: 2                                │  │
│  │ - Health check type: ELB                                    │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │             CloudWatch (Monitoring)                          │  │
│  │ - CPU Utilization alarms                                    │  │
│  │ - Scale up > 50% CPU for 2 minutes                          │  │
│  │ - Scale down < 30% CPU for 5 minutes                        │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
         │                                    │
         │                                    │
         ▼                                    ▼
  ┌────────────────┐              ┌──────────────────┐
  │  Users/Clients │              │  AWS Services    │
  │                │              │  (IAM, etc.)     │
  │ - Web Browser  │              │                  │
  │ - Mobile App   │              │ EC2 Role:        │
  │ - API Client   │              │ S3 Access        │
  └────────────────┘              │ CloudWatch       │
                                  └──────────────────┘
```

## Request Flow Diagram

### Upload Image Flow
```
┌─────────────┐
│   User      │
│ Selects     │
│ Image File  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────┐
│ Browser Form Submission     │
│ POST /api/upload            │
│ multipart/form-data         │
└──────┬──────────────────────┘
       │ (over HTTP/HTTPS)
       ▼
┌─────────────────────────────┐
│ ALB receives request        │
│ Forwards to available EC2   │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Express.js handler          │
│ multer validates file       │
│ - Check MIME type          │
│ - Check file size (10MB)    │
└──────┬──────────────────────┘
       │
       ├─ Valid? ──────▶ AWS.S3.upload()
       │                    │
       │                    ▼
       │            ┌──────────────────┐
       │            │ S3 Bucket        │
       │            │ Stores file      │
       │            │ with metadata    │
       │            └────┬─────────────┘
       │                 │
       │                 ▼
       │         ┌──────────────────┐
       │         │ Return success   │
       │         │ JSON response    │
       │         └────┬─────────────┘
       │              │
       ▼              ▼
   Invalid    ┌──────────────────────┐
   File?      │ Browser receives     │
   │          │ Success/Error message│
   │          │ Updates gallery      │
   │          │ Shows alert          │
   │          └──────────────────────┘
   │
   ▼
┌──────────────────────┐
│ Return error 400     │
│ "Invalid file type"  │
└──────────────────────┘
```

### Download Image Flow
```
┌──────────────────┐
│ User clicks      │
│ Download button  │
│ for "photo.jpg"  │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────┐
│ Browser sends request        │
│ GET /api/download/photo.jpg  │
└────────┬─────────────────────┘
         │ (over HTTP/HTTPS)
         ▼
┌──────────────────────────────┐
│ ALB routes to EC2 instance   │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Express.js validates image   │
│ name parameter               │
└────────┬─────────────────────┘
         │
         ├─ Found? ──────▶ AWS.S3.getObject()
         │                    │
         │                    ▼
         │            ┌──────────────────┐
         │            │ S3 retrieves     │
         │            │ image binary data│
         │            └────┬─────────────┘
         │                 │
         │                 ▼
         │         ┌──────────────────┐
         │         │ Set HTTP headers │
         │         │ Content-Type     │
         │         │ Content-Disp.    │
         │         └────┬─────────────┘
         │              │
         ▼              ▼
     Not Found  ┌────────────────────┐
     │          │ Send binary data   │
     │          │ Browser downloads  │
     │          │ file as download   │
     │          └────────────────────┘
     │
     ▼
┌──────────────────────┐
│ Return 404          │
│ "Image not found"   │
└──────────────────────┘
```

### Get Metadata Flow
```
┌──────────────────┐
│ User enters      │
│ image name       │
│ "photo.jpg"      │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────┐
│ Browser sends request        │
│ GET /api/metadata/photo.jpg  │
└────────┬─────────────────────┘
         │ (over HTTP/HTTPS)
         ▼
┌──────────────────────────────┐
│ ALB routes to EC2 instance   │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Express.js handler           │
│ AWS.S3.headObject()          │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ S3 returns object metadata   │
│ - ContentLength (size)       │
│ - ContentType                │
│ - LastModified               │
│ - ETag                       │
│ - StorageClass              │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Format as JSON response      │
│ {                            │
│   "name": "photo.jpg",       │
│   "size": 2048576,           │
│   "contentType": "image/jpeg"│
│   "lastModified": "...",     │
│   "etag": "...",             │
│   "storageClass": "STANDARD" │
│ }                            │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Browser receives JSON        │
│ Displays metadata in card    │
│ Shows:                       │
│ - File size (formatted)      │
│ - MIME type                  │
│ - Last modified date/time    │
│ - ETag (version)             │
└──────────────────────────────┘
```

### Random Image Metadata Flow
```
┌──────────────────┐
│ User clicks      │
│ "Get Random"     │
│ button           │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Browser sends request                │
│ GET /api/random-metadata             │
└────────┬─────────────────────────────┘
         │ (over HTTP/HTTPS)
         ▼
┌──────────────────────────────────────┐
│ ALB routes to EC2 instance           │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Express.js handler                   │
│ 1. AWS.S3.listObjectsV2()            │
│    Get all objects in bucket         │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Filter out directories               │
│ Create array of image names          │
│ [photo1.jpg, photo2.png, ...]        │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Generate random index                │
│ Math.random() * length               │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Select random image from array       │
│ e.g., "landscape.jpg"                │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ AWS.S3.headObject() for random image │
│ Get metadata just like /metadata     │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Return JSON with metadata            │
│ {                                    │
│   "name": "landscape.jpg",           │
│   "size": 3145728,                   │
│   ...metadata...                     │
│ }                                    │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Browser receives JSON                │
│ Displays random image metadata       │
│ Shows alert: "Random image: ..."     │
└──────────────────────────────────────┘
```

### Delete Image Flow
```
┌──────────────────┐
│ User enters      │
│ image name       │
│ "photo.jpg"      │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────┐
│ User clicks delete button     │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Browser shows confirmation   │
│ "Are you sure?"              │
└────────┬─────────────────────┘
         │
      Yes│
         ▼
┌──────────────────────────────┐
│ Browser sends DELETE request │
│ DELETE /api/delete/photo.jpg │
└────────┬─────────────────────┘
         │ (over HTTP/HTTPS)
         ▼
┌──────────────────────────────┐
│ ALB routes to EC2 instance   │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Express.js handler           │
│ AWS.S3.deleteObject()        │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ S3 removes object from bucket│
│ Returns success              │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Return success JSON response │
│ {                            │
│   "message": "Image deleted",│
│   "name": "photo.jpg"        │
│ }                            │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Browser receives success     │
│ Shows alert: "Deleted!"      │
│ Reloads image gallery        │
│ Photo removed from display   │
└──────────────────────────────┘
```

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Request Processing Flow                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Browser        Express.js       AWS SDK          S3 Bucket   │
│  ──────         ──────────       ───────          ─────────   │
│    │                │               │                  │       │
│    │─HTTP Req──────▶│               │                  │       │
│    │                │               │                  │       │
│    │            Validate            │                  │       │
│    │                │               │                  │       │
│    │            Parse/Process       │                  │       │
│    │                │               │                  │       │
│    │                │─S3 API Req──▶│                  │       │
│    │                │               │                  │       │
│    │                │               │─Operation────▶  │       │
│    │                │               │                  │       │
│    │                │               │◀───Response────  │       │
│    │                │               │                  │       │
│    │                │◀─S3 Response─│                  │       │
│    │                │               │                  │       │
│    │            Format JSON         │                  │       │
│    │                │               │                  │       │
│    │◀───Response────│               │                  │       │
│    │                │               │                  │       │
│    │ Process &      │               │                  │       │
│    │ Display UI     │               │                  │       │
│    │                │               │                  │       │
│    └────────────────┴───────────────┴──────────────────┘       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## State Diagram (Image Lifecycle)

```
┌─────────────────────────────────────────────────────────────┐
│              Image Lifecycle in S3 Bucket                   │
└─────────────────────────────────────────────────────────────┘

              ┌──────────────┐
              │  User's PC   │
              │ (image file) │
              └──────┬───────┘
                     │
                     │ SELECT & UPLOAD
                     ▼
              ┌──────────────────────────────┐
              │ UPLOADING                    │
              │ - Validation in progress     │
              │ - File transfer to S3        │
              └──────┬───────────────────────┘
                     │
                     │ UPLOAD SUCCESS
                     ▼
              ┌──────────────────────────────┐
              │ STORED IN S3                 │
              │ ✓ Available for operations:  │
              │   - View/Display             │
              │   - Download                 │
              │   - Get Metadata             │
              │   - List in Gallery          │
              └──────┬───────────────────────┘
                     │
       ┌─────────────┼─────────────┐
       │             │             │
       │ VIEW    DOWNLOAD    GET METADATA
       │             │             │
       │             │             │
       ▼             ▼             ▼
   ┌─────────────────────────────────────┐
   │ IMAGE ACCESSED                      │
   │ - Metadata retrieved                │
   │ - File downloaded to user           │
   │ - Displayed in gallery              │
   └──────┬────────────────────────────┬─┘
          │                            │
          └────────────┬───────────────┘
                       │
                       │ DELETE REQUEST
                       ▼
              ┌──────────────────────────────┐
              │ DELETED FROM S3              │
              │ ✗ No longer available        │
              │ - Removed from gallery       │
              │ - Cannot be accessed         │
              └──────────────────────────────┘
```

## Component Interaction Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                   APPLICATION COMPONENTS                       │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│ ┌──────────────────────────────────────────────────────────┐  │
│ │               Express.js Server                          │  │
│ │  ┌────────────────────────────────────────────────────┐ │  │
│ │  │  Middleware Layer                                 │ │  │
│ │  │ - Express.json()                                 │ │  │
│ │  │ - Express.urlencoded()                           │ │  │
│ │  │ - Multer (file upload)                           │ │  │
│ │  │ - Static file serving                            │ │  │
│ │  └────────────────────────────────────────────────────┘ │  │
│ │                      ▲                                   │  │
│ │                      │                                   │  │
│ │  ┌────────────────────────────────────────────────────┐ │  │
│ │  │  Route Handlers                                   │ │  │
│ │  │ - POST /api/upload                               │ │  │
│ │  │ - GET /api/images                                │ │  │
│ │  │ - GET /api/metadata/:name                        │ │  │
│ │  │ - GET /api/random-metadata                       │ │  │
│ │  │ - GET /api/download/:name                        │ │  │
│ │  │ - DELETE /api/delete/:name                       │ │  │
│ │  │ - GET /health                                    │ │  │
│ │  │ - GET / (UI)                                     │ │  │
│ │  └────────────────────────────────────────────────────┘ │  │
│ │                      ▲                                   │  │
│ │                      │                                   │  │
│ │  ┌────────────────────────────────────────────────────┐ │  │
│ │  │  AWS SDK Integration                              │ │  │
│ │  │ - S3 Client (auto-configured from IAM role)       │ │  │
│ │  │ - Methods:                                        │ │  │
│ │  │   • upload()                                      │ │  │
│ │  │   • listObjectsV2()                               │ │  │
│ │  │   • getObject()                                   │ │  │
│ │  │   • headObject()                                  │ │  │
│ │  │   • deleteObject()                                │ │  │
│ │  └────────────────────────────────────────────────────┘ │  │
│ └──────────────────────────────────────────────────────────┘  │
│            │                                                   │
│            └────────────────────┬──────────────────────────┐   │
│                                 ▼                          ▼   │
│                        ┌─────────────────┐    ┌─────────────┐ │
│                        │   S3 Bucket     │    │ EC2 Instance│ │
│                        │ (Image Storage) │    │ (Metadata)  │ │
│                        └─────────────────┘    └─────────────┘ │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

## Technology Stack Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    TECHNOLOGY STACK                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│ ┌─────────────────┐                                            │
│ │   Frontend      │                                            │
│ │  ───────────    │                                            │
│ │  • HTML5        │                                            │
│ │  • CSS3         │                                            │
│ │  • Vanilla JS   │                                            │
│ │  • Responsive   │                                            │
│ │    Design       │                                            │
│ └────────┬────────┘                                            │
│          │ HTTP/HTTPS                                          │
│          ▼                                                      │
│ ┌─────────────────────────────────────────────┐               │
│ │   Backend (Node.js/Express)                 │               │
│ │  ───────────────────────────────────        │               │
│ │  • Node.js v18+                             │               │
│ │  • Express.js v4.18.2                       │               │
│ │  • Multer v1.4.5 (file upload)              │               │
│ │  • Axios v1.6.0 (HTTP client)               │               │
│ │  • AWS SDK v2.1400.0 (S3 operations)        │               │
│ │  • Dotenv v16.3.1 (env variables)           │               │
│ └────────┬────────────────────────────────────┘               │
│          │ AWS API                                             │
│          ▼                                                      │
│ ┌──────────────────────────────────────────┐                 │
│ │   AWS Services                           │                 │
│ │  ─────────────────────────────────       │                 │
│ │  • S3 (Image Storage)                   │                 │
│ │  • EC2 (Compute)                        │                 │
│ │  • Auto Scaling                         │                 │
│ │  • ALB (Load Balancer)                  │                 │
│ │  • IAM (Access Control)                 │                 │
│ │  • CloudWatch (Monitoring)              │                 │
│ │  • CloudFormation (IaC)                 │                 │
│ └──────────────────────────────────────────┘                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

**Note**: These diagrams provide visual representations of:
1. Overall system architecture
2. Request/response flows for each operation
3. Data flow between components
4. Image lifecycle in the system
5. Component interactions
6. Technology stack organization
