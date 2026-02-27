---
name: executive-reporting
description: Generación de informes ejecutivos multi-proyecto para dirección
context: fork
agent: tech-writer
context_cost: medium
---

# Skill: executive-reporting

> Generación de informes ejecutivos multi-proyecto para dirección: PowerPoint y Word con formato corporativo.

**Prerequisito:** Leer `.claude/skills/azure-devops-queries/SKILL.md` y `.claude/skills/sprint-management/SKILL.md`

## Constantes de esta skill

```bash
OUTPUT_DIR="./output/executive"
CORPORATE_COLOR_PRIMARY="#0078D4"     # Azul corporativo
CORPORATE_COLOR_SECONDARY="#F3F3F3"   # Gris claro
CORPORATE_FONT="Calibri"              # Fuente corporativa

# Umbrales de semáforo
VELOCITY_GREEN_THRESHOLD=0.90         # ≥ 90% → verde
VELOCITY_YELLOW_THRESHOLD=0.70        # 70-89% → amarillo; < 70% → rojo
BLOCKED_ITEMS_RED_THRESHOLD=2         # ≥ 2 bloqueos → rojo
```

---

## Flujo 1 — Recopilar Datos Multi-Proyecto

Para cada proyecto activo:
1. Leer configuración del proyecto
2. Obtener sprint actual (az boards iteration)
3. Obtener work items con WIQL (azure-devops-queries)
4. Guardar en `/tmp/{proyecto}-items.json`

---

## Flujo 2 — Calcular Semáforo de Estado

> Detalle: @references/traffic-light-logic.md

Entradas: SP completados, SP planificados, días restantes, velocity media, bloqueos activos

Lógica:
- 🔴 Rojo: bloqueos ≥ 2 O ratio_velocity < 0.70
- 🟡 Amarillo: bloqueos ≥ 1 O ratio_velocity < 0.90 O riesgo_tiempo > 0.6
- 🟢 Verde: en buen camino

---

## Flujo 3 — Generar PowerPoint Ejecutivo

```bash
node scripts/report-generator.js \
  --type executive --format pptx \
  --proyectos "proyecto-alpha,proyecto-beta" \
  --output "$OUTPUT_DIR/$(date +%Y%m%d)-executive-report.pptx"
```

> Detalle: @references/pptx-structure.md

Diapositivas: Portada | Resumen | Por proyecto | KPIs | Hitos | Decisiones | Próximos pasos

---

## Flujo 4 — Generar Word Ejecutivo

```bash
node scripts/report-generator.js \
  --type executive --format docx \
  --proyectos "proyecto-alpha,proyecto-beta" \
  --output "$OUTPUT_DIR/$(date +%Y%m%d)-executive-report.docx"
```

Estructura: Resumen | Por proyecto | Consolidadas | Plan próxima semana

---

## Flujo 5 — Enviar por Email (Graph API)

```bash
TOKEN=$(obtener_graph_token)
ATTACHMENT=$(base64 < "$OUTPUT_DIR/$FILENAME")
curl -s -X POST "https://graph.microsoft.com/v1.0/users/$REMITENTE_EMAIL/sendMail" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"message\": {...}}"
```

> ⚠️ Confirmar destinatarios con el usuario antes de enviar.

---

## Plantilla Visual

> Detalle: @references/visual-template.md

- Portada: Azul corporativo (#0078D4), blanco, logo
- Diapositivas: Blanco, barra superior azul
- Semáforos: Verde (#00B050) / Amarillo (#FFC000) / Rojo (#FF0000)
- Tablas: Cabecera azul oscuro, filas alternas

---

## Referencias

- `references/traffic-light-logic.md` — Lógica semáforos
- `references/pptx-structure.md` — Estructura PowerPoint
- `references/visual-template.md` — Esquema colores
- Sprint management: `../sprint-management/SKILL.md`
- Comando: `/report-executive`
