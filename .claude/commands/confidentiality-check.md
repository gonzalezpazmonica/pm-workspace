# /confidentiality-check — Verificar cumplimiento de niveles de confidencialidad

> Escanea ficheros del proyecto activo y detecta violaciones de niveles.
> Regla: @.claude/rules/domain/context-placement-confirmation.md

---

## Parametros

- `$ARGUMENTS` — Nombre del proyecto (default: proyecto activo)

## Razonamiento

1. Leer la regla de niveles de confidencialidad
2. Identificar el proyecto y sus repos asociados (N4-SHARED, N4-VASS, N4b-PM)
3. Escanear ficheros buscando violaciones
4. Generar informe con hallazgos y acciones correctivas

## Flujo

1. Cargar `projects/{proyecto}/CONFIDENTIALITY.md` (si existe)
2. Cargar `@.claude/rules/domain/context-placement-confirmation.md`
3. Para cada fichero en `projects/{proyecto}/`:
   - Detectar PII (nombres reales sin @handle, emails, telefonos)
   - Detectar datos de nivel superior al permitido en ese repo
   - Detectar datos de empresa en repo publico (N1)
   - Detectar datos personales de equipo fuera de N4b
   - Detectar secretos o credenciales fuera de config.local/
4. Guardar informe en `output/audits/YYYYMMDD-confidentiality-{proyecto}.md`
5. Mostrar resumen en chat (max 15 lineas)

## Verificaciones por nivel

- **N1 (publico)**: sin PII, sin nombres empresa, sin handles reales, sin URLs de org
- **N2 (empresa)**: sin datos de proyecto concreto, sin datos personales
- **N3 (usuario)**: sin datos de proyecto, sin datos de empresa
- **N4 (proyecto)**: sin datos personales de equipo (van a N4b)
- **N4b (equipo)**: solo PM puede acceder, verificar que no hay refs desde N4

## Banner de finalizacion

```
✅ /confidentiality-check — Completado
📄 Informe: output/audits/YYYYMMDD-confidentiality-{proyecto}.md
🔒 Violaciones: X criticas | Y warnings | Z info
⚡ /compact
```
