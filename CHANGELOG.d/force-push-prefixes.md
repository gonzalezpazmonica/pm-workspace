---
version_bump: patch
section: Security
---

### Security

- block-force-push: «git push --force», «push origin main», «commit --amend» y «reset --hard» ya no se esquivan con prefijos (VAR=valor, env, command, sudo), subshell o «git -C dir»; las menciones dentro de mensajes o echo siguen sin bloquear.

