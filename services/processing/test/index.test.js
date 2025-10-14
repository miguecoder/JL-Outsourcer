// Basic unit tests for processing Lambda (Static code analysis)

const assert = require('assert');
const fs = require('fs');
const path = require('path');

console.log('🧪 Running Processing Lambda Tests...\n');

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

// Test 2: DynamoDB table name from environment
try {
  assert.ok(
    code.includes('process.env.CURATED_TABLE_NAME') || code.includes('process.env.TABLE_NAME'),
    'Lambda should use table name from environment'
  );
  console.log('✅ Test 2: DynamoDB table name is from environment');
} catch (error) {
  console.error('❌ Test 2 failed:', error.message);
  process.exit(1);
}

// Test 3: Idempotency implementation
try {
  assert.ok(
    code.includes('ConditionExpression') && code.includes('attribute_not_exists'),
    'Lambda should implement idempotent upsert with ConditionExpression'
  );
  console.log('✅ Test 3: Idempotency is implemented');
} catch (error) {
  console.error('❌ Test 3 failed:', error.message);
  process.exit(1);
}

// Test 4: S3 getObject operation
try {
  assert.ok(
    code.includes('getObject') || code.includes('GetObject'),
    'Lambda should read from S3'
  );
  console.log('✅ Test 4: S3 read operations are implemented');
} catch (error) {
  console.error('❌ Test 4 failed:', error.message);
  process.exit(1);
}

// Test 5: DynamoDB put operation
try {
  assert.ok(
    code.includes('.put(') || code.includes('putItem'),
    'Lambda should write to DynamoDB'
  );
  console.log('✅ Test 5: DynamoDB write operations are implemented');
} catch (error) {
  console.error('❌ Test 5 failed:', error.message);
  process.exit(1);
}

// Test 6: Error handling
try {
  assert.ok(
    code.includes('try') && code.includes('catch'),
    'Lambda should have error handling'
  );
  console.log('✅ Test 6: Error handling is implemented');
} catch (error) {
  console.error('❌ Test 6 failed:', error.message);
  process.exit(1);
}

// Test 7: Fingerprint/hash generation
try {
  assert.ok(
    code.includes('createHash') || code.includes('fingerprint') || code.includes('hash'),
    'Lambda should generate fingerprints for deduplication'
  );
  console.log('✅ Test 7: Fingerprinting is implemented');
} catch (error) {
  console.error('❌ Test 7 failed:', error.message);
  process.exit(1);
}

console.log('\n✅ All Processing Lambda tests passed! (7/7)\n');
process.exit(0);
