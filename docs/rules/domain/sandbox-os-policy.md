---
context_tier: L2
spec: SPEC-149
---

# Sandbox OS-level Policy (SPEC-149)

Defensa en profundidad: 3 capas para modos autonomos de Savia.

## Capa A -- application (permission block)

opencode.json bloquea comandos destructivos en bash (deny rules).
Caveat: capa A sola es bypasseable (bug feb-2026). Requiere Capa B.

## Capa B -- kernel (opencode-sandbox)

Plugin opencode-sandbox (npm, MIT). Linux: bubblewrap. macOS: Seatbelt.

Declarar en opencode.json: {"plugin": ["opencode-sandbox"]}

Linux prerequisite: sudo apt install bubblewrap socat

Ubuntu 24.04+ AppArmor fix:
  sudo apt install apparmor-profiles
  sudo ln -s /etc/apparmor.d/bwrap-userns-restrict /etc/apparmor.d/force-complain/bwrap-userns-restrict
  sudo apparmor_parser -r /etc/apparmor.d/bwrap-userns-restrict

## Capa C -- Docker Sandboxes (opcional)

Para pentesting/research. Mounting controlado: solo REPO, sin credenciales.

## Policy files

Ubicacion: .opencode/sandbox-policies/{mode}.yaml
Modos: default-readonly, overnight-sprint, code-improvement-loop, tech-research-agent, pentesting

Para anadir dominio a allowlist: editar el yaml del modo en network.allow_domains.

## Verificar

  bash scripts/savia-sandbox-doctor.sh

## Limitaciones

- permission.bash sola es bypasseable (bug feb-2026)
- Capa B no protege contra MCP servers maliciosos fuera del sandbox
- Kernel escapes no cubiertos
- Secretos en memoria del proceso no protegidos

El sandbox es defensa en profundidad, no garantia absoluta.
autonomous-safety.md sigue siendo obligatorio.