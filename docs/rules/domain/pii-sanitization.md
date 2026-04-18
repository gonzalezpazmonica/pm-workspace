# PII Sanitization — Zero Personal Data in Public Repo

> Prioridad: **CRÍTICA** — Aplica a TODO artefacto versionado.

---

## Principio

PM-Workspace es software libre genérico. El repositorio público NO debe contener
nombres reales, empresas, handles de GitHub, emails ni ningún dato que identifique
a personas o equipos concretos. Los datos personales SOLO viven en ficheros
git-ignorados (`*.local.md`, `CLAUDE.local.md`, `active-user.md`).

---

## Prohibido en artefactos versionados

| Categoría          | Ejemplo prohibido              | Alternativa genérica            |
|--------------------|-------------------------------|---------------------------------|
| Nombre real        | la usuaria, González              | alice, bob, admin               |
| Handle GitHub      | gonzalezpazmonica             | your-handle, org-name           |
| Nombre de empresa  | AIrquiTech                    | test-org, acme-corp, test company repo |
| Email personal     | user@gmail.com                | user@example.com                |
| URL con handle     | github.com/gonzalezpazmonica/ | github.com/your-org/            |
| DNI/NIE/IBAN       | cualquiera                    | NUNCA, ni como ejemplo          |

---

## Ámbito — dónde aplica

- Scripts (`scripts/*.sh`)
- Tests (`scripts/test-*.sh`) — usar datos ficticios
- CHANGELOG.md, README.md, README.en.md
- Releases y tags de GitHub
- Mensajes de commit y descripciones de PR
- Reglas (`docs/rules/`)
- Skills (`.claude/skills/`)
- Docs (`docs/`)
- Propuestas (`docs/propuestas/`)

---

## Excepciones (ficheros git-ignorados o legítimamente públicos)

- `CLAUDE.local.md` — configuración local del usuario
- `docs/rules/pm-config.local.md` — config local
- `.claude/profiles/active-user.md` — perfil activo local
- `CONTRIBUTORS.md` — atribución pública voluntaria
- `README.md` badges/links al repo — URL pública del proyecto
- `CHANGELOG.md` links de comparación de versiones — URL estándar

---

## Checklist pre-commit

Antes de commit/push, verificar que NO aparecen PII:

```bash
# Buscar PII en ficheros staged (excluir .local.md y .git/)
git diff --cached --name-only | \
  xargs grep -ilE '(AIrquiTech|gonzalezpazmonica|mónica)' 2>/dev/null | \
  grep -v '\.local\.md$' | grep -v 'CONTRIBUTORS' | grep -v '\.git/'
# Si devuelve resultados → PARAR y sanitizar
```

---

## Responsabilidad del agente

1. **Al generar código/docs**: usar SIEMPRE placeholders genéricos.
2. **Al escribir CHANGELOG/releases**: describir cambios técnicos sin nombres.
3. **Al crear PRs/commits**: mensajes descriptivos sin PII.
4. **En caso de duda**: preferir genérico sobre específico.
5. **Si se detecta PII en artefacto existente**: corregir inmediatamente.
