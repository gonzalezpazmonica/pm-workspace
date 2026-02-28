---
name: Go Performance Patterns
description: Anti-patrones de goroutines, channels, memory allocation y DB en Go
context_cost: low
---

# Go Performance Anti-Patterns

## Goroutine / Channel Anti-Patterns

### Goroutine leaks (CRITICAL)
- **Detect**: `go func()` sin mecanismo de shutdown (context, done channel)
- **Detect**: goroutine bloqueada en channel read/write sin timeout ni context
- **Risk**: memory leak, goroutine count crece indefinidamente
- **Fix**: pasar `context.Context`, usar `select` con `ctx.Done()`

### Unclosed channels (CRITICAL)
- **Detect**: channel creado sin `defer close(ch)` ni close explícito
- **Risk**: goroutines bloqueadas esperando en channel
- **Fix**: `defer close(ch)` en el productor, pattern productor-consumidor

### Missing context cancellation (HIGH)
- **Detect**: HTTP handler que lanza goroutines sin propagar `r.Context()`
- **Fix**: `ctx := r.Context()`, pasar a goroutines, verificar `ctx.Err()`

### WaitGroup misuse (HIGH)
- **Detect**: `wg.Add()` dentro de goroutine (race condition)
- **Detect**: `wg.Done()` no en `defer` (puede no ejecutarse)
- **Fix**: `wg.Add(n)` antes del loop, `defer wg.Done()` al inicio de goroutine

### Channel sin timeout (HIGH)
- **Detect**: `<-ch` sin `select` con `time.After` o `ctx.Done()`
- **Fix**: `select { case v := <-ch: ... case <-time.After(5*time.Second): ... }`

## Memory / Allocation

### Slice pre-allocation (HIGH)
- **Detect**: `var s []T` seguido de `append()` en loop cuando el tamaño es conocido
- **Fix**: `s := make([]T, 0, expectedLen)` — evita re-allocations

### Map pre-sizing (MEDIUM)
- **Detect**: `m := make(map[K]V)` cuando el tamaño aproximado es conocido
- **Fix**: `m := make(map[K]V, expectedLen)` — reduce rehashing

### String builder (HIGH)
- **Detect**: `s += "..."` o `fmt.Sprintf()` en loop para concatenar
- **Fix**: `var b strings.Builder; b.WriteString(...)` o `bytes.Buffer`

### Interface boxing (MEDIUM)
- **Detect**: conversión frecuente de concrete type a `interface{}` en hot path
- **Risk**: allocation en heap para cada boxing
- **Fix**: generics (Go 1.18+), type-specific functions

### Escape analysis (MEDIUM)
- **Detect**: variables que escapan al heap innecesariamente
- **Diagnóstico**: `go build -gcflags="-m"` para ver escape analysis
- **Fix**: pasar por valor en vez de pointer para tipos pequeños, evitar retornar puntero a local

## Database / sql.DB

### Connection pool sizing (HIGH)
- **Detect**: `sql.Open()` sin configurar `SetMaxOpenConns`, `SetMaxIdleConns`
- **Risk**: conexiones ilimitadas bajo carga → DB overwhelmed
- **Fix**: `db.SetMaxOpenConns(25); db.SetMaxIdleConns(5); db.SetConnMaxLifetime(5*time.Minute)`

### Prepared statements reuse (MEDIUM)
- **Detect**: `db.Query(sql, args...)` repetido con misma query
- **Fix**: `stmt, _ := db.Prepare(sql)` → reusar `stmt.Query(args...)`

### Connection leaks (CRITICAL)
- **Detect**: `rows, _ := db.Query(...)` sin `defer rows.Close()`
- **Fix**: `defer rows.Close()` inmediatamente después de verificar error

### Missing context in queries (HIGH)
- **Detect**: `db.Query()` en vez de `db.QueryContext(ctx, ...)`
- **Fix**: siempre usar variantes `*Context()` para timeout y cancellation

## Patterns generales

### Error handling overhead (LOW)
- **Detect**: `fmt.Errorf()` con wrapping excesivo en hot path
- **Fix**: sentinels errors (`var ErrNotFound = errors.New(...)`), pre-allocated errors

### defer en loops (MEDIUM)
- **Detect**: `defer` dentro de for loop
- **Risk**: defers se acumulan hasta que la función retorna
- **Fix**: extraer body del loop a función separada, o llamar cleanup explícito

### Mutex contention (HIGH)
- **Detect**: `sync.Mutex` con lock durante operaciones I/O
- **Fix**: `sync.RWMutex`, reducir critical section, lock-free con `sync/atomic`

## Herramientas recomendadas

- **pprof**: CPU, memory, goroutine, block profiling
- **go tool trace**: visualización de scheduler, GC, goroutines
- **goleak**: detección de goroutine leaks en tests
- **benchstat**: comparación estadística de benchmarks
- **dlv (Delve)**: debugger con soporte para goroutines
