---
name: security-guardian-runbook
description: "Protocolo detallado de los 9 SEC-checks, formato de informe y decision trees del agente security-guardian. Cargar cuando se necesita el detalle de cada check de auditoria de seguridad pre-commit."
summary: |
  Runbook auxiliar del agente security-guardian.
  Contiene: 9 SEC-checks completos con criterios de bloqueo,
  formato de informe, decision trees y metricas.
maturity: stable
context: fork
context_cost: low
---

# Security Guardian — Runbook Completo

## Los 9 SEC-checks (ejecutar en orden)

Ver referencia completa en `docs/rules/domain/security-check-patterns.md`.

### SEC-1 — Credenciales y secretos
Bloqueo si detecta tokens de proveedor cloud, tokens de plataformas de codigo, claves de API reales.
Buscar cadenas de alta entropia en contexto de asignacion de variable de tipo clave o token.

### SEC-2 — Nombres de proyectos/clientes privados
Bloqueo si no son placeholders de ejemplo.
Aceptable: MI-ORGANIZACION, TU-PROYECTO-AQUI, proyecto-alpha, acme-corp.
No aceptable: nombres reales descubiertos en perfiles o directorio de proyectos.

### SEC-3 — IPs y hostnames internos
Bloqueo (rastreados): IPs en rangos privados RFC 1918.
Advertencia (git-ignorados): mencionados en texto pero no en codigo productivo.

### SEC-4 — Datos personales GDPR
Bloqueo: correos reales fuera de dominio ejemplo.
Dominios aceptados: @example.com, @test.com, @contoso.com.
Advertencia: identificadores personales como DNI, telefono, direccion fisica.

### SEC-5 — URLs privadas
Bloqueo: repos no publicos, URLs de servicios internos, endpoints de staging no documentados.
Aceptable: la URL publica del repositorio pm-workspace en GitHub.

### SEC-6 — Ficheros prohibidos
Bloqueo si estan staged: ficheros de entorno, archivos de secretos, claves privadas,
ficheros de configuracion gitignored con datos reales.

### SEC-7 — Infraestructura expuesta
Bloqueo: cadenas de conexion a base de datos con credenciales reales,
nombres de servidores de BD reales en configuracion.

### SEC-8 — Merge conflicts
BLOQUEO ABSOLUTO si hay marcadores de conflicto git en los ficheros staged.
Sin excepciones, sin workarounds.

### SEC-9 — Metadatos reveladores
Advertencia si comentarios en codigo revelan contexto privado (nombre real de cliente o proyecto).

## Formato del informe

```
SECURITY AUDIT — PRE-COMMIT
Rama: [rama] | Ficheros staged: [N]

  SEC-1 — Credenciales ............. OK / BLOQUEADO [detalle]
  SEC-2 — Proyectos privados ....... OK / BLOQUEADO [detalle]
  SEC-3 — IPs/hostnames internos ... OK / AVISO / BLOQUEADO
  SEC-4 — Datos personales GDPR .... OK / AVISO / BLOQUEADO
  SEC-5 — URLs privadas ............ OK / BLOQUEADO
  SEC-6 — Ficheros prohibidos ...... OK / BLOQUEADO
  SEC-7 — Infraestructura expuesta . OK / BLOQUEADO
  SEC-8 — Merge conflicts .......... OK / BLOQUEADO
  SEC-9 — Metadatos reveladores .... OK / AVISO

VEREDICTO: APROBADO / APROBADO_CON_ADVERTENCIAS / BLOQUEADO
```

## Veredictos y acciones

APROBADO: devolver "SECURITY: APROBADO" al agente llamante.

APROBADO_CON_ADVERTENCIAS: devolver con lista de avisos. Commit puede proceder.

BLOQUEADO: devolver "SECURITY: BLOQUEADO" con detalle exacto.
NUNCA sugerir bypass de hooks. Escalar siempre al humano.

## Decision Trees

- Credencial potencial detectada: BLOCK inmediatamente, nunca intentar resolverlo.
- Hallazgo ambiguo (placeholder o real): escalar como BLOQUEADO, dejar al humano decidir.
- Conflicto con output de otro agente: seguridad siempre gana; bloquear primero, discutir despues.
- Fix de codigo necesario: reportar hallazgo, dejar a `dotnet-developer` corregir tras aprobacion humana.
- Marcadores de conflicto git encontrados: BLOCK absoluto, sin excepciones.

## Metricas de exito

- Zero datos sensibles filtrados al repositorio publico
- Los 9 SEC-checks ejecutados en cada auditoria — sin atajos
- Tasa de falsos negativos: 0% (preferir falsos positivos a omisiones)
- Cada hallazgo incluye fichero exacto, linea y contenido relevante
