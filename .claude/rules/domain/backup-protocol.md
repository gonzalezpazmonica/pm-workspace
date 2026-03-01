---
name: backup-protocol
description: Protocolo de backup cifrado para datos locales de pm-workspace
auto_load: false
paths: []
---

# Protocolo de Backup — Cifrado y Nube

> 🦉 Savia protege tus datos con cifrado AES-256 antes de subirlos a la nube.

---

## Principio fundamental

Los datos del usuario se cifran localmente ANTES de salir de la máquina. La passphrase NUNCA se transmite ni almacena en claro — solo se guarda un hash SHA-256 para verificación.

---

## Qué incluir en el backup

Fichero | Descripción | Prioridad
---|---|---
`.claude/profiles/users/{activo}/` | Perfil del usuario (6 fragmentos) | Alta
`.claude/profiles/active-user.md` | Perfil activo | Alta
`CLAUDE.local.md` | Config privada y proyectos | Alta
`decision-log.md` | Decisiones del equipo | Media
`.claude/rules/pm-config.local.md` | Config local de reglas | Media
`$HOME/.azure/devops-pat` | PAT de Azure DevOps | Alta (opcional)
`$HOME/.pm-workspace/update-config` | Config de actualización | Baja

---

## Qué excluir del backup

- `projects/` — Código fuente (ya versionado en git)
- `output/` — Informes generados (regenerables)
- `.claude/commands/` — Vienen del repositorio
- `.claude/rules/` — Vienen del repositorio
- `.claude/agents/` — Vienen del repositorio
- `.claude/skills/` — Vienen del repositorio
- `node_modules/`, `.venv/` — Dependencias regenerables

---

## Algoritmo de cifrado

1. **Recopilación**: tar.gz de todos los ficheros a respaldar
2. **Manifest**: SHA-256 de cada fichero incluido
3. **Cifrado**: AES-256-CBC con salt
4. **Derivación de clave**: PBKDF2 con 100.000 iteraciones
5. **Passphrase**: proporcionada por el usuario, NUNCA almacenada

```bash
# Cifrar
tar czf - data/ | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
  -pass "pass:$PASSPHRASE" -out backup.enc

# Descifrar
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -pass "pass:$PASSPHRASE" -in backup.enc | tar xzf -
```

---

## Estrategia de rotación

- Máximo **7 backups** locales
- Al crear el 8.°, se elimina el más antiguo
- Nombrado: `pm-backup-YYYYMMDD-HHMMSS.enc`
- Backups en `$HOME/.pm-workspace/backups/`

---

## Proveedores de nube

### NextCloud Files (WebDAV)

- Endpoint: `{URL}/remote.php/dav/files/{USER}/pm-workspace-backups/`
- Autenticación: usuario + contraseña
- Método: `curl -T` (upload) / `curl -o` (download)
- Directorio remoto: `pm-workspace-backups/`

### Google Drive (MCP)

- Usa el MCP connector de Google Drive
- Fichero cifrado se sube como binario
- Carpeta: `pm-workspace-backups/`

---

## Flujo de restauración

1. Descargar backup cifrado (de nube o local)
2. Solicitar passphrase al usuario
3. Descifrar con openssl
4. Verificar MANIFEST.sha256
5. Mostrar ficheros restaurados
6. Confirmar antes de copiar a ubicaciones originales
7. **NUNCA** sobrescribir sin confirmación

---

## Sugerencia de backup en session-init

Si `auto_backup=true` y han pasado más de 24h desde el último backup:

```
💾 Hace más de 24h de tu último backup. Ejecuta /backup now para proteger tus datos.
```
