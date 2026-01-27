/**
 * Lambda function: webproject-DataConsistencyFunction
 * 
 * Purpose:
 * - Verifies data consistency between RDS database and S3 bucket
 * - Checks if image metadata in DB matches actual images in S3
 * - Can be invoked via: EventBridge (scheduled), API Gateway, or Web App
 * 
 * Environment Variables:
 * - DB_HOST: RDS endpoint
 * - DB_USER: Database username
 * - DB_PASSWORD: Database password
 * - DB_NAME: Database name
 * - S3_BUCKET: S3 bucket name
 * - AWS_REGION: Auto-set by Lambda runtime (ap-south-1)
 */

const mysql = require('mysql2/promise');
const AWS = require('aws-sdk');

// AWS_REGION is automatically set by Lambda runtime
// Use fallback only for local testing
const awsRegion = process.env.AWS_REGION || 'ap-south-1';

// Initialize S3 client
const s3 = new AWS.S3({
  region: awsRegion
});

// Database configuration
const dbConfig = {
  host: 'webproject-database.c14e66sq09ij.ap-south-1.rds.amazonaws.com',
  user: 'admin',
  password: "PasswordwebProject2024'",
  database: 'webproject',
  waitForConnections: true,
  connectionLimit: 1,
  queueLimit: 0,
  enableKeepAlive: true,
  keepAliveInitialDelayMs: 0
};

// Create connection pool (initialized outside handler for best practices)
let pool = null;

async function initializePool() {
  if (!pool) {
    pool = await mysql.createPool(dbConfig);
    console.log('✓ Database connection pool initialized');
  }
  return pool;
}

/**
 * Main Lambda Handler - Synchronous invocation
 * Can be triggered by:
 * - EventBridge (detail-type: "scheduled")
 * - API Gateway (detail-type: "api-gateway")
 * - Web Application (detail-type: "web-application")
 */
exports.handler = async (event, context) => {
  console.log('='.repeat(50));
  
  // Determine invocation source
  const detailType = event.detailType || event['detail-type'] || 'unknown';
  const invocationSource = event.source || 'direct-invoke';
  
  console.log(`📌 Invocation Source: ${invocationSource}`);
  console.log(`📌 Detail Type: ${detailType}`);
  console.log(`📌 Timestamp: ${new Date().toISOString()}`);
  console.log(`📌 Request ID: ${context.requestId}`);
  console.log('='.repeat(50));

  try {
    // Initialize database pool
    const pool = await initializePool();

    // Get connection from pool
    const connection = await pool.getConnection();

    try {
      // Step 1: Get all image records from database
      console.log('\n[DB] Querying image records from database...');
      const [dbImages] = await connection.query(
        'SELECT id, fileName, fileSize, fileExtension, uploadedAt FROM image_uploads ORDER BY fileName'
      );
      console.log(`✓ Found ${dbImages.length} images in database`);

      // Step 2: Get all objects from S3 bucket
      console.log('\n[S3] Querying objects from S3 bucket...');
      const params = { Bucket: process.env.S3_BUCKET || 'shravani-jawalkar-webproject-bucket' };
      const s3Objects = await s3.listObjectsV2(params).promise();
      const s3Images = (s3Objects.Contents || [])
        .filter(obj => !obj.Key.endsWith('/'))
        .map(obj => ({ key: obj.Key, size: obj.Size, modified: obj.LastModified }));
      console.log(`✓ Found ${s3Images.length} images in S3 bucket`);

      // Step 3: Validate consistency
      console.log('\n[VALIDATION] Checking data consistency...');
      const consistencyResult = validateConsistency(dbImages, s3Images);

      // Step 4: Log results with source distinction
      logConsistencyResult(detailType, consistencyResult);

      // Prepare response
      const response = {
        statusCode: 200,
        timestamp: new Date().toISOString(),
        source: detailType,
        consistency: {
          isConsistent: consistencyResult.isConsistent,
          totalDBImages: dbImages.length,
          totalS3Images: s3Images.length,
          missingInS3: consistencyResult.missingInS3,
          orphanedInS3: consistencyResult.orphanedInS3,
          details: consistencyResult.details
        }
      };

      console.log('\n[RESPONSE] Returning consistency check result');
      console.log('='.repeat(50));
      return response;

    } finally {
      // Release connection back to pool
      connection.release();
    }

  } catch (error) {
    console.error('\n❌ ERROR in Lambda execution');
    console.error(`Error Type: ${error.name}`);
    console.error(`Error Message: ${error.message}`);
    console.error(`Stack: ${error.stack}`);
    console.log('='.repeat(50));

    return {
      statusCode: 500,
      timestamp: new Date().toISOString(),
      source: detailType,
      error: error.message,
      consistency: {
        isConsistent: false
      }
    };
  }
};

/**
 * Validates consistency between DB records and S3 objects
 */
function validateConsistency(dbImages, s3Images) {
  const s3Keys = new Set(s3Images.map(img => img.key));
  const dbFileNames = new Set(dbImages.map(img => img.fileName));

  const missingInS3 = [];
  const orphanedInS3 = [];

  // Check DB images that don't exist in S3
  for (const dbImage of dbImages) {
    if (!s3Keys.has(dbImage.fileName)) {
      missingInS3.push({
        fileName: dbImage.fileName,
        id: dbImage.id,
        reason: 'DB record exists but file missing from S3'
      });
    }
  }

  // Check S3 objects that don't have DB records
  for (const s3Image of s3Images) {
    if (!dbFileNames.has(s3Image.key)) {
      orphanedInS3.push({
        key: s3Image.key,
        size: s3Image.size,
        reason: 'File exists in S3 but no DB record'
      });
    }
  }

  const isConsistent = missingInS3.length === 0 && orphanedInS3.length === 0;

  return {
    isConsistent,
    missingInS3,
    orphanedInS3,
    details: {
      totalMatched: dbImages.length - missingInS3.length,
      totalInconsistencies: missingInS3.length + orphanedInS3.length
    }
  };
}

/**
 * Logs consistency result with source distinction
 */
function logConsistencyResult(detailType, result) {
  const prefix = `[${detailType.toUpperCase()}]`;
  
  console.log(`\n${prefix} Consistency Check Result:`);
  console.log(`${prefix} Is Consistent: ${result.isConsistent ? '✓ YES' : '✗ NO'}`);
  console.log(`${prefix} Total Matched: ${result.details.totalMatched}`);
  console.log(`${prefix} Total Inconsistencies: ${result.details.totalInconsistencies}`);

  if (result.missingInS3.length > 0) {
    console.log(`${prefix} ⚠️  Missing in S3 (${result.missingInS3.length}):`);
    result.missingInS3.forEach(item => {
      console.log(`${prefix}   - ${item.fileName} (ID: ${item.id})`);
    });
  }

  if (result.orphanedInS3.length > 0) {
    console.log(`${prefix} ⚠️  Orphaned in S3 (${result.orphanedInS3.length}):`);
    result.orphanedInS3.forEach(item => {
      console.log(`${prefix}   - ${item.key} (${item.size} bytes)`);
    });
  }

  if (result.isConsistent) {
    console.log(`${prefix} ✓ All data is consistent between DB and S3`);
  }
}
