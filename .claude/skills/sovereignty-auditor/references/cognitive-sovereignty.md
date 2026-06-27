# Regla: Soberanía Cognitiva — Protección contra el Lock-in de IA
# ── Diagnóstico y cuantificación de dependencia de proveedores IA ──

> Basado en: "La Trampa Cognitiva" (Álvaro de Nicolás, LinkedIn, Mar 2026)
> Complementa: @docs/rules/domain/ai-governance.md (cumplimiento normativo)
> "En los 90 el lock-in era técnico. En los 2000 contractual. En los 2010 de
> procesos. En 2026 es cognitivo." — Cuando la IA entiende tu organización
> mejor que tú, el coste de cambiar de proveedor ya no es técnico.

## Evolución del lock-in empresarial

| Década | Tipo | Mecanismo | Coste de salida |
|---|---|---|---|
| 1990s | Técnico | Formatos propietarios, hardware específico | Migración de datos |
| 2000s | Contractual | Licencias, penalizaciones, volumen mínimo | Legal + financiero |
| 2010s | De procesos | Workflows integrados, APIs acopladas | Reingeniería |
| 2026+ | **Cognitivo** | IA aprende patrones org., grafo decisional | **Estratégico** |

## Las 5 dimensiones del Sovereignty Score

### D1 — Portabilidad de datos (peso: 25%)

¿El conocimiento organizacional es exportable sin la herramienta?

| Indicador | Score alto (80-100) | Score bajo (0-30) |
|---|---|---|
| Formato de datos | Markdown, CSV, JSON en Git | APIs propietarias, DBs cerradas |
| SaviaHub | Configurado con company/clients/users | Sin repo de conocimiento |
| Memoria de agentes | MEMORY.md en Git | Solo en cloud del proveedor |
| Backlogs | BacklogGit (snapshots md) | Solo en API del PM tool |

### D2 — Independencia de proveedor LLM (peso: 25%)

¿Se puede operar sin el proveedor LLM actual?

| Indicador | Score alto | Score bajo |
|---|---|---|
| Emergency Mode | Configurado + modelo descargado | No configurado |
| Multi-modelo | Smart frontmatter (haiku/sonnet/opus) | Single model hardcoded |
| Prompts | Portables, sin features exclusivas | Dependientes de API específica |
| Fallback local | Ollama + modelo 7B+ disponible | Sin alternativa offline |

### D3 — Protección del grafo organizacional (peso: 20%)

¿Quién accede a la estructura de decisiones y relaciones?

| Indicador | Score alto | Score bajo |
|---|---|---|
| Datos sensibles | Git-ignorados, cifrados | En commits públicos |
| Company Savia | RSA-4096 + AES-256-CBC | Sin cifrado |
| Perfiles de cliente | Locales en SaviaHub | En cloud de terceros |
| PII scanning | hook-pii-gate activo | Sin protección |

### D4 — Gobernanza del consumo (peso: 15%)

¿Se controla y mide el uso de IA?

| Indicador | Score alto | Score bajo |
|---|---|---|
| Governance policy | Documentada y revisada | Inexistente |
| Audit trail | Trazas de agentes activas | Sin registro |
| Token tracking | Medición por sesión/sprint | Sin medición |
| Governance audit | Ejecutada trimestralmente | Nunca ejecutada |

### D5 — Opcionalidad de salida (peso: 15%)

¿Se puede migrar a otro proveedor en <72h?

| Indicador | Score alto | Score bajo |
|---|---|---|
| Documentación | Completa en markdown | Dispersa o ausente |
| Exit plan | Documentado y actualizado | Inexistente |
| Datos separados | Empresa ≠ herramienta | Acoplados |
| Backups | Cifrados y verificados | Sin backups |

## Cálculo del Sovereignty Score

```
Score = D1×0.25 + D2×0.25 + D3×0.20 + D4×0.15 + D5×0.15
```

| Rango | Nivel | Significado |
|---|---|---|
| 90-100 | Soberanía plena | Migración trivial |
| 70-89 | Soberanía alta | Migración viable, esfuerzo moderado |
| 50-69 | Riesgo medio | Dependencias significativas |
| 30-49 | Riesgo alto | Lock-in cognitivo en progreso |
| 0-29 | Lock-in crítico | Migración prácticamente inviable |

## Vendor Risk Matrix

| Proveedor | Riesgo lock-in | Mitigación pm-workspace |
|---|---|---|
| LLM (Claude/GPT) | ALTO — aprende patrones org. | Emergency Mode + multi-modelo |
| PM Tool (Azure/Jira) | MEDIO — workflows acoplados | BacklogGit + Savia Flow Git-native |
| Cloud (AWS/Azure/GCP) | MEDIO — infra dependiente | Scripts portables, sin cloud-lock |
| Data store | BAJO si Git, ALTO si SaaS | Todo en Git markdown |

## Señales de alarma

Indicadores de que el lock-in cognitivo está avanzando:
1. No puedes explicar tu proceso de decisión sin la herramienta IA
2. El proveedor sube precios y no hay alternativa viable (<6 meses migración)
3. Los nuevos empleados necesitan la IA para entender los procesos existentes
4. La documentación organizacional solo existe dentro del sistema IA
5. No hay exit plan actualizado ni se ha probado una migración de prueba

## Integración

- **governance-audit**: audita cumplimiento normativo (NIST, EU AI Act, AEPD)
- **sovereignty-audit**: audita independencia del proveedor (5 dimensiones)
- Ambos se complementan: cumplir la ley ≠ ser independiente

## Referencias

- De Nicolás, Á. (2026). "La Trampa Cognitiva". LinkedIn Pulse.
- Gartner (2025). "35% of countries will adopt region-specific AI platforms by 2027"
- AEPD (2026). "Orientaciones sobre IA Agéntica y Protección de Datos"
- EU AI Act (2024). Reglamento (UE) 2024/1689
