# Cobertura de verificación automática de reglas

## ✅ Verificaciones automáticas (pre-commit gate)

Estas reglas se verifican por script antes de cada commit. No dependen del contexto del LLM.

| Regla | Script de verificación | Severidad |
|-------|----------------------|-----------|
| `changelog-enforcement.md` | `scripts/validate-changelog-links.sh` | Bloqueante |
| File size (commands ≤150) | `.claude/compliance/checks/check-file-size.sh` | Bloqueante |
| Command frontmatter YAML | `.claude/compliance/checks/check-command-frontmatter.sh` | Warning |
| README sync ES/EN | `.claude/compliance/checks/check-readme-sync.sh` | Bloqueante |

## 🔄 Verificaciones contextuales (cargadas vía rules)

Estas reglas dependen del contexto de la conversación. Se cargan automáticamente por globs.

- `adaptive-output.md` — Tono y formato de salida
- `inclusive-review.md` — Code reviews sin rejection sensitivity
- `guided-work-protocol.md` — Protocolo de trabajo guiado
- `accessibility-output.md` — Adaptaciones de accesibilidad
- `pii-sanitization.md` — Datos personales (parcialmente verificable)
- `security-check-patterns.md` — Patrones de seguridad (parcialmente verificable)

## 📊 Cobertura

- **4 reglas** verificadas automáticamente por script
- **~80 reglas** dependen del contexto del LLM
- Las 4 reglas automáticas cubren los errores recurrentes más frecuentes

## Cómo añadir nuevas verificaciones

1. Crear script en `.claude/compliance/checks/check-{nombre}.sh`
2. El script recibe ficheros como argumentos
3. Exit 0 = OK, exit 1 = violación
4. Añadir llamada en `.claude/compliance/runner.sh`
5. Actualizar esta tabla
