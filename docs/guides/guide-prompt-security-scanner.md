# Prompt Security Scanner

> Version: v4.7 | Era: 176 | Desde: 2026-04-03

## Que es

Analizador estatico que detecta vulnerabilidades de seguridad en prompts de agentes, skills y commands. Aplica 10 reglas (PS-01 a PS-10) usando regex puro — sin LLM, ejecucion instantanea. Identifica inyecciones de prompt, fugas de credenciales, secuestro de rol y otros vectores de ataque.

## Requisitos

Preinstalado desde v4.7. Sin dependencias externas.

## Uso basico

```bash
# Escanear un fichero
bash scripts/prompt-security-scan.sh .claude/agents/mi-agente.md

# Escanear un directorio completo
bash scripts/prompt-security-scan.sh .claude/agents/

# Modo silencioso (solo errores)
bash scripts/prompt-security-scan.sh --quiet .claude/

# Escanear con path especifico
bash scripts/prompt-security-scan.sh --path .claude/skills/
```

Salida tipica:
```
[PS-03] Role hijack pattern in agent-x.md:12
        "ignore previous instructions"
        Severity: HIGH
```

## Las 10 reglas

| Regla | Detecta |
|-------|---------|
| PS-01 | Inyeccion de prompt (bait patterns) |
| PS-02 | Exfiltracion de datos (leakage) |
| PS-03 | Secuestro de rol (role hijack) |
| PS-04 | Fuga de credenciales |
| PS-05 | Ejecucion de codigo arbitrario |
| PS-06 | Blobs base64 sospechosos |
| PS-07 | Datos personales (PII) en prompts |
| PS-08 | Modelo no especificado en frontmatter |
| PS-09 | Herramientas wildcard (acceso excesivo) |
| PS-10 | Patrones combinados de riesgo |

## Integracion

- **validate-ci-local.sh**: el scanner se ejecuta como parte de la validacion CI local
- **commit-guardian**: puede invocar el scanner en pre-commit para ficheros staged en `.claude/`
- **prompt-security-scan.sh --quiet**: modo CI, retorna exit code 1 si encuentra hallazgos criticos

## Configuracion

No requiere configuracion. Las 10 reglas estan hardcoded como regex para garantizar determinismo.

Para excluir un fichero del scan, se puede usar `--path` apuntando solo al directorio relevante.

## Troubleshooting

**Falso positivo**: revisar el patron detectado. Si es un ejemplo documentado (dentro de un bloque de codigo), el scanner puede detectarlo. Usar `--quiet` para filtrar solo criticos.

**No detecta un patron conocido**: verificar que el fichero tiene extension `.md`. El scanner solo procesa markdown.

**Integracion con CI falla**: verificar que `scripts/prompt-security-scan.sh` tiene permisos de ejecucion: `chmod +x scripts/prompt-security-scan.sh`
