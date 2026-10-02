# Savia Space — espacio de trabajo local sobre las cúpulas

> **Spec**: SE-427 · **Estado**: 0.1 en curso (MVP funcional) · **Licencia**: la del repo
> **Lenguajes**: Rust (edition 2024) + Vue 3/TypeScript · **Modelo**: Ollama local

## Reglas del proyecto

- **Solo lectura** (ADR-002, addendum READ_ONLY): sin herramientas, sin efectos, solo loopback.
- **Datos**: en el repo solo corpus sintético N1 (`fixtures/n1`). Nunca notas reales.
- **Validación de citas**: nunca relajarla para que pase un modelo; arreglar el contrato de salida.
- **TDD**: cada `x.rs` con su `x.test.rs` (`#[cfg(test)] #[path = "x.test.rs"] mod tests;`).

## Estructura

| Ruta | Qué |
|---|---|
| `crates/space-contracts` | JSON estricto, JCS (RFC 8785), hashes, modelo de datos |
| `crates/space-store` | SQLite: sesiones, runs, eventos, capturas, retención |
| `crates/space-core` | Contexto, validación, decodificador, runtime (FSM de runs) |
| `crates/space-server` | Binario `savia-space`: API HTTP, SSE, emparejado, Ollama, Vaults |
| `apps/web` | Cliente Vue (inspector de bytes exactos, SSE, citas) |
| `fixtures/n1` | Corpus sintético |

## Comandos

```bash
cargo test --workspace && cargo clippy --workspace --all-targets -- -D warnings && cargo fmt --check
cd apps/web && npm ci && npm test && npm run build
SAVIA_SPACE_HOME=<dir> ./target/release/savia-space serve --web apps/web/dist
SAVIA_SPACE_HOME=<dir> ./target/release/savia-space pair   # código de un solo uso
```
