---
id: SE-105
title: SE-105 — Adoptar Governance Layer Manifest (GLM v1.0) como capa de declaración interoperable
status: APPROVED
origin: external-analysis https://www.certifywebcontent.com/supervised-ai/governance-layer-manifest/ + análisis comparativo 2026-05-30
author: Savia
priority: media
effort: M 4h
proposed_at: "2026-05-30"
tier: 2
related: [SE-057, ai-governance, governance-enterprise, verification-policy, audit-trail-schema, savia-ethical-principles]
non_blocks: [Tier 0 actual (SE-094 partial, SE-096, SE-097, SE-100 en curso)]
resource: https://github.com/GoogleCloudPlatform/governance-layer-manifest
---

# SE-105 — Adoptar Governance Layer Manifest (GLM v1.0)

## Resumen ejecutivo

GLM (Governance Layer Manifest) es un estándar abierto propuesto en mayo 2026 por EVIDE Governance Lab para que sistemas de governance de IA declaren sus boundaries en JSON machine-readable publicado en `/.well-known/governance-layer-manifest.json` (RFC 8615). Permite a auditores, procurement teams y sistemas adyacentes determinar qué reclama y excluye una capa sin leer documentación.

Savia tiene governance maduro (8 reglas dominio, 9 skills audit, 18 jueces, verification-lattice 5 capas, Truth Tribunal 7 jueces, Code Review Court 4-5 jueces) pero ninguna **declaración formal machine-readable consumible externamente**. Procurement o reviewers externos deben leer markdown disperso para entender qué hace y qué NO hace Savia.

Esta spec propone publicar un GLM manifest declarando los layer types que Savia opera, con énfasis en **explicit non-claims** y **consumer boundary constraints** para prevenir malentendidos sobre el scope.

## Motivación

### Lo que aprende Savia de GLM

1. **Self-declaration formal**: hoy Savia describe su governance en markdown humano. Un sistema externo no puede consultar programáticamente qué reclama.
2. **Vocabulario controlado de layer types**: substrate / witness / boundary / closure / reviewability / cross_cutting. Nuestros 18 jueces y 9 skills audit carecen de taxonomía explícita.
3. **Explicit non-claims**: declarar qué NO hacemos previene litigios y malentendidos. Ejemplo: "Savia NO certifica validez legal de outputs" — útil para evitar que un consumidor asuma evidencia forense.
4. **Consumer boundary constraint**: qué pueden y no pueden inferir los downstream consumers. Ejemplo: "El veredicto del Truth Tribunal NO es certificación regulatoria GDPR".
5. **Composability declarations**: permitir que frameworks adyacentes (LangGraph, AutoGen, Copilot Enterprise) declaren interop con Savia.

### Lo que NO copiamos

- **Posicionamiento legal/forense de EVIDE**: Savia es PM/SDD, no servicio de evidencia legal.
- **Manifest único monolítico**: tenemos múltiples capas (Truth Tribunal, Code Review Court, verification-lattice, Savia Shield, audit-trail). Usaremos manifest cross-cutting con surfaces.
- **Auto-promoción como "certificación"**: GLM explícitamente NO certifica; respetamos esa propiedad.

### Por qué no es Tier 0

- No bloquea desarrollo actual.
- GLM v1.0 es propuesta no adoptada por standards body — riesgo de drift bajo si la spec evoluciona.
- Beneficio principal: positioning externo + interop futura, no operación interna.

## Objetivos

### AC-1: Publicar manifest cross-cutting

Crear `/.well-known/governance-layer-manifest.json` en el repo (no servido en web aún, suficiente como artefacto verificable in-repo). Declarar Savia como `cross_cutting` con surfaces:

- `substrate` — `audit-trail-schema.md` (history JSONL queryable)
- `witness` — Savia Shield 7 capas (preserve evidence of governed-state)
- `boundary` — `verification-policy.md` + Code Review Court (admissibility at bind-time)
- `closure` — Truth Tribunal + signed PRs `pr-signing-protocol.md` (post-bind stabilization)
- `reviewability` — `verification-lattice` (post-closure independent review test)

### AC-2: Explicit non-claims

Declarar qué Savia NO hace:

- Savia NO emite certificación legal ni forense.
- Savia NO sustituye revisión humana en decisiones críticas (Rule #8 SDD Code Review SIEMPRE humano).
- Savia NO garantiza ausencia de hallucinations — solo detecta y reduce.
- Savia NO es authority sobre regulatory compliance — apunta a marcos externos (GDPR, EU AI Act, AEPD).
- Savia NO procesa datos N4/N4b en cloud sin Savia Shield.

### AC-3: Consumer boundary constraints

Declarar qué un consumidor NO debe inferir:

- Un veredicto del Truth Tribunal NO es prueba legal admisible.
- Una aprobación del Code Review Court NO sustituye revisión humana E1 (Rule #8).
- Un audit trail JSONL es evidencia operacional, NO certificación regulatoria firmada.
- Una decisión del Recommendation Tribunal NO es asesoramiento legal/médico/financiero.

### AC-4: Composability declarations

Declarar layer_types compatibles:

```json
"composable_with_types": ["substrate", "witness", "boundary", "closure", "reviewability"],
"composable_with_manifests": []
```

Empezamos con array vacío. Slice 2 (futuro) añadiría URLs específicos cuando otros frameworks publiquen GLM.

### AC-5: Manifest digest verificable

- Calcular SHA-256 del JSON canonicalizado.
- Incluir `manifest_digest.value` en el propio fichero.
- Script `scripts/glm-verify.sh` que descarga (o lee local), hashea, compara.
- Test BATS que valida que el digest declarado coincide con el calculado.

### AC-6: Documentación

- Nueva regla `docs/rules/domain/governance-layer-manifest.md` (≤150L) explicando GLM, por qué lo adoptamos, qué declaramos.
- Sección en `CLAUDE.md` lazy reference: "GLM manifest declarado".
- Entry en `CHANGELOG.md` Unreleased.

### AC-7: NO publicación web automática

El fichero vive en `.well-known/` del repo. **No** se sirve en una web pública desde este repo (Rule #20 PII-Free + zero-project-leakage). Si Savia tuviera un dominio público en el futuro, se publicaría ahí.

## Diseño técnico

### Estructura del manifest

```json
{
  "schema_version": "1.0",
  "valid_from": "2026-05-30",
  "supersedes": null,
  "layer": {
    "layer_type": "cross_cutting",
    "vendor_layer_name": "Savia",
    "vendor_layer_descriptor": "AI-supervised PM workspace with multi-layer governance for SDD pipelines"
  },
  "timing_axis": {
    "position": "cross_cutting",
    "surfaces": [
      {"layer_type": "substrate", "anchor": "docs/rules/domain/audit-trail-schema.md"},
      {"layer_type": "witness", "anchor": "docs/savia-shield.md"},
      {"layer_type": "boundary", "anchor": "docs/rules/domain/verification-policy.md"},
      {"layer_type": "closure", "anchor": "docs/rules/domain/pr-signing-protocol.md"},
      {"layer_type": "reviewability", "anchor": ".opencode/skills/verification-lattice/SKILL.md"}
    ]
  },
  "operational_scope": {
    "does": [
      "Multi-judge tribunal validation (Truth Tribunal 7 judges, Code Review Court 4-5 judges, Recommendation Tribunal 4 judges)",
      "5-layer data sovereignty enforcement (Savia Shield: regex, NER, LLM local, proxy, audit)",
      "Append-only JSONL audit trail per agent action",
      "Spec-Driven Development with mandatory human review (E1)",
      "Risk-scored verification policy (layers 1-5)"
    ],
    "does_not": [
      "Issue legal or forensic certifications",
      "Substitute human review in critical decisions",
      "Guarantee absence of hallucinations",
      "Act as authority on regulatory compliance"
    ]
  },
  "claims_boundary": {
    "authoritative_layer_claim": "Savia provides multi-layer pre-merge governance (substrate + witness + boundary + closure + reviewability) for AI-agent-driven software delivery pipelines, with mandatory human review at risk-classified gates",
    "explicit_non_claims": [...AC-2 items...],
    "consumer_boundary_constraint": "Outputs of Savia governance layers are operational evidence and pre-merge gates. They are not legal certifications, regulatory attestations, or substitutes for human review at decision gates declared in verification-policy.md"
  },
  "composition": {
    "composable_with_types": ["substrate", "witness", "boundary", "closure", "reviewability"],
    "composable_with_manifests": []
  },
  "machine_readable_status": {
    "boundary_readiness": "stable",
    "authority_dependency": "none",
    "execution_capability": true,
    "reviewability_state": "portable"
  },
  "public_anchors": [
    "https://github.com/<repo>/blob/main/docs/rules/domain/ai-governance.md",
    "https://github.com/<repo>/blob/main/docs/rules/domain/savia-ethical-principles.md",
    "https://github.com/<repo>/blob/main/docs/savia-shield.md",
    "https://github.com/<repo>/blob/main/docs/rules/domain/verification-policy.md"
  ],
  "manifest_digest": {
    "type": "sha256",
    "value": "<computed-at-commit-time>"
  }
}
```

### Workflow de publicación

1. Editar `.well-known/governance-layer-manifest.json` con placeholder `<computed>`.
2. `bash scripts/glm-compute-digest.sh` calcula SHA-256 del fichero con placeholder y lo reemplaza in-place.
3. `bash scripts/glm-verify.sh` valida que el digest coincide.
4. Hook pre-commit valida que si el fichero cambió, el digest se recomputó.

### Coexistencia con governance existente

GLM es **descriptive**, no replace. Coexiste con:

- `docs/rules/domain/ai-governance.md` (canónico interno)
- `docs/rules/domain/governance-enterprise.md` (matrices GDPR/AEPD/ISO/EU AI Act)
- `docs/rules/domain/audit-trail-schema.md` (formato JSONL)
- `docs/rules/domain/verification-policy.md` (gates por risk score)

GLM es la **vista externa machine-readable** de lo que esos docs declaran en humano.

## Criterios de aceptación

- [ ] AC-1: `.well-known/governance-layer-manifest.json` con 5 surfaces declarados
- [ ] AC-2: ≥5 explicit_non_claims declarados
- [ ] AC-3: consumer_boundary_constraint ≥1 párrafo
- [ ] AC-4: composable_with_types con 5 layer types
- [ ] AC-5: `scripts/glm-compute-digest.sh` + `scripts/glm-verify.sh` + 1 test BATS
- [ ] AC-6: `docs/rules/domain/governance-layer-manifest.md` ≤150L
- [ ] AC-7: Manifest NO se sirve en web; solo vive en repo

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| GLM v1.0 evoluciona y nuestro manifest queda desfasado | Schema version trackeado; revisión semestral |
| Auditor externo malinterpreta el manifest como certificación | explicit_non_claims + consumer_boundary_constraint fuertes |
| Filtración de datos privados en public_anchors | Solo apuntan a docs OSS del repo público |
| Manifest cae en disrepair (drift con realidad) | Test BATS valida digest + revisión semestral |
| Posicionamiento "estándar" sobreestima madurez | Documentar explícitamente que GLM v1.0 es propuesta sin standards body adoption |

## Out of scope (este SE)

- Publicación en dominio web público (futuro, requiere infra Savia)
- Manifest signature (cryptographic signature binding digest to identity) — GLM v1.0 declara separadamente, slice 2
- Composability con manifests de terceros — slice 2 cuando otros frameworks publiquen GLM
- GLM compliance certification — GLM explícitamente no certifica

## Effort estimation

- Diseño del manifest JSON: 45min
- Scripts compute/verify: 60min
- Test BATS: 30min
- Regla `governance-layer-manifest.md`: 45min
- Hook pre-commit digest: 30min
- CHANGELOG + CLAUDE.md lazy ref: 15min
- Verificación E1: 15min
- **Total: M 4h**

## Notas

- SE-057 (rule-manifest integrity) es distinto: cubre integridad interna de manifests de reglas (`.opencode/rules/manifest.json`). GLM es manifesto público externo de boundaries.
- Esta spec NO depende de Tier 0. Puede ejecutarse en paralelo o tras Tier 0.
- Si GLM v1.1+ rompe compatibilidad, supersedes apunta al digest v1.0 anterior.
