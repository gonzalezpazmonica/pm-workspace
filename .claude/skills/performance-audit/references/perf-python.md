---
name: Python Performance Patterns
description: Anti-patrones async, GIL, Django/SQLAlchemy N+1 y memory en Python
context_cost: low
---

# Python Performance Anti-Patterns

## Async Anti-Patterns

### Blocking en async def (CRITICAL)
- **Detect**: `time.sleep()`, `requests.get()`, `open()` dentro de `async def`
- **Risk**: bloquea el event loop entero
- **Fix**: `await asyncio.sleep()`, `httpx.AsyncClient`, `aiofiles.open()`

### CPU-bound en event loop (CRITICAL)
- **Detect**: cómputo pesado (loops largos, crypto, parsing) en `async def`
- **Fix**: `await loop.run_in_executor(None, cpu_func)` o `ProcessPoolExecutor`

### Missing await (HIGH)
- **Detect**: llamada a coroutine sin `await` (genera RuntimeWarning)
- **Fix**: añadir `await` o usar `asyncio.create_task()` si fire-and-forget

### Sync library en async context (HIGH)
- **Detect**: `import requests` en proyecto con `asyncio`/`fastapi`
- **Fix**: usar `httpx`, `aiohttp`, `motor` (MongoDB async), `asyncpg`

## GIL y Concurrencia

### Threading para CPU-bound (HIGH)
- **Detect**: `threading.Thread` o `ThreadPoolExecutor` para cómputo puro
- **Risk**: GIL impide paralelismo real en CPU
- **Fix**: `multiprocessing`, `ProcessPoolExecutor`, o Cython/Rust extension

### Global state en threads (MEDIUM)
- **Detect**: variables globales modificadas desde múltiples threads sin Lock
- **Fix**: `threading.Lock`, `queue.Queue`, o diseño sin estado compartido

## Django / SQLAlchemy

### Django N+1 (CRITICAL)
- **Detect**: acceso a FK/M2M en loop sin `select_related`/`prefetch_related`
- **Detect**: `for obj in queryset: obj.related_field.name`
- **Fix**: `Model.objects.select_related('fk')` / `.prefetch_related('m2m')`

### SQLAlchemy lazy loading (CRITICAL)
- **Detect**: acceso a relationship en loop con `lazy='select'` (default)
- **Fix**: `joinedload()`, `subqueryload()`, `selectinload()` en query

### QuerySet evaluation innecesaria (HIGH)
- **Detect**: `list(queryset)` o `len(queryset)` cuando solo se necesita `.count()` o `.exists()`
- **Fix**: usar `.count()`, `.exists()`, `.values_list()` según caso

### Missing DB indexes (MEDIUM)
- **Detect**: queries con `filter()` en campos sin `db_index=True`
- **Fix**: añadir `db_index=True` o `Meta.indexes`

## Pythonic Performance

### List vs Generator (HIGH)
- **Detect**: `[x for x in huge_list if condition]` cuando solo se itera una vez
- **Fix**: `(x for x in huge_list if condition)` — generator expression

### String concatenation en loops (HIGH)
- **Detect**: `result += string` dentro de for loop
- **Fix**: `''.join(list_of_strings)` o `io.StringIO`

### Global lookups repetidos (MEDIUM)
- **Detect**: acceso a `module.function()` o `dict[key]` repetidamente en loop
- **Fix**: asignar a variable local antes del loop

### Copy vs Reference (MEDIUM)
- **Detect**: `copy.deepcopy()` en objetos grandes dentro de loops
- **Fix**: shallow copy si suficiente, o diseño que evite copias

## Memory Patterns

### Large list in memory (HIGH)
- **Detect**: `readlines()` en archivo grande, `list(range(10**8))`
- **Fix**: iteración línea por línea, generators, `itertools`

### Circular references (MEDIUM)
- **Detect**: objetos que se referencian mutuamente sin `weakref`
- **Fix**: `weakref.ref()`, `weakref.proxy()`

## Herramientas recomendadas

- **cProfile / profile**: profiling integrado
- **py-spy**: sampling profiler sin overhead
- **scalene**: CPU + memory + GPU profiler
- **line_profiler**: profiling línea por línea
- **memory_profiler**: tracking de uso de memoria
- **django-debug-toolbar**: queries SQL, tiempo por request
