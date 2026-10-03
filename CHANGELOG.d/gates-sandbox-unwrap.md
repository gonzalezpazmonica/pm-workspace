---
version_bump: patch
section: Security
---

### Security

- savia-gates: los guards PreToolUse evalúan el comando original y el desenvuelto cuando un plugin de sandbox (opencode-sandbox) lo envuelve antes; basta con que uno bloquee. Antes, con el sandbox delante, `rm -rf` y `sudo` pasaban sin bloqueo.

