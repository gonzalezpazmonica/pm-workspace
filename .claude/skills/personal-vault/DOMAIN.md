# Personal Vault — Contexto de Dominio

## Por que existe esta skill

Los datos personales del usuario (perfil, preferencias, memoria, instintos)
estaban dispersos en 5+ ubicaciones sin versionado, sin portabilidad y sin
separacion formal del codigo publico ni de los datos de proyecto. El vault
los consolida en un unico repositorio git con nivel de confidencialidad N3.

## Conceptos de dominio

- **Vault**: repositorio git personal en `~/.savia/personal-vault/`
- **Junction/Symlink**: enlace del sistema de ficheros que conecta la ubicacion
  original (donde Savia espera el fichero) con el vault (donde realmente vive)
- **N3 (USUARIO)**: nivel de confidencialidad para datos solo visibles por la
  persona usuaria del workspace
- **Profile fragment**: fichero individual del perfil (identity, tone, workflow, etc.)
- **Sync**: commit + push del vault a su remote git

## Reglas de negocio que implementa

- **RN-CONF-01**: cada nivel de confidencialidad tiene su propio repo git
- **RN-CONF-02**: datos N3 NUNCA se mezclan con N1 (publico), N2 (empresa) ni N4 (proyecto)
- **RN-VAULT-01**: el vault es fuente de verdad; las ubicaciones originales son punteros
- **RN-VAULT-02**: la migracion de datos es reversible (vault-export + vault-restore)

## Relacion con otras skills

- **Upstream**: profile-onboarding (crea perfil → sugiere vault-init)
- **Upstream**: session-init (verifica salud del vault al arrancar)
- **Downstream**: backup-protocol (vault-export reutiliza cifrado AES-256)
- **Downstream**: travel-pack (incluye vault en paquete portable)
- **Paralelo**: context-caching (cache de sesion vive en vault/cache/)

## Decisiones clave

- **Junctions sobre copias**: evita drift entre ubicacion original y vault.
  Coste: dependencia del sistema de ficheros. Beneficio: zero-maintenance sync.
- **Git sobre backup cifrado**: permite historial de cambios en preferencias.
  vault-export complementa con archivo cifrado para portabilidad offline.
- **NTFS junctions en Windows**: `mklink /J` no requiere permisos de administrador
  (a diferencia de symlinks en Windows). Compatible con Windows 10/11.
