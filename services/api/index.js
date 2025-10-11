const { DynamoDB } = require('aws-sdk');

const dynamodb = new DynamoDB.DocumentClient();
const TABLE_NAME = process.env.CURATED_TABLE_NAME;

// Helper para respuestas HTTP
const response = (statusCode, body) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,X-Api-Key',
    'Access-Control-Allow-Methods': 'GET,OPTIONS'
  },
  body: JSON.stringify(body)
});

// GET /records - Lista con paginación
const listRecords = async (queryParams) => {
  try {
    const limit = parseInt(queryParams?.limit) || 20;
    const source = queryParams?.source;
    
    let params = {
      TableName: TABLE_NAME,
      Limit: limit
    };
    
    // Si hay filtro por source, usar el GSI
    if (source) {
      params.IndexName = 'SourceIndex';
      params.KeyConditionExpression = '#source = :source';
      params.ExpressionAttributeNames = { '#source': 'source' };
      params.ExpressionAttributeValues = { ':source': source };
      
      const result = await dynamodb.query(params).promise();
      
      return response(200, {
        records: result.Items,
        count: result.Count,
        scannedCount: result.ScannedCount
      });
    }
    
    // Sin filtro, hacer scan
    if (queryParams?.lastKey) {
      params.ExclusiveStartKey = JSON.parse(
        Buffer.from(queryParams.lastKey, 'base64').toString()
      );
    }
    
    const result = await dynamodb.scan(params).promise();
    
    return response(200, {
      records: result.Items,
      count: result.Count,
      lastKey: result.LastEvaluatedKey 
        ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString('base64')
        : null
    });
    
  } catch (error) {
    console.error(JSON.stringify({ message: 'Error listing records', error: error.message }));
    return response(500, { error: 'Failed to list records', message: error.message });
  }
};

// GET /records/{id} - Detalle de un record
const getRecord = async (id) => {
  try {
    const result = await dynamodb.get({
      TableName: TABLE_NAME,
      Key: { id }
    }).promise();
    
    if (!result.Item) {
      return response(404, { error: 'Record not found', id });
    }
    
    return response(200, result.Item);
    
  } catch (error) {
    console.error(JSON.stringify({ message: 'Error getting record', id, error: error.message }));
    return response(500, { error: 'Failed to get record', message: error.message });
  }
};

// GET /analytics - Agregaciones y métricas
const getAnalytics = async () => {
  try {
    // Escanear toda la tabla para calcular métricas
    const result = await dynamodb.scan({
      TableName: TABLE_NAME
    }).promise();
    
    const records = result.Items;
    
    // Contar por source
    const bySource = records.reduce((acc, record) => {
      acc[record.source] = (acc[record.source] || 0) + 1;
      return acc;
    }, {});
    
    // Contar por fecha (solo fecha, sin hora)
    const byDate = records.reduce((acc, record) => {
      const date = record.captured_at?.split('T')[0] || 'unknown';
      acc[date] = (acc[date] || 0) + 1;
      return acc;
    }, {});
    
    // Últimos 7 días
    const sortedDates = Object.entries(byDate)
      .sort(([a], [b]) => b.localeCompare(a))
      .slice(0, 7);
    
    // Record más reciente y más antiguo
    const sortedByDate = records
      .filter(r => r.captured_at)
      .sort((a, b) => b.captured_at.localeCompare(a.captured_at));
    
    return response(200, {
      summary: {
        total_records: records.length,
        total_sources: Object.keys(bySource).length,
        oldest_record: sortedByDate[sortedByDate.length - 1]?.captured_at,
        newest_record: sortedByDate[0]?.captured_at
      },
      by_source: bySource,
      by_date: Object.fromEntries(sortedDates),
      timeline: sortedDates.map(([date, count]) => ({ date, count }))
    });
    
  } catch (error) {
    console.error(JSON.stringify({ message: 'Error getting analytics', error: error.message }));
    return response(500, { error: 'Failed to get analytics', message: error.message });
  }
};

// Main handler
exports.handler = async (event) => {
  console.log(JSON.stringify({ message: 'API Request', path: event.path, rawPath: event.rawPath, method: event.httpMethod }));
  
  // Handle OPTIONS for CORS
  if (event.httpMethod === 'OPTIONS') {
    return response(200, {});
  }
  
  // API Gateway HTTP API uses rawPath (v2.0) or path (v1.0)
  // Remove stage prefix if present (e.g., /dev/analytics -> /analytics)
  let path = event.rawPath || event.path || '';
  const method = event.httpMethod || event.requestContext?.http?.method;
  
  // Strip stage prefix if it exists (e.g., /dev, /prod, etc.)
  path = path.replace(/^\/[^\/]+/, '');
  
  // If path is empty after stripping, it was just the stage
  if (path === '') {
    path = '/';
  }
  
  try {
    // Routing
    if (method === 'GET' && path === '/records') {
      return await listRecords(event.queryStringParameters);
    }
    
    if (method === 'GET' && path.startsWith('/records/')) {
      const id = path.split('/').filter(p => p)[1]; // Get second non-empty part
      return await getRecord(id);
    }
    
    if (method === 'GET' && path === '/analytics') {
      return await getAnalytics();
    }
    
    // Route not found
    return response(404, { error: 'Route not found', path, method, originalPath: event.path });
    
  } catch (error) {
    console.error(JSON.stringify({ message: 'Unhandled error', error: error.message, stack: error.stack }));
    return response(500, { error: 'Internal server error', message: error.message });
  }
};

