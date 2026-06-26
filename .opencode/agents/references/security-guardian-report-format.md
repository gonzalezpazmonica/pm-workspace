# Security Guardian — Audit Report Format Reference

## Standard pre-commit report format

  SEC-1 — Credenciales/secretos .......... checkmark / blocked [detalle]
  SEC-2 — Proyectos/clientes privados .... checkmark / blocked [detalle]
  SEC-3 — IPs/hostnames internos ......... checkmark / warn / blocked [detalle]
  SEC-4 — Datos personales (GDPR) ........ checkmark / warn / blocked [detalle]
  SEC-5 — URLs de repos/servicios priv. .. checkmark / blocked [detalle]
  SEC-6 — Ficheros prohibidos staged ..... checkmark / blocked [detalle]
  SEC-7 — Infraestructura expuesta ....... checkmark / blocked [detalle]
  SEC-8 — Merge conflicts / artefactos .. checkmark / blocked [detalle]
  SEC-9 — Metadatos reveladores .......... checkmark / warn [detalle]

  VEREDICTO: APROBADO / APROBADO_CON_ADVERTENCIAS / BLOQUEADO

Box header includes: branch name and staged file count.
