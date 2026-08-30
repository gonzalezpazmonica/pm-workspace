# poc-verify oracles (SE-351)

Directorios de oráculos de verificación binaria para `scripts/poc-verify.sh`.
Cada JSON define un target + oráculo de éxito evaluado **programáticamente**
(exit code, regex, o ambos) — independiente del juicio del LLM. Lección CyberGym:
"el programa decide, no el agente".

## Formato

```json
{
  "name": "nombre-descriptivo",
  "target": {
    "type": "command | docker | http",
    "command": "comando a ejecutar; {poc} se sustituye por la ruta del PoC",
    "docker_image": "imagen (solo type=docker)",
    "timeout_secs": 10,
    "network": "none | host"
  },
  "oracle": {
    "mode": "exit_code_nonzero | regex | combined",
    "expected_exit": 1,
    "regex": "patrón a buscar en el output",
    "require_all": true
  }
}
```

## Modos de oráculo

| mode | Regla de éxito |
|---|---|
| `exit_code_nonzero` | exit code ≠ 0 (y ≠ `expected_exit`) |
| `regex` | el output matchea `regex` |
| `combined` | exit≠0 Y/O regex según `require_all` |

## Seguridad (CRIT-001)

- Los PoCs se ejecutan **solo** en entornos controlados del workspace
  (Docker local con `network=none`, o comando local time-boxed).
- **NUNCA** contra producción sin autorización escrita (reglas skill pentesting §4).
- El recibo solo guarda un preview acotado del output (2 KB) — sin datos N3+ completos.
- Cero llamadas a proveedor cloud.

## Ejemplos

- `example.json` — target de comando con oráculo combinado (demo).
