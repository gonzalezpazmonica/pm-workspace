# Gauntlet Tooling por Ecosistema

Preferir lo que el proyecto ya usa (chequear package.json / pyproject.toml /
Makefile / CI primero). Estos son los defaults cuando no existe nada.

## Python

| Capa | Tool | Comando |
|---|---|---|
| Tests | pytest | `pytest -q` |
| Types | mypy | `mypy <pkg>` (o pyright) |
| Lint + format | ruff | `ruff check . && ruff format --check .` |
| Changed-line coverage | coverage.py | `pytest --cov=<pkg> --cov-branch --cov-report=term-missing --cov-fail-under=<n>` + `diff-cover coverage.xml --fail-under=100` para gatear líneas tocadas |
| Mutation | mutmut (3+) | `mutmut run "my_module*"` — survivors = tests débiles |
| Property-based | hypothesis | `@given(...)` para invariantes |

## JavaScript / TypeScript

| Capa | Tool | Comando |
|---|---|---|
| Tests | vitest / jest | `npx vitest run` / `npx jest` |
| Types | tsc | `npx tsc --noEmit` |
| Lint | eslint | `npx eslint .` |
| Changed-line coverage | vitest/jest | `npx vitest run --coverage` (v8, per-file); `diff-cover` para gatear líneas tocadas |
| Mutation | Stryker | `npx stryker run` (scope con `mutate: [<changed files>]`) |
| Property-based | fast-check | `fc.assert(fc.property(...))` |

## Go

| Capa | Tool | Comando |
|---|---|---|
| Tests | go test | `go test ./... -race` |
| Types | compiler | `go build ./...` |
| Lint | go vet + staticcheck | `go vet ./... && staticcheck ./...` |
| Coverage | built-in | `go test -coverprofile=c.out ./... && go tool cover -func=c.out` |
| Mutation | (sin default maduro) | mutación manual |
| Property-based | testing/quick o rapid | `rapid.Check(t, ...)` |

## Rust

| Capa | Tool | Comando |
|---|---|---|
| Tests | cargo | `cargo test` |
| Types | compiler | `cargo check` |
| Lint | clippy | `cargo clippy -- -D warnings` |
| Coverage | llvm-cov | `cargo llvm-cov --branch` |
| Mutation | cargo-mutants | `cargo mutants --file <changed file>` |
| Property-based | proptest | `proptest!` macros |

## Java

| Capa | Tool | Comando |
|---|---|---|
| Tests | JUnit 5 (Maven/Gradle) | `./mvnw test` / `./gradlew test` |
| Types | javac | `./mvnw compile` / `./gradlew classes` |
| Lint + format | Checkstyle + Spotless | `./mvnw checkstyle:check spotless:check` |
| Changed-line coverage | JaCoCo | `./mvnw verify`, inspeccionar XML/HTML para líneas/ramas tocadas |
| Mutation | PIT | `./mvnw test-compile org.pitest:pitest-maven:mutationCoverage` (scope changed packages) |
| Property-based | jqwik | `@Property` tests |

## .NET (C#) — extensión pm-workspace

| Capa | Tool | Comando |
|---|---|---|
| Tests | dotnet test | `dotnet test *.sln --configuration Release` |
| Types | compiler | `dotnet build --no-restore` |
| Lint + format | dotnet format | `dotnet format --verify-no-changes` |
| Changed-line coverage | XPlat Code Coverage + ReportGenerator | `--collect "XPlat Code Coverage"` + `diff-cover` o `coverlet` por fichero tocado |
| Mutation | Stryker.NET | `dotnet stryker` (scope changed projects) |
| Property-based | FsCheck | `Prop.ForAll(...)` |

## Capas siempre activas (SKILL.md) + menú extendido por Tier 3

| Capa | Tools | Cuándo |
|---|---|---|
| Dependency audit | pip-audit / npm audit / govulncheck / cargo-audit | cuando cambió el set de dependencias |
| License check | pip-licenses / license-checker / go-licenses | al añadir deps a código redistribuible |
| Secret scan | gitleaks | sobre el diff antes de commit |
| Capability diff | review manual / semgrep | siempre barato: ¿el cambio usa network/subprocess/fs/env que antes no? |
| Suite health | pytest-randomly / `--sequence.shuffle` / `-shuffle=on` | orden aleatorio; repetir flakes sospechosos |
| API compatibility | griffe / api-extractor / apidiff / cargo-semver-checks | cuando se toca API pública |
| Concurrency | `-race` / loom / stress + rerun | Tier 3, cuando el failure model nombra races |
| Performance | pytest-benchmark / hyperfine / criterion | solo si el SPEC declara budget |
| UI checks | axe-core / Playwright screenshot / Lighthouse | cuando el cambio toca UI user-facing |
| Version matrix | tox / nox / CI matrix | cuando se declara soporte multi-versión |
| Observability | assertions de logs/metrics en tests | cuando el failure model incluye "falla en silencio en prod" |

Nuevas dependencias: asunto de SPEC primero (justificación de una línea en setup
plan), tool después. EVIDENCE registra el dependency diff final.

## Principio de cobertura: changed-line, no % global

El % global de cobertura es vanity — no detecta líneas nuevas sin test. La
restricción real es: **toda línea cambiada/añadida ejercitada por un test**.
La capa debe exit-nonzero cuando no se alcanza el umbral
(`--cov-fail-under`, `diff-cover --fail-under`, equivalente). Una capa que
imprime un porcentaje y sale 0 es un informe, no una capa del gauntlet.

## Checkers fail-closed

El gauntlet es tan fiable como sus checkers. Herramientas off-the-shelf
(pytest, mypy, tsc…) tienen su comportamiento de fallo ganado; los checks
caseros (grep gates, scripts propios, runner de mutación manual) no. Dos
reglas — ver `docs/rules/domain/checker-fail-closed.md`:

1. **Fail closed**: crash, input ilegible, exit code inesperado o item saltado
   en silencio = fallo duro de la capa. Nada de `|| true`, `2>/dev/null`, fallthrough.
2. **Probar que puede fallar antes de confiar en su pass**: negative control
   contra un input malo conocido. Verifica que el control no es vacío rompiendo
   la defensa y viendo el control pasar a rojo.

## Procedimiento de mutación manual (sin tool)

Usa la tool de mutación del proyecto primero — genera mutantes desde el AST y
no puede saltarse uno en silencio. La mutación manual es fallback:

1. Elige el código nuevo/cambiado.
2. Uno a uno, introduce 3-5 bugs plausibles: flip de comparación (`<`→`<=`),
   off-by-one en loop/slice, borrar una rama, `and`/`or`, reemplazar return por
   constante.
3. Corre la suite tras cada mutante. **Todo mutante debe hacer fallar ≥1 test.**
   Un survivor = assertion faltante o vacía → añade el test que lo mata.
4. Restaura (verifica con `git diff`) y corre la suite para confirmar verde.
5. Reporta: "manual mutation: N/N killed".

**El runner debe probar que ejecutó cada mutante.** El bug de cache de bytecode
(dos mutantes idénticos comparten cache → el runner reporta kills que nunca
corrió) solo infla el score y jamás aparece como rojo. Guard equivalente:
mtime pinning, chequeo de cache que aborta el run. Ver `../mutation-audit/SKILL.md`.

**Atribución de kills**: un kill se atribuye al test que falla primero, así que
7/7 valida la suite entera, no cada capa. En Tier 3, re-correr mutantes contra
la suite de propiedades sola antes de afirmar que las propiedades verifican algo.

## Plantilla de informe EVIDENCE

```markdown
## Evidence Report — <task> (Tier <1|2|3>)

- Spec approval: <obtained from user | not obtained (autonomous run) — confianza degradada>
- Source state: <commit SHA | sha256 tree hash (persistir como script)>
- Toolchain: <fichero de versiones pineadas, p.ej. requirements-dev.txt>
- Entry point: <comando único que re-corrre todas las capas>
- Independent verification: <not performed | passed | failed | blocked> (Tier 3)

### Spec → Test mapping
Estado: pass / fail / unverified / n-a. Una fila "skipped: <razón>" debe ser
unverified o n-a — nunca pass.

| Scenario | Test | Estado |
|---|---|---|
| <nombre> | <test file>::<test name> | pass |
| Must NOT: <restricción negativa> | <test / capa / skipped: razón> | pass | unverified |

### Gauntlet (ejecución fresca final)
| Capa | Comando | Resultado |
|---|---|---|
| Tests | <cmd> | <N> passed, 0 failed |
| Types | <cmd> | 0 errors |
| Lint | <cmd> | 0 warnings |
| Changed-line coverage | <cmd> | <covered>/<total> líneas tocadas |
| Mutation | <tool o "manual"> | <killed>/<total> killed |
| Property-based | <cmd> | <N> properties |
| Real execution | <cmd> | <output observado> |
| Supply chain | <cmd> | 0 vulns conocidas; nuevas deps: <lista ↔ justificación SPEC> |
| Suite health | <cmd> | orden aleatorio (seed <n>), all passed |

### Skipped layers
- <capa>: <razón> (o "none")

### Honest notes
- <fallos durante la tarea y cómo se resolvieron; revisiones de spec; lo que reduce confianza>
```
