# Guia de Savia Shield — Proteccion de datos para el dia a dia

> Uso practico. Para arquitectura tecnica: [docs/savia-shield.md](savia-shield.md)

## Que es Savia Shield

Savia Shield impide que datos confidenciales de proyectos de cliente (nivel N4/N4b) se filtren a ficheros publicos del repositorio (nivel N1). Opera con 5 capas independientes, cada una auditable. Esta desactivado por defecto y se activa cuando empiezas a trabajar con datos de clientes.

## Los 4 perfiles de hooks

Los perfiles controlan que hooks se ejecutan. Cada perfil incluye al anterior:

| Perfil | Hooks activos | Caso de uso |
|--------|--------------|-------------|
| `minimal` | Solo blockers de seguridad (credenciales, force-push, infra destructiva, soberania) | Demos, onboarding, debugging |
| `standard` | Seguridad + calidad (validacion bash, plan gate, TDD, scope guard, compliance) | Trabajo diario (recomendado) |
| `strict` | Standard + dispatch validation, quality gate al parar, competence tracker | Antes de releases, codigo critico |
| `ci` | Igual que standard pero sin interactividad | Pipelines automaticos, scripts |

```bash
bash scripts/hook-profile.sh get           # Ver perfil activo
bash scripts/hook-profile.sh set standard  # Cambiar (persiste entre sesiones)
export SAVIA_HOOK_PROFILE=ci               # O con variable de entorno
```

Hooks de seguridad que corren en TODOS los perfiles: `block-credential-leak.sh`, `block-force-push.sh`, `block-infra-destructive.sh`, `data-sovereignty-gate.sh`.

---

## Las 5 capas de proteccion

**Capa 0 — Proxy API**: Intercepta prompts salientes a Anthropic. Enmascara entidades automaticamente. Activar con `export ANTHROPIC_BASE_URL=http://127.0.0.1:8443`.

**Capa 1 — Gate determinista** (< 2s): Hook PreToolUse que escanea contenido antes de escribir ficheros publicos. Regex para credenciales, IPs, tokens. Incluye NFKC y base64.

**Capa 2 — Clasificacion local con LLM**: Ollama qwen2.5:7b clasifica texto semantico como CONFIDENTIAL o PUBLIC. Datos nunca salen de localhost. Sin Ollama, solo opera Capa 1.

**Capa 3 — Auditoria post-escritura**: Hook asincrono que re-escanea el fichero completo. No bloquea. Alerta inmediata si detecta fuga.

**Capa 4 — [DEPRECIADA] Masking manual eliminado**

El masking manual (`sovereignty-mask.sh`) fue eliminado el 2026-05-05.  
La Capa 4 (Proxy) mantiene su propio masking interno en `savia-shield-proxy.py`.  
Este slot queda reservado para una alternativa futura.

---

## Activar y desactivar

```bash
/savia-shield enable    # Activar
/savia-shield disable   # Desactivar
/savia-shield status    # Ver estado e instalacion
```

O editando `.claude/settings.local.json`:

```json
{ "env": { "SAVIA_SHIELD_ENABLED": "true" } }
```

## Configuracion por proyecto

Cada proyecto puede definir entidades sensibles en:

- `projects/{nombre}/GLOSSARY.md` — terminos de dominio
- `projects/{nombre}/GLOSSARY-MASK.md` — entidades para masking
- `projects/{nombre}/team/TEAM.md` — nombres de stakeholders

Shield carga estos ficheros automaticamente al operar sobre el proyecto.

## Instalacion completa (opcional)

Para las 5 capas incluyendo proxy y NER:

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

Requisitos: Python 3.12+, Ollama, jq, 8GB RAM minimo. Sin instalacion completa: las capas 1 y 3 (regex + auditoria) operan siempre.

## Los 5 niveles de confidencialidad

| Nivel | Quien ve | Ejemplo |
|-------|----------|---------|
| N1 Publico | Internet | Codigo del workspace |
| N2 Empresa | La organizacion | Config de la org |
| N3 Usuario | Solo tu | Tu perfil |
| N4 Proyecto | Equipo del proyecto | Datos del cliente |
| N4b PM-Only | Solo la PM | One-to-ones |

Shield protege las fronteras **N4/N4b hacia N1**. Escribir en ubicaciones privadas siempre esta permitido.

## Mejoras Era 171 (SPEC-071)

- **Cobertura de eventos**: 17 de 28 eventos de Claude Code cubiertos (61%, antes 25%)
- **Condiciones `if`**: 7 hooks saltan automaticamente si el fichero no es codigo (ahorra ~40% de spawns)
- **Nuevos eventos**: SubagentStart/Stop, TaskCreated/Completed, FileChanged, InstructionsLoaded, ConfigChange
- **Portabilidad**: eliminadas todas las rutas `/tmp/` hardcodeadas y `sed -i` incompatibles
- **Timeout auditable**: si el daemon tarda >5s, se registra como TIMEOUT_ALLOW en el audit log

> Arquitectura completa: [docs/savia-shield.md](savia-shield.md) | Tests: `bats tests/test-data-sovereignty.bats`
