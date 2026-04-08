---
spec_id: SPEC-096
title: Blocker-as-Context — Knowledge Chain for Dev Session Slices
status: Proposed
origin: Anvil research (ppazosp/anvil, 2026-04-08)
severity: Media
effort: ~2h
---

# SPEC-096: Blocker-as-Context Knowledge Chain

## Problema

En dev-session, cada slice se implementa con contexto fresco. El subagente
recibe el spec-excerpt + ficheros target, pero NO sabe qué decisiones se
tomaron en slices anteriores. Esto causa:

- Inconsistencias entre slices (naming, patterns, error handling)
- El developer reimplementa patterns ya resueltos en slices previos
- El coherence-validator detecta divergencias que un contexto compartido evitaría

Inspirado en Anvil: al empezar un issue, lee los "completion summaries"
de todos los blockers resueltos y los inyecta como contexto.

## Solución

Script `scripts/slice-context-chain.sh` que:

1. Lee `state.json` de una dev-session activa
2. Para cada slice completado, extrae un "completion summary":
   - Ficheros creados/modificados
   - Decisiones de diseño tomadas (patterns elegidos)
   - Convenciones establecidas (naming, error handling)
   - Interfaces expuestas (que slices posteriores podrían usar)
3. Genera un `context-chain.md` compacto (max 2K tokens)
4. Este fichero se inyecta como contexto adicional en Fase 3 del siguiente slice

### Formato del completion summary por slice

```markdown
## Slice {n}: {name} — Completado

**Ficheros**: Service.cs, IService.cs
**Patrón**: Repository pattern con inyección por constructor
**Naming**: PascalCase para públicos, _camelCase para privados
**Interfaces**: IReservaService.CreateAsync(ReservaDto) → Reserva
**Errores**: NotFoundException para entidad no encontrada, ValidationException para input
```

### Formato del context-chain.md acumulado

```markdown
# Knowledge Chain — Dev Session {id}

Contexto acumulado de slices completados. Inyectar en el subagente del slice actual.

## Convenciones establecidas
- Patrón: Repository + Service layer
- Naming: PascalCase público, _camelCase privado
- Errores: NotFoundException, ValidationException

## Interfaces disponibles
- IReservaService.CreateAsync(ReservaDto) → Reserva
- ISalaRepository.GetByIdAsync(Guid) → Sala?

## Decisiones de diseño
- Slice 1: Elegido record para DTOs (inmutabilidad)
- Slice 2: Elegido EF Core Fluent API para config (no attributes)
```

## Integración con dev-session

En `/dev-session next` (Fase 3 — Implement):
1. Antes de invocar subagente, ejecutar `slice-context-chain.sh build`
2. Si existe `context-chain.md`, incluirlo en el prompt del subagente
3. Tras completar slice, ejecutar `slice-context-chain.sh update` para añadir summary
4. El context-chain se comprime si supera 2K tokens (mantener solo decisiones + interfaces)

## Criterios de aceptación

- [ ] Script `scripts/slice-context-chain.sh` con build/update/show subcomandos
- [ ] Extrae summary de slices completados desde validation/*.md e impl/*.md
- [ ] Genera context-chain.md compacto (max ~500 palabras)
- [ ] Compresión automática si supera umbral de tokens
- [ ] Compatible con state.json de dev-session existente
- [ ] Tests BATS >= 12 casos
