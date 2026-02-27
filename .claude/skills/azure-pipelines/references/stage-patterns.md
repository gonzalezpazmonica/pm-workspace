# Patrones de Stages Multi-Entorno

> Patrones para pipelines con deploy a DEV/PRE/PRO.

---

## 1. Flujo estándar (3 entornos)

```
Build → Test → Deploy DEV → Deploy PRE → Deploy PRO
         │         │              │              │
         │    (automático)   (approval:      (approval:
         │                   tech-lead)      PM + PO)
         │
    coverage >= 80%
```

### Gates de aprobación

| Entorno | Gate | Aprobadores | Timeout |
|---|---|---|---|
| DEV | Automático | Ninguno (si build OK) | — |
| PRE | Manual | Tech Lead del proyecto | 48h |
| PRO | Manual (doble) | PM + Product Owner | 72h |

### Conditions recomendadas

```yaml
# Deploy DEV: solo si build OK
condition: succeeded()

# Deploy PRE: solo si DEV OK + rama main
condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))

# Deploy PRO: solo si PRE OK + tag de release
condition: and(succeeded(), startsWith(variables['Build.SourceBranch'], 'refs/tags/v'))
```

---

## 2. Patrón Canary (PRO)

```yaml
- stage: DeployPRO_Canary
  dependsOn: DeployPRE
  jobs:
    - deployment: Canary
      environment: 'PRO-Canary'
      strategy:
        canary:
          increments: [10, 50]
          deploy:
            steps:
              - script: echo "Deploy canary"
          on:
            success:
              steps:
                - script: echo "Promote to 100%"
            failure:
              steps:
                - script: echo "Rollback canary"
```

---

## 3. Patrón Blue-Green (PRO)

```
1. Deploy a slot "staging" (Blue)
2. Smoke tests automáticos
3. Swap slots (Blue ↔ Green)
4. Si falla → swap back (rollback instantáneo)
```

---

## 4. Variables por entorno

```yaml
variables:
  - name: environment
    value: 'DEV'
  - ${{ if eq(variables['Build.SourceBranch'], 'refs/heads/main') }}:
    - group: 'pre-variables'
    - name: environment
      value: 'PRE'
  - ${{ if startsWith(variables['Build.SourceBranch'], 'refs/tags/') }}:
    - group: 'pro-variables'
    - name: environment
      value: 'PRO'
```

---

## 5. Integración con PM-Workspace

| Evento pipeline | Acción PM-Workspace |
|---|---|
| Build fallida | `/pipeline:logs` → investigar → crear Bug si recurrente |
| Deploy PRE OK | Notificar equipo → preparar Sprint Review demo |
| Deploy PRO OK | Actualizar PBI state → Closed |
| Approval pendiente | `/pipeline:status` muestra alerta |
| Coverage < 80% | Alerta en `/kpi:dashboard` |
