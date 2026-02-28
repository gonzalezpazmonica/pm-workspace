---
name: .NET Performance Patterns
description: Anti-patrones async, LINQ, EF Core y memory en C#/.NET
context_cost: low
---

# .NET Performance Anti-Patterns

## Async Anti-Patterns

### async void (CRITICAL)
- **Detect**: `async void` en métodos que NO son event handlers
- **Risk**: excepciones no capturables, crash del proceso
- **Fix**: cambiar a `async Task` o `async Task<T>`

### Sync-over-async (CRITICAL)
- **Detect**: `.Result`, `.Wait()`, `.GetAwaiter().GetResult()` sobre Task
- **Risk**: deadlock en contextos con SynchronizationContext (ASP.NET, WPF)
- **Fix**: propagar `await` hasta el caller, usar `async` end-to-end

### Missing ConfigureAwait(false) (MEDIUM)
- **Detect**: `await` sin `ConfigureAwait(false)` en libraries (no en controllers)
- **Risk**: captura innecesaria de SynchronizationContext
- **Fix**: añadir `.ConfigureAwait(false)` en library code

### Fire-and-forget sin tracking (HIGH)
- **Detect**: `_ = SomeAsyncMethod()` o `Task.Run()` sin await/log
- **Fix**: usar `IHostedService`, `BackgroundService`, o al menos log errores

## LINQ en Hot Paths

### ToList() / ToArray() innecesario (HIGH)
- **Detect**: `.ToList()` seguido de `.Where()`, `.Select()`, `.FirstOrDefault()`
- **Fix**: encadenar LINQ sin materializar, usar `IEnumerable<T>` lazy

### Multiple enumeration (HIGH)
- **Detect**: variable `IEnumerable<T>` usada en múltiples foreach/LINQ
- **Fix**: materializar una vez con `.ToList()` si se necesita reutilizar

## EF Core / Database

### N+1 Queries (CRITICAL)
- **Detect**: acceso a navigation property en loop sin `.Include()`
- **Detect**: `foreach(var item in dbSet)` seguido de `item.Related.Property`
- **Fix**: `.Include(x => x.Related).ThenInclude(x => x.SubRelated)`

### Tracking queries innecesarias (MEDIUM)
- **Detect**: queries de solo lectura sin `.AsNoTracking()`
- **Fix**: añadir `.AsNoTracking()` o configurar `QueryTrackingBehavior.NoTracking`

### Raw SQL vs LINQ overhead (MEDIUM)
- **Detect**: LINQ complejo con muchos joins/subqueries en hot path
- **Fix**: considerar `FromSqlRaw()` o stored procedure para queries críticas

## Memory Patterns

### String concatenation en loops (HIGH)
- **Detect**: `string += "..."` o `string = string + "..."` dentro de for/foreach
- **Fix**: `StringBuilder` o `string.Join()`, `string.Create()` (.NET 6+)

### Boxing/Unboxing (MEDIUM)
- **Detect**: value types asignados a `object`, interfaces no genéricas
- **Fix**: usar generics, `Span<T>`, `stackalloc` donde aplique

### Large object heap pressure (HIGH)
- **Detect**: allocations >85KB repetidas (arrays, strings grandes en loops)
- **Fix**: `ArrayPool<T>.Shared.Rent()`, `MemoryPool<T>`, pre-allocation

## Herramientas recomendadas

- **BenchmarkDotNet**: micro-benchmarks con estadísticas
- **dotnet-counters**: métricas runtime en tiempo real
- **dotnet-trace**: tracing de CPU y allocations
- **dotnet-dump**: análisis de memory dumps
- **PerfView**: ETW traces, GC analysis
