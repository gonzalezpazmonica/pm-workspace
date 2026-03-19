# Regla: Politicas Declarativas de Agentes

> Inspirado en NVIDIA NemoClaw: sandbox orchestration con politicas YAML hot-reloadable.
> Complementa autonomous-safety.md con control granular por proyecto.

---

## Principio

Cada proyecto puede definir politicas que restringen lo que los agentes pueden hacer.
Las politicas son declarativas (YAML), validables antes de ejecucion, y auditables.

## Fichero de politicas por proyecto

Ruta: `projects/{proyecto}/agent-policies.yaml`

```yaml
# Ejemplo de politicas
paths:
  allowed:
    - "projects/{proyecto}/"
    - "output/"
  denied:
    - "config.local/"
    - "*.pat"
    - "*.secret"
    - "*.key"
    - "*.pem"

actions:
  require_approval:
    - delete_file
    - force_push
    - modify_config
    - install_dependency
    - execute_migration
  auto_allow:
    - read_file
    - search_code
    - run_tests
    - generate_report

limits:
  max_execution_minutes: 15
  max_files_modified: 20
  max_lines_changed: 500

network:
  allowed_hosts:
    - "dev.azure.com"
    - "github.com"
    - "api.anthropic.com"
  denied_hosts:
    - "*"  # deny-by-default
```

## Politica por defecto (sin fichero)

Si un proyecto no tiene `agent-policies.yaml`, aplican defaults conservadores:
- Paths: solo el directorio del proyecto + output/
- Actions: todo requiere aprobacion excepto lectura
- Limits: 15 min, 10 ficheros, 300 lineas
- Network: solo hosts ya configurados en pm-config

## Validacion

Antes de ejecutar un agente, verificar:
1. Leer politica del proyecto activo (o usar defaults)
2. Comparar accion solicitada contra `actions.require_approval`
3. Comparar paths afectados contra `paths.allowed` y `paths.denied`
4. Si violacion: registrar en `output/policy-violations.jsonl` y escalar

## Formato de violacion

```json
{
  "timestamp": "2026-03-19T02:00:00Z",
  "agent": "dotnet-developer",
  "project": "alpha",
  "action": "modify_config",
  "path": "config.local/secrets.env",
  "policy_rule": "paths.denied",
  "resolution": "blocked"
}
```

## Integracion

- **autonomous-safety.md**: politicas complementan las reglas inmutables de seguridad
- **commit-guardian**: verifica politicas antes de commit en modos autonomos
- **overnight-sprint**: carga politicas del proyecto al iniciar sesion nocturna
- `/policy-check`: muestra politicas activas y su estado

## Jerarquia de precedencia

1. Reglas inmutables de autonomous-safety.md (SIEMPRE prevalecen)
2. Politicas del proyecto (agent-policies.yaml)
3. Defaults conservadores (sin fichero)
