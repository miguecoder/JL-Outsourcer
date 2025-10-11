const { S3, DynamoDB } = require('aws-sdk');
const crypto = require('crypto');

const s3 = new S3();
const dynamodb = new DynamoDB.DocumentClient();

const TABLE_NAME = process.env.CURATED_TABLE_NAME;

exports.handler = async (event) => {
  console.log(JSON.stringify({ message: 'Processing messages', recordCount: event.Records.length }));
  
  const results = [];
  
  for (const record of event.Records) {
    try {
      const message = JSON.parse(record.body);
      console.log(JSON.stringify({ message: 'Processing', source: message.source, s3Key: message.s3Key }));
      
      const s3Object = await s3.getObject({
        Bucket: message.s3Bucket,
        Key: message.s3Key
      }).promise();
      
      const rawData = JSON.parse(s3Object.Body.toString());
      
      let processedRecords = [];
      
      if (message.source === 'jsonplaceholder') {
        processedRecords = Array.isArray(rawData) 
          ? rawData.slice(0, 10).map(item => ({
              id: `${message.source}-${item.id}-${message.hash.substring(0, 8)}`,
              source: message.source,
              captured_at: message.capturedAt,
              title: item.title || '',
              body: item.body || '',
              userId: String(item.userId || ''),
              raw_s3_key: message.s3Key,
              fingerprint: crypto.createHash('md5').update(JSON.stringify(item)).digest('hex'),
              processed_at: new Date().toISOString()
            }))
          : [];
      } 
      else if (message.source === 'randomuser') {
        const users = rawData.results || [];
        processedRecords = users.map(user => ({
          id: `${message.source}-${user.login.uuid}-${message.hash.substring(0, 8)}`,
          source: message.source,
          captured_at: message.capturedAt,
          name: `${user.name.first} ${user.name.last}`,
          email: user.email,
          country: user.location.country,
          gender: user.gender,
          raw_s3_key: message.s3Key,
          fingerprint: crypto.createHash('md5').update(JSON.stringify(user)).digest('hex'),
          processed_at: new Date().toISOString()
        }));
      }
      
      for (const item of processedRecords) {
        try {
          await dynamodb.put({
            TableName: TABLE_NAME,
            Item: item,
            ConditionExpression: 'attribute_not_exists(id)'
          }).promise();
          
          console.log(JSON.stringify({ message: 'Stored record', id: item.id }));
        } catch (error) {
          if (error.code === 'ConditionalCheckFailedException') {
            console.log(JSON.stringify({ message: 'Record exists (idempotent)', id: item.id }));
          } else {
            throw error;
          }
        }
      }
      
      results.push({
        source: message.source,
        status: 'success',
        processedCount: processedRecords.length
      });
      
    } catch (error) {
      console.error(JSON.stringify({ message: 'Error processing', error: error.message }));
      results.push({
        messageId: record.messageId,
        status: 'error',
        error: error.message
      });
      throw error;
    }
  }
  
  return {
    statusCode: 200,
    body: JSON.stringify({
      message: 'Processing completed',
      results: results
    })
  };
};
