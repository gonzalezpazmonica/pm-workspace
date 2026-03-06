# Guía: Auditoría de Soberanía Cognitiva

> Escenario: tu empresa usa IA en la gestión de proyectos y quiere asegurar que no está creando una dependencia estratégica con el proveedor. Esta guía explica cómo usar `/sovereignty-audit` para diagnosticar, medir y reducir el riesgo de lock-in cognitivo.

---

## ¿Qué es el lock-in cognitivo?

El lock-in ha evolucionado: en los 90 era técnico (formatos propietarios), en los 2000 contractual (licencias), en los 2010 de procesos (workflows acoplados). En 2026 es **cognitivo** — cuando la IA aprende los patrones de decisión, las relaciones internas y el flujo de conocimiento de tu organización, cambiar de proveedor deja de ser un problema técnico y se convierte en un problema estratégico.

Referencia: "La Trampa Cognitiva" (Álvaro de Nicolás, 2026).

---

## ¿Quién debería usar `/sovereignty-audit`?

| Rol | Para qué | Frecuencia |
|---|---|---|
| **CTO / CIO** | Informe para comité de dirección | Trimestral |
| **Project Manager** | Verificar que los proyectos no crean dependencias | Al incorporar proveedor nuevo |
| **Responsable de Compliance** | Alinear con EU AI Act y AEPD | Semestral |
| **Arquitecto** | Verificar portabilidad de la arquitectura | Antes de decisiones de stack |

---

## Paso 1: Tu primer scan

```
/sovereignty-audit scan
```

Savia analiza tu workspace y calcula un **Sovereignty Score (0-100)** con 5 dimensiones:

1. **Portabilidad de datos** (25%) — ¿tus datos están en Git/markdown o atrapados en APIs?
2. **Independencia LLM** (25%) — ¿puedes operar sin Claude? ¿tienes Emergency Mode?
3. **Protección del grafo** (20%) — ¿los datos sensibles están cifrados y locales?
4. **Gobernanza del consumo** (15%) — ¿controlas y mides el uso de IA?
5. **Opcionalidad de salida** (15%) — ¿puedes migrar a otro proveedor en <72h?

El resultado se guarda en `output/sovereignty-scan-YYYYMMDD.md`.

---

## Paso 2: Interpretar el score

| Rango | Nivel | Qué hacer |
|---|---|---|
| 90-100 | Soberanía plena | Mantener. Revisar cada 6 meses. |
| 70-89 | Soberanía alta | Bien posicionado. Mejorar dimensiones débiles. |
| 50-69 | Riesgo medio | Acción necesaria. Ejecutar `/sovereignty-audit recommend`. |
| 30-49 | Riesgo alto | Plan de mitigación urgente. Escalar a dirección. |
| 0-29 | Lock-in crítico | Riesgo estratégico. Preparar exit plan inmediato. |

---

## Paso 3: Pedir recomendaciones

```
/sovereignty-audit recommend
```

Savia identifica las dimensiones con score < 70 y te da acciones concretas, ordenadas por impacto/esfuerzo. Ejemplo:

```
🔴 D2 Independencia LLM: 35/100
   → Acción: Configura Emergency Mode para operar offline
   → Comando: /emergency-mode setup
   → Esfuerzo: 15 minutos
   → Impacto: +35 puntos en D2

🟡 D4 Gobernanza del consumo: 58/100
   → Acción: Crea una política de gobernanza de IA
   → Comando: /governance-policy create
   → Esfuerzo: 30 minutos
   → Impacto: +20 puntos en D4
```

---

## Paso 4: Generar informe para dirección

```
/sovereignty-audit report
```

Genera un informe ejecutivo con: score global, tendencia (si hay scans anteriores), desglose por dimensión, riesgos priorizados y recomendaciones top-3. Formato pensado para presentar en comité de dirección o incluir en informes de compliance.

---

## Paso 5: Preparar un exit plan

```
/sovereignty-audit exit-plan
```

Genera un plan de salida documentado: inventario de datos, dependencias del proveedor, estimación de esfuerzo de migración, timeline y alternativas. No ejecuta ninguna migración — solo documenta cómo se haría.

Útil para: renovaciones de contrato con proveedores, auditorías de compliance, due diligence.

---

## Cuándo ejecutar cada subcomando

| Situación | Subcomando |
|---|---|
| Revisión trimestral de IT | `scan` + `report` |
| Antes de firmar contrato con proveedor IA | `scan` + `exit-plan` |
| Después de implementar mejoras | `scan` (comparar con anterior) |
| Alguien pregunta "¿y si mañana desaparece Claude?" | `exit-plan` |
| Score < 70 en alguna dimensión | `recommend` |
| Auditoría de compliance EU AI Act | `report` + `exit-plan` |

---

## Relación con otros comandos

`/sovereignty-audit` se complementa con el sistema de gobernanza existente:

| Comando | Qué audita | Enfoque |
|---|---|---|
| `/governance-audit` | Cumplimiento normativo (NIST, EU AI Act) | ¿Cumples la ley? |
| `/aepd-compliance` | Protección de datos (AEPD, RGPD) | ¿Proteges los datos? |
| `/sovereignty-audit` | Independencia del proveedor | ¿Eres libre de cambiar? |

Los tres se complementan: **cumplir la ley no es lo mismo que ser independiente**.

---

## Ejemplo real: consultora con Azure DevOps + Claude

Una consultora de 15 personas, 3 proyectos activos, usando pm-workspace desde hace 4 meses:

```
/sovereignty-audit scan

Sovereignty Score: 78/100 — Soberanía alta

D1 Portabilidad     82  ████████████████░░░░  SaviaHub + BacklogGit activos
D2 Independencia    72  ██████████████░░░░░░  Emergency Mode configurado
D3 Grafo org.       85  █████████████████░░░  Cifrado activo, PII gate ON
D4 Gobernanza       58  ████████████░░░░░░░░  Sin governance policy formal
D5 Salida           80  ████████████████░░░░  Docs completos, backups OK

⚠️ D4 bajo 70 → /governance-policy create
```

La consultora tiene un score alto porque pm-workspace guarda todo en Git por diseño. El punto débil es la gobernanza formal (no tienen política documentada). Con `/sovereignty-audit recommend`, obtienen la acción concreta para subir 20 puntos.

---

## Por qué pm-workspace protege contra el lock-in

pm-workspace está diseñado desde su fundación para evitar la trampa cognitiva:

- **Todo es texto en Git** — markdown, YAML, JSON. Sin bases de datos propietarias.
- **SaviaHub** guarda el conocimiento organizacional en ficheros locales.
- **Emergency Mode** permite operar con LLMs locales (Ollama) sin internet.
- **Agent Memory** (MEMORY.md) es portable — no depende de APIs de ningún proveedor.
- **BacklogGit** versiona backlogs en markdown, no en APIs de Jira/Azure.

La pregunta de Álvaro de Nicolás — "¿Quién posee la inteligencia?" — tiene una respuesta clara con pm-workspace: **tú**.
