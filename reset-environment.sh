#!/bin/bash

# Script para limpiar el entorno de Odoo Docker (Local)

# Cargar variables de entorno
if [ -f .env ]; then
    export $(grep -E '^[a-zA-Z0-9_]+=' .env | xargs)
fi

DB_NAME=${ODOO_DB_NAME:-odoo_elantar_dev}
DB_SERVICE="db-dev"
COMPOSE_FILE="docker-compose.local.yml"

show_help() {
    echo "Uso: ./reset-environment.sh [soft|hard]"
    echo ""
    echo "Opciones:"
    echo "  soft    (Recomendado) Borra solo la base de datos '$DB_NAME'."
    echo "          Mantiene los archivos adjuntos y la configuración de Docker."
    echo ""
    echo "  hard    (FACTORY RESET) Borra TODO: bases de datos y volúmenes."
    echo "          Odoo quedará como recién instalado. Se pierden adjuntos y fotos."
    echo ""
}

if [ -z "$1" ] || [ "$1" == "--help" ]; then
    show_help
    exit 0
fi

case "$1" in
    soft)
        echo "⚠️  Iniciando SOFT RESET (Borrando base de datos '$DB_NAME')..."
        docker compose -f $COMPOSE_FILE exec $DB_SERVICE dropdb -U $POSTGRES_USER $DB_NAME --if-exists
        docker compose -f $COMPOSE_FILE exec $DB_SERVICE createdb -U $POSTGRES_USER $DB_NAME
        echo "✅ Base de datos '$DB_NAME' recreada completamente vacía."
        ;;
    hard)
        echo "🚨 INICIANDO HARD RESET (BORRADO TOTAL)..."
        echo "Esto eliminará todos los datos, adjuntos y configuraciones."
        read -p "¿Estás seguro? (s/N): " confirm
        if [[ $confirm == [sS] ]]; then
            docker compose -f $COMPOSE_FILE down -v
            echo "✅ Volúmenes y contenedores eliminados."
            echo "🚀 Levantando entorno limpio..."
            docker compose -f $COMPOSE_FILE up -d
            echo "✅ Entorno listo y vacío."
        else
            echo "Operación cancelada."
        fi
        ;;
    *)
        echo "Opción no válida."
        show_help
        exit 1
        ;;
esac
