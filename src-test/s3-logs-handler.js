const { S3Client, GetObjectCommand, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const { CloudWatchLogsClient, DescribeLogGroupsCommand } = require('@aws-sdk/client-cloudwatch-logs');

const s3Client = new S3Client({ region: 'ap-south-1' });
const logsClient = new CloudWatchLogsClient({ region: 'ap-south-1' });

/**
 * Lambda handler for S3 logs testing and demonstration
 * This function is useful for testing S3 access, listing objects, and checking CloudWatch logs
 */
exports.handler = async (event, context) => {
  console.log('S3 Logs Function - Testing/Demo Handler');
  console.log('Event:', JSON.stringify(event, null, 2));
  
  const results = {
    timestamp: new Date().toISOString(),
    functionName: context.functionName,
    functionVersion: context.functionVersion,
    awsRequestId: context.awsRequestId,
    tests: {}
  };

  try {
    // Test 1: List CloudWatch Log Groups
    console.log('Test 1: Listing CloudWatch Log Groups...');
    try {
      const logsResponse = await logsClient.send(new DescribeLogGroupsCommand({
        limit: 10
      }));
      
      results.tests.logGroups = {
        status: 'success',
        count: logsResponse.logGroups ? logsResponse.logGroups.length : 0,
        logGroups: logsResponse.logGroups ? logsResponse.logGroups.map(lg => ({
          name: lg.logGroupName,
          creationTime: lg.creationTime,
          retentionInDays: lg.retentionInDays || 'No retention set'
        })) : []
      };
      console.log('CloudWatch Log Groups:', JSON.stringify(results.tests.logGroups, null, 2));
    } catch (error) {
      console.error('Error listing log groups:', error);
      results.tests.logGroups = {
        status: 'error',
        message: error.message
      };
    }

    // Test 2: List S3 buckets (if bucket name provided in event)
    if (event.bucketName) {
      console.log(`Test 2: Listing objects in bucket: ${event.bucketName}...`);
      try {
        const s3Response = await s3Client.send(new ListObjectsV2Command({
          Bucket: event.bucketName,
          MaxKeys: 10
        }));

        results.tests.s3Objects = {
          status: 'success',
          bucket: event.bucketName,
          objectCount: s3Response.Contents ? s3Response.Contents.length : 0,
          objects: s3Response.Contents ? s3Response.Contents.map(obj => ({
            key: obj.Key,
            size: obj.Size,
            lastModified: obj.LastModified
          })) : []
        };
        console.log('S3 Objects:', JSON.stringify(results.tests.s3Objects, null, 2));
      } catch (error) {
        console.error('Error listing S3 objects:', error);
        results.tests.s3Objects = {
          status: 'error',
          bucket: event.bucketName,
          message: error.message
        };
      }
    } else {
      results.tests.s3Objects = {
        status: 'skipped',
        reason: 'bucketName not provided in event'
      };
    }

    // Test 3: Get S3 object (if bucket and key provided)
    if (event.bucketName && event.objectKey) {
      console.log(`Test 3: Getting object from S3: ${event.bucketName}/${event.objectKey}...`);
      try {
        const getObjectResponse = await s3Client.send(new GetObjectCommand({
          Bucket: event.bucketName,
          Key: event.objectKey
        }));

        // Read the body as a string
        const bodyString = await getObjectResponse.Body.transformToString();

        results.tests.s3GetObject = {
          status: 'success',
          bucket: event.bucketName,
          key: event.objectKey,
          contentType: getObjectResponse.ContentType,
          contentLength: getObjectResponse.ContentLength,
          lastModified: getObjectResponse.LastModified,
          bodyPreview: bodyString.substring(0, 200) // First 200 chars
        };
        console.log('S3 Object Retrieved:', JSON.stringify(results.tests.s3GetObject, null, 2));
      } catch (error) {
        console.error('Error getting S3 object:', error);
        results.tests.s3GetObject = {
          status: 'error',
          bucket: event.bucketName,
          key: event.objectKey,
          message: error.message
        };
      }
    } else {
      results.tests.s3GetObject = {
        status: 'skipped',
        reason: 'bucketName or objectKey not provided in event'
      };
    }

  } catch (error) {
    console.error('Unexpected error:', error);
    results.error = error.message;
    return {
      statusCode: 500,
      body: JSON.stringify(results)
    };
  }

  console.log('Final Results:', JSON.stringify(results, null, 2));

  return {
    statusCode: 200,
    body: JSON.stringify(results)
  };
};
