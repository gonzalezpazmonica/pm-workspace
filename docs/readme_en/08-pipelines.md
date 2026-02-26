# Pipeline Definition (PR and CI/CD)

The workspace allows defining PR validation and CI/CD pipelines so Claude can generate, review, and maintain them correctly.

## How to define pipelines

In each project's `CLAUDE.md`, add a `pipeline_config` section:

```yaml
# In projects/{project}/CLAUDE.md

pipeline_config:
  # ── CI/CD Platform ────────────────────────────────────────
  platform: "azure-devops"        # azure-devops | github-actions | gitlab-ci

  # ── Pull Request Pipeline (validation) ─────────────────────
  pr_pipeline:
    trigger: "pull_request"
    target_branches: ["main", "develop"]
    steps:
      - name: "Restore dependencies"
        command: "dotnet restore"        # Adjust to project language
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

  # ── CI/CD Pipeline (deployment) ────────────────────────────
  cicd_pipeline:
    environments:
      - name: "DEV"
        trigger: "auto"               # Automatic on merge
        approval_required: false
        steps:
          - "restore"
          - "build"
          - "test"
          - "docker-build"
          - "docker-push"
          - "deploy"

      - name: "PRE"
        trigger: "manual"             # Manual or approval-based
        approval_required: true
        steps:
          - "docker-pull"
          - "deploy"
          - "smoke-test"
          - "integration-test"

      - name: "PRO"
        trigger: "manual"
        approval_required: true
        approvers: ["tech-lead", "pm"]  # Double approval for production
        steps:
          - "docker-pull"
          - "deploy"
          - "smoke-test"
          - "health-check"
          - "rollback-if-fail"
```

## Pipeline steps by language

Claude generates pipelines adapted to each language's conventions:

| Language | Build | Lint | Test | Security |
|---|---|---|---|---|
| C#/.NET | `dotnet build` | `dotnet format --verify` | `dotnet test` | `dotnet list package --vulnerable` |
| TypeScript | `npm run build` | `eslint . && prettier --check` | `vitest run` | `npm audit` |
| Java/Spring | `mvn package -DskipTests` | `mvn checkstyle:check` | `mvn test` | `mvn dependency-check:check` |
| Python | `— (interpreted)` | `ruff check . && mypy .` | `pytest` | `safety check` |
| Go | `go build ./...` | `golangci-lint run` | `go test ./...` | `govulncheck ./...` |
| Rust | `cargo build --release` | `cargo fmt --check && cargo clippy` | `cargo test` | `cargo audit` |
| PHP | `— (interpreted)` | `php-cs-fixer fix --dry-run && phpstan` | `phpunit` | `composer audit` |

## Pipeline conventions

1. **PR Pipeline**: runs on every Pull Request, must pass before merge. Includes: build + tests + lint + security scan.
2. **CI/CD Pipeline**: runs on merge. DEV is automatic. PRE and PRO always require human approval.
3. **Rollback**: PRO pipeline always includes automatic rollback if health check fails after deployment.
4. **Secrets**: sensitive variables (connection strings, API keys) go in the CI/CD platform's secret store, never in pipeline files.
5. **Artifacts**: PR pipeline generates artifacts (binaries, Docker images) that are reused in CI/CD — no rebuild per environment.
