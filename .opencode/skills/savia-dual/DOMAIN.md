# Savia Dual — Dominio

## Por qué existe esta skill

Savia es la única interfaz de trabajo del usuario con pm-workspace. Si
Claude Code pierde conexión con Anthropic (cable caído, outage, cuota
agotada, latencia inaceptable), el usuario se queda sin herramienta.
Savia Dual elimina ese punto único de fallo añadiendo un cerebro local
que toma el relevo automáticamente cuando la nube falla.

## Conceptos de dominio

- **Soberanía de inferencia**: capacidad de ejecutar razonamiento del
  agente en infraestructura propia del usuario, sin depender de un
  proveedor externo. Complementa la soberanía de datos.
- **Upstream primario**: API de Anthropic. Calidad máxima, latencia baja.
- **Upstream de fallback**: Ollama local con variante gemma4. Calidad
  menor, latencia mayor, pero 100% disponible offline.
- **Trigger de fallback**: evento observable en la petición primaria que
  justifica enrutar al fallback (error de red, 5xx, 429, timeout).
- **Circuit breaker**: patrón de resiliencia que, tras N fallos
  consecutivos, corta temporalmente el upstream primario para evitar
  saturarlo y degradar aún más la experiencia.
- **Routing decision**: cada petición se enruta a uno de dos upstreams;
  la decisión queda registrada en un log auditable.

## Reglas de negocio que implementa

- **RN-SD-01**: La nube se usa siempre que responda correctamente dentro
  del timeout configurado. No hay modo "forzar local".
- **RN-SD-02**: Cualquier fallback debe registrarse con motivo explícito
  en `~/.savia/dual/events.jsonl`.
- **RN-SD-03**: Los logs NUNCA contienen prompts ni respuestas. Solo
  metadatos de routing (timestamp, upstream, status, latencia, motivo).
- **RN-SD-04**: El hardware del usuario se detecta localmente y nunca se
  persiste a ficheros versionados ni se transmite.
- **RN-SD-05**: Si ambos upstreams fallan, el proxy devuelve 503 con
  cuerpo JSON describiendo los dos errores — no hay silencio.

## Relación con otras skills

**Upstream** (lo que viene antes):
- `data-sovereignty` — configura la clasificación local de datos antes
  de permitir enviarlos a cloud. Savia Dual asume que esta capa ya
  filtra qué contenido sale de la máquina.

**Downstream** (lo que viene después):
- `emergency-mode` — sigue existiendo como modo manual completo (sin
  proxy, reemplazando `ANTHROPIC_BASE_URL` directamente). Savia Dual
  es el modo automático y transparente; emergency-mode es el manual.
- `memory-prune`, `context-compress` — operan sobre cualquier upstream.

**Paralelo**:
- `context-health` — monitoriza el uso de contexto; el proxy no afecta.
- `hook-profiles` — los hooks siguen ejecutándose independientemente del
  upstream que sirve la respuesta.

## Decisiones clave

- **Stdlib Python, no dependencias**: el proxy debe arrancar en cualquier
  máquina con Python 3.8+, sin `pip install` que pueda fallar offline.
  Descartado LiteLLM / claude-code-router por añadir superficie de ataque
  y dependencias. El proxy son ~300 líneas que se leen y auditan.
- **Ollama nativo /v1/messages**: Ollama 0.20.0 añadió endpoint Anthropic
  nativo. Elimina la necesidad de traducir OpenAI↔Anthropic. Requisito
  mínimo: Ollama ≥ 0.20.0.
- **gemma4 como familia local**: razonamiento multimodal, tamaños desde
  2B hasta 31B, licencia permisiva, soporte Ollama estable.
- **Variante por hardware, no por preferencia**: el usuario no elige
  manualmente el modelo; el installer decide según RAM/VRAM reales para
  evitar configuraciones que no arrancan o degradan drásticamente.
- **Puerto 8787**: evita colisión con Ollama (11434), Grafana (3000),
  proxies comunes (8080, 8888).
- **Sin autenticación propia**: el proxy escucha solo en 127.0.0.1. No
  es una superficie de red expuesta. Acceso vía loopback únicamente.
- **Logs JSONL, no DB**: auditabilidad máxima sin dependencias. El
  usuario puede `tail -f`, `grep`, `jq` y rotar con herramientas estándar.
- **Sin mocking del upstream caído**: si Anthropic falla por timeout, no
  cancelamos la petición y devolvemos un error falso. Esperamos la
  respuesta real (para aprender) y caemos a Ollama cuando corresponde.
