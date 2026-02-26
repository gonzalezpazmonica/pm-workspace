# Reglas de Análisis Estático C#/.NET — Knowledge Base para Agente de Revisión

> Fuente: [SonarSource sonar-dotnet](https://github.com/SonarSource/sonar-dotnet) · [Reglas C#](https://rules.sonarsource.com/csharp/)
> Última actualización: 2026-02-25

---

## Instrucciones para el Agente

Eres un agente de revisión de código C#/.NET. Tu rol es analizar código fuente aplicando las reglas documentadas a continuación, equivalentes a un análisis de SonarQube.

**Protocolo de reporte:**

Para cada hallazgo reporta:

- **ID de regla** (ej: S2259)
- **Severidad** (Blocker / Critical / Major / Minor)
- **Línea(s) afectada(s)**
- **Descripción del problema**
- **Sugerencia de corrección con código**

**Priorización obligatoria:**

1. Primero: **Vulnerabilities** y **Security Hotspots** — riesgo de seguridad
2. Después: **Bugs** — comportamiento incorrecto en runtime
3. Finalmente: **Code Smells** — mantenibilidad y deuda técnica

**Directivas de contexto:**

- Aplica las reglas **en contexto** — no reportes falsos positivos obvios
- Si un patrón es intencional y está documentado (comentario explícito), no lo reportes
- Considera el framework (.NET 8/10, ASP.NET Core, EF Core) al evaluar las reglas
- Responde siempre en **español**

---

## 1. VULNERABILITIES — Seguridad

> 🔴 Prioridad máxima. Cada hallazgo aquí es un riesgo de seguridad real.

### 1.1 Blocker

#### S2068 — Credenciales hardcodeadas

**Severidad**: Blocker · **Tags**: cwe
**Problema**: Contraseñas y credenciales embebidas en código fuente exponen accesos no autorizados.

```csharp
// ❌ Noncompliant
string password = "Admin123";
string url = "scheme://user:Admin123@domain.com";

// ✅ Compliant
string password = GetEncryptedPassword();
string url = $"scheme://{username}:{GetSecret()}@domain.com";
```

**Impacto**: Cualquier persona con acceso al código fuente obtiene las credenciales.

#### S2115 — Conexión a BD sin contraseña segura

**Severidad**: Blocker · **Tags**: cwe
**Problema**: Connection strings con password vacío permiten acceso sin autenticación.

```csharp
// ❌ Noncompliant
optionsBuilder.UseSqlServer("Server=myServer;Database=myDB;User Id=admin;Password=");

// ✅ Compliant
optionsBuilder.UseSqlServer("Server=myServer;Database=myDB;Integrated Security=True");
```

**Impacto**: Acceso no autenticado a la base de datos.

#### S2755 — Vulnerabilidad XXE en parseo XML

**Severidad**: Blocker · **Tags**: cwe
**Problema**: XML parsers con resolución de entidades externas habilitada permiten XXE.

```csharp
// ❌ Noncompliant
XmlDocument parser = new XmlDocument();
parser.XmlResolver = new XmlUrlResolver();
parser.LoadXml(input);

// ✅ Compliant
XmlDocument parser = new XmlDocument();
parser.XmlResolver = null;
parser.LoadXml(input);
```

**Impacto**: Lectura de ficheros del servidor, SSRF, DoS.

#### S6418 — Secretos hardcodeados

**Severidad**: Blocker · **Tags**: cwe
**Problema**: Tokens y secretos como constantes en código son extraíbles fácilmente.

```csharp
// ❌ Noncompliant
const string mySecret = "47828a8dd77ee1eb9dde2d5e93cb221ce8c32b37";

// ✅ Compliant
static readonly string mySecret = Environment.GetEnvironmentVariable("MY_APP_SECRET");
```

**Impacto**: Exposición directa de tokens de autenticación.

#### S6781 — Claves JWT expuestas

**Severidad**: Blocker · **Tags**: cwe, symbolic-execution
**Problema**: Claves JWT en configuración o hardcodeadas permiten falsificar tokens.

```csharp
// ❌ Noncompliant
var key = _config["Jwt:Key"];
var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key));

// ✅ Compliant
var key = Environment.GetEnvironmentVariable("JWT_KEY")
    ?? throw new ApplicationException("JWT key not configured.");
var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key));
```

**Impacto**: Suplantación de identidad mediante tokens forjados.

### 1.2 Critical

#### S2053 — Salt predecible en hashing de passwords

**Severidad**: Critical · **Tags**: cwe, symbolic-execution
**Problema**: Sales débiles o predecibles facilitan ataques con tablas precomputadas.

```csharp
// ❌ Noncompliant
var salt = Encoding.UTF8.GetBytes("salty");
var hashed = new Rfc2898DeriveBytes(password, salt);

// ✅ Compliant
var hashed = new Rfc2898DeriveBytes(password, 16, 100_000, HashAlgorithmName.SHA512);
```

#### S3329 — IV predecible en cifrado CBC

**Severidad**: Critical · **Tags**: cwe, symbolic-execution
**Problema**: Reutilizar el mismo IV permite detectar patrones en el texto cifrado.

```csharp
// ❌ Noncompliant
byte[] iv = new byte[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
var encryptor = aes.CreateEncryptor(key, iv);

// ✅ Compliant
var encryptor = aes.CreateEncryptor(key, aes.IV);
```

#### S4423 — Protocolos SSL/TLS débiles

**Severidad**: Critical · **Tags**: cwe, privacy
**Problema**: TLS 1.0/1.1 y SSL 3.0 tienen vulnerabilidades criptográficas conocidas.

```csharp
// ❌ Noncompliant
ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls;

// ✅ Compliant
ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12 | SecurityProtocolType.Tls13;
```

#### S4426 — Claves criptográficas débiles

**Severidad**: Critical · **Tags**: cwe, privacy
**Problema**: RSA < 2048 bits o ECC < 224 bits son vulnerables a fuerza bruta.

```csharp
// ❌ Noncompliant
var rsa = new RSACryptoServiceProvider(); // Default: 1024 bits
ECDsa ecdsa = ECDsa.Create(ECCurve.NamedCurves.brainpoolP160t1);

// ✅ Compliant
var rsa = new RSACryptoServiceProvider(2048);
ECDsa ecdsa = ECDsa.Create(ECCurve.NamedCurves.nistP256);
```

#### S4433 — Conexión LDAP sin autenticación

**Severidad**: Critical · **Tags**: cwe
**Problema**: Conexiones LDAP anónimas permiten acceso no autorizado al directorio.

```csharp
// ❌ Noncompliant
var entry = new DirectoryEntry(adPath);
entry.AuthenticationType = AuthenticationTypes.None;

// ✅ Compliant
var entry = new DirectoryEntry(adPath, "user", "pass", AuthenticationTypes.Secure);
```

#### S4830 — Validación de certificados TLS desactivada

**Severidad**: Critical · **Tags**: cwe, privacy, ssl
**Problema**: Desactivar la validación de certificados permite ataques MITM.

```csharp
// ❌ Noncompliant
ServicePointManager.ServerCertificateValidationCallback +=
    (sender, cert, chain, errors) => true;

// ✅ Compliant — usar validación por defecto o añadir CAs al trust store
```

#### S5344 — Hashing de passwords débil

**Severidad**: Critical · **Tags**: cwe
**Problema**: Algoritmos rápidos (MD5, SHA1) o pocas iteraciones en PBKDF2.

```csharp
// ❌ Noncompliant
KeyDerivation.Pbkdf2(password, salt, KeyDerivationPrf.HMACSHA256, iterationCount: 1, numBytesRequested: 32);

// ✅ Compliant
KeyDerivation.Pbkdf2(password, salt, KeyDerivationPrf.HMACSHA256, iterationCount: 100_000, numBytesRequested: 32);
```

#### S5445 — Creación insegura de ficheros temporales

**Severidad**: Critical · **Tags**: cwe
**Problema**: `Path.GetTempFileName()` tiene race conditions explotables.

```csharp
// ❌ Noncompliant
var tempPath = Path.GetTempFileName();

// ✅ Compliant
var randomPath = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
using var fs = new FileStream(randomPath, FileMode.CreateNew, FileAccess.Write,
    FileShare.None, 4096, FileOptions.DeleteOnClose);
```

#### S5542 — Modo de cifrado débil

**Severidad**: Critical · **Tags**: cwe, privacy
**Problema**: ECB no oculta patrones; PKCS1v1.5 para RSA es vulnerable.

```csharp
// ❌ Noncompliant
new AesManaged { Mode = CipherMode.ECB };

// ✅ Compliant
var aes = new AesGcm(key);
```

#### S5547 — Algoritmo criptográfico obsoleto

**Severidad**: Critical · **Tags**: cwe, privacy
**Problema**: DES, Triple DES, RC2 son insuficientes para protección moderna.

```csharp
// ❌ Noncompliant
var cipher = new DESCryptoServiceProvider();

// ✅ Compliant
using var aes = Aes.Create();
```

#### S5659 — JWT sin verificar firma

**Severidad**: Critical · **Tags**: cwe, privacy
**Problema**: Tokens JWT sin verificación de firma permiten tokens forjados.

```csharp
// ❌ Noncompliant
decoder.Decode(token, secret, verify: false);

// ✅ Compliant
decoder.Decode(token, secret, verify: true);
```

### 1.3 Major

#### S5773 — Deserialización sin restricciones

**Severidad**: Major · **Tags**: cwe, symbolic-execution
**Problema**: Deserialización no restringida de datos no confiables permite RCE.

```csharp
// ❌ Noncompliant
var formatter = new BinaryFormatter();
formatter.Deserialize(stream);

// ✅ Compliant
var formatter = new BinaryFormatter();
formatter.Binder = new AllowListBinder(); // Restricción de tipos
formatter.Deserialize(stream);
```

**Impacto**: Ejecución remota de código.

#### S6377 — Validación insegura de firmas XML

**Severidad**: Major
**Problema**: Validar firmas XML sin verificar la referencia permite manipulación.

---

## 2. SECURITY HOTSPOTS — Revisión manual necesaria

> 🟡 Código potencialmente sensible que requiere evaluación contextual.

### 2.1 Critical

#### S2245 — PRNG no criptográfico usado en contexto de seguridad

**Tags**: cwe
**Problema**: `System.Random` es predecible; no usar para tokens o claves.

```csharp
// ❌ Sensitive
var random = new Random();
byte[] token = new byte[16];
random.NextBytes(token);

// ✅ Compliant
var rng = RandomNumberGenerator.Create();
byte[] token = new byte[16];
rng.GetBytes(token);
```

#### S4502 — CSRF protection desactivada

**Tags**: cwe
**Problema**: Desactivar tokens anti-CSRF permite ataques cross-site.

```csharp
// ❌ Sensitive
[HttpPost, IgnoreAntiforgeryToken]
public IActionResult ChangeEmail(Model model) => View();

// ✅ Compliant
[HttpPost, AutoValidateAntiforgeryToken]
public IActionResult ChangeEmail(Model model) => View();
```

#### S4790 — Algoritmos hash débiles

**Tags**: cwe
**Problema**: MD5 y SHA-1 pueden producir colisiones.

```csharp
// ❌ Sensitive
var hash = new MD5CryptoServiceProvider();
var hash2 = new SHA1Managed();

// ✅ Compliant
var hash = new SHA512Managed();
```

#### S5042 — Zip Bomb

**Tags**: cwe
**Problema**: Extraer archivos sin validar tamaño permite DoS.

```csharp
// ❌ Sensitive
entry.ExtractToFile("output.txt", true); // Sin validar tamaño

// ✅ Compliant — validar ratio de compresión, tamaño total y número de entradas
```

#### S5332 — Protocolos en texto claro

**Tags**: cwe
**Problema**: HTTP, FTP, Telnet exponen datos a interceptación.

```csharp
// ❌ Sensitive
var url = "http://example.com";
using var smtp = new SmtpClient("host", 25); // Sin SSL

// ✅ Compliant
var url = "https://example.com";
using var smtp = new SmtpClient("host", 25) { EnableSsl = true };
```

#### S5443 — Ficheros temporales en directorios públicos

**Tags**: cwe
**Problema**: Nombres predecibles en /tmp permiten race conditions.

```csharp
// ❌ Sensitive
using var writer = new StreamWriter("/tmp/f");

// ✅ Compliant
var path = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
```

### 2.2 Major

#### S2077 — SQL con string formatting

**Tags**: cwe, sql
**Problema**: Concatenar strings en queries SQL facilita SQL injection.

```csharp
// ❌ Sensitive
string query = string.Format("INSERT INTO Users (name) VALUES (\"{0}\")", param);
command = new SqlCommand(query);

// ✅ Compliant
context.Database.ExecuteSqlCommand("SELECT * FROM mytable WHERE col=@p0", param);
```

#### S5693 — Sin límite de tamaño en requests HTTP

**Tags**: cwe
**Problema**: Permitir requests ilimitados facilita DoS.

```csharp
// ❌ Sensitive
[HttpPost, DisableRequestSizeLimit]
public IActionResult Upload(Model model) { }

// ✅ Compliant
[HttpPost, RequestSizeLimit(8_388_608)] // 8 MB
public IActionResult Upload(Model model) { }
```

#### S6444 — Regex sin timeout

**Tags**: cwe, regex
**Problema**: Regex sin timeout pueden causar ReDoS (catastrophic backtracking).

```csharp
// ❌ Sensitive
var regex = new Regex("(a+)+");
Regex.IsMatch(input, "[0-9]+");

// ✅ Compliant
var regex = new Regex("(a+)+", RegexOptions.None, TimeSpan.FromMilliseconds(100));
Regex.IsMatch(input, "[0-9]+", RegexOptions.NonBacktracking); // .NET 7+
```

### 2.3 Minor

#### S2092 — Cookie sin flag Secure

**Tags**: cwe, privacy
**Problema**: Cookies sin `Secure` se transmiten por HTTP sin cifrar.

```csharp
// ❌ Sensitive
myCookie.Secure = false;

// ✅ Compliant
myCookie.Secure = true;
```

#### S3330 — Cookie sin flag HttpOnly

**Tags**: cwe, privacy
**Problema**: Cookies sin `HttpOnly` son accesibles desde JavaScript (XSS).

```csharp
// ❌ Sensitive
myCookie.HttpOnly = false;

// ✅ Compliant
myCookie.HttpOnly = true;
```

#### S4507 — Debug habilitado en producción

**Tags**: cwe, debug
**Problema**: `UseDeveloperExceptionPage()` expone información sensible del sistema.

```csharp
// ❌ Sensitive
app.UseDeveloperExceptionPage(); // Sin verificar entorno

// ✅ Compliant
if (env.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}
```

#### S5122 — CORS permisivo

**Tags**: cwe
**Problema**: `Access-Control-Allow-Origin: *` permite a cualquier sitio acceder a la API.

```csharp
// ❌ Sensitive
builder.WithOrigins("*");
builder.AllowAnyOrigin();
Response.Headers.Add("Access-Control-Allow-Origin", origin); // Sin validar

// ✅ Compliant
builder.WithOrigins("https://trustedwebsite.com");
if (trustedOrigins.Contains(origin))
{
    Response.Headers.Add("Access-Control-Allow-Origin", origin);
}
```

---

## 3. BUGS — Errores de runtime

> 🔴 Código que causa comportamiento incorrecto en ejecución.

### 3.1 Blocker

#### S1048 — Excepción en Finalizer

**Tags**: (ninguno)
**Problema**: Lanzar excepciones en `~Destructor()` puede crashear la aplicación.

```csharp
// ❌ Noncompliant
~MyClass()
{
    throw new NotImplementedException();
}

// ✅ Compliant
~MyClass()
{
    // Cleanup sin excepciones
}
```

#### S2190 — Recursión o bucle infinito

**Tags**: suspicious
**Problema**: Bucles sin condición de salida o recursión sin caso base causan StackOverflow.

```csharp
// ❌ Noncompliant
while (true) { result += i; i++; }
int Prop { get => Prop; } // Recursión infinita en getter

// ✅ Compliant
while (result < 1000) { result += i; i++; }
```

#### S2275 — Format string inválido

**Tags**: (ninguno)
**Problema**: Placeholders incorrectos o argumentos insuficientes causan `FormatException`.

```csharp
// ❌ Noncompliant
string.Format("[0}", arg0);          // Bracket incorrecto
string.Format("{0} {1}", arg0);      // Falta arg1

// ✅ Compliant
string.Format("{0} {1}", arg0, arg1);
```

#### S2930 — IDisposable no dispuesto

**Tags**: cwe, denial-of-service
**Problema**: Recursos no dispuestos causan memory leaks y file handle leaks.

```csharp
// ❌ Noncompliant
var fs = new FileStream(path, FileMode.Open);
fs.Write(bytes, 0, bytes.Length);
// fs nunca se dispone

// ✅ Compliant
using var fs = new FileStream(path, FileMode.Open);
fs.Write(bytes, 0, bytes.Length);
```

#### S2931 — Clase con campo IDisposable sin implementar IDisposable

**Tags**: cwe, denial-of-service
**Problema**: Campos IDisposable nunca se disponen si la clase no implementa el patrón.

```csharp
// ❌ Noncompliant
public class ResourceHolder // No implementa IDisposable
{
    private FileStream fs;
}

// ✅ Compliant
public class ResourceHolder : IDisposable
{
    private FileStream fs;
    public void Dispose() => fs?.Dispose();
}
```

### 3.2 Critical

#### S2222 — Lock no liberado en todos los paths

**Tags**: cwe, multi-threading, symbolic-execution
**Problema**: Locks no liberados causan deadlocks.

```csharp
// ❌ Noncompliant
Monitor.Enter(obj);
if (condition) { Monitor.Exit(obj); }
// Si !condition, lock nunca se libera

// ✅ Compliant
lock (obj) { /* ... */ }
```

#### S2551 — Lock en objetos compartidos

**Tags**: multi-threading
**Problema**: `lock(this)`, `lock(typeof(T))` o `lock("string")` causan deadlocks accidentales.

```csharp
// ❌ Noncompliant
lock (this) { /* ... */ }

// ✅ Compliant
private readonly object _lock = new();
lock (_lock) { /* ... */ }
```

#### S4586 — Método async que retorna null

**Tags**: async-await
**Problema**: Retornar null desde un método que devuelve Task causa NullReferenceException al await.

```csharp
// ❌ Noncompliant
public Task DoAsync() => null;

// ✅ Compliant
public Task DoAsync() => Task.CompletedTask;
```

#### S5856 — Regex con sintaxis inválida

**Tags**: regex
**Problema**: Expresiones regulares malformadas lanzan excepción en runtime.

```csharp
// ❌ Noncompliant
var regex = new Regex("[A");

// ✅ Compliant
var regex = new Regex("[A-Z]");
```

#### S7131 — Read/Write lock liberado incorrectamente

**Tags**: symbolic-execution
**Problema**: Liberar un write lock cuando se adquirió un read lock (y viceversa).

#### S7133 — Lock liberado fuera del método de adquisición

**Tags**: symbolic-execution
**Problema**: Locks adquiridos en un método deben liberarse en el mismo método.

### 3.3 Major (selección más relevante para .NET moderno)

#### S2259 — Null pointer dereference

**Tags**: cwe, symbolic-execution
**Problema**: Acceder a una referencia null causa `NullReferenceException`.

```csharp
// ❌ Noncompliant
object obj = null;
Console.WriteLine(obj.ToString());

// ✅ Compliant
var obj = new object();
Console.WriteLine(obj.ToString());
```

#### S3168 — Método async void

**Tags**: multi-threading, async-await
**Problema**: `async void` impide capturar excepciones y testear correctamente.

```csharp
// ❌ Noncompliant
private async void ThrowExceptionAsync()
{
    throw new InvalidOperationException();
}

// ✅ Compliant
private async Task ThrowExceptionAsync()
{
    throw new InvalidOperationException();
}
```

#### S3655 — Acceso a Nullable sin verificar HasValue

**Tags**: cwe, symbolic-execution
**Problema**: Acceder a `.Value` sin verificar lanza `InvalidOperationException`.

```csharp
// ❌ Noncompliant
int? val = condition ? 42 : null;
Console.WriteLine(val.Value);

// ✅ Compliant
if (val.HasValue) { Console.WriteLine(val.Value); }
```

#### S3949 — Overflow en cálculos

**Tags**: overflow, symbolic-execution
**Problema**: Operaciones aritméticas que exceden el rango del tipo se truncan silenciosamente.

```csharp
// ❌ Noncompliant
int number = int.MaxValue;
return number + value;

// ✅ Compliant
long number = int.MaxValue;
return number + value;
```

#### S2583 — Condición siempre true/false

**Tags**: cwe, symbolic-execution
**Problema**: Condiciones constantes generan código inalcanzable.

```csharp
// ❌ Noncompliant
bool a = false;
if (a) { DoSomething(); } // Nunca se ejecuta

// ✅ Compliant
bool a = EvaluateCondition();
if (a) { DoSomething(); }
```

#### S1244 — Comparación de flotantes con ==

**Tags**: (ninguno)
**Problema**: La imprecisión de punto flotante hace que `==` sea poco fiable.

```csharp
// ❌ Noncompliant
if (myNumber == 3.146f) { }

// ✅ Compliant
if (Math.Abs(myNumber - 3.146f) < 0.0001f) { }
```

#### S2201 — Retorno ignorado de método sin side effects

**Tags**: suspicious
**Problema**: Llamar a un método puro sin usar su resultado es código muerto.

#### S2114 — Colección pasada como argumento a su propio método

**Tags**: (ninguno)
**Problema**: `list.AddRange(list)` o `list.Equals(list)` es un error o sinsentido.

#### S3966 — Doble dispose

**Tags**: (ninguno)
**Problema**: Disponer un objeto dos veces puede causar `ObjectDisposedException`.

#### S4143 — Elementos de colección reemplazados incondicionalmente

**Tags**: suspicious
**Problema**: Asignar al mismo key sin verificar sobrescribe datos silenciosamente.

---

## 4. CODE SMELLS — Mantenibilidad

> 🟡 No causan bugs directos pero aumentan la deuda técnica.

### 4.1 Critical

#### S3776 — Complejidad cognitiva alta

**Tags**: brain-overload
**Problema**: Métodos con demasiada complejidad son difíciles de entender y testear.

```csharp
// ❌ Noncompliant — Complejidad cognitiva > 15
decimal CalculatePrice(User user, Cart cart)
{
    decimal total = CalculateTotal(cart);
    if (user.HasMembership()               // +1
        && user.OrdersCount > 10           // +1
        && user.AccountActive
        && !user.HasDiscount
        || user.OrdersCount == 1)          // +1
    {
        total = ApplyDiscount(user, total);
    }
    return total;
}

// ✅ Compliant — Extraer condiciones
decimal CalculatePrice(User user, Cart cart)
{
    decimal total = CalculateTotal(cart);
    if (IsEligibleForDiscount(user)) { total = ApplyDiscount(user, total); }
    return total;
}
```

#### S3216 — ConfigureAwait(false) en librerías

**Tags**: multi-threading, async-await, performance
**Problema**: Código de librería debe usar `ConfigureAwait(false)` para evitar deadlocks.

```csharp
// ❌ Noncompliant (en código de librería)
var response = await httpClient.GetAsync(url);

// ✅ Compliant
var response = await httpClient.GetAsync(url).ConfigureAwait(false);
```

#### S5034 — ValueTask consumido incorrectamente

**Tags**: async-await
**Problema**: `ValueTask` no debe ser awaited múltiples veces ni usado concurrentemente.

```csharp
// ❌ Noncompliant
ValueTask<int> vt = ComputeAsync();
int r1 = await vt;
int r2 = await vt; // Segundo await

// ✅ Compliant
int r1 = await ComputeAsync();
int r2 = await ComputeAsync();
```

#### S2696 — Escritura a campo static desde método de instancia

**Tags**: multi-threading
**Problema**: Actualizar campos estáticos desde métodos de instancia causa race conditions.

```csharp
// ❌ Noncompliant
class MyClass { private static int count = 0; public void Inc() { count++; } }

// ✅ Compliant — usar Interlocked o método estático
```

#### S4487 — Campo privado escrito pero nunca leído

**Tags**: cwe, unused
**Problema**: Dead store — campo que se asigna pero jamás se lee.

#### S927 — Nombres de parámetros inconsistentes con base

**Tags**: suspicious
**Problema**: Override que cambia nombres de parámetros confunde a los consumidores.

### 4.2 Major (selección .NET moderno)

#### S1854 — Asignaciones no usadas (dead stores)

**Tags**: cwe, unused
**Problema**: Variables asignadas cuyo valor nunca se lee son código muerto.

```csharp
// ❌ Noncompliant
int x = 100;  // Dead store
x = 150;      // Dead store
x = 200;
return x;

// ✅ Compliant
int x = 200;
return x;
```

#### S1481 — Variable local no usada

**Tags**: unused
**Problema**: Variables declaradas pero nunca referenciadas añaden ruido.

```csharp
// ❌ Noncompliant
public int Minutes(int hours) { int seconds = 0; return hours * 60; }

// ✅ Compliant
public int Minutes(int hours) { return hours * 60; }
```

#### S112 — Lanzar excepciones genéricas o reservadas

**Tags**: cwe, error-handling
**Problema**: `throw new Exception()` o `throw new NullReferenceException()` no es específico.

```csharp
// ❌ Noncompliant
throw new NullReferenceException("obj");

// ✅ Compliant
throw new ArgumentNullException(nameof(obj));
```

#### S1144 — Miembros privados no usados

**Tags**: unused
**Problema**: Código muerto — métodos o clases privadas sin referencias.

#### S1066 — Ifs anidados que pueden fusionarse

**Tags**: clumsy
**Problema**: Ifs anidados sin else pueden combinarse con `&&`.

```csharp
// ❌ Noncompliant
if (file != null) { if (file.IsFile()) { /* ... */ } }

// ✅ Compliant
if (file != null && file.IsFile()) { /* ... */ }
```

#### S2971 — LINQ simplificable

**Tags**: clumsy
**Problema**: Expresiones LINQ con pasos redundantes reducen rendimiento y legibilidad.

```csharp
// ❌ Noncompliant
seq.Select(x => x as Car).Any(x => x != null);
seq.Where(x => x.HasOwner).Any();
list.Count();       // Usa Count() en vez de .Count

// ✅ Compliant
seq.OfType<Car>().Any();
seq.Any(x => x.HasOwner);
list.Count;         // Propiedad directa
```

#### S2589 — Expresiones booleanas gratuitas

**Tags**: cwe, suspicious, symbolic-execution
**Problema**: Condiciones que siempre son true/false no aportan lógica.

```csharp
// ❌ Noncompliant
var a = true;
if (a) { DoSomething(); }     // Siempre true
string d = null;
var v = d ?? "value";          // d siempre null
```

#### S2933 — Campos que deberían ser readonly

**Tags**: confusing
**Problema**: Campos asignados solo en constructor deben ser `readonly`.

```csharp
// ❌ Noncompliant
private int _birthYear;
Person(int year) { _birthYear = year; }

// ✅ Compliant
private readonly int _birthYear;
Person(int year) { _birthYear = year; }
```

#### S4144 — Métodos con implementación idéntica

**Tags**: suspicious
**Problema**: Métodos duplicados indican copy-paste; refactorizar.

#### S2699 — Tests sin assertions

**Tags**: tests
**Problema**: Tests sin aserciones dan falsa sensación de cobertura.

```csharp
// ❌ Noncompliant
[Fact]
public void Add_SingleNumber()
{
    var calc = new StringCalculator();
    var result = calc.Add("0"); // Sin assert
}

// ✅ Compliant
[Fact]
public void Add_SingleNumber()
{
    var calc = new StringCalculator();
    var result = calc.Add("0");
    result.Should().Be(0);
}
```

#### S1118 — Utility class instanciable

**Tags**: design
**Problema**: Clases con solo miembros estáticos no deben poder instanciarse.

```csharp
// ❌ Noncompliant
public class StringUtils { public static string Concat(string a, string b) => a + b; }

// ✅ Compliant
public static class StringUtils { public static string Concat(string a, string b) => a + b; }
```

#### S1168 — Retornar null en vez de colección vacía

**Tags**: (ninguno)
**Problema**: Retornar null fuerza al caller a verificar nulidad.

```csharp
// ❌ Noncompliant
public Result[] GetResults() => null;

// ✅ Compliant
public Result[] GetResults() => Array.Empty<Result>();
public IEnumerable<Result> GetResults() => Enumerable.Empty<Result>();
```

#### S125 — Código comentado

**Tags**: unused
**Problema**: Código comentado es ruido; está en el control de versiones si se necesita.

#### S2139 — Excepciones logueadas Y relanzadas

**Tags**: logging, error-handling
**Problema**: Loguear y relanzar duplica trazas en los logs.

#### S2925 — Thread.Sleep en tests

**Tags**: tests, bad-practice
**Problema**: `Thread.Sleep` hace tests lentos e intermitentes.

#### S3169 — Múltiples OrderBy

**Tags**: performance
**Problema**: Cada `OrderBy()` reemplaza el anterior; usar `ThenBy()`.

---

## 5. REGLAS DE ARQUITECTURA — Clean Architecture / DDD

> Complementan las reglas de SonarQube con buenas prácticas de arquitectura hexagonal y DDD.

### 5.1 Separación de capas

#### ARCH-01 — Domain no debe depender de Infrastructure

**Severidad**: Blocker
**Problema**: El dominio importa namespaces de infraestructura (EF Core, HttpClient, etc).

```csharp
// ❌ Noncompliant
namespace MyApp.Domain.Entities;
using Microsoft.EntityFrameworkCore; // Domain depende de Infrastructure

// ✅ Compliant
namespace MyApp.Domain.Entities;
// Solo tipos propios del dominio, sin dependencias externas
```

**Verificación**: `grep -rn "using Microsoft.EntityFrameworkCore" src/Domain/`

#### ARCH-02 — Application solo depende de Domain

**Severidad**: Critical
**Problema**: La capa Application importa implementaciones concretas de Infrastructure.

```csharp
// ❌ Noncompliant
namespace MyApp.Application.Services;
using MyApp.Infrastructure.Persistence; // Dependencia directa

// ✅ Compliant
namespace MyApp.Application.Services;
using MyApp.Domain.Interfaces; // Solo interfaces
```

#### ARCH-03 — API/Controllers no deben contener lógica de negocio

**Severidad**: Major
**Problema**: Controllers con más de validación + orquestación indican lógica mal ubicada.

```csharp
// ❌ Noncompliant
[HttpPost]
public async Task<IActionResult> CreateOrder(OrderRequest req)
{
    // Lógica de negocio directamente en el controller
    if (req.Items.Sum(i => i.Price) > 1000) { /* descuento */ }
    var order = new Order { /* mapeo manual */ };
    _context.Orders.Add(order);
    await _context.SaveChangesAsync();
    return Ok(order);
}

// ✅ Compliant
[HttpPost]
public async Task<IActionResult> CreateOrder(CreateOrderCommand command)
{
    var result = await _mediator.Send(command);
    return result.Match(Ok, BadRequest);
}
```

### 5.2 Inyección de dependencias

#### ARCH-04 — No usar `new` para crear servicios en producción

**Severidad**: Critical
**Problema**: Instanciar servicios con `new` viola DIP y dificulta el testing.

```csharp
// ❌ Noncompliant
public class OrderService
{
    private readonly EmailService _email = new EmailService(); // Acoplamiento directo
}

// ✅ Compliant
public class OrderService
{
    private readonly IEmailService _email;
    public OrderService(IEmailService email) { _email = email; }
}
```

#### ARCH-05 — Interfaces en Domain, implementaciones en Infrastructure

**Severidad**: Major
**Problema**: Las interfaces de repositorio deben estar en Domain, las implementaciones en Infrastructure.

```csharp
// ❌ Noncompliant
// src/Infrastructure/IOrderRepository.cs ← interfaz en infra

// ✅ Compliant
// src/Domain/Interfaces/IOrderRepository.cs ← interfaz en domain
// src/Infrastructure/Persistence/OrderRepository.cs ← impl en infra
```

### 5.3 Value Objects e inmutabilidad

#### ARCH-06 — Value Objects deben ser inmutables

**Severidad**: Major
**Problema**: Value Objects con setters públicos pierden sus garantías de igualdad por valor.

```csharp
// ❌ Noncompliant
public class Money
{
    public decimal Amount { get; set; }  // Mutable
    public string Currency { get; set; } // Mutable
}

// ✅ Compliant
public record Money(decimal Amount, string Currency);
// O con clase:
public sealed class Money : ValueObject
{
    public decimal Amount { get; }
    public string Currency { get; }
    public Money(decimal amount, string currency) { Amount = amount; Currency = currency; }
    protected override IEnumerable<object> GetEqualityComponents()
    {
        yield return Amount;
        yield return Currency;
    }
}
```

#### ARCH-07 — Entities deben proteger sus invariantes

**Severidad**: Major
**Problema**: Entidades con setters públicos permiten estados inválidos.

```csharp
// ❌ Noncompliant
public class Order
{
    public OrderStatus Status { get; set; }  // Cualquiera puede cambiar el estado
    public List<OrderLine> Lines { get; set; } = new();
}

// ✅ Compliant
public class Order
{
    public OrderStatus Status { get; private set; }
    private readonly List<OrderLine> _lines = new();
    public IReadOnlyList<OrderLine> Lines => _lines.AsReadOnly();

    public void Cancel()
    {
        if (Status == OrderStatus.Shipped)
            throw new DomainException("No se puede cancelar un pedido enviado.");
        Status = OrderStatus.Cancelled;
    }
}
```

### 5.4 EF Core y persistencia

#### ARCH-08 — DbContext no debe exponerse fuera de Infrastructure

**Severidad**: Critical
**Problema**: Inyectar `DbContext` directamente en Application/API acopla capas.

```csharp
// ❌ Noncompliant
public class OrderService
{
    private readonly AppDbContext _context; // Application depende de EF Core
}

// ✅ Compliant
public class OrderService
{
    private readonly IOrderRepository _orders; // Abstracción
}
```

#### ARCH-09 — Queries deben usar AsNoTracking para lecturas

**Severidad**: Minor
**Problema**: Queries de solo lectura sin `AsNoTracking()` desperdician memoria en change tracking.

```csharp
// ❌ Noncompliant
var orders = await _context.Orders.Where(o => o.Status == "Active").ToListAsync();

// ✅ Compliant
var orders = await _context.Orders
    .AsNoTracking()
    .Where(o => o.Status == "Active")
    .ToListAsync();
```

#### ARCH-10 — No materializar queries prematuramente

**Severidad**: Major
**Problema**: `.ToList()` antes de filtrar ejecuta la query completa en memoria.

```csharp
// ❌ Noncompliant
var result = _context.Orders.ToList().Where(o => o.Total > 100);
// Trae TODOS los pedidos a memoria y luego filtra

// ✅ Compliant
var result = await _context.Orders.Where(o => o.Total > 100).ToListAsync();
// Filtra en base de datos
```

### 5.5 async/await

#### ARCH-11 — Cadena async completa, sin .Result ni .Wait()

**Severidad**: Critical
**Problema**: `.Result` y `.Wait()` causan deadlocks en ASP.NET Core.

```csharp
// ❌ Noncompliant
public string GetData()
{
    var result = _httpClient.GetStringAsync(url).Result; // Deadlock potencial
    return result;
}

// ✅ Compliant
public async Task<string> GetDataAsync()
{
    var result = await _httpClient.GetStringAsync(url);
    return result;
}
```

#### ARCH-12 — CancellationToken en toda la cadena async

**Severidad**: Major
**Problema**: Métodos async de I/O sin `CancellationToken` no pueden cancelarse.

```csharp
// ❌ Noncompliant
public async Task<Order> GetOrderAsync(Guid id)
{
    return await _context.Orders.FindAsync(id);
}

// ✅ Compliant
public async Task<Order> GetOrderAsync(Guid id, CancellationToken ct = default)
{
    return await _context.Orders.FindAsync(new object[] { id }, ct);
}
```

---

## Referencia rápida de severidades

| Severidad | Acción | Bloquea merge |
|---|---|---|
| **Blocker** | Corregir inmediatamente | ✅ Sí |
| **Critical** | Corregir antes de merge | ✅ Sí |
| **Major** | Corregir en el sprint actual | 🟡 Depende |
| **Minor** | Backlog técnico | ❌ No |
| **Info** | Informativo | ❌ No |
