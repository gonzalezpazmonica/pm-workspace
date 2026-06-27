---
context_tier: L2
token_budget: 500
resource: internal://docs/rules/domain/org-intelligence-protocol.md
updated_at: "2026-06-28"
---

# Protocolo org-intelligence — Schemas y Reglas de Uso

> Protocolo para la familia de skills org-intelligence (SE-232).
> Define schemas de nodos, reglas de privacidad y criterios de uso responsable.
> Ref: SE-232, docs/rules/domain/skill-families-registry.md

## Schemas de nodos

### DECISOR

Representa un actor organizativo con poder de decisión real (no necesariamente formal).

```yaml
DECISOR:
  campos:
    nombre: string  # nombre o pseudónimo — puede anonimizarse
    rol_formal: string  # título en el organigrama
    influencia_real: [ALTA | MEDIA | BAJA]
    posicion_iniciativa: [PROMOTOR | NEUTRO | OPOSITOR | DESCONOCIDA]
    canal_preferido: string  # email / reunión presencial / Slack / etc.
    notas: string  # contexto libre — tratar como confidencial
  relaciones:
    - APOYA → [DECISOR | PROYECTO | INICIATIVA]
    - SE_OPONE_A → [DECISOR | PROYECTO | INICIATIVA]
    - INFLUYE_EN → [DECISOR]
    - ES_INFLUIDO_POR → [DECISOR]
```

### INFORMAL_AGREEMENT

Representa un acuerdo no formalizado que condiciona decisiones o proyectos.

```yaml
INFORMAL_AGREEMENT:
  campos:
    partes: [lista de DECISOR]
    contenido_acuerdo: string  # descripción del acuerdo
    fecha_aproximada: date  # puede ser vaga: "Q1 2026"
    confidencialidad: [ALTA | MEDIA | BAJA]
    impacto_en: string  # qué iniciativas o decisiones afecta
  relaciones:
    - ENTRE → [DECISOR]
    - CONDICIONA → [PROYECTO | INICIATIVA | DECISIÓN]
    - BLOQUEA → [PROYECTO | INICIATIVA]
    - HABILITA → [PROYECTO | INICIATIVA]
```

### POLITICAL_CONTEXT

Representa el contexto político de una iniciativa o decisión específica.

```yaml
POLITICAL_CONTEXT:
  campos:
    iniciativa: string  # nombre de la iniciativa o decisión
    coaliciones_favor: [lista de DECISOR o grupos]
    coaliciones_contra: [lista de DECISOR o grupos]
    acuerdos_previos: [lista de INFORMAL_AGREEMENT relevantes]
    riesgo: [ALTO | MEDIO | BAJO]
    timing: string  # cuándo es el momento óptimo para actuar
  relaciones:
    - AFECTA_A → [PROYECTO | INICIATIVA]
    - GENERADO_POR → [DECISOR]
    - RESUELVE → [POLITICAL_CONTEXT previo]
```

## Reglas de privacidad y uso responsable

### Obligaciones

1. Los outputs de org-intelligence son CONFIDENCIALES por defecto
2. No compartir mapas de stakeholders con personas externas a la iniciativa sin autorización
3. Los nombres de personas deben anonimizarse antes de almacenar en cualquier sistema compartido
4. Los acuerdos informales documentados no deben usarse como "evidencia" en disputas

### Prohibiciones

1. NUNCA usar org-intelligence para excluir personas de procesos de decisión de forma encubierta
2. NUNCA almacenar perfiles de stakeholders con datos personales sin base legal (RGPD art. 6)
3. NUNCA usar el análisis político para manipular o coaccionar a individuos
4. NUNCA compartir INFORMAL_AGREEMENT con las partes no involucradas en el acuerdo

### Disclaimer de privacidad (obligatorio en todos los outputs de org-intelligence)

```
AVISO DE CONFIDENCIALIDAD: Este análisis contiene información sobre dinámicas
organizativas que puede incluir datos sobre comportamientos y posiciones de personas
identificables. Tratar como CONFIDENCIAL. No distribuir sin autorización del solicitante.
Los perfiles individuales son orientativos y subjetivos — no constituyen evaluaciones
objetivas de capacidad ni comportamiento.
```

## Señales de uso indebido

La skill debe negarse a producir output si detecta:
- Solicitud de "estrategia para eliminar a X persona del proceso"
- Análisis diseñado para discriminar por razones protegidas (género, edad, origen)
- Construcción de perfil de acoso sobre un individuo específico
- Intención declarada de usar el análisis en un conflicto laboral como "prueba"

## Integración con knowledge-graph (SE-162)

Los nodos DECISOR, INFORMAL_AGREEMENT y POLITICAL_CONTEXT pueden integrarse
en el grafo de conocimiento del proyecto si:
1. Los datos están anonimizados
2. Hay base legal para el tratamiento (art. 6 RGPD)
3. El responsable del proyecto ha dado autorización explícita

La integración es opcional y siempre requiere decisión humana.
