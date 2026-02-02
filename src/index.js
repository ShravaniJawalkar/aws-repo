const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');

const snsClient = new SNSClient({ region: 'ap-south-1' });
const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN;

/**
 * Lambda handler for processing SQS messages and publishing to SNS
 * This function is triggered by SQS events and publishes image upload notifications to SNS
 */
exports.handler = async (event, context) => {
  console.log('Received event:', JSON.stringify(event, null, 2));
  
  const results = {
    successCount: 0,
    failureCount: 0,
    processedMessages: [],
    batchItemFailures: []
  };

  // Validate input
  if (!event.Records || event.Records.length === 0) {
    console.log('No records found in event');
    return { batchItemFailures: [] };
  }

  console.log(`Processing ${event.Records.length} messages from SQS`);

  // Process each SQS message
  for (const record of event.Records) {
    try {
      console.log(`Processing Message ID: ${record.messageId}`);
      
      // Parse the SQS message body
      let uploadEvent;
      try {
        uploadEvent = JSON.parse(record.body);
      } catch (parseError) {
        throw new Error(`Failed to parse message body: ${parseError.message}`);
      }

      // Validate upload event
      if (!uploadEvent || !uploadEvent.fileName) {
        throw new Error('Invalid upload event: missing fileName field');
      }

      // Extract event details
      const fileExtension = uploadEvent.fileExtension || '.unknown';
      const fileSize = uploadEvent.fileSize || 0;
      const fileSizeMB = (fileSize / (1024 * 1024)).toFixed(2);
      const description = uploadEvent.description || 'No description';
      const uploadedBy = uploadEvent.uploadedBy || 'System';
      const timestamp = uploadEvent.timestamp || new Date().toISOString();
      const eventId = uploadEvent.eventId || 'N/A';

      // Create notification message
      const notificationMessage = createNotificationMessage({
        fileName: uploadEvent.fileName,
        fileSizeMB,
        fileExtension,
        description,
        uploadedBy,
        timestamp,
        eventId
      });

      console.log(`Publishing notification for: ${uploadEvent.fileName}`);

      // Publish to SNS
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

      const publishResult = await snsClient.send(new PublishCommand(publishParams));

      console.log(`Published to SNS. Message ID: ${publishResult.MessageId}`);

      results.successCount++;
      results.processedMessages.push({
        messageId: record.messageId,
        status: 'success',
        snsMessageId: publishResult.MessageId,
        fileName: uploadEvent.fileName,
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error(`Error processing message ${record.messageId}: ${error.message}`, error);
      
      results.failureCount++;
      results.processedMessages.push({
        messageId: record.messageId,
        status: 'failed',
        reason: error.message,
        timestamp: new Date().toISOString()
      });
      
      // Add to batch failures for retry
      results.batchItemFailures.push({
        itemId: record.messageId
      });
    }
  }

  console.log('Processing Results:', JSON.stringify(results, null, 2));
  
  return {
    batchItemFailures: results.batchItemFailures
  };
};

/**
 * Helper function to create a formatted notification message
 */
function createNotificationMessage(details) {
  return `
================================
IMAGE UPLOAD NOTIFICATION
================================

File Name: ${details.fileName}
File Size: ${details.fileSizeMB} MB
Extension: ${details.fileExtension}
Description: ${details.description}
Uploaded By: ${details.uploadedBy}
Event ID: ${details.eventId}
Timestamp: ${details.timestamp}

================================
This is an automated notification from webproject.
Please do not reply to this email.
================================
  `.trim();
}
