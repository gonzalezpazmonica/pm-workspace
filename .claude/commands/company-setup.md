---
name: company-setup
description: Onboarding conversacional de empresa — genera el perfil organizacional completo
developer_type: all
agent: task
context_cost: medium
---

# /company-setup

> 🦉 Savia conoce tu empresa para contextualizar cada recomendación.

---

## Cargar perfil de usuario

Grupo: **Infrastructure** — cargar:

- `identity.md` — nombre, rol (debe ser CEO, CTO o admin)

---

## Subcomandos

- `/company-setup` — onboarding completo guiado
- `/company-setup --quick` — solo identity + vertical (mínimo viable)
- `/company-setup --import {file}` — importar desde documento existente

---

## Flujo

### Paso 1 — Verificar permisos

Solo CEO, CTO o usuarios con rol admin pueden ejecutar el setup inicial.
Si no hay company profile, cualquier usuario puede iniciarlo.

### Paso 2 — Recopilar información conversacional

```
🦉 ¡Hola! Voy a conocer tu empresa para ayudarte mejor.

  Bloque 1 — Identidad:
  ├─ Nombre de la empresa
  ├─ Año de fundación
  ├─ Sector principal
  ├─ Tamaño (empleados)
  ├─ Misión / propósito
  └─ Valores corporativos

  Bloque 2 — Estructura:
  ├─ Áreas / departamentos principales
  ├─ Equipos de desarrollo (nombres, tamaños)
  └─ Líneas de reporte principales

  Bloque 3 — Estrategia:
  ├─ OKRs o prioridades del año
  ├─ Budget por área (opcional)
  └─ Iniciativas estratégicas activas

  Bloque 4 — Políticas:
  ├─ Política de uso de IA (si existe)
  ├─ Requisitos de compliance
  └─ Nivel de seguridad requerido

  Bloque 5 — Tecnología:
  ├─ Stack tecnológico principal
  ├─ Cloud provider(s)
  ├─ Herramientas de gestión (Azure DevOps, Jira, etc.)
  └─ Restricciones tecnológicas

  Bloque 6 — Vertical:
  ├─ Industria/sector específico
  ├─ Regulaciones aplicables
  └─ Certificaciones actuales
```

### Paso 3 — Generar ficheros del company profile

Crear directorio `.claude/profiles/company/` con 6 ficheros:

```
.claude/profiles/company/
├── identity.md      # nombre, sector, tamaño, misión, valores
├── structure.md     # organigrama, equipos, reporting lines
├── strategy.md      # OKRs, prioridades, budget, iniciativas
├── policies.md      # política IA, compliance, seguridad
├── technology.md    # stack, cloud, herramientas, restricciones
└── vertical.md      # industria, regulaciones, certificaciones
```

### Paso 4 — Confirmar y validar

Mostrar resumen consolidado y pedir confirmación.

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: company_setup
files_created: 6
company_name: "{nombre}"
sector: "{sector}"
size: "{tamaño}"
vertical_detected: "{vertical}"
```

---

## Restricciones

- **NUNCA** almacenar datos financieros concretos (cuentas, facturación)
- **NUNCA** guardar información personal de empleados individuales
- **NUNCA** incluir contraseñas, tokens o credenciales
- Los ficheros son editables por CEO/CTO/admin únicamente
- Cada fichero debe ser ≤100 líneas para minimizar carga de contexto
