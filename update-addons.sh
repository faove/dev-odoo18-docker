#!/bin/bash

# Actualizar todos los submodules a la última versión
echo "Actualizando submodules OCA..."
git submodule update --remote --merge

# Mostrar estado
echo "Estado actual de submodules:"
git submodule status
