---
name: gdrive-upload
description: >
  Subir informes y documentos generados a Google Drive. Organiza
  automáticamente en la carpeta del proyecto y comparte el link.
---

# Upload a Google Drive

**Argumentos:** $ARGUMENTS

> Uso: `/gdrive-upload {fichero} --project {p}` o `/gdrive-upload --project {p} --latest {tipo}`

## Parámetros

- `{fichero}` — Ruta al fichero a subir (relativa a `output/` o absoluta)
- `--project {nombre}` — Proyecto de PM-Workspace
- `--folder {id}` — ID de carpeta destino (defecto: `GDRIVE_REPORTS_FOLDER` del proyecto)
- `--latest {tipo}` — Subir el informe más reciente de un tipo:
  - `sprint-report` → último `output/sprints/YYYYMMDD-sprint-report-{p}.*`
  - `executive` → último `output/reports/YYYYMMDD-executive-{p}.*`
  - `hours` → último `output/reports/YYYYMMDD-hours-{p}.*`
  - `capacity` → último `output/reports/YYYYMMDD-capacity-{p}.*`
- `--share {email}` — Compartir con un email después de subir (viewer)
- `--notify` — Enviar notificación por email al compartir

## Contexto requerido

1. `.claude/rules/connectors-config.md` — Verificar Google Drive habilitado
2. `projects/{proyecto}/CLAUDE.md` — `GDRIVE_REPORTS_FOLDER`

## Pasos de ejecución

1. **Verificar conector** — Comprobar Google Drive disponible
   - Si no activado → mostrar instrucciones de activación

2. **Resolver fichero**:
   - Si `{fichero}` explícito → verificar que existe
   - Si `--latest {tipo}` → buscar en `output/` el más reciente por patrón
   - Si no se encuentra → informar al usuario

3. **Resolver carpeta destino**:
   - Si `--folder` → usar ese ID
   - Si `--project` → buscar `GDRIVE_REPORTS_FOLDER` en CLAUDE.md del proyecto
   - Si ninguno → usar `GDRIVE_REPORTS_FOLDER` global de connectors-config
   - Si ninguno configurado → pedir al usuario

4. **Organizar en subcarpeta**:
   - Estructura en Drive: `{proyecto}/sprints/`, `{proyecto}/reports/`
   - Crear subcarpeta si no existe (basada en el tipo de informe)

5. **Confirmar upload**:
   ```
   📤 Subir a Google Drive:
   Fichero: {nombre} ({tamaño})
   Destino: {carpeta}/{subcarpeta}/
   ¿Confirmar? (y/n)
   ```

6. **Subir fichero** usando el conector MCP de Google Drive

7. Si `--share` → compartir el fichero con el email indicado

8. **Confirmar**:
   ```
   ✅ Fichero subido a Google Drive
   📎 Link: https://drive.google.com/file/d/{id}
   ```

## Integración con otros comandos

- `/report-hours --upload-gdrive` → sube automáticamente tras generar
- `/report-executive --upload-gdrive` → sube informe ejecutivo
- `/report-capacity --upload-gdrive` → sube informe de capacidad
- `/sprint-review --upload-gdrive` → sube resumen del sprint

## Restricciones

- **SIEMPRE confirmar antes de subir** (el fichero puede contener datos sensibles)
- No eliminar ficheros existentes en Drive
- No modificar permisos de carpetas — solo del fichero subido
- Si la carpeta no existe → informar, no crear carpeta raíz
- Máximo 5 ficheros por ejecución
- No subir ficheros > 100MB
- No subir secrets, `.env` ni credenciales
