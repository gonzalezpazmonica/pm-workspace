---
name: human-code-map-domain
description: Contexto de dominio del skill human-code-map — por qué existe y cómo encaja
type: domain
---

# Human Code Map — Contexto de Dominio

## Por qué existe este skill

Los desarrolladores pasan el 58% de su tiempo leyendo código (Osmani, 2024). Este coste
se multiplica exponencialmente en módulos sin documentación de modelo mental. Cada "¿cómo
funciona X?" que un developer no puede responder en 2 minutos es deuda cognitiva activa.

pm-workspace ya resolvió este problema para los **agentes de IA** con los `.acm`.
Este skill resuelve el mismo problema para los **humanos** con los `.hcm`.

La hipótesis central: si documentamos el *modelo mental* de un componente (no su estructura,
sino cómo pensarlo), el coste de re-aprendizaje colapsa de horas a minutos.

## Conceptos de dominio

**Deuda cognitiva**: Coste acumulado de re-entender código que ya se entendió antes.
Diferente de deuda técnica (código) — esta vive en los mapas mentales de las personas.

**Primer paseo** (first walk): La primera vez que alguien entiende un componente a fondo.
Es la inversión más cara. El .hcm convierte ese coste en activo reutilizable.

**Walk-time**: Tiempo estimado para leer y absorber un .hcm (target: 2-4 minutos).
Si un .hcm tarda más de 5 minutos en leerse, es demasiado largo.

**Debt-score**: Puntuación 0-10 de cuánta deuda cognitiva acumula activamente un componente.
Un score > 7 significa que este módulo está costando tiempo de equipo ahora mismo.

**Gotcha**: Comportamiento no obvio que sorprende a devs nuevos. Los gotchas son el activo
más valioso de un .hcm — son el conocimiento tácito que muere con el autor original.

## Reglas de negocio que implementa

- `.hcm` siempre derivado de `.acm` (precisión estructural garantizada)
- `debt-score > 7` → escalar al PM (coste activo identificado)
- `last-walk` solo actualizable por humano (no por AI)
- Un `.hcm` sin validación humana = borrador, no mapa válido
- Si `.acm` es stale → `.hcm` también es stale (automático)

## Relación con otros skills

**Upstream:**
- `agent-code-map` — provee el .acm base del que deriva el .hcm
- `ast-comprehension` — provee análisis estructural del código fuente

**Downstream:**
- Onboarding de devs nuevos (cargar .hcm antes de primera tarea)
- `/dev-session start` — puede cargar .hcm del módulo a modificar
- `/spec-generate` — puede incluir .hcm como contexto de diseño

**Paralelo:**
- `code-comprehension-report` — informes de comprensibilidad post-implementación
- `drift-auditor` — detecta cuando código diverge de su documentación

## Decisiones clave de diseño

**¿Por qué .hcm en vez de README mejorado?**
Los README son proyecto-level. Los .hcm son componente-level. Un README explica el
proyecto; un .hcm explica cómo funciona la cabeza de quien diseñó el hooks pipeline.

**¿Por qué no solo comentarios de código?**
Los comentarios están en el código, fragmentados por fichero. El .hcm sintetiza el
modelo mental completo en un único lugar de 2-4 minutos de lectura.

**¿Por qué derivar del .acm y no generarlo independientemente?**
El .acm garantiza precisión estructural. Un .hcm generado sin base estructural inventa.
El .acm es el esqueleto; el .hcm añade la narrativa. Separar garantiza que la narrativa
no contradiga la estructura.

**¿Por qué requiere validación humana?**
La parte más valiosa de un .hcm son los gotchas y las decisiones de diseño. Ningún AI
puede inferir "elegimos este enfoque porque tuvimos un incidente de producción en 2024".
El AI genera el borrador; el humano aporta el conocimiento tácito.
