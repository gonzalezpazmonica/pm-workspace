# Regla: Configuración del Asistente de Análisis de Contexto
# ── Entrevista estructurada para recabar información de clientes y proyectos ──

> El Asistente de Análisis de Contexto guía al PM mediante una entrevista
> estructurada de 8 fases para recopilar toda la información necesaria
> sobre un cliente o proyecto. Los datos se persisten en SaviaHub.

## Ubicación de sesiones

```
$SAVIA_HUB_PATH/clients/{client-slug}/
└── interviews/
    ├── 20260305-erp-migration.md    ← Sesión de entrevista
    └── 20260310-new-module.md
```

## Formato de sesión

```yaml
---
client: "acme-corp"
project: "erp-migration"
started: "2026-03-05T10:00:00Z"
status: "in-progress"       # in-progress | completed | paused
current_phase: 3
total_phases: 8
sector: "fintech"
interviewer: "savia"
pm: "monica-gonzalez"
---
```

Seguido de secciones por fase con preguntas y respuestas.

## 8 Fases

### Fase 1 — Dominio
Preguntas: área de negocio, producto/servicio principal, usuarios finales,
terminología específica, conceptos clave del dominio.
Persistir en: `profile.md` → sección Dominio

### Fase 2 — Stakeholders
Preguntas: personas involucradas, roles, responsabilidades, decisores,
canales de comunicación, horarios, idioma preferido.
Persistir en: `contacts.md` + `profile.md` → sección Metodología

### Fase 3 — Stack tecnológico
Preguntas: lenguajes, frameworks, bases de datos, infraestructura cloud,
CI/CD, repositorios, entornos (dev/pre/pro).
Persistir en: `profile.md` → sección Stack tecnológico

### Fase 4 — Restricciones
Preguntas: limitaciones técnicas, presupuesto, plazos inamovibles,
integraciones obligatorias, legacy systems, deuda técnica conocida.
Persistir en: `rules.md` → sección Restricciones técnicas

### Fase 5 — Reglas de negocio
Preguntas: lógica de dominio, validaciones, excepciones, workflows,
estados permitidos, permisos, reglas de cálculo.
Persistir en: `rules.md` → sección Reglas de negocio

### Fase 6 — Compliance (sector-adaptativa)
Selección automática según sector del cliente:
- **fintech/banking**: PCI-DSS, PSD2, MiFID II, KYC/AML
- **healthcare**: HIPAA, HL7/FHIR, consentimiento informado
- **legal**: GDPR/LOPD, retención documental, cadena de custodia
- **education**: COPPA, GDPR Art. 8, protección de menores
- **industrial**: ISO 9001, ISO 27001, normativa sectorial
- **general**: GDPR/LOPD básico, protección de datos
Persistir en: `rules.md` → nueva sección Compliance

### Fase 7 — Timeline
Preguntas: hitos del proyecto, deadlines, fases, dependencias entre fases,
riesgos temporales, buffer estimado.
Persistir en: `projects/{project}/metadata.md`

### Fase 8 — Resumen y validación
Generar resumen consolidado de todas las fases. Presentar al PM para
validación. Detectar gaps. Marcar entrevista como `completed`.

## Comportamiento de Savia durante la entrevista

- Preguntar UNA cosa a la vez (no bombardear con múltiples preguntas)
- Si el PM no sabe una respuesta → marcar como gap, NO bloquear
- Adaptar el tono al perfil del PM (formal/informal según preferencia)
- Si detecta inconsistencias entre respuestas → preguntar amablemente
- Ofrecer ejemplos cuando la pregunta es abstracta
- Cada respuesta se persiste inmediatamente (no esperar al final)

## Detección de gaps

Esquema esperado por fase (campos mínimos):

| Fase | Campos mínimos |
|------|---------------|
| 1 | area_negocio, producto, usuarios_finales |
| 2 | al menos 1 contacto con rol |
| 3 | al menos 1 lenguaje, infra definida |
| 4 | al menos 1 restricción documentada |
| 5 | al menos 1 regla de negocio |
| 6 | normativa aplicable identificada |
| 7 | al menos 1 hito con fecha |
| 8 | resumen validado por PM |

## Seguridad

- Datos del cliente → SaviaHub (repo separado, datos reales OK)
- NUNCA incluir passwords, tokens o API keys en sesiones
- Respetar preferencias de privacidad del PM
- Si el PM indica datos confidenciales → marcar con `<private>`
