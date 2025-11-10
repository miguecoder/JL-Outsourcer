# 🔐 Configuración AWS: Sin Conflictos entre Proyectos

## 🎯 Problema

Trabajas con **2 proyectos** en cuentas AWS diferentes:
- **Proyecto 1 (otro)**: Usa SSO y también exporta `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` directamente
- **Proyecto 2 (este - TWL Pipeline)**: Tiene credenciales diferentes en `.env.secrets`

Si ambos usan `AWS_ACCESS_KEY_ID` estándar, habrá conflictos cuando trabajes en ambos proyectos al mismo tiempo.

## ✅ Solución

Este proyecto usa **variables con prefijo `PIPELINE_*`** en `.env.secrets` y **wrappers** que las convierten temporalmente a variables AWS estándar solo durante la ejecución.

**Resultado:** Las variables AWS estándar **NO persisten** en tu shell, evitando conflictos con el otro proyecto.

## 📋 Configuración

### 1. Crear `.env.secrets`

Crea el archivo `.env.secrets` en la raíz del proyecto:

```bash
# .env.secrets - Credenciales AWS para TWL Pipeline
# Usa prefijo PIPELINE_ para evitar conflictos con otros proyectos

PIPELINE_AWS_ACCESS_KEY_ID=tu_access_key_real
PIPELINE_AWS_SECRET_ACCESS_KEY=tu_secret_key_real
PIPELINE_AWS_REGION=us-east-1

# Opcional: Si usas credenciales temporales
# PIPELINE_AWS_SESSION_TOKEN=tu_session_token
```

**⚠️ IMPORTANTE:**
- **NUNCA** commitees este archivo (ya está en `.gitignore`)
- Usa **prefijo `PIPELINE_`** para evitar conflictos

### 2. Dar permisos de ejecución

```bash
chmod +x terraform.sh aws-cli.sh
```

## 🚀 Uso

### Opción 1: Usar wrappers directamente

```bash
# Terraform
./terraform.sh plan
./terraform.sh apply
./terraform.sh destroy

# AWS CLI
./aws-cli.sh sts get-caller-identity
./aws-cli.sh lambda list-functions
./aws-cli.sh s3 ls
```

### Opción 2: Usar Makefile (automático)

El Makefile ya usa los wrappers automáticamente:

```bash
make infra-plan
make infra-apply
make deploy-lambdas
make test-ingestion
make logs-api
```

## 🔄 Workflow

### **Para trabajar en TWL Pipeline (este proyecto):**

```bash
# Usar wrappers o Makefile (NO exporta variables en el shell)
./terraform.sh plan
make infra-apply
./aws-cli.sh sts get-caller-identity
```

### **Para trabajar en el otro proyecto:**

```bash
# NO necesitas limpiar nada (las variables no están activas)
export AWS_PROFILE=TwlDevQA-590184109054
aws sso login --profile TwlDevQA-590184109054

# O exportar credenciales directamente (como siempre)
export AWS_ACCESS_KEY_ID="otra_key"
export AWS_SECRET_ACCESS_KEY="otra_secret"

# Trabajar normalmente
cd /ruta/al/otro/proyecto
terraform plan
```

## 🎯 Cómo Funciona

1. **`.env.secrets`** contiene variables con prefijo `PIPELINE_*`
2. **`terraform.sh`** y **`aws-cli.sh`** leen `.env.secrets`
3. Convierten `PIPELINE_*` a variables AWS estándar **solo durante la ejecución**
4. Las variables **NO persisten** en el shell (se ejecutan en subproceso)
5. **Resultado:** Cero conflictos con otros proyectos

## ✅ Ventajas

✅ **Cero conflictos**: Variables no persisten en el shell  
✅ **Automático**: Makefile usa wrappers automáticamente  
✅ **Seguro**: No afecta otros proyectos  
✅ **Simple**: Solo 2 archivos (`terraform.sh` y `aws-cli.sh`)  

## 🆘 Troubleshooting

### Error: "Permission denied"
```bash
chmod +x terraform.sh aws-cli.sh
```

### Error: ".env.secrets no encontrado"
```bash
# Crear el archivo
cat > .env.secrets << EOF
PIPELINE_AWS_ACCESS_KEY_ID=tu_access_key
PIPELINE_AWS_SECRET_ACCESS_KEY=tu_secret_key
PIPELINE_AWS_REGION=us-east-1
EOF
```

### Verificar que no hay variables activas
```bash
# Verificar que NO hay variables AWS_* activas
env | grep AWS
# No debería mostrar nada (o solo AWS_PROFILE si usas SSO en el otro proyecto)
```

