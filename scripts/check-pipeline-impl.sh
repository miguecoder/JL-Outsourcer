#!/bin/bash
# Pipeline Health Check Implementation
# This is a copy of the original check-pipeline.sh for reference

set -e

echo "=========================================="
echo "  Pipeline Health Check"
echo "=========================================="
echo ""

cd "$(dirname "$0")/../infra/envs/dev"

# Get resource names
BUCKET=$(terraform output -raw raw_bucket_name)
TABLE=$(terraform output -raw curated_table_name)
QUEUE_URL=$(terraform output -raw queue_url)

echo "📦 Recursos:"
echo "   S3 Bucket: $BUCKET"
echo "   DynamoDB Table: $TABLE"
echo "   SQS Queue: $QUEUE_URL"
echo ""

# Check S3
echo "=========================================="
echo "1️⃣  Verificando S3 (Raw Data)"
echo "=========================================="
S3_COUNT=$(aws s3 ls s3://$BUCKET/raw/ --recursive 2>/dev/null | wc -l)
echo "✅ Archivos en S3: $S3_COUNT"
if [ $S3_COUNT -gt 0 ]; then
    echo "   Últimos 3 archivos:"
    aws s3 ls s3://$BUCKET/raw/ --recursive --human-readable | tail -3
fi
echo ""

# Check SQS
echo "=========================================="
echo "2️⃣  Verificando SQS Queue"
echo "=========================================="
MESSAGES=$(aws sqs get-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --attribute-names ApproximateNumberOfMessages \
    --query 'Attributes.ApproximateNumberOfMessages' \
    --output text)
echo "✅ Mensajes en cola: $MESSAGES"
echo ""

# Check DynamoDB
echo "=========================================="
echo "3️⃣  Verificando DynamoDB (Curated Data)"
echo "=========================================="
DYNAMO_COUNT=$(aws dynamodb scan --table-name $TABLE --select COUNT --query 'Count' --output text)
echo "✅ Records en DynamoDB: $DYNAMO_COUNT"
if [ $DYNAMO_COUNT -gt 0 ]; then
    echo "   Primeros 3 records:"
    aws dynamodb scan --table-name $TABLE --limit 3 --query 'Items[*].[id.S, source.S]' --output text
fi
echo ""

echo "=========================================="
echo "  📊 Resumen"
echo "=========================================="
echo ""
echo "Pipeline:"
echo "  Ingestion → S3 ($S3_COUNT archivos)"
echo "  SQS → Processing ($MESSAGES en cola)"
echo "  Processing → DynamoDB ($DYNAMO_COUNT records)"
echo ""

