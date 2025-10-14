// Basic unit tests for ingestion Lambda (Static code analysis)

const assert = require('assert');
const fs = require('fs');
const path = require('path');

console.log('🧪 Running Ingestion Lambda Tests...\n');

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

// Test 2: Environment variables are used
try {
  assert.ok(
    code.includes('process.env.RAW_BUCKET_NAME') || code.includes('process.env.BUCKET_NAME'),
    'Lambda should use bucket name from environment'
  );
  assert.ok(
    code.includes('process.env.QUEUE_URL'),
    'Lambda should use queue URL from environment'
  );
  console.log('✅ Test 2: Environment variables are used correctly');
} catch (error) {
  console.error('❌ Test 2 failed:', error.message);
  process.exit(1);
}

// Test 3: AWS SDK imports
try {
  assert.ok(
    code.includes('require') && (code.includes('aws-sdk') || code.includes('@aws-sdk')),
    'Lambda should import AWS SDK'
  );
  console.log('✅ Test 3: AWS SDK is imported');
} catch (error) {
  console.error('❌ Test 3 failed:', error.message);
  process.exit(1);
}

// Test 4: S3 operations
try {
  assert.ok(
    code.includes('putObject') || code.includes('PutObject'),
    'Lambda should use S3 putObject operation'
  );
  console.log('✅ Test 4: S3 operations are implemented');
} catch (error) {
  console.error('❌ Test 4 failed:', error.message);
  process.exit(1);
}

// Test 5: SQS operations
try {
  assert.ok(
    code.includes('sendMessage') || code.includes('SendMessage'),
    'Lambda should send messages to SQS'
  );
  console.log('✅ Test 5: SQS operations are implemented');
} catch (error) {
  console.error('❌ Test 5 failed:', error.message);
  process.exit(1);
}

// Test 6: Structured logging
try {
  assert.ok(
    code.includes('JSON.stringify') && code.includes('console.log'),
    'Lambda should use structured logging'
  );
  console.log('✅ Test 6: Structured logging is implemented');
} catch (error) {
  console.error('❌ Test 6 failed:', error.message);
  process.exit(1);
}

console.log('\n✅ All Ingestion Lambda tests passed! (6/6)\n');
process.exit(0);
