/**
 * Lambda function: webproject-UploadsNotificationFunction
 * 
 * Purpose:
 * - Triggered by SQS messages from webproject-UploadsNotificationQueue
 * - Receives image upload events from the queue
 * - Publishes notifications to webproject-UploadsNotificationTopic (SNS)
 * - Emails are sent to subscribers of the SNS topic
 * 
 * Environment Variables:
 * - SNS_TOPIC_ARN: ARN of the SNS topic
 */

const AWS = require('aws-sdk');

// Initialize SNS client
const sns = new AWS.SNS({
  region: process.env.AWS_REGION || 'ap-south-1'
});

const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN || 'arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic';

/**
 * Lambda Handler - triggered by SQS events
 */
exports.handler = async (event, context) => {
  console.log('Received event:', JSON.stringify(event, null, 2));

  // Track results
  const results = {
    successCount: 0,
    failureCount: 0,
    processedMessages: []
  };

  // Process each SQS record
  if (!event.Records || event.Records.length === 0) {
    console.log('No records found in event');
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'No records to process',
        results
      })
    };
  }

  // Process records sequentially to maintain order
  for (const record of event.Records) {
    try {
      console.log(`\n[Processing] Message ID: ${record.messageId}`);

      // Parse the SQS message body
      let uploadEvent;
      try {
        uploadEvent = JSON.parse(record.body);
        console.log('Parsed upload event:', uploadEvent);
      } catch (parseError) {
        console.error('Failed to parse message body:', parseError);
        results.failureCount++;
        results.processedMessages.push({
          messageId: record.messageId,
          status: 'failed',
          reason: 'Invalid JSON format'
        });
        throw new Error('Invalid message format');
      }

      // Validate required fields
      if (!uploadEvent || !uploadEvent.fileName) {
        throw new Error('Invalid upload event: missing fileName');
      }

      // Set defaults for optional fields
      const fileExtension = uploadEvent.fileExtension || '.unknown';
      const fileSize = uploadEvent.fileSize || 0;
      const description = uploadEvent.description || 'No description provided';
      const timestamp = uploadEvent.timestamp || new Date().toISOString();
      const eventId = uploadEvent.eventId || 'unknown';

      // Create human-readable notification message
      const notificationMessage = createNotificationMessage(uploadEvent);

      console.log(`Publishing notification for file: ${uploadEvent.fileName}`);

      // Publish to SNS topic
      const publishParams = {
        TopicArn: SNS_TOPIC_ARN,
        Subject: `Image Upload Notification: ${uploadEvent.fileName}`,
        Message: notificationMessage,
        MessageAttributes: {
          ImageExtension: {
            StringValue: fileExtension,
            DataType: 'String'
          },
          FileSize: {
            StringValue: fileSize.toString(),
            DataType: 'Number'
          },
          EventType: {
            StringValue: 'ImageUpload',
            DataType: 'String'
          },
          EventId: {
            StringValue: eventId,
            DataType: 'String'
          }
        }
      };

      // Publish to SNS
      const publishResult = await sns.publish(publishParams).promise();
      console.log(`✓ Successfully published to SNS. Message ID: ${publishResult.MessageId}`);

      results.successCount++;
      results.processedMessages.push({
        messageId: record.messageId,
        status: 'success',
        snsMessageId: publishResult.MessageId,
        fileName: uploadEvent.fileName
      });

    } catch (error) {
      console.error(`✗ Error processing message ${record.messageId}:`, error.message);
      results.failureCount++;
      results.processedMessages.push({
        messageId: record.messageId,
        status: 'failed',
        reason: error.message
      });

      // Re-throw to let Lambda handle the failure
      // This will cause the message to be reprocessed (depending on your retry policy)
      throw error;
    }
  }

  // Log summary
  console.log('\n=== Processing Summary ===');
  console.log(`Success: ${results.successCount}, Failures: ${results.failureCount}`);
  console.log('Processed messages:', JSON.stringify(results.processedMessages, null, 2));

  return {
    statusCode: results.failureCount === 0 ? 200 : 207,
    body: JSON.stringify({
      message: `Processed ${event.Records.length} messages`,
      results
    })
  };
};

/**
 * Helper function to create a human-readable notification message
 */
function createNotificationMessage(uploadEvent) {
  const {
    fileName,
    fileSize,
    fileExtension,
    description,
    timestamp,
    uploadedBy,
    eventId
  } = uploadEvent;

  const fileSizeMB = fileSize ? (fileSize / (1024 * 1024)).toFixed(2) : 'unknown';

  return `
Image Upload Notification
==========================

File Name:     ${fileName || 'N/A'}
File Size:     ${fileSizeMB} MB
Extension:     ${fileExtension || 'N/A'}
Description:   ${description || 'No description provided'}
Uploaded By:   ${uploadedBy || 'System'}
Timestamp:     ${timestamp || 'Unknown'}
Event ID:      ${eventId || 'N/A'}

This is an automated notification from your Image Upload Service.
If you did not expect this email, please contact your administrator.

---
AWS Lambda Function: webproject-UploadsNotificationFunction
  `;
}
