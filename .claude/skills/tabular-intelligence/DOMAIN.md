# tabular-intelligence — Domain knowledge

## Origin

Inspirado en TFMs (TabPFN, TabICL, KumoRFM). Los TFMs predicen. Savia describe.

## Enforcement (4 capas)

1. Pre-LLM hook: detecta >5 filas, sustituye por perfil
2. RESOLVER routing: intencion tabular → tabular-intelligence
3. Agent prompt: agentes de datos exigen tabular_query
4. Self-audit: post-turno verifica uso de herramienta

## When NOT to use

- <5 filas (coste > beneficio)
- Datos no estructurados (texto)
- Prediccion (usar TFM especializado)
