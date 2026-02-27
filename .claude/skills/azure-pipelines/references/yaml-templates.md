# Templates YAML para Azure Pipelines

> Plantillas base para pipelines comunes. Adaptar al lenguaje y proyecto.

---

## 1. Build + Test (genérico)

```yaml
trigger:
  branches:
    include: [main, develop]
  paths:
    exclude: [docs/*, README.md]

pool:
  vmImage: 'ubuntu-latest'

stages:
  - stage: Build
    jobs:
      - job: BuildAndTest
        steps:
          - task: UseDotNet@2       # Ajustar al lenguaje
            inputs:
              version: '8.x'
          - script: dotnet build --configuration Release
            displayName: 'Build'
          - script: dotnet test --configuration Release --collect:"XPlat Code Coverage"
            displayName: 'Test'
          - task: PublishTestResults@2
            inputs:
              testResultsFormat: 'VSTest'
              testResultsFiles: '**/*.trx'
          - task: PublishCodeCoverageResults@2
            inputs:
              summaryFileLocation: '**/coverage.cobertura.xml'
```

## 2. Build + Deploy multi-entorno

```yaml
trigger:
  branches:
    include: [main]

variables:
  - group: 'common-variables'

stages:
  - stage: Build
    jobs:
      - job: Build
        steps:
          - script: echo "Build steps here"
          - task: PublishBuildArtifacts@1
            inputs:
              PathtoPublish: '$(Build.ArtifactStagingDirectory)'
              ArtifactName: 'drop'

  - stage: DeployDEV
    dependsOn: Build
    condition: succeeded()
    jobs:
      - deployment: Deploy
        environment: 'DEV'
        strategy:
          runOnce:
            deploy:
              steps:
                - script: echo "Deploy to DEV"

  - stage: DeployPRE
    dependsOn: DeployDEV
    condition: succeeded()
    jobs:
      - deployment: Deploy
        environment: 'PRE'    # Requires approval gate
        strategy:
          runOnce:
            deploy:
              steps:
                - script: echo "Deploy to PRE"

  - stage: DeployPRO
    dependsOn: DeployPRE
    condition: succeeded()
    jobs:
      - deployment: Deploy
        environment: 'PRO'    # Requires PM + PO approval
        strategy:
          runOnce:
            deploy:
              steps:
                - script: echo "Deploy to PRO"
```

## 3. PR Validation

```yaml
trigger: none
pr:
  branches:
    include: [main, develop]

pool:
  vmImage: 'ubuntu-latest'

jobs:
  - job: Validate
    steps:
      - script: echo "Lint + Build + Test"
      - script: echo "Security scan"
      - script: echo "Code coverage check >= $(TEST_COVERAGE_MIN)"
```

## 4. Scheduled (nightly)

```yaml
trigger: none
schedules:
  - cron: '0 2 * * 1-5'
    displayName: 'Nightly build'
    branches:
      include: [main]
    always: true

stages:
  - stage: NightlyBuild
    jobs:
      - job: FullSuite
        timeoutInMinutes: 60
        steps:
          - script: echo "Full test suite + integration tests"
          - script: echo "Dependency vulnerability scan"
          - script: echo "Performance benchmarks"
```

---

## Selección de template

| Caso | Template | Trigger |
|---|---|---|
| Proyecto nuevo sin deploy | Build + Test | Push a main/develop |
| Proyecto con entornos | Build + Deploy multi-entorno | Push a main |
| Validación de PRs | PR Validation | PR a main/develop |
| Tests nocturnos | Scheduled | Cron L-V 02:00 |
