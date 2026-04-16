# Spec: Savia Dual N-Upstream — Failover en cascada Anthropic -> Qwen -> Ollama

**Task ID:**        SPEC-SAVIA-DUAL-NUPSTREAM
**PBI padre:**      Inference sovereignty expansion
**Sprint:**         2026-08
**Fecha creacion:** 2026-04-11
**Creado por:**     Savia (research: github.com/QwenLM/qwen-code)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     8h
**Estado:**         Pendiente
**Max turns:**      35
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

Savia Dual actual (ver `savia-dual.md`) es un proxy 2-upstream hardcoded:
Anthropic primario -> Ollama fallback. qwen-code publica `modelProviders`
declarativos en `~/.qwen/settings.json` con OAuth tier gratuito 1000
req/dia para Qwen3-Coder.

Implicaciones para pm-workspace:

1. **Tier intermedio gratuito**: entre Anthropic (calidad maxima) y Ollama
   local (calidad menor), Qwen OAuth da un tercer nivel razonable sin
   coste marginal.
2. **Agentes Haiku-tier pueden moverse a Qwen**: `tech-writer`,
   `azure-devops-operator`, `commit-guardian` hacen tareas simples donde
   Qwen3-Coder es suficiente.
3. **Failover mas robusto**: cascada 3-nivel en vez de 2 reduce la
   probabilidad de quedarse sin upstream utilizable.

**Objetivo:** extender el proxy Savia Dual para soportar lista declarativa
de N providers con cascada en orden. Configuracion en
`~/.savia/dual/config.json` con schema versionado.

**Criterios de Aceptacion:**
- [ ] `savia-dual-proxy.py` lee lista `providers[]` en vez de 2 hardcoded
- [ ] Cascada configurable: Anthropic -> Qwen OAuth -> Ollama
- [ ] `setup-savia-dual.sh` detecta disponibilidad de Qwen OAuth
- [ ] `events.jsonl` registra el provider utilizado por request
- [ ] Circuit breaker independiente por provider
- [ ] Backward compat: configs antiguos de 2 providers siguen funcionando
- [ ] Test BATS con >=80 score

---

## 2. Contrato Tecnico

### 2.1 Schema de config

```json
{
  "schema_version": 2,
  "listen": "127.0.0.1:8787",
  "providers": [
    {
      "id": "anthropic",
      "type": "anthropic",
      "base_url": "https://api.anthropic.com",
      "api_key_file": "~/.anthropic/api-key",
      "priority": 1,
      "triggers": {
        "network_error": true,
        "http_5xx": true,
        "http_429": true,
        "timeout_seconds": 30
      },
      "circuit_breaker": {
        "failure_threshold": 3,
        "cooldown_seconds": 60
      }
    },
    {
      "id": "qwen-oauth",
      "type": "anthropic",
      "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
      "oauth_token_file": "~/.qwen/oauth-token",
      "priority": 2,
      "daily_quota": 1000,
      "triggers": { "network_error": true, "timeout_seconds": 45 }
    },
    {
      "id": "ollama",
      "type": "ollama",
      "base_url": "http://localhost:11434/v1",
      "model": "gemma4:e4b",
      "priority": 3,
      "triggers": { "always_last_resort": true }
    }
  ]
}
```

Schema v2 es backward compat: si el proxy ve v1 (solo `primary`/`fallback`),
lo migra automaticamente a v2 en memoria.

### 2.2 Logica de enrutamiento

```
for provider in sorted(providers, key=priority):
  if provider.circuit_breaker_open:
    continue
  if provider.daily_quota_exceeded:
    continue
  try:
    response = forward_request(provider, request)
    record_success(provider)
    return response
  except TriggerMatched as e:
    record_failure(provider, reason=e)
    continue

raise NoProviderAvailableError
```

### 2.3 Daily quota tracking

Para providers con `daily_quota` (Qwen OAuth tiene 1000 req/dia):

```
$HOME/.savia/dual/quota/{provider_id}.json
{
  "date": "2026-04-11",
  "count": 42,
  "limit": 1000
}
```

A las 00:00 UTC se resetea el contador.

### 2.4 setup-savia-dual.sh extendido

```bash
# Detectar Qwen OAuth
if [[ -f ~/.qwen/oauth-token ]]; then
  add_provider qwen-oauth priority=2
  echo "Qwen OAuth detected: 1000 req/day free tier"
elif ask_yes_no "Setup Qwen OAuth tier (1000 req/day free)?"; then
  run_qwen_oauth_setup
  add_provider qwen-oauth priority=2
fi

# Ollama siempre al final
add_provider ollama priority=last
```

### 2.5 events.jsonl extendido

```json
{"ts":"2026-04-11T10:00:00Z","provider":"anthropic","route":"anthropic","status":200,"latency_ms":420}
{"ts":"2026-04-11T10:01:00Z","provider":"qwen-oauth","route":"qwen-oauth","status":200,"fallback_reason":"http_429","fallback_from":"anthropic","latency_ms":1200}
{"ts":"2026-04-11T10:02:00Z","provider":"ollama","route":"ollama","status":200,"fallback_reason":"daily_quota_exceeded","fallback_from":"qwen-oauth","latency_ms":5400}
```

### 2.6 Circuit breaker por provider

Cada provider tiene su propio breaker independiente. Un fallo en Anthropic
NO abre el breaker de Qwen. Permite cascada limpia incluso con un provider
totalmente caido.

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| SDN-01 | Providers ordenados por priority (1=primary) | Cascada incorrecta |
| SDN-02 | Daily quota respetado, reset 00:00 UTC | Overuse facturable |
| SDN-03 | Circuit breaker independiente por provider | Cascada rota |
| SDN-04 | Ollama siempre disponible como last resort | Single point of failure |
| SDN-05 | Schema v1 migrable a v2 sin perdida | Rotura usuarios existentes |
| SDN-06 | events.jsonl NUNCA contiene prompts o respuestas | Fuga de contenido |
| SDN-07 | Qwen OAuth token file gitignored | Filtracion credencial |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Dependencias | Python stdlib (sin cambios vs version actual) |
| Compatibilidad | v1 configs siguen funcionando (migration in-memory) |
| Performance | Overhead <10ms por request (lookup + quota check) |
| Privacidad | Zero envio de hardware specs o prompts fuera |
| Seguridad | Tokens en ficheros 0600, no en env vars |

---

## 5. Test Scenarios

### Cascada completa — Anthropic OK

```
GIVEN   3 providers configurados, todos operativos
WHEN    request al proxy
THEN    Anthropic responde
AND     events.jsonl registra provider=anthropic
AND     Qwen y Ollama no invocados
```

### Anthropic 429 -> Qwen

```
GIVEN   Anthropic devuelve 429
WHEN    request al proxy
THEN    Qwen invocado como fallback
AND     events.jsonl registra fallback_reason=http_429
AND     Ollama no invocado
```

### Qwen quota exceeded -> Ollama

```
GIVEN   Qwen daily_quota = 0 restante
WHEN    Anthropic falla y request cae a Qwen
THEN    Qwen se salta por quota
AND     Ollama invocado
AND     events.jsonl registra fallback_reason=daily_quota_exceeded
```

### Migracion v1 -> v2

```
GIVEN   config.json antiguo con primary/fallback
WHEN    proxy arranca
THEN    migra en memoria a schema v2
AND     funciona identico al comportamiento antiguo
AND     log "migrated v1 -> v2"
```

### Circuit breaker independiente

```
GIVEN   3 fallos consecutivos en Anthropic
WHEN    request al proxy
THEN    Anthropic breaker abierto, Qwen invocado directamente
AND     Anthropic no se intenta durante cooldown
AND     Qwen breaker permanece cerrado
```

### Daily quota reset

```
GIVEN   Qwen quota=1000 usada, fecha=2026-04-11
WHEN    llega 00:00 UTC del dia siguiente
THEN    quota=0 usada, date=2026-04-12
AND     Qwen vuelve a estar disponible
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Modificar | scripts/savia-dual-proxy.py | Logica N-upstream + quota |
| Modificar | scripts/setup-savia-dual.sh | Detectar y configurar Qwen |
| Crear | scripts/qwen-oauth-setup.sh | Setup OAuth Qwen |
| Modificar | docs/rules/domain/savia-dual.md | Documentar N-upstream |
| Crear | tests/test-savia-dual-nupstream.bats | Suite BATS |
| Crear | docs/savia-dual-providers.md | Guia de providers disponibles |
| Modificar | .gitignore | ~/.qwen/oauth-token |

---

## 7. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Disponibilidad | 99.9% (alguno de 3 up) | events.jsonl analysis |
| Qwen utilization | 10-30% en workload tipico | events stats |
| Anthropic primary | >=80% | events stats |
| Ollama last resort | <5% | events stats |
| Migration v1->v2 | 100% sin intervencion | Test automatizado |
| Quota precision | 100% (zero overuse) | quota.json audit |

---

## Checklist Pre-Entrega

- [ ] Schema v2 documentado y migrable
- [ ] Cascada 3-nivel funcional
- [ ] Qwen OAuth setup asistido
- [ ] Daily quota tracking con reset UTC
- [ ] Circuit breakers independientes
- [ ] Backward compat v1 verificado
- [ ] events.jsonl sin contenido sensible
- [ ] Tests BATS >=80 score
