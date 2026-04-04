# Plugin Packaging -- Dominio

## Por que existe esta skill

pm-workspace necesita ser distribuible como plugin de Claude Code. Sin validacion estructural y manifest dinamico, los componentes pueden publicarse incompletos o con metadatos desactualizados. Esta skill empaqueta, valida y genera el manifest con conteos reales.

## Conceptos de dominio

- **plugin.json**: manifest del plugin con metadatos (nombre, version, capabilities) y conteos de componentes.
- **Validacion estructural**: verificacion de que cada skill, agent y command tiene frontmatter correcto y <= 150 lineas.
- **Conteos dinamicos**: skills, agents y commands se cuentan del filesystem, nunca hardcodeados.
- **Versionado**: la version en plugin.json debe coincidir con la entrada mas reciente de CHANGELOG.md.

## Reglas de negocio que implementa

- file-size-limit.md: ningun fichero empaquetado supera 150 lineas.
- command-validation.md: frontmatter obligatorio (name, description) en todos los componentes.
- changelog-enforcement.md: version del plugin alineada con CHANGELOG.
- managed-content.md: secciones auto-generadas usan marcadores managed-by para regeneracion segura.

## Relacion con otras skills

- **Upstream**: context-optimized-dev (dependencia declarada), managed-content (sincronizacion de secciones).
- **Downstream**: marketplace-publish (publicacion del paquete validado).
- **Paralelo**: plugin-validate (validacion sin empaquetado), changelog-update (version alineada).

## Decisiones clave

- Conteos dinamicos sobre valores estaticos: elimina desincronizacion entre manifest y realidad.
- tar.gz sobre formato propietario: estandar, portable, inspeccionable.
- Validacion antes de empaquetado: fallos detectados antes de distribuir, no despues.
