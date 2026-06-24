---
name: code-reviewer-runbook
description: "Checklists detallados, formato de informe y arboles de decision para el agente code-reviewer. Cargar cuando se necesita el detalle completo de checks de seguridad, calidad C#, SOLID y formato de veredicto."
summary: |
  Runbook auxiliar del agente code-reviewer.
  Contiene: checklists de seguridad .NET, calidad C#, principios SOLID,
  formato completo del informe de revision, decision trees y metricas.
maturity: stable
context: fork
context_cost: low
---

# Code Reviewer — Runbook Completo

## Checklists de revision

### Seguridad .NET — reglas S2068, S6418, S2077, S5131, S2755, S5122

- SQL injection en queries WIQL o ADO.NET directo (EF Core protege, pero verificar)
- XSS: validar que las respuestas de API sanitizan HTML donde aplica
- Secrets hardcodeados: buscar patrones de credenciales en codigo (ver S2068)
- Insecure deserialization: `JsonSerializer` con opciones seguras
- CORS mal configurado en ASP.NET Core (`AllowAnyOrigin` + `AllowCredentials`)
- Autorizacion: `[Authorize]` donde hace falta, no solo `[ApiController]`
- Validacion de inputs: nada llega sin validar a las capas de dominio

### Calidad de codigo C# — reglas S3168, S2259, S2930, S3655, S4586, S2971

- async/await: detectar `.Result`, `.Wait()`, deadlocks potenciales (ARCH-11)
- Disposables: `IDisposable` / `IAsyncDisposable` gestionados con `using` (S2930, S2931)
- Null safety: nullable reference types activados, sin `!` injustificados (S2259)
- EF Core: detectar N+1 queries, `ToList()` prematuro, falta de `AsNoTracking()` (ARCH-09, ARCH-10)
- Excepciones: `catch (Exception)` vacio, swallowing de errores (S112)
- Logging: mensajes con nivel correcto, sin datos sensibles en logs

### Principios SOLID y Arquitectura — reglas ARCH-01 a ARCH-12

- SRP: cada clase tiene una sola razon para cambiar
- OCP: se extiende sin modificar codigo existente
- LSP: los subtipos cumplen el contrato del tipo base
- ISP: las interfaces son pequenas y cohesivas
- DIP: las capas altas dependen de abstracciones, no de implementaciones (ARCH-02, ARCH-04)

### Cumplimiento de Spec SDD

- El codigo implementa exactamente lo que dice la spec (ni mas ni menos)
- Los tests cubren los casos definidos en la spec
- Los ficheros creados/modificados son los indicados en la spec

## Formato del informe de revision

```
Code Review: [Nombre del fichero / PR]

Lo que esta bien
[2-3 puntos positivos concretos]

Bloqueantes (deben corregirse antes de merge)
1. [Problema] en [fichero:linea]: [descripcion] — [solucion propuesta]

Mejoras recomendadas (no bloquean pero deberian hacerse)
1. [Problema] en [fichero:linea]: [descripcion] — [solucion propuesta]

Notas (sugerencias menores o informativas)
- [...]

Veredicto
- APROBADO — listo para merge
- APROBADO CON CAMBIOS MENORES — puede mergearse corrigiendo los amarillos
- RECHAZADO — corregir bloqueantes y repetir review
```

## Pre-revision (comandos obligatorios)

```bash
dotnet build --configuration Release 2>&1
dotnet format --verify-no-changes 2>&1
dotnet test --filter "Category=Unit" --no-build 2>&1
```

## Decision Trees

- Tests fallan antes de la revision: rechazar inmediatamente, delegar fix a `dotnet-developer`.
- Spec ambigua: marcar CONDITIONAL, listar que no se puede verificar.
- Vulnerabilidad de seguridad: marcar CRITICAL, escalar a humano independientemente.
- Conflicto con diseno de `architect`: deferir en diseno, mantener firmeza en calidad de codigo.
- Revision mayor de 30 ficheros: dividir en lotes logicos, revisar cada uno independientemente.

## Metricas de exito

- Zero vulnerabilidades de seguridad omitidas en codigo revisado
- Todos los hallazgos referencian un rule ID especifico (S-XXXX, ARCH-XX)
- Turnaround en 1 ciclo de invocacion (sin re-lecturas)
- Ratio constructivo: al menos 1 hallazgo positivo por revision
