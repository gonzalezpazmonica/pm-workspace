# Definición de Pipelines (PR y CI/CD)

El workspace permite definir las pipelines del proyecto para que Claude las genere, revise y mantenga correctamente. Las pipelines cubren dos escenarios principales: validación de Pull Requests y despliegue a entornos.

## Cómo definir las pipelines

En el `CLAUDE.md` del proyecto, añade una sección `pipeline_config`:

```yaml
# En projects/{proyecto}/CLAUDE.md

pipeline_config:
  # ── Plataforma de CI/CD ───────────────────────────────────────
  platform: "azure-devops"        # azure-devops | github-actions | gitlab-ci

  # ── Pipeline de Pull Request (validación) ─────────────────────
  pr_pipeline:
    trigger: "pull_request"
    target_branches: ["main", "develop"]
    steps:
      - name: "Restore dependencies"
        command: "dotnet restore"        # Ajustar al lenguaje del proyecto
      - name: "Build"
        command: "dotnet build --no-restore --configuration Release"
      - name: "Lint / Format check"
        command: "dotnet format --verify-no-changes"
      - name: "Run unit tests"
        command: "dotnet test --no-build --filter Category=Unit"
      - name: "Run integration tests"
        command: "dotnet test --no-build --filter Category=Integration"
      - name: "Security scan"
        command: "dotnet list package --vulnerable --include-transitive"
      - name: "Code coverage check"
        command: "dotnet test --collect:'XPlat Code Coverage' -- threshold=80"

  # ── Pipeline de CI/CD (despliegue) ────────────────────────────
  cicd_pipeline:
    environments:
      - name: "DEV"
        trigger: "auto"               # Automático al merge a develop/main
        approval_required: false
        steps:
          - "restore"
          - "build"
          - "test"
          - "docker-build"
          - "docker-push"
          - "deploy"

      - name: "PRE"
        trigger: "manual"             # Manual o tras aprobación
        approval_required: true
        approvers: ["tech-lead"]
        steps:
          - "docker-pull"
          - "deploy"
          - "smoke-test"
          - "integration-test"

      - name: "PRO"
        trigger: "manual"
        approval_required: true
        approvers: ["tech-lead", "pm"]  # Doble aprobación para producción
        steps:
          - "docker-pull"
          - "deploy"
          - "smoke-test"
          - "health-check"
          - "rollback-if-fail"
```

## Plantillas de pipeline por lenguaje

Claude genera la pipeline adaptada al Language Pack del proyecto. Estos son los pasos estándar por lenguaje:

| Lenguaje | Restore | Build | Lint | Test | Security |
|---|---|---|---|---|---|
| C#/.NET | `dotnet restore` | `dotnet build` | `dotnet format --verify` | `dotnet test` | `dotnet list package --vulnerable` |
| TypeScript | `npm ci` | `npm run build` | `eslint . && prettier --check` | `vitest run` | `npm audit` |
| Java/Spring | `mvn dependency-resolve` | `mvn package -DskipTests` | `mvn checkstyle:check` | `mvn test` | `mvn dependency-check:check` |
| Python | `pip install -r requirements.txt` | `— (interpretado)` | `ruff check . && mypy .` | `pytest` | `safety check` |
| Go | `go mod download` | `go build ./...` | `golangci-lint run` | `go test ./...` | `govulncheck ./...` |
| Rust | `— (cargo)` | `cargo build --release` | `cargo fmt --check && cargo clippy` | `cargo test` | `cargo audit` |
| PHP | `composer install` | `— (interpretado)` | `php-cs-fixer fix --dry-run && phpstan` | `phpunit` | `composer audit` |

## Convenciones de pipeline

1. **PR Pipeline**: se ejecuta en cada Pull Request. DEBE pasar antes de poder hacer merge. Incluye build + tests + lint + security scan como mínimo.
2. **CI/CD Pipeline**: se ejecuta al hacer merge. DEV se despliega automáticamente. PRE y PRO siempre requieren aprobación humana.
3. **Rollback**: la pipeline de PRO siempre incluye un paso de rollback automático si el health check falla tras el despliegue.
4. **Secrets en pipelines**: las variables sensibles (connection strings, API keys) se almacenan en el servicio de secrets del CI/CD (Variable Groups en Azure DevOps, Secrets en GitHub Actions), nunca en el fichero de pipeline.
5. **Artefactos**: la pipeline de PR genera artefactos (binarios, imágenes Docker) que se reutilizan en la pipeline de CI/CD — no se reconstruye en cada entorno.

## Ejemplo: Azure DevOps Pipeline para proyecto .NET

```yaml
# deploy/pipelines/azure-pipelines.pr.yml
trigger: none
pr:
  branches:
    include: [main, develop]

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: UseDotNet@2
    inputs:
      version: '8.x'
  - script: dotnet restore
  - script: dotnet build --no-restore -c Release
  - script: dotnet format --verify-no-changes
  - script: dotnet test --no-build -c Release --filter Category=Unit
  - script: dotnet test --no-build -c Release --filter Category=Integration
  - script: dotnet list package --vulnerable --include-transitive
```

## Ejemplo: GitHub Actions para proyecto TypeScript/Node.js

```yaml
# .github/workflows/pr.yml
name: PR Validation
on:
  pull_request:
    branches: [main, develop]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run build
      - run: npx eslint .
      - run: npx prettier --check .
      - run: npm test
      - run: npm audit --audit-level=moderate
```

## Comandos de pipeline

| Comando | Descripción |
|---|---|
| `/infra-plan {proyecto} {env}` | Genera plan de infraestructura incluyendo pipelines |
| `/pr-review [PR]` | Revisión multi-perspectiva de PR (incluye validación de pipeline) |

---
