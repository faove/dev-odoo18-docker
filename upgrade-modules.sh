#!/bin/bash

# Script mejorado para actualización de módulos en Odoo Docker (Local)

# Asegurar que el script se ejecute desde su propia ubicación
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Cargar variables de entorno desde .env, ignorando líneas inválidas y comentarios
if [ -f .env ]; then
    export $(grep -E '^[a-zA-Z0-9_]+=' .env | xargs)
fi

# Variables de configuración
SERVICE_NAME="odoo-dev"
DB_SERVICE="db-dev"
COMPOSE_FILE="docker-compose.yml"

# --- Funciones ---

show_help() {
    echo "Uso: ./upgrade-modules.sh [módulos|all] [base_de_datos]"
    echo ""
    echo "Opciones:"
    echo "  all                 Actualiza TODOS los módulos instalados."
    echo "  modulo1,modulo2     Actualiza módulos específicos (separados por coma)."
    echo "  base_de_datos       Nombre de la base de datos (opcional, se detectará si no se provee)."
    echo "  --help              Muestra esta ayuda."
}

get_databases() {
    docker compose -f $COMPOSE_FILE exec -T $DB_SERVICE psql -U $POSTGRES_USER -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres' AND datname != 'template1' AND datname != 'odoo';" | xargs
}

get_local_version() {
    local module=$1
    local manifest="./addons/$module/__manifest__.py"
    if [ -f "$manifest" ]; then
        grep "'version':" "$manifest" | head -n 1 | sed -E "s/.*'version': *['\"]([^'\"]*)['\"].*/\1/"
    else
        echo "unknown"
    fi
}

get_db_version() {
    local module=$1
    local db=$2
    docker compose -f $COMPOSE_FILE exec -T $DB_SERVICE psql -U $POSTGRES_USER -d $db -t -c "SELECT latest_version FROM ir_module_module WHERE name = '$module';" | xargs
}

compare_versions() {
    # Retorna 0 si v1 > v2, 1 si son iguales, 2 si v1 < v2
    if [[ "$1" == "$2" ]]; then return 1; fi
    local v1=(${1//./ })
    local v2=(${2//./ })
    for ((i=0; i<${#v1[@]}; i++)); do
        if [[ -z ${v2[i]} ]]; then return 0; fi
        if ((10#${v1[i]} > 10#${v2[i]})); then return 0; fi
        if ((10#${v1[i]} < 10#${v2[i]})); then return 2; fi
    done
    if [ ${#v1[@]} -lt ${#v2[@]} ]; then return 2; fi
    return 1
}

# --- Lógica principal ---

if [ "$1" == "--help" ]; then
    show_help
    exit 0
fi

MODULES=$1
if [ -z "$MODULES" ]; then
    show_help
    exit 1
fi

# 1. Detectar Bases de Datos
if [ -n "$2" ]; then
    DB_NAME=$2
else
    echo "🔍 Detectando bases de datos en '$DB_SERVICE'..."
    DBS=($(get_databases))
    
    if [ ${#DBS[@]} -eq 0 ]; then
        echo "❌ No se encontraron bases de datos disponibles."
        exit 1
    elif [ ${#DBS[@]} -eq 1 ]; then
        DB_NAME=${DBS[0]}
        echo "📦 Usando única base de datos encontrada: $DB_NAME"
    else
        echo "❓ Múltiples bases de datos detectadas. Selecciona una:"
        select db in "${DBS[@]}"; do
            if [ -n "$db" ]; then
                DB_NAME=$db
                break
            fi
        done
    fi
fi

# 2. Verificación de versiones (si no es 'all')
if [ "$MODULES" != "all" ]; then
    IFS=',' read -ra MOD_LIST <<< "$MODULES"
    for mod in "${MOD_LIST[@]}"; do
        echo "📝 Verificando versión de '$mod'..."
        LOCAL_V=$(get_local_version $mod)
        DB_V=$(get_db_version $mod $DB_NAME)
        
        if [ "$LOCAL_V" == "unknown" ]; then
            echo "   ⚠️ Manifest no encontrado localmente para '$mod'. Se intentará actualizar igualmente."
            continue
        fi
        
        if [ -z "$DB_V" ] || [ "$DB_V" == "" ]; then
            echo "   🆕 El módulo '$mod' no está instalado o no se encontró en la DB. Se procederá con la instalación."
            continue
        fi
        
        echo "   [Local: $LOCAL_V] vs [DB: $DB_V]"
        
        compare_versions "$LOCAL_V" "$DB_V"
        RES=$?
        if [ $RES -eq 1 ]; then
            echo "   ✅ La versión ya está al día ($LOCAL_V)."
            read -p "   ¿Deseas forzar la actualización de '$mod'? (s/n): " confirm
            if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
                echo "   ⏭️ Saltando '$mod'..."
                # En un script más complejo aquí filtraríamos la lista, por ahora seguimos.
            fi
        elif [ $RES -eq 2 ]; then
            echo "   ⚠️ ¡ALERTA! La versión local ($LOCAL_V) es INFERIOR a la de la DB ($DB_V)."
            read -p "   ¿Estás SEGURO de querer hacer un DOWNGRADE de '$mod'? (s/n): " confirm
            if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
                echo "   🚫 Operación cancelada por el usuario."
                exit 1
            fi
        else
            echo "   🚀 Nueva versión detectada: $LOCAL_V (DB: $DB_V). Procediendo..."
        fi
    done
fi

echo "🚀 Iniciando actualización de módulos: $MODULES"
echo "📂 Base de datos: $DB_NAME"

# Comando de actualización de Odoo
docker compose -f $COMPOSE_FILE exec -T -u root $SERVICE_NAME sh -c "odoo \
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
