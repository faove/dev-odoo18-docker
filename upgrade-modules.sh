#!/bin/bash

# Script para automatizar la actualización de módulos en Odoo Docker (Local)

# Cargar variables de entorno desde .env, ignorando líneas inválidas y comentarios
if [ -f .env ]; then
    export $(grep -E '^[a-zA-Z0-9_]+=' .env | xargs)
fi

# Variables de configuración
DB_NAME=${2:-${ODOO_DB_NAME:-odoo_elantar_dev}}
SERVICE_NAME="odoo-dev"
COMPOSE_FILE="docker-compose.yml"

show_help() {
    echo "Uso: ./upgrade-modules.sh [módulos|all] [base_de_datos]"
    echo ""
    echo "Opciones:"
    echo "  all                 Actualiza TODOS los módulos instalados."
    echo "  modulo1,modulo2     Actualiza módulos específicos (separados por coma)."
    echo "  base_de_datos       Nombre de la base de datos (opcional, por defecto: $DB_NAME)."
    echo "  --help              Muestra esta ayuda."
    echo ""
    echo "Ejemplos:"
    echo "  ./upgrade-modules.sh all"
    echo "  ./upgrade-modules.sh n8n_bridge restore251229"
    echo "  ./upgrade-modules.sh web,dms odoo_elantar_dev"
}

if [ "$1" == "--help" ] || [ -z "$1" ]; then
    show_help
    exit 0
fi

MODULES=$1

echo "🚀 Iniciando actualización de módulos: $MODULES"
echo "📂 Base de datos: $DB_NAME"

# Comando de actualización de Odoo
# Usamos 'sh -c' para que las variables ($HOST, $USER, $PASSWORD) se resuelvan DENTRO del contenedor
docker compose -f $COMPOSE_FILE exec -u root $SERVICE_NAME sh -c "odoo \
    -u $MODULES \
    -d $DB_NAME \
    --db_host=\$HOST \
    --db_user=\$USER \
    --db_password=\$PASSWORD \
    --stop-after-init"

if [ $? -eq 0 ]; then
    echo "✅ Actualización completada correctamente."
    echo "♻️ Reiniciando contenedor para aplicar cambios..."
    docker compose -f $COMPOSE_FILE restart $SERVICE_NAME
else
    echo "❌ Error durante la actualización. Revisa los logs:"
    echo "docker compose -f $COMPOSE_FILE logs $SERVICE_NAME"
fi
