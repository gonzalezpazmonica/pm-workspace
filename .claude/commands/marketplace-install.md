---
name: Instalar del Marketplace Interno
description: Instala skills/playbooks del marketplace con resolución de dependencias, preview, rollback y verificación de compatibilidad
developer_type: all
agent: task
context_cost: high
---

# /marketplace-install — Instalar del Marketplace Interno

Instala skills y playbooks del marketplace interno. Savia valida compatibilidad, resuelve dependencias e incluye rollback automático si algo falla.

## Sintaxis

```
/marketplace-install {skill|playbook} [--version latest|X.Y.Z] [--preview] [--lang es|en]
```

## Parámetros

- **skill|playbook**: Nombre del recurso en el marketplace
- **--version**: Versión a instalar (default: latest)
- **--preview**: Mostrar cambios sin instalar (dry-run)
- **--lang**: Idioma de la salida (es|en, default: es)

## Flujo de Instalación

```
Búsqueda en marketplace → Verificación compatibilidad 
→ Resolución de dependencias → (Opcional) Preview 
→ Descarga e instalación → Notificación de éxito
```

## Compatibilidad

Savia verifica:
- Versión de pm-workspace ≥ requerida
- Dependencias satisfechas
- Conflictos con recursos existentes
- Capacidad de almacenamiento

## Resolución de Dependencias

Si un skill requiere otros:
```yaml
email-notify-skill v1.0 requiere:
  - email-provider-skill >= 2.0
  - logging-skill >= 1.5
```

Savia detecta versiones, verifica compatibilidad, instala faltantes e iguala conflictos.

## Preview Mode

Con `--preview`:
- Muestra cambios a realizar
- Estima tiempo y espacio
- No modifica nada
- Pide confirmación antes de proceder

## Rollback Automático

Si falla la instalación:
1. Detención inmediata
2. Restauración a estado anterior
3. Log del error en `output/marketplace-install-error.log`
4. Sugerencia de reportar si es conocido

## Actualización Automática

Savia notifica nuevas versiones:
```
"email-notify-skill: v1.1.0 disponible"
/marketplace-install email-notify-skill --version 1.1.0
```

## Casos de Uso

**Instalar skill**
```
/marketplace-install report-sprint-skill --lang es
```

**Versión específica**
```
/marketplace-install email-notify-skill --version 1.0.0
```

**Previsualizar**
```
/marketplace-install playbook-release --preview
```

## Salida Esperada

```
✓ Completado: report-sprint-skill v1.2.1

Recurso:    report-sprint-skill
Versión:    1.2.1
Ubicación:  tenants/marketing/.marketplace/skills/
Deps:       ✓ logging-skill v1.5 | ✓ graph-api-skill v2.0

Nuevos comandos:
  /report-sprint --metrics {metrics} --format {format}

Próximos pasos:
1. /help report-sprint para documentación
2. /report-sprint --metrics velocity burndown
3. Para desinstalar: /marketplace-uninstall report-sprint-skill
```

## Auditoría

Registra: quién, cuándo, qué, dependencias, cambios, rolbacks.

## Integración

Consume /marketplace-publish, complementa /tenant-share, cierre de loop: compartir → publicar → descubrir → instalar.

---
**Era 12: Team Excellence & Enterprise** | Comando 249/249 (FINAL)
