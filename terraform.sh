#!/bin/bash
# terraform.sh - Wrapper para Terraform que usa variables PIPELINE_* desde .env.secrets
#
# Este script lee .env.secrets con variables PIPELINE_* y las convierte
# temporalmente a variables AWS estándar solo durante la ejecución de Terraform.
# Las variables NO persisten en el shell, evitando conflictos con otros proyectos.
#
# USO:
#   ./terraform.sh plan
#   ./terraform.sh apply
#   ./terraform.sh destroy

# Verificar que existe .env.secrets
if [ ! -f .env.secrets ]; then
    echo "❌ ERROR: Archivo .env.secrets no encontrado"
    echo "   Crea el archivo .env.secrets con:"
    echo "   PIPELINE_AWS_ACCESS_KEY_ID=tu_access_key"
    echo "   PIPELINE_AWS_SECRET_ACCESS_KEY=tu_secret_key"
    echo "   PIPELINE_AWS_REGION=us-east-1"
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

# Determinar el entorno (prioridad: variable ENV > PIPELINE_ENV desde .env.secrets > dev por defecto)
if [ -n "$ENV" ]; then
    # Usar variable ENV si está definida (pasada desde Makefile o línea de comandos)
    ENV_TO_USE="$ENV"
elif [ -n "$PIPELINE_ENV" ]; then
    # Usar PIPELINE_ENV desde .env.secrets
    ENV_TO_USE="$PIPELINE_ENV"
else
    # Por defecto dev
    ENV_TO_USE="dev"
fi

# Cambiar al directorio de Terraform según el entorno
cd infra/envs/$ENV_TO_USE || exit 1

# Ejecutar Terraform con los argumentos pasados
terraform "$@"

# Guardar código de salida
EXIT_CODE=$?

# Limpiar variables (aunque en un subproceso no afectan al padre)
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
unset AWS_DEFAULT_REGION
unset AWS_REGION

exit $EXIT_CODE

