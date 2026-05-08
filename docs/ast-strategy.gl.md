# Estratexia AST de Savia — Comprensión e Calidade de Código

> Documento técnico: como Savia usa Árbores de Sintaxe Abstracta para entender código legado
> e garantir a calidade do código xerado polos seus axentes.

---

## O problema que resolve

Os axentes de IA xeran código a alta velocidade. Sen validación estrutural, ese código pode:
- Introducir patróns async bloqueantes que fallan en produción
- Crear consultas N+1 que degradan o rendemento ao 10% baixo carga real
- Silenciar excepcións en bloques `catch {}` baleiros que ocultan erros críticos
- Modificar un ficheiro de 300 liñas sen entender as súas dependencias internas

Savia resolve ambos problemas coa mesma tecnoloxía: AST.

---

## Arquitectura cuádruple: catro propósitos, unha árbore

```
Código fonte
     │
     ▼
Árbore de Sintaxe Abstracta (AST)
     │
     ├──► Comprensión (ANTES de editar)                 ← hook PreToolUse
     │         Entende o que xa existe
     │         Non modifica nada
     │         Inxección de contexto pre-edición
     │
     ├──► Calidade (DESPOIS de xerar)                    ← hook PostToolUse async
     │         Valida o que se acaba de escribir
     │         12 Quality Gates universais
     │         Informe con puntuación 0-100
     │
     ├──► Mapas de código (.acm)                         ← Contexto persistente entre sesións
     │         Pre-xerado antes da sesión
     │         Máximo 150 liñas por ficheiro .acm
     │         Carga progresiva con @include
     │
     └──► Mapas humanos (.hcm)                           ← Loita activa contra a débeda cognitiva
               Narrativa en linguaxe natural
               Validados por humanos, non por CI
               Por que existe o código, non só o que fai
```

A clave do deseño: a mesma árbore serve para **catro** fases do ciclo de vida do código,
con ferramentas distintas e en momentos distintos do pipeline de hooks.

---

## Parte 1 — Comprensión de código legado

### O principio

Antes de que un axente edite un ficheiro, Savia extrae o seu mapa estrutural.
O axente recibe ese mapa no seu contexto, como se xa lera o código de antemán.

### Pipeline de extracción (3 capas)

```
Ficheiro obxectivo
      │
      ▼
Capa 1: Tree-sitter (universal, 0 dependencias de runtime)
  • Todos os idiomas do Language Pack
  • Clases, funcións, métodos, enums
  • Declaracións de importación
  • ~1-3s, 95% cobertura semántica

      │ (se non dispoñible)
      ▼
Capa 2: Ferramenta semántica nativa do idioma
  • Python: ast.walk() (módulo built-in, 100% precisión)
  • TypeScript: ts-morph (Compiler API completa)
  • Go: gopls symbols
  • C#: Roslyn SyntaxWalker
  • Rust: cargo check + rustfmt AST
  • Java: javap -c, semgrep
  • ~2-10s, 100% cobertura semántica

      │ (se non dispoñible)
      ▼
Capa 3: Grep-estrutural (0 dependencias absolutas)
  • Regex universal para os 16 idiomas
  • Extrae clases, funcións, importacións por patróns
  • <500ms, ~70% cobertura semántica
  • Sempre dispoñible — nunca falla
```

**Regra de degradación garantida**: se todas as ferramentas avanzadas fallan,
grep-estrutural sempre funciona. Nunca se bloquea unha edición por falta de ferramenta.

### Disparador automático: hook PreToolUse

```
Usuario pide editar ficheiro
         │
         ▼
Hook: ast-comprehend-hook.sh (PreToolUse, matcher: Edit)
  • Le file_path do JSON de entrada do hook
  • Verifica: ¿o ficheiro ten ≥50 liñas?
  • Se si: executa ast-comprehend.sh --surface-only (timeout 15s)
  • Extrae: clases, funcións, complexidade ciclomática
  • Se complexidade > 15: emite aviso visible
         │
         ▼
O axente recibe no seu contexto:
  ╔══════════════════════════════════════════════════╗
  ║  AST Comprehension — Pre-edit context           ║
  ╚══════════════════════════════════════════════════╝
  Ficheiro: src/Services/AuthService.cs
  Liñas:  248  |  Clases: 1  |  Funcións: 12
  Complexidade: 42 puntos de decisión  ⚠️  Proceder con cautela

  Mapa estrutural:
  { "classes": [{ "name": "AuthService", "line": 12 }],
    "functions": [{ "name": "ValidateToken", "line": 45 }] }
         │
         ▼
O axente edita con contexto completo do ficheiro
```

O hook é **non-async** porque debe completarse ANTES de que o axente edite.
O hook sempre fai `exit 0` — a comprensión é consultiva, nunca bloquea.

---

## Parte 2 — Calidade do código xerado

### Os 12 Quality Gates universais

| Gate | Nome | Clasificación | Idiomas |
|------|------|---------------|---------|
| QG-01 | Async/concorrencia bloqueante | BLOCKER | .NET, TypeScript, Python, Rust |
| QG-02 | Consultas N+1 | ERROR | .NET, Java, Python, Ruby |
| QG-03 | Null dereference sen garda | BLOCKER | .NET, Go, Java, Swift/Kotlin |
| QG-04 | Números máxicos sen constante | WARNING | Todos os idiomas |
| QG-05 | Catch baleiro / excepcións tragadas | BLOCKER | .NET, Java, TypeScript, Go |
| QG-06 | Complexidade ciclomática >15 | WARNING | Todos os idiomas |
| QG-07 | Métodos >50 liñas | INFO | Todos os idiomas |
| QG-08 | Duplicación >15% | WARNING | Todos os idiomas |
| QG-09 | Segredos hardcodeados | BLOCKER | Todos os idiomas |
| QG-10 | Logging excesivo en produción | INFO | Todos os idiomas |
| QG-11 | Código morto / dead code | INFO | Todos os idiomas |
| QG-12 | Lóxica de negocio sen tests | BLOCKER | Todos os idiomas |

```
score = 100 - (BLOCKER × 10) - (WARNING × 3) - (INFO × 1)
```

### Disparador automático: hook PostToolUse async

```
O axente escribe/edita ficheiro
         │
         ▼
Hook: ast-quality-gate-hook.sh (PostToolUse, async, matcher: Edit|Write)
  • Executa en segundo plano — non bloquea o axente
  • Detecta idioma pola extensión
  • Executa ast-quality-gate.sh co ficheiro
  • Calcula puntuación (0-100) e nota (A-F)
  • Se puntuación < 60 (nota D ou F): emite alerta visible
  • Garda o informe en output/ast-quality/
```

---

## Parte 3 — Mapas de código para axentes (.acm)

### O problema

Cada sesión do axente comeza de cero. Sen contexto pre-xerado, o axente
consume o 30–60 % da súa fiestra de contexto explorando a arquitectura
antes de escribir unha soa liña de código.

Os Agent Code Maps (.acm) son mapas estruturais persistentes entre sesións,
almacenados en `.agent-maps/` e optimizados para consumo directo polos axentes.

```
.agent-maps/
├── INDEX.acm              ← Punto de entrada de navegación
├── domain/
│   ├── entities.acm       ← Entidades de dominio
│   └── services.acm       ← Servizos de negocio
├── infrastructure/
│   └── repositories.acm   ← Repositorios e acceso a datos
└── api/
    └── controllers.acm    ← Controllers e endpoints
```

**Límite de 150 liñas por .acm**: se crece, divídese automaticamente.
**Sistema @include**: carga progresiva baixo demanda — o axente carga só o que necesita.

### Modelo de frescura

| Estado | Condición | Acción do axente |
|--------|-----------|-----------------|
| `fresco` | Hash .acm coincide co código fonte | Usar directamente |
| `obsoleto` | Cambios internos, estrutura intacta | Usar con aviso |
| `roto` | Ficheiros eliminados ou sinaturas públicas cambiadas | Rexenerar antes de usar |

### Integración no pipeline SDD

Os ficheiros .acm cárganse ANTES de `/spec:generate`. O axente coñece a
arquitectura real do proxecto dende o primeiro token, sen exploración ás cegas.

```
[0] CARGAR — /codemap:check && /codemap:load <scope>
[1-5] Pipeline SDD sen cambios
[post-SDD] ACTUALIZAR — /codemap:refresh --incremental
```

---

## Parte 4 — Mapas humanos (.hcm)

### O problema

Os desenvolvedores invisten o 58 % do tempo lendo código vs. o 42 % escribíndoo
(Addy Osmani, 2024). Ese 58 % multiplícase en áreas con **débeda cognitiva**: subsistemas
que alguén ten que re-aprender cada vez que os toca porque non existe un mapa narrativo
que pre-dirixa o camiño mental.

Os ficheiros `.hcm` loitan activamente contra a débeda cognitiva: son o xemelgo humano
dos `.acm`. Mentres `.acm` lle di a un axente "que existe e onde", `.hcm` dílle
a un desenvolvedor "por que existe e como pensalo".

### Formato .hcm

```markdown
# {Compoñente} — Mapa humano (.hcm)
> version: 1.0 | last-walk: YYYY-MM-DD | walk-time: Xmin | debt-score: N/10
> acm-sync: .agent-maps/{compoñente}.acm

## A historia (1 parágrafo)
Que problema resolve, en linguaxe humana.

## O modelo mental
Como pensar neste compoñente. Analoxías se axudan.

## Puntos de entrada (tarefa → onde comezar)
- Para engadir X → comeza en {ficheiro}:{sección}
- Se Y falla → o punto de entrada é {hook/script}

## Gotchas (comportamentos non obvios)
- O que sorprende os desenvolvedores que chegan novos
- As trampas documentadas deste subsistema

## Por que está construído así
- Decisións de deseño coa súa motivación
- Compromisos aceptados conscientemente

## Indicadores de débeda
- Áreas coñecidas de confusión ou refactor pendente
```

### Debt Score (0–10)

```
debt_score =
  min((days_since_last_walk / 30) * 2, 4)   # Stale penalty (max 4)
  + complexity_indicator                      # 0-3 (coupling)
  + (1 - test_coverage_ratio) * 3             # Coverage gap (max 3)

0-3: Mapa fresco
4-6: Revisar pronto
7-10: Débeda activa — custando diñeiro agora
```

### Localización por proxecto

Cada proxecto xestiona os seus propios mapas dentro do seu cartafol:

```
projects/{proxecto}/
├── CLAUDE.md
├── .human-maps/               ← Mapas narrativos para desenvolvedores
│   ├── {proxecto}.hcm         ← Mapa xeral do proxecto
│   └── _archived/             ← Compoñentes eliminados ou fusionados
└── .agent-maps/               ← Mapas estruturais para axentes
    ├── {proxecto}.acm
    └── INDEX.acm
```

### Ciclo de vida

```
Creación (/codemap:generate-human) → Validación humana → Activo
         ↓ cambios de código
      .acm rexenérase → .hcm marcado como obsoleto → Actualización (/codemap:walk)
```

**Regra inmutable:** Un `.hcm` nunca pode ter `last-walk` máis recente que o seu `.acm`.
Se o `.acm` é obsoleto, o `.hcm` tamén o é independentemente da súa data.

### Comandos

```bash
# Xerar o borrador .hcm desde .acm + código
/codemap:generate-human projects/o-meu-proxecto/

# Sesión guiada de re-lectura (actualización)
/codemap:walk o-meu-módulo

# Mostrar os debt-scores de todos os .hcm do proxecto
/codemap:debt-report

# Forzar a actualización do .hcm indicado
/codemap:refresh-human projects/o-meu-proxecto/.human-maps/o-meu-módulo.hcm
```

---

## Garantías do sistema

1. **Nunca bloquea unha edición**: RN-COMP-02 — se a comprensión falla, exit 0 sempre
2. **Nunca destrúe código**: RN-COMP-02 — a comprensión é só de lectura
3. **Sempre ten fallback**: RN-COMP-05 — grep-estrutural garante cobertura mínima
4. **Criterios agnósticos**: os 12 QG aplican igual a todos os idiomas
5. **Esquema unificado**: todos os outputs son comparables entre idiomas

---

## Referencias

- Skill comprensión: `.opencode/skills/ast-comprehension/SKILL.md`
- Skill calidade: `.opencode/skills/ast-quality-gate/SKILL.md`
- Hook comprensión: `.opencode/hooks/ast-comprehend-hook.sh`
- Hook calidade: `.opencode/hooks/ast-quality-gate-hook.sh`
- Script comprensión: `scripts/ast-comprehend.sh`
- Script calidade: `scripts/ast-quality-gate.sh`
- Skill mapas de código: `.opencode/skills/agent-code-map/SKILL.md`
- Regra mapas humanos: `docs/rules/domain/hcm-maps.md`
- Skill mapas humanos: `.opencode/skills/human-code-map/SKILL.md`
- Mapas do workspace: `.human-maps/`
- Mapas de proxecto: `projects/*/.human-maps/*.hcm`
