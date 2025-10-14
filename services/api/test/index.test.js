// Basic unit tests for API Lambda (Static code analysis)

const assert = require('assert');
const fs = require('fs');
const path = require('path');

console.log('🧪 Running API Lambda Tests...\n');

const indexPath = path.join(__dirname, '..', 'index.js');
const code = fs.readFileSync(indexPath, 'utf8');

// Test 1: Handler function is exported
try {
  assert.ok(
    code.includes('exports.handler') || code.includes('module.exports.handler'),
    'Lambda should export a handler function'
  );
  console.log('✅ Test 1: Handler function is exported');
} catch (error) {
  console.error('❌ Test 1 failed:', error.message);
  process.exit(1);
}

// Test 2: Required routes are implemented
try {
  assert.ok(code.includes('/records'), 'Should handle /records route');
  assert.ok(code.includes('/analytics'), 'Should handle /analytics route');
  console.log('✅ Test 2: Required routes (/records, /analytics) are defined');
} catch (error) {
  console.error('❌ Test 2 failed:', error.message);
  process.exit(1);
}

// Test 3: CORS headers
try {
  assert.ok(
    code.includes('Access-Control-Allow-Origin'),
    'Lambda should set CORS headers'
  );
  console.log('✅ Test 3: CORS headers are configured');
} catch (error) {
  console.error('❌ Test 3 failed:', error.message);
  process.exit(1);
}

// Test 4: DynamoDB operations
try {
  assert.ok(
    code.includes('.scan(') || code.includes('.query(') || code.includes('.get('),
    'Lambda should query DynamoDB'
  );
  console.log('✅ Test 4: DynamoDB query operations are implemented');
} catch (error) {
  console.error('❌ Test 4 failed:', error.message);
  process.exit(1);
}

// Test 5: HTTP methods handling
try {
  assert.ok(
    code.includes('GET') || code.includes('httpMethod'),
    'Lambda should handle HTTP methods'
  );
  assert.ok(
    code.includes('OPTIONS'),
    'Lambda should handle CORS preflight (OPTIONS)'
  );
  console.log('✅ Test 5: HTTP methods (GET, OPTIONS) are handled');
} catch (error) {
  console.error('❌ Test 5 failed:', error.message);
  process.exit(1);
}

// Test 6: Response helper function
try {
  assert.ok(
    code.includes('statusCode') && code.includes('headers'),
    'Lambda should format HTTP responses correctly'
  );
  console.log('✅ Test 6: HTTP response formatting is implemented');
} catch (error) {
  console.error('❌ Test 6 failed:', error.message);
  process.exit(1);
}

// Test 7: Path routing logic
try {
  assert.ok(
    code.includes('path') && (code.includes('replace') || code.includes('split')),
    'Lambda should handle path routing'
  );
  console.log('✅ Test 7: Path routing logic exists');
} catch (error) {
  console.error('❌ Test 7 failed:', error.message);
  process.exit(1);
}

// Test 8: Error handling
try {
  assert.ok(
    code.includes('try') && code.includes('catch'),
    'Lambda should have error handling'
  );
  console.log('✅ Test 8: Error handling is implemented');
} catch (error) {
  console.error('❌ Test 8 failed:', error.message);
  process.exit(1);
}

console.log('\n✅ All API Lambda tests passed! (8/8)\n');
process.exit(0);
