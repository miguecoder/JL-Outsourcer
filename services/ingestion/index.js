const https = require('https');
const crypto = require('crypto');
const { S3, SQS } = require('aws-sdk'); // SDK v2 está disponible en Node 16

const s3 = new S3();
const sqs = new SQS();

const BUCKET_NAME = process.env.RAW_BUCKET_NAME;
const QUEUE_URL = process.env.QUEUE_URL;

function httpsGet(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

const DATA_SOURCES = [
  {
    name: 'jsonplaceholder',
    url: 'https://jsonplaceholder.typicode.com/posts',
    type: 'posts'
  },
  {
    name: 'randomuser',
    url: 'https://randomuser.me/api/?results=10',
    type: 'users'
  }
];

exports.handler = async (event) => {
  console.log(JSON.stringify({ message: 'Starting ingestion', timestamp: new Date().toISOString() }));
  
  const results = [];
  
  for (const source of DATA_SOURCES) {
    try {
      console.log(JSON.stringify({ message: 'Fetching data', source: source.name }));
      
      const data = await httpsGet(source.url);
      
      const timestamp = new Date().toISOString();
      const date = timestamp.split('T')[0];
      const hash = crypto.createHash('md5').update(JSON.stringify(data)).digest('hex');
      
      const s3Key = `raw/source=${source.name}/date=${date}/${timestamp}-${hash}.json`;
      
      await s3.putObject({
        Bucket: BUCKET_NAME,
        Key: s3Key,
        Body: JSON.stringify(data, null, 2),
        ContentType: 'application/json',
        Metadata: {
          source: source.name,
          type: source.type,
          capturedAt: timestamp,
          hash: hash
        }
      }).promise();
      
      console.log(JSON.stringify({ message: 'Stored in S3', s3Key }));
      
      const message = {
        source: source.name,
        type: source.type,
        s3Bucket: BUCKET_NAME,
        s3Key: s3Key,
        capturedAt: timestamp,
        hash: hash,
        recordCount: Array.isArray(data) ? data.length : (data.results?.length || 1)
      };
      
      await sqs.sendMessage({
        QueueUrl: QUEUE_URL,
        MessageBody: JSON.stringify(message),
        MessageAttributes: {
          source: {
            DataType: 'String',
            StringValue: source.name
          }
        }
      }).promise();
      
      console.log(JSON.stringify({ message: 'Sent to SQS', source: source.name }));
      
      results.push({
        source: source.name,
        status: 'success',
        s3Key: s3Key,
        recordCount: message.recordCount
      });
      
    } catch (error) {
      console.error(JSON.stringify({ message: 'Error', source: source.name, error: error.message }));
      results.push({
        source: source.name,
        status: 'error',
        error: error.message
      });
    }
  }
  
  return {
    statusCode: 200,
    body: JSON.stringify({
      message: 'Ingestion completed',
      results: results,
      timestamp: new Date().toISOString()
    })
  };
};
