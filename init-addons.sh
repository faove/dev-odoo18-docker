#!/bin/bash

echo "Inicializando estructura de directorios para Odoo..."

# Crear directorios principales
mkdir -p addons oca-addons enterprise-addons

# Crear archivos __init__.py
for dir in addons oca-addons enterprise-addons; do
    touch "$dir/__init__.py"
    touch "$dir/.gitkeep"
    echo "✓ Directorio $dir inicializado"
done

# Crear estructura básica de módulos personalizados
mkdir -p addons/custom_module
cat > addons/custom_module/__init__.py << EOF
# Custom Module
EOF

cat > addons/custom_module/__manifest__.py << EOF
{
    'name': 'Custom Module',
    'version': '18.0.1.0.0',
    'category': 'Extra Tools',
    'summary': 'Módulo personalizado base',
    'depends': ['base'],
    'data': [],
    'demo': [],
    'installable': True,
    'application': False,
    'auto_install': False,
}
EOF

echo "✓ Estructura de módulo personalizado creada"
echo "✅ Estructura de addons inicializada correctamente"
