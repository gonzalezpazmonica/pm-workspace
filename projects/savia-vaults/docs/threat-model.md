# SaviaVaults — Threat Model

> Based on SE-286 S3. Documents what is protected, what is NOT protected,
> and the threat actor model for a local-first context dome server.

## Protected

| Asset | Protection |
|---|---|
| Vault contents on disk | Path sandbox (traversal, symlink, deny list, allow list, depth, size) |
| Content provenance | Ed25519 signing on writes (placeholder in v0.1.0; full crypto in next iteration) |
| Server availability | Rate limiter (token bucket per client, max 100/min configurable) |
| Agent prompt integrity | Content served as data; never interpreted as instruction |

## NOT Protected

| Threat | Rationale |
|---|---|
| Compromised local process | If attacker has filesystem access, vault is readable. SaviaVaults is a server, not a DRM system. |
| Network interception (no TLS) | A2A server binds to loopback by default. Network exposure requires explicit flag and TLS (not yet implemented in v0.1.0). |
| Malicious content in vault | Content is served as-is. SaviaVaults does not scan or filter content. Agents consuming content are responsible for their own prompt safety. |
| Denial of service from local process | Rate limiter protects against agent loops. A local process with root can bypass filesystem limits. |

## Threat Actors

| Actor | Capability | Mitigation |
|---|---|---|
| Malicious local process | Can read filesystem, intercept loopback traffic | None (out of scope). SaviaVaults trusts the host machine. |
| Compromised AI agent | Can send MCP/A2A requests, attempt traversal | Path sandbox blocks traversal; rate limiter caps request rate |
| Poisoned vault content | Content contains injection payloads | Served as data, never interpreted; content-as-data principle |
| Hostile MCP client | Can connect to MCP transport | stdin/stdout transport is inherently single-client; trust boundary is the OS process boundary |
| Network attacker (if bound to non-loopback) | Can sniff HTTP traffic | Requires explicit flag + TLS (future); loopback default prevents exposure |

## Content-as-Data Guarantee

SaviaVaults guarantees: documents from the vault are delivered as-is to the
requesting agent. The server does NOT interpret, modify, or execute vault
content. A document containing "ignore all previous instructions" is served
verbatim. The consuming agent is responsible for its own prompt safety.

This principle is inherited from SE-273 S5 of the Savia ecosystem.

## Loopback Default

SaviaVaults binds to `127.0.0.1` by default. Binding to a network interface
requires an explicit `--host 0.0.0.0` flag which emits a warning. This is a
fail-closed default (CRIT-023).
