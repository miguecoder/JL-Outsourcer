#!/bin/bash
# aws-cli.sh - Wrapper para AWS CLI que usa variables PIPELINE_* desde .env.secrets
#
# Este script lee .env.secrets con variables PIPELINE_* y las convierte
# temporalmente a variables AWS estándar solo durante la ejecución de AWS CLI.
# Las variables NO persisten en el shell, evitando conflictos con otros proyectos.
#
# USO:
#   ./aws-cli.sh sts get-caller-identity
#   ./aws-cli.sh lambda list-functions
#   ./aws-cli.sh s3 ls

# Verificar que existe .env.secrets
if [ ! -f .env.secrets ]; then
    echo "❌ ERROR: Archivo .env.secrets no encontrado"
    exit 1
fi

# Cargar variables PIPELINE_* desde .env.secrets
set -a
source .env.secrets
set +a

# Convertir variables PIPELINE_* a variables AWS estándar temporalmente
export AWS_ACCESS_KEY_ID="$PIPELINE_AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$PIPELINE_AWS_SECRET_ACCESS_KEY"

if [ -n "$PIPELINE_AWS_SESSION_TOKEN" ]; then
    export AWS_SESSION_TOKEN="$PIPELINE_AWS_SESSION_TOKEN"
fi

if [ -n "$PIPELINE_AWS_REGION" ]; then
    export AWS_DEFAULT_REGION="$PIPELINE_AWS_REGION"
    export AWS_REGION="$PIPELINE_AWS_REGION"
else
    export AWS_DEFAULT_REGION="us-east-1"
    export AWS_REGION="us-east-1"
fi

# Ejecutar AWS CLI con los argumentos pasados
aws "$@"

# Guardar código de salida
EXIT_CODE=$?

# Limpiar variables
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
unset AWS_DEFAULT_REGION
unset AWS_REGION

exit $EXIT_CODE

