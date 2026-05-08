---
name: backup
description: Backup cifrado de perfiles, configuraciones y datos locales a NextCloud o Google Drive
developer_type: all
agent: none
context_cost: low
---

# /backup {subcommand}

> 🦉 Savia protege tus datos — cifra y respalda perfiles, configs y PATs en la nube.

---

## Cargar perfil de usuario

Grupo: **Memory & Context** — cargar `identity.md` + `preferences.md` del perfil activo.
Ver `.claude/profiles/context-map.md`.

## Prerequisitos

- `openssl` instalado (para cifrado AES-256-CBC)
- Para NextCloud: URL del servidor y credenciales
- Para Google Drive: MCP connector configurado
- Leer `@docs/rules/domain/backup-protocol.md` para protocolo completo

## Subcomandos

### `/backup now`

Backup inmediato cifrado:

1. Mostrar banner: `🦉 Backup · Ahora`
2. Verificar prerequisitos (`openssl`) — mostrar ✅/❌
3. Recopilar ficheros a respaldar (ver protocolo)
4. Solicitar passphrase si es la primera vez
5. `bash scripts/backup.sh now`
6. Mostrar: ficheros respaldados, tamaño, destino
7. Banner fin: `✅ Backup completado`

### `/backup restore`

Restaurar desde el último backup:

1. Mostrar banner: `🦉 Backup · Restaurar`
2. Solicitar passphrase
3. `bash scripts/backup.sh restore`
4. Verificar integridad SHA256
5. Mostrar ficheros restaurados
6. **NUNCA** sobrescribir sin confirmación

### `/backup auto-on`

Activar recordatorio de backup:

1. `bash scripts/backup.sh auto-on`
2. Savia recordará hacer backup al inicio de sesión si hace más de 24h

### `/backup auto-off`

Desactivar recordatorio:

1. `bash scripts/backup.sh auto-off`

### `/backup status`

Ver estado del sistema de backup:

1. Mostrar banner: `🦉 Backup · Status`
2. `bash scripts/backup.sh status`
3. Mostrar: auto-backup, último backup, cloud config, backups locales

## Qué se respalda

- Perfiles de usuario (`.claude/profiles/users/{activo}/`)
- `active-user.md` (perfil activo)
- `CLAUDE.local.md` (config privada)
- `decision-log.md` (decisiones)
- `pm-config.local.md` (config local)
- `$HOME/.azure/devops-pat` (PAT, opcional)
- `$HOME/.pm-workspace/update-config`

## Qué NO se respalda

- `projects/` — código fuente (ya en git)
- `output/` — informes (regenerables)
- `.opencode/commands/`, `docs/rules/` — vienen del repo

## Voz de Savia

- Humano: "Tus datos están seguros. Backup cifrado con AES-256 y subido a NextCloud. 🦉"
- Agente (YAML):
  ```yaml
  status: ok
  action: backup_now
  file: "pm-backup-20260301-143000.enc"
  size: "2.4K"
  cloud: "nextcloud"
  ```

## Restricciones

- **NUNCA** transmitir passphrase a ningún servicio externo
- **NUNCA** subir sin cifrar — siempre AES-256-CBC con PBKDF2
- **NUNCA** restaurar sin verificar SHA256
- **SIEMPRE** confirmar antes de sobrescribir datos existentes
- Rotación máxima: 7 backups (el más antiguo se elimina)
