# SaviaVaults — Guía de Backups + Nextcloud

## Backups locales

SaviaVaults guarda backups en `~/.savia-vaults/backups/`. Cada backup es un archivo tar.gz con timestamp.

### Crear

```bash
savia-vaults backup create --path vaults/mi-vault
```

### Listar

```bash
savia-vaults backup list
# verify-test-2026-08-01T09-44-28-995Z  10.5 KB  2026-08-01T09:44:28.998Z
```

### Restaurar

```bash
savia-vaults backup restore verify-test-2026-08-01T09-44-28-995Z --target ./restored
```

## Nextcloud

### Opción A: Desktop client (recomendado)

Si usas el cliente de escritorio de Nextcloud, configura la variable de entorno para que apunte a la carpeta sincronizada:

```bash
export SAVIA_BACKUP_NEXTCLOUD_DIR="$HOME/Nextcloud/SaviaVaults"
```

Cada backup se copia automáticamente a esta carpeta al crearse. El cliente de Nextcloud lo sincroniza con el servidor.

### Opción B: WebDAV directo

Si no tienes el cliente de escritorio, SaviaVaults puede subir backups directamente via WebDAV:

```bash
export NEXTCLOUD_URL="https://tu-servidor.nextcloud.com"
export NEXTCLOUD_USER="tu-usuario"
export NEXTCLOUD_PASS="tu-contraseña"

savia-vaults backup create --path vaults/mi-vault
```

El backup se sube a `remote.php/dav/files/{usuario}/SaviaVaults/` en tu Nextcloud.

### Configuración permanente

Añade las variables a tu `~/.bashrc` o `.env`:

```bash
# ~/.savia-vaults/backup.env
SAVIA_BACKUP_NEXTCLOUD_DIR="$HOME/Nextcloud/SaviaVaults"
```

Y carga antes de usar:

```bash
source ~/.savia-vaults/backup.env
savia-vaults backup create
```

### Verificar estado

```bash
savia-vaults backup status
# Backups: 3 in /home/user/.savia-vaults/backups
# Nextcloud: configured
```

## Restauración desde Nextcloud

Si pierdes los backups locales, descarga el archivo .tar.gz desde Nextcloud (via web o desktop client) y restaura:

```bash
savia-vaults backup restore <archivo-descargado> --target ./restored
```

O extrae manualmente:

```bash
tar -xzf backup.tar.gz -C ./restored
```
