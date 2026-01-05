#!/bin/bash

# Script para limpiar el entorno de Odoo Docker (Local)

# Cargar variables de entorno (preferir las finales si hay duplicados)
if [ -f .env ]; then
    export $(grep -E '^[a-zA-Z0-9_]+=' .env | xargs)
fi

# Intentar obtener POSTGRES_DB si no está en las variables cargadas
DB_NAME=${POSTGRES_DB:-odoo_elantar_dev}
DB_SERVICE="db-dev"
COMPOSE_FILE="docker-compose.yml"

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
        # Forzar el uso del usuario de Postgres correcto
        PG_PASSWORD=${POSTGRES_PASSWORD:-odoo_pass_123}
        PG_USER=${POSTGRES_USER:-odoo}
        
        docker compose -f $COMPOSE_FILE exec -e PGPASSWORD="$PG_PASSWORD" $DB_SERVICE dropdb -U $PG_USER $DB_NAME --if-exists
        docker compose -f $COMPOSE_FILE exec -e PGPASSWORD="$PG_PASSWORD" $DB_SERVICE createdb -U $PG_USER $DB_NAME
        echo "✅ Base de datos '$DB_NAME' recreada completamente vacía."
        echo "♻️ Reiniciando Odoo para asegurar conexión limpia..."
        docker compose -f $COMPOSE_FILE restart odoo-dev
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
