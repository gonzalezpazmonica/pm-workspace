---
paths:
  - "**/*.cs"
---

# C#/.NET — Reglas de Análisis Estático (SonarQube-equivalent)

> Fuente: [SonarSource sonar-dotnet](https://github.com/SonarSource/sonar-dotnet)
> Última actualización: 2026-02-25

## Protocolo de reporte

Para cada hallazgo: **ID** · **Severidad** (Blocker/Critical/Major/Minor) · **Línea(s)** · **Descripción** · **Fix con código**.
Priorizar: 1) Vulnerabilities/Security Hotspots → 2) Bugs → 3) Code Smells. Responder en español.

---

## 1. VULNERABILITIES — Seguridad

### Blocker

| ID | Regla | Patrón ❌ | Fix ✅ |
|----|-------|-----------|--------|
| S2068 | Credenciales hardcodeadas | `string password = "Admin123"` | `GetEncryptedPassword()` |
| S2115 | BD sin contraseña segura | `Password=` en connection string | `Integrated Security=True` |
| S2755 | XXE en parseo XML | `XmlResolver = new XmlUrlResolver()` | `XmlResolver = null` |
| S6418 | Secretos hardcodeados | `const string mySecret = "47828..."` | `Environment.GetEnvironmentVariable()` |
| S6781 | Claves JWT expuestas | `_config["Jwt:Key"]` | `Environment.GetEnvironmentVariable("JWT_KEY")` |

### Critical

| ID | Regla | Patrón ❌ | Fix ✅ |
|----|-------|-----------|--------|
| S2053 | Salt predecible | `Encoding.UTF8.GetBytes("salty")` | `Rfc2898DeriveBytes(pw, 16, 100_000, SHA512)` |
| S3329 | IV predecible en CBC | `byte[] iv = new byte[] {1,2,...}` | `aes.CreateEncryptor(key, aes.IV)` |
| S4423 | TLS débil | `SecurityProtocolType.Tls` | `Tls12 \| Tls13` |
| S4426 | Claves criptográficas cortas | `RSACryptoServiceProvider()` (1024) | `RSACryptoServiceProvider(2048)` |
| S4433 | LDAP sin auth | `AuthenticationTypes.None` | `AuthenticationTypes.Secure` |
| S4830 | Validación TLS desactivada | `=> true` en cert callback | Validación por defecto |
| S5344 | Hashing passwords débil | `iterationCount: 1` | `iterationCount: 100_000` |
| S5445 | Ficheros temp inseguros | `Path.GetTempFileName()` | `Path.Combine(GetTempPath(), GetRandomFileName())` |
| S5542 | Cifrado ECB/PKCS1 | `CipherMode.ECB` | `AesGcm` |
| S5547 | Cripto obsoleta | `DESCryptoServiceProvider` | `Aes.Create()` |
| S5659 | JWT sin verificar firma | `verify: false` | `verify: true` |

### Major

| ID | Regla | Clave |
|----|-------|-------|
| S5773 | Deserialización sin restricciones | Usar `AllowListBinder` con `BinaryFormatter` |
| S6377 | Firma XML insegura | Verificar referencia al validar |

---

## 2. SECURITY HOTSPOTS — Revisión manual

### Critical

| ID | Regla | Patrón sensible |
|----|-------|-----------------|
| S2245 | PRNG no criptográfico | `new Random()` para tokens → usar `RandomNumberGenerator` |
| S4502 | CSRF desactivado | `[IgnoreAntiforgeryToken]` → `[AutoValidateAntiforgeryToken]` |
| S4790 | Hash débil | `MD5`, `SHA1` → `SHA512` |
| S5042 | Zip Bomb | Extraer sin validar tamaño → validar ratio/tamaño/entries |
| S5332 | Protocolo texto claro | `http://`, SMTP sin SSL → `https://`, `EnableSsl = true` |
| S5443 | Temp en dir público | `/tmp/f` predecible → `GetRandomFileName()` |

### Major

| ID | Regla | Patrón sensible |
|----|-------|-----------------|
| S2077 | SQL injection | `string.Format` en SQL → parámetros `@p0` |
| S5693 | Request sin límite | `[DisableRequestSizeLimit]` → `[RequestSizeLimit(8_388_608)]` |
| S6444 | Regex sin timeout | `new Regex(pattern)` → agregar `TimeSpan` o `NonBacktracking` |

### Minor

| ID | Regla | Fix |
|----|-------|-----|
| S2092 | Cookie sin Secure | `Secure = true` |
| S3330 | Cookie sin HttpOnly | `HttpOnly = true` |
| S4507 | Debug en producción | Envolver en `if (env.IsDevelopment())` |
| S5122 | CORS permisivo | `WithOrigins("*")` → origins explícitos validados |

---

## 3. BUGS — Errores de runtime

### Blocker

| ID | Regla | Patrón ❌ | Fix ✅ |
|----|-------|-----------|--------|
| S1048 | Excepción en Finalizer | `throw` en `~Destructor()` | Cleanup sin excepciones |
| S2190 | Recursión/bucle infinito | `while(true)` sin break, getter recursivo | Condición de salida |
| S2275 | Format string inválido | `"[0}"`, args insuficientes | Validar placeholders y args |
| S2930 | IDisposable no dispuesto | `var fs = new FileStream(...)` | `using var fs = ...` |
| S2931 | Clase sin IDisposable con campo IDisposable | Campo `FileStream` sin patrón Dispose | Implementar `IDisposable` |

### Critical

| ID | Regla | Clave |
|----|-------|-------|
| S2222 | Lock no liberado en todos los paths | Usar `lock()` en vez de `Monitor.Enter/Exit` manual |
| S2551 | Lock en objetos compartidos | No `lock(this)`/`lock(typeof(T))` → `private readonly object _lock` |
| S4586 | Async retorna null | `Task DoAsync() => null` → `Task.CompletedTask` |
| S5856 | Regex inválida | Sintaxis malformada → validar pattern |
| S7131 | Read/Write lock cruzado | No liberar write lock cuando se adquirió read lock |
| S7133 | Lock liberado fuera del método | Adquirir y liberar en el mismo método |

### Major (selección .NET moderno)

| ID | Regla | Clave |
|----|-------|-------|
| S2259 | Null pointer dereference | Verificar null antes de `.` |
| S3168 | `async void` | Cambiar a `async Task` (excepto event handlers) |
| S3655 | Nullable sin HasValue | Verificar `.HasValue` antes de `.Value` |
| S3949 | Overflow aritmético | Usar tipo más ancho (`long` en vez de `int`) |
| S2583 | Condición siempre true/false | Código inalcanzable, revisar lógica |
| S1244 | Comparación float con == | `Math.Abs(a - b) < epsilon` |
| S2201 | Retorno ignorado (método puro) | Usar el valor o eliminar la llamada |
| S2114 | Colección argumento de sí misma | `list.AddRange(list)` es error |
| S3966 | Doble dispose | Una sola llamada a `Dispose()` |
| S4143 | Overwrite incondicional en colección | Verificar antes de asignar al mismo key |

---

## 4. CODE SMELLS — Mantenibilidad

### Critical

| ID | Regla | Clave |
|----|-------|-------|
| S3776 | Complejidad cognitiva > 15 | Extraer condiciones a métodos con nombre |
| S3216 | ConfigureAwait en librerías | `.ConfigureAwait(false)` en código de librería |
| S5034 | ValueTask consumido mal | No await múltiples veces; usar `Task` si se necesita |
| S2696 | Static field desde instancia | Race condition → `Interlocked` o método estático |
| S4487 | Campo privado escrito nunca leído | Dead store — eliminar |
| S927 | Nombres params inconsistentes en override | Mantener nombres del base |

### Major (selección .NET moderno)

| ID | Regla | Clave |
|----|-------|-------|
| S1854 | Dead stores | Asignación sobrescrita sin leer → eliminar |
| S1481 | Variable local no usada | Eliminar declaración |
| S112 | Excepciones genéricas | `throw new Exception()` → `ArgumentNullException(nameof(...))` |
| S1144 | Miembros privados no usados | Eliminar código muerto |
| S1066 | Ifs anidados fusionables | Combinar con `&&` |
| S2971 | LINQ simplificable | `.Select().Any()` → `.OfType().Any()`, `.Count` vs `.Count()` |
| S2589 | Booleanos gratuitos | Condición constante true/false → simplificar |
| S2933 | Campos → readonly | Solo asignado en constructor → `readonly` |
| S4144 | Métodos idénticos | Refactorizar duplicados |
| S2699 | Tests sin assertions | Todo test debe tener al menos una aserción |
| S1118 | Utility class instanciable | `public class` → `public static class` |
| S1168 | Return null vs colección vacía | `Array.Empty<T>()` o `Enumerable.Empty<T>()` |
| S125 | Código comentado | Eliminar — está en git |
| S2139 | Log + rethrow duplica trazas | Solo loguear O relanzar, no ambos |
| S2925 | Thread.Sleep en tests | Tests lentos e intermitentes → async wait |
| S3169 | Múltiples OrderBy | Segundo `OrderBy` reemplaza el primero → `ThenBy` |

---

## 5. ARQUITECTURA — Clean Architecture / DDD

### Separación de capas

| ID | Severidad | Regla | Verificación |
|----|-----------|-------|--------------|
| ARCH-01 | Blocker | Domain no depende de Infrastructure | `grep "using Microsoft.EntityFrameworkCore" src/Domain/` |
| ARCH-02 | Critical | Application solo depende de Domain | No imports de `Infrastructure.*` en Application |
| ARCH-03 | Major | Controllers sin lógica de negocio | Controller → `_mediator.Send(command)` |

### DI e inmutabilidad

| ID | Severidad | Regla | Clave |
|----|-----------|-------|-------|
| ARCH-04 | Critical | No `new` para servicios | Inyectar `IService` via constructor |
| ARCH-05 | Major | Interfaces en Domain, impl en Infra | `Domain/Interfaces/` + `Infrastructure/Persistence/` |
| ARCH-06 | Major | Value Objects inmutables | `record Money(decimal Amount, string Currency)` |
| ARCH-07 | Major | Entities protegen invariantes | `private set`, `IReadOnlyList<T>`, métodos de dominio |

### EF Core y persistencia

| ID | Severidad | Regla | Clave |
|----|-----------|-------|-------|
| ARCH-08 | Critical | DbContext no se expone fuera de Infra | Inyectar `IRepository`, no `AppDbContext` |
| ARCH-09 | Minor | AsNoTracking en lecturas | `.AsNoTracking()` en queries de solo lectura |
| ARCH-10 | Major | No materializar prematuramente | `.Where().ToListAsync()`, no `.ToList().Where()` |

### Async/Await

| ID | Severidad | Regla | Clave |
|----|-----------|-------|-------|
| ARCH-11 | Critical | Sin .Result ni .Wait() | Deadlock en ASP.NET → `await` completo |
| ARCH-12 | Major | CancellationToken en cadena async | Propagar `ct` en toda la cadena I/O |

---

## Referencia de severidades

| Severidad | Acción | Bloquea merge |
|-----------|--------|---------------|
| Blocker | Corregir inmediatamente | Sí |
| Critical | Corregir antes de merge | Sí |
| Major | Corregir en sprint actual | Depende |
| Minor | Backlog técnico | No |
