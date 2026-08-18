# SE-293 — Auditoria de accesos en tiempo real + Quotas por usuario

**Status:** APPROVED
**Fecha:** 2026-08-02
**Area:** Security / Operations / Audit
**Branch:** agent/se293-audit-quotas
**Estimacion total:** ~17h (5 slices)
**Depende de:** SE-291 (multi-dome access control). SE-293 extiende la capa de auth de SE-291 sin modificarla: añade observabilidad (audit trail) y control de consumo (quotas). Sin SE-291, estas capacidades no tienen donde engancharse.

---

## Origen

SE-291 dejo dos capacidades fuera de scope porque habrian alargado un spec ya ambicioso (42h, 7 slices): auditoria de accesos en tiempo real y quotas por usuario. Ambas son necesarias para operar un servidor multi-usuario en produccion:

- **Sin auditoria**, el operador no sabe quien accedio a que ni cuando. Un acceso indebido es indistinguible de uno legitimo. En el contexto del EU AI Act Art. 50 y del modelo de encargos (SE-271), la trazabilidad de accesos es un requisito de compliance, no una feature.
- **Sin quotas**, un token comprometido o un cliente defectuoso puede saturar el servidor. La ausencia de limites de consumo convierte un fallo de autenticacion —inevitable a largo plazo— en un fallo de disponibilidad.

La tesis de este spec es que observabilidad y control de consumo son la misma capacidad vista desde dos angulos: el audit trail registra lo que paso, las quotas limitan lo que puede pasar. Se implementan juntas porque comparten el punto de integracion (AccessController de SE-291) y porque una sin la otra da una falsa sensacion de control.

---

## Objetivo

Un sistema de auditoria que registre **cada intento de acceso** (exitoso y fallido) en un log estructurado (JSONL), consultable desde CLI con filtros por usuario, dome, fecha, accion y resultado. Un sistema de quotas que limite **el numero de operaciones por usuario en ventanas de tiempo** (minuto, hora, dia), con limites configurables por usuario y por dome, y notificacion temprana al alcanzar el 80% del limite.

---

## Out of scope explicito

- NO dashboard ni UI de auditoria — solo CLI y JSONL exportable
- NO alertas en tiempo real (webhook, email) — solo log consultable
- NO retencion automatica ni rotacion configurable — rotacion diaria fija, el operador archiva los logs manualmente
- NO quotas por dome (solo por usuario) — el servidor no tiene tantos usuarios como para necesitar quotas por recurso
- NO integracion con SIEM externo — el log JSONL es el formato de exportacion
- NO analisis de patrones de acceso ni deteccion de anomalias — eso es competencia del operador sobre el log

---

## Diseno general

```
AccessController.authorize()  ← SE-291 (existe)
        │
        ├──► AuditLogger.record()   ← SE-293 S1 (nuevo)
        │      │
        │      └──► savia-vaults.audit.jsonl
        │
        └──► UserQuotaStore.check() ← SE-293 S3 (nuevo)
               │
               ├── 80% → warning en metadata de respuesta
               ├── 100% → QuotaExceededError (429 en A2A)
               └── OK → actualiza contadores en memoria
```

### Decisiones de diseno

**D1. AuditLogger hook dentro de AccessController.authorize(), no wrapper externo.** Cada llamada a authorize() genera un registro de auditoria con el resultado. Esto garantiza que TODO acceso —permitido o denegado— queda registrado sin depender de que cada tool handler recuerde llamar al logger. Si una tool nueva se añade en el futuro y usa authorize(), la auditoria viene gratis.

**D2. JSONL rotado por dia.** Mismo patron que `src/federation/audit-logger.ts`. Un archivo por dia: `savia-vaults.audit-YYYY-MM-DD.jsonl`. Facil de archivar, facil de buscar con herramientas estandar (grep, jq). Sin dependencia de base de datos.

**D3. Contadores de quotas en memoria con persistencia periodica.** Las operaciones son frecuentes (cada tool call) y escribir a disco en cada una degradaria el rendimiento. Los contadores viven en un Map en memoria y se persisten a disco cada 60 segundos y en shutdown. Esto significa que un crash pierde hasta 60s de contadores — aceptable para quotas, inaceptable para auditoria (que escribe sincrono).

**D4. Soft enforcement con aviso temprano.** Al 80% del limite, la respuesta incluye un header/warning `X-Quota-Remaining: N`. Al 100%, se deniega con error explicito. Esto permite al cliente adaptarse antes del bloqueo y evita la sorpresa de un 429 sin previo aviso.

**D5. Quotas por usuario, no por dome.** Con el volumen actual (un operador, pocos domes), la granularidad de quotas por usuario es suficiente. Si un usuario tiene un token comprometido, el atacante no deberia poder consumir recursos excesivos independientemente del dome al que acceda.

---

## Slice 1 — AuditLogger: registro de accesos en JSONL (4h)

**Problema:** El AccessController decide PERMITIR/DENEGAR pero no deja rastro. No hay forma de saber quien accedio a que.

**Diseno minimo:**
- `src/auth/audit-logger.ts`: clase `AuditLogger`
  ```typescript
  interface AuditEntry {
    ts: string;               // ISO 8601 con ms
    username: string;         // "anonymous" para accesos N1 sin token
    dome: string;             // dome al que se intento acceder
    action: 'read' | 'write' | 'admin';
    tool?: string;            // tool MCP que genero el acceso (opcional, poblado desde el handler)
    result: 'allowed' | 'denied';
    reason?: string;          // razon del deny (ej. "forbidden: reader on N4 dome")
    ip?: string;              // para A2A; undefined en MCP stdio (sin IP)
  }
  ```
- Escritura sincrona a `savia-vaults.audit-YYYY-MM-DD.jsonl` (una linea JSON por entrada, append-only)
- Rotacion diaria automatica: al cambiar de dia, nuevo archivo
- El archivo de auditoria esta en la raiz del proyecto y es gitignored
- `AuditLogger.record(entry)`: escribe la entrada. Si falla el write, loguea a stderr pero NO bloquea la operacion (la auditoria no debe ser un punto de fallo para el acceso)
- En AccessController.authorize(), tras cada decision:
  ```typescript
  // Al final de authorize(), tanto en el return como en cada catch(AuthError):
  this.auditLogger.record({
    ts: new Date().toISOString(),
    username: user?.username || 'anonymous',
    dome: params.dome,
    action: params.action,
    result: 'denied',  // o 'allowed' en el return
    reason: e.message,  // solo en deny
  });
  ```
- El logger verifica que el directorio padre existe antes de escribir. Si `savia-vaults.audit-*.jsonl` no se puede crear (permisos), advierte en stderr y sigue.
- Tests de auditoria: 6 operaciones (3 permitidas + 3 denegadas) generan 6 entradas en el log.

**Acceptance criteria:**
- AC-1.1. `vault_read` de usuario autorizado → entrada en audit log con result="allowed"
- AC-1.2. `vault_read` de usuario sin permiso → entrada en audit log con result="denied" y reason
- AC-1.3. `vault_read` de dome N1 sin token → entrada con username="anonymous", result="allowed"
- AC-1.4. Archivo de auditoria rota al cambiar de dia (test con fecha mockeada)
- AC-1.5. Fallo de escritura en log NO bloquea el acceso (stderr warning, operacion sigue)
- AC-1.6. Entradas de auditoria son JSON valido, una por linea (parseable con jq)
- AC-1.7. Tests unitarios: `tests/unit/auth/audit-logger.test.ts` (7+ tests)

**Esfuerzo:** 4h

---

## Slice 2 — Audit CLI: consulta y filtrado de logs (3h)

**Problema:** Los logs existen en disco pero no hay herramienta para consultarlos sin usar `grep`/`jq` manualmente.

**Diseno minimo:**
- Comandos nuevos en `src/cli/index.ts`:
  ```
  savia-vaults audit show [opciones]
  savia-vaults audit stats [opciones]
  savia-vaults audit tail [-f] [-n N]
  ```
- `audit show`:
  - `--username <name>`: filtrar por usuario
  - `--dome <name>`: filtrar por dome
  - `--action read|write|admin`: filtrar por tipo de accion
  - `--result allowed|denied`: filtrar por resultado
  - `--since YYYY-MM-DD`: desde fecha (inclusive)
  - `--until YYYY-MM-DD`: hasta fecha (inclusive)
  - `--json`: salida JSON (array de entradas)
  - `--last N`: ultimas N entradas
  - Sin filtros → ultimas 50 entradas
- `audit stats`:
  - Agrupa por: dia, usuario, dome, accion, resultado
  - Muestra conteos y top-N
  - `--json` para salida machine-readable
  - Ejemplo de salida:
    ```
    Audit Summary (ultimos 7 dias)
    ════════════════════════════════
    Total: 1,247 accesses (92.3% allowed, 7.7% denied)

    By user:
      monica: 1,102 (88.4%)
      alice:   145 (11.6%)

    By dome:
      example-context: 892 (71.5%)
      Labs:       355 (28.5%)

    By action:
      read:  1,103 (88.4%)
      write:   144 (11.6%)

    Denied accesses (96 total):
      monica on Legal: 72 (forbidden: N4 requires admin)
      alice on example-context: 24 (forbidden: reader on write)
    ```
- `audit tail`:
  - Sigue el archivo de auditoria del dia actual (como `tail -f`)
  - `-n N`: muestra las ultimas N entradas antes de seguir
  - Ctrl+C para salir
- Todos los comandos operan sobre `savia-vaults.audit-*.jsonl` en la raiz del proyecto
- Validacion: archivo no existe → mensaje claro (no error), archivo corrupto (linea no es JSON) → warning y continua

**Acceptance criteria:**
- AC-2.1. `savia-vaults audit show --last 10` muestra las 10 entradas mas recientes
- AC-2.2. `savia-vaults audit show --username alice --dome Labs --since 2026-08-01` filtra correctamente
- AC-2.3. `savia-vaults audit show --json` produce JSON parseable
- AC-2.4. `savia-vaults audit stats` muestra resumen agrupado con conteos
- AC-2.5. `savia-vaults audit stats --json` produce JSON con datos agregados
- AC-2.6. `savia-vaults audit tail -n 5` muestra ultimas 5 y sigue en vivo
- AC-2.7. Linea corrupta en JSONL → warning y continua (no aborta)
- AC-2.8. Tests unitarios: `tests/unit/cli/audit-commands.test.ts` (6+ tests)

**Esfuerzo:** 3h

---

## Slice 3 — UserQuotaStore: limites de consumo por usuario (4h)

**Problema:** No hay limites de uso. Un token comprometido puede hacer miles de requests sin que nada lo detenga.

**Diseno minimo:**
- `src/auth/quota-store.ts`: clase `UserQuotaStore`
  ```typescript
  interface QuotaConfig {
    requestsPerMinute: number;   // default 60
    requestsPerHour: number;     // default 1000
    requestsPerDay: number;      // default 5000
  }

  interface UserQuota {
    username: string;
    config: QuotaConfig;
    counters: {
      minute: { window: number; count: number };  // window = timestamp inicio del minuto
      hour: { window: number; count: number };
      day: { window: number; count: number };
    };
  }

  class UserQuotaStore {
    // Verifica si el usuario tiene quota disponible. Si no, lanza QuotaExceededError.
    // Si esta al 80%+, incluye warning en el resultado.
    async check(username: string): Promise<{ allowed: boolean; warning?: string }>;

    // Actualiza contadores tras una operacion exitosa (no se cuentan los denegados por auth)
    async record(username: string): Promise<void>;

    // Persiste contadores a disco (llamado cada 60s y en shutdown)
    async persist(): Promise<void>;

    // Carga estado desde disco
    async load(): Promise<void>;

    // Configuracion de quotas
    getConfig(username: string): QuotaConfig;
    setConfig(username: string, config: Partial<QuotaConfig>): void;
    resetCounters(username: string): void;
  }
  ```
- Ventanas de tiempo deslizantes implementadas con `Math.floor(Date.now() / windowMs)`:
  - Minuto: `Math.floor(now / 60000)`
  - Hora: `Math.floor(now / 3600000)`
  - Dia: `Math.floor(now / 86400000)`
- Al inicio de cada check(), se evalua si la ventana cambio → reset del contador de esa ventana
- Persistencia a `savia-vaults.quotas.json` (gitignored):
  ```json
  {
    "version": 1,
    "users": {
      "monica": {
        "config": { "requestsPerMinute": 120, "requestsPerHour": 2000, "requestsPerDay": 10000 },
        "counters": {
          "minute": { "window": 2876543, "count": 15 },
          "hour": { "window": 47942, "count": 234 },
          "day": { "window": 1997, "count": 1234 }
        }
      }
    }
  }
  ```
- Default quotas aplican a cualquier usuario sin configuracion explicita
- Integracion en AccessController.authorize():
  ```typescript
  // Tras validar identidad, antes de devolver:
  const quota = await this.quotaStore.check(username);
  if (!quota.allowed) {
    throw new AuthError('forbidden', `Quota exceeded for user "${username}"`);
  }
  ```
- El record() se llama solo si la operacion fue permitida (no tras un deny de auth)

**Acceptance criteria:**
- AC-3.1. Usuario con 60 req/min → operacion 61 en el mismo minuto denegada con QuotaExceededError
- AC-3.2. Cambio de ventana (siguiente minuto) → contador se resetea, acceso permitido
- AC-3.3. Usuario al 80% (48/60 rpm) → warning incluido en metadata de respuesta
- AC-3.4. Usuario al 100% (60/60 rpm) → operacion 61 denegada
- AC-3.5. Persistencia periodica: contadores sobreviven a un reinicio del servidor
- AC-3.6. Usuario sin configuracion explicita → defaults se aplican
- AC-3.7. QuotaStore.setConfig('alice', { requestsPerMinute: 30 }) persiste
- AC-3.8. QuotaStore.resetCounters('alice') pone todo a cero
- AC-3.9. Tests unitarios: `tests/unit/auth/quota-store.test.ts` (10+ tests)

**Esfuerzo:** 4h

---

## Slice 4 — Quota CLI: gestion de limites por usuario (3h)

**Problema:** No hay forma de configurar quotas sin editar el JSON a mano.

**Diseno minimo:**
- Comandos nuevos en `src/cli/index.ts`:
  ```
  savia-vaults user quota <username>              # mostrar quotas actuales
  savia-vaults user quota <username> --set-rpm N  # requests por minuto
  savia-vaults user quota <username> --set-rph N  # requests por hora
  savia-vaults user quota <username> --set-rpd N  # requests por dia
  savia-vaults user quota <username> --reset      # resetear contadores a cero
  ```
- `user quota <username>` sin flags: muestra configuracion actual + uso actual
  ```
  Quotas for monica:
    Requests per minute:  15 / 60  (25%)  [window: 2026-08-02T22:15:00Z]
    Requests per hour:   234 / 1000 (23%)
    Requests per day:   1234 / 5000 (24%)
  ```
- `user quota <username> --set-rpm 120`: actualiza limite de rpm
- `user quota <username> --reset`: pone todos los contadores a cero (no cambia config)
- `--json` para salida machine-readable
- Si el usuario no existe en UserStore → error

**Acceptance criteria:**
- AC-4.1. `savia-vaults user quota alice` muestra config y uso actual
- AC-4.2. `savia-vaults user quota alice --set-rpm 30` actualiza y persiste
- AC-4.3. `savia-vaults user quota alice --reset` pone contadores a cero
- AC-4.4. `savia-vaults user quota ghost` → error "user not found"
- AC-4.5. `savia-vaults user quota alice --set-rph 0` deshabilita quota por hora (0 = sin limite)
- AC-4.6. Tests unitarios: `tests/unit/cli/quota-commands.test.ts` (5+ tests)

**Esfuerzo:** 3h

---

## Slice 5 — Integracion final: AccessController, MCP, tests end-to-end (3h)

**Problema:** Las piezas existen pero no estan conectadas al flujo real de MCP.

**Diseno minimo:**
- AccessController recibe AuditLogger y UserQuotaStore en constructor:
  ```typescript
  class AccessController {
    constructor(
      userStore: UserStore,
      domeRegistry: DomeRegistry,
      auditLogger: AuditLogger,       // ← nuevo
      quotaStore: UserQuotaStore,     // ← nuevo
    )
  }
  ```
- authorize() registra auditoria en TODOS los casos (allow y deny) y verifica quotas antes de devolver
- MCP server inicializa AuditLogger + UserQuotaStore si el modo multi-dome esta activo
- MCP tools pasan el nombre de la tool al AuditLogger para trazabilidad fina (via parametro opcional en authorize)
- A2A server: incluye header `X-Quota-Remaining` en respuestas cuando se alcanza el 80%
- `.gitignore`: agregar `savia-vaults.audit-*.jsonl` y `savia-vaults.quotas.json`
- `CLAUDE.md` del proyecto: documentar nuevos comandos y archivos
- Test end-to-end:
  1. Crear usuario
  2. Asignar permisos
  3. Hacer 3 reads (todas allowed) → verificar 3 entradas en audit log
  4. Hacer 1 write sin permiso → verificar entrada denied en audit log
  5. Configurar quota rpm=2, hacer 3 reads en el mismo minuto → tercera denegada por quota
  6. Verificar que el audit log contiene las 5 entradas (3 allowed + 1 denied auth + 1 denied quota)
- Smoke test: `savia-vaults serve --transport mcp` arranca con AuditLogger + QuotaStore sin errores

**Acceptance criteria:**
- AC-5.1. `vault_read` exitoso → entrada en audit log + contador de quota incrementado
- AC-5.2. `vault_write` denegado por rol → entrada en audit log con result="denied" + contador NO incrementado
- AC-5.3. `vault_read` denegado por quota → entrada en audit log + QuotaExceededError
- AC-5.4. MCP server arranca con --path legacy (sin archivo de domes) → AuditLogger/QuotaStore no se inicializan, no hay error
- AC-5.5. Test E2E: flujo completo (5 operaciones, auditoria + quotas) pasa
- AC-5.6. `npm test` todos los tests existentes (147) + nuevos (~30) = ~177 PASS
- AC-5.7. `npm run build` sin errores
- AC-5.8. `npm run typecheck` sin errores
- AC-5.9. `.gitignore` incluye los nuevos archivos de auditoria y quotas

**Esfuerzo:** 3h

---

## Plan de Implementacion

### Orden recomendado

S1 (AuditLogger, 4h) → S2 (Audit CLI, 3h) → S3 (QuotaStore, 4h) → S4 (Quota CLI, 3h) → S5 (Integracion, 3h)

Total: 17h

### Dependencias

- S2 depende de S1 (necesita AuditLogger para generar entradas que consultar)
- S4 depende de S3 (opera sobre UserQuotaStore)
- S5 depende de S1-S4 (integra todo en MCP server)
- S3 y S1 son independientes entre si (pueden implementarse en paralelo)

### Riesgos

| Riesgo | Prob | Impacto | Mitigacion |
|---|---|---|---|
| Escritura sincrona de auditoria degrada rendimiento | Baja | Medio | JSONL append es O(1). Si se detecta latencia >5ms, pasar a escritura async con buffer |
| Ventanas de quota inconsistentes en cluster | Nula | Bajo | Servidor es single-process (stdio). Si en el futuro hay cluster, migrar a Redis |
| Archivos de auditoria crecen sin control | Baja | Bajo | Rotacion diaria. El operador archiva logs antiguos. Tool `audit stats` muestra tamaño total |

---

## Verification method

1. `savia-vaults serve --transport mcp` arranca con AuditLogger + QuotaStore
2. `vault_read` autorizado → entrada en `savia-vaults.audit-*.jsonl` con result="allowed"
3. `vault_write` denegado → entrada con result="denied" y reason
4. `vault_read` de dome N1 sin token → entrada con username="anonymous"
5. `savia-vaults audit show --last 5` muestra las ultimas 5 entradas
6. `savia-vaults audit stats` muestra resumen agrupado con conteos
7. `savia-vaults user quota monica --set-rpm 2` → tercera operacion en el mismo minuto denegada
8. `savia-vaults user quota monica` muestra uso actual
9. `savia-vaults user quota monica --reset` → contadores a cero, operaciones permitidas de nuevo
10. E2E: 5 operaciones, auditoria y quotas verificadas. ~177 tests PASS

---

## Ficheros nuevos

```
projects/savia-vaults/
├── src/auth/
│   ├── audit-logger.ts           # AuditLogger (JSONL append, daily rotation)
│   └── quota-store.ts            # UserQuotaStore (ventanas, persistencia)
├── tests/unit/auth/
│   ├── audit-logger.test.ts      # 7+ tests
│   └── quota-store.test.ts       # 10+ tests
├── tests/unit/cli/
│   ├── audit-commands.test.ts    # 6+ tests
│   └── quota-commands.test.ts    # 5+ tests
└── tests/integration/
    └── audit-quota-workflow.test.ts  # 5+ tests (E2E)
```

## Ficheros modificados

```
projects/savia-vaults/
├── src/auth/controller.ts        # +AuditLogger +UserQuotaStore en constructor
├── src/auth/index.ts             # +export AuditLogger, UserQuotaStore
├── src/cli/index.ts              # +audit show/stats/tail, +user quota
├── src/server/mcp.ts             # +Init AuditLogger + QuotaStore
├── src/server/a2a.ts             # +X-Quota-Remaining header
├── .gitignore                    # +savia-vaults.audit-*.jsonl, +savia-vaults.quotas.json
└── CLAUDE.md                     # +nuevos comandos y archivos
```

---

## OpenCode Implementation Plan (SE-110)

### Classification
- **Complexity:** MEDIUM (5 slices, 2 nuevos modulos, integracion con SE-291)
- **Risk:** LOW (extension pura de SE-291, sin modificar auth existente)
- **Parallelizable:** S1+S3 pueden implementarse en paralelo (modulos independientes)
- **Test surface:** ~30 tests nuevos + 147 existentes = ~177 total

### Implementation Strategy
- **Agent:** typescript-developer
- **Review:** code-reviewer post-implementation
- **Gates:**
  - Gate 1 (post-S2): `npm test` → AuditLogger + CLI tests pass (~13 new)
  - Gate 2 (post-S4): `npm test` → QuotaStore + Quota CLI tests pass (~15 new)
  - Gate 3 (post-S5): `npm test` → full green (~177 tests). E2E workflow smoke test
- **Security review:** Bajo riesgo (no modifica auth, solo añade observabilidad)
