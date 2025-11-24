# Odoo 18 + PostgreSQL 15 en Docker

Este proyecto levanta una instancia de **Odoo 18** conectada a una base de datos **PostgreSQL 15** usando Docker y Docker Compose.

---

## 🚀 Cómo iniciar

1. Cloná el repositorio:
```bash
git clone https://github.com/faove/odoo18-docker.git
cd odoo18-docker
```

2. Iniciar los contenedores:
```bash
docker-compose -f docker-compose-prod.yml up -d
```

3. Verificar que los contenedores estén corriendo:
```bash
docker-compose ps
```

4. Ver los logs de Odoo:
```bash
docker logs elantar_odoo --tail 20
```

---

## 🔄 Restaurar Base de Datos de Odoo

En caso de que necesites restaurar la base de datos desde un backup, sigue estos pasos:

### Método Automático (Recomendado)

1. Navegar al directorio del proyecto:
```bash
cd /var/www/html/odoo18-docker
```

2. Actualizar el código (si es necesario):
```bash
git pull
```

3. Verificar los backups disponibles:
```bash
ls -lh /opt/odoo-backup/backupszip/ | tail -10
```

4. Verificar el contenido de un backup (opcional):
```bash
cd /opt/odoo-backup/backupszip && unzip -l elantar_odoo_20251123_023001.zip | head -20
```

5. Ejecutar el script de restauración:
```bash
./restore_backup.sh /opt/odoo-backup/backupszip/elantar_odoo_20251123_023001.zip
```

El script realizará automáticamente:
- Detener el contenedor de Odoo
- Extraer el backup
- Eliminar la base de datos existente (si existe)
- Crear una nueva base de datos
- Restaurar el dump de PostgreSQL
- Restaurar el filestore
- Reiniciar el contenedor de Odoo

6. Verificar que la restauración fue exitosa:
```bash
docker logs elantar_odoo --tail 50
```

### Método Manual (Si el script falla)

Si el script automático falla, puedes seguir estos pasos manualmente:

1. Detener el contenedor de Odoo:
```bash
docker stop elantar_odoo
```

2. Extraer el backup en un directorio temporal:
```bash
cd /tmp
mkdir odoo_restore_$(date +%Y%m%d_%H%M%S)
cd odoo_restore_*
unzip /opt/odoo-backup/backupszip/elantar_odoo_20251123_023001.zip
```

3. Eliminar la base de datos existente:
```bash
docker exec -i odoo_db psql -U odoo -d postgres -c "DROP DATABASE IF EXISTS elantar_odoo;"
```

4. Crear una nueva base de datos:
```bash
docker exec -i odoo_db psql -U odoo -d postgres -c "CREATE DATABASE elantar_odoo OWNER odoo;"
```

5. Restaurar el dump de PostgreSQL:
```bash
docker exec -i odoo_db pg_restore -U odoo -d elantar_odoo --no-owner --no-acl < elantar_odoo.dump
```

6. Iniciar el contenedor de Odoo para crear el directorio filestore:
```bash
docker start elantar_odoo
```

7. Crear el directorio filestore (si no existe):
```bash
docker exec elantar_odoo mkdir -p /var/lib/odoo/filestore
```

8. Restaurar el filestore:
```bash
docker cp /tmp/odoo_restore_*/filestore/elantar_odoo/. elantar_odoo:/var/lib/odoo/filestore/elantar_odoo/
```

9. Reiniciar el contenedor de Odoo:
```bash
docker restart elantar_odoo
```

10. Verificar los logs:
```bash
docker logs elantar_odoo --tail 50
```

### Verificar Estructura del Contenedor (Troubleshooting)

Si necesitas verificar la estructura de directorios dentro del contenedor:
```bash
docker exec elantar_odoo ls -la /var/lib/odoo/ | head -10
```

---

## 📋 Comandos Útiles

### Ver estado de los contenedores
```bash
docker-compose ps
# o
docker ps
```

### Ver logs de Odoo
```bash
docker logs elantar_odoo --tail 20
```

### Ver logs de la base de datos
```bash
docker logs odoo_db --tail 20
```

### Reiniciar contenedores
```bash
docker-compose -f docker-compose-prod.yml restart
```

### Detener contenedores
```bash
docker-compose -f docker-compose-prod.yml down
```

### Iniciar contenedores
```bash
docker-compose -f docker-compose-prod.yml up -d
```

### Acceder a la base de datos PostgreSQL
```bash
docker exec -it odoo_db psql -U odoo -d elantar_odoo
```

### Listar bases de datos
```bash
docker exec -it odoo_db psql -U odoo -d postgres -c "\l"
```

---

## 🔧 Configuración

### Variables de Entorno

El archivo `docker-compose-prod.yml` contiene las siguientes configuraciones:

- **HOST**: Nombre del contenedor de la base de datos (`db`)
- **USER**: Usuario de PostgreSQL (`odoo`)
- **PASSWORD**: Contraseña de PostgreSQL (`qwerty76%&/`)
- **PROXY_MODE**: Modo proxy activado (`True`)
- **WEB_BASE_URL**: URL base de la aplicación (`https://erpelantar.com`)

### Volúmenes

- `odoo18-docker_odoo_data`: Datos de Odoo (incluyendo filestore)
- `odoo18-docker_db_data`: Datos de PostgreSQL

### Redes

- `elantar_net`: Red externa para comunicación entre contenedores

---

## ⚠️ Notas Importantes

1. **Backups**: Los backups se almacenan en `/opt/odoo-backup/backupszip/`
2. **Base de datos**: El nombre de la base de datos es `elantar_odoo`
3. **Contenedores**: 
   - `elantar_odoo`: Contenedor de Odoo
   - `odoo_db`: Contenedor de PostgreSQL
4. **Puerto**: Odoo corre en el puerto 8069 (no expuesto directamente, solo a través de Traefik)
5. **Filestore**: Los archivos adjuntos se almacenan en `/var/lib/odoo/filestore/elantar_odoo/` dentro del contenedor

---

## 🐛 Troubleshooting

### Error: "password authentication failed"
Si obtienes un error de autenticación, verifica y actualiza la contraseña:
```bash
docker exec -it odoo_db psql -U odoo -d postgres -c "ALTER USER odoo PASSWORD 'qwerty76%&/';"
```

### Error: "relation does not exist"
Esto indica que la base de datos no tiene el esquema de Odoo. Restaura desde un backup o inicializa la base de datos.

### Error: "filestore directory not found"
Asegúrate de crear el directorio antes de copiar:
```bash
docker exec elantar_odoo mkdir -p /var/lib/odoo/filestore
```

### Contenedor no inicia
Verifica los logs para identificar el problema:
```bash
docker logs elantar_odoo --tail 50
docker logs odoo_db --tail 50
```

---

## 📝 Historial de Restauraciones

Cuando se restaure una base de datos, documenta:
- Fecha y hora de la restauración
- Backup utilizado
- Motivo de la restauración
- Resultado (éxito/fallo)

---

## 🔗 Enlaces Útiles

- [Documentación de Odoo](https://www.odoo.com/documentation/18.0/)
- [Documentación de Docker Compose](https://docs.docker.com/compose/)
- [Documentación de PostgreSQL](https://www.postgresql.org/docs/)
