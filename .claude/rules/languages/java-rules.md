---
paths:
  - "**/*.java"
---

# Reglas de Análisis Estático Java — Knowledge Base para Agente de Revisión

> Fuente: [SonarJava](https://rules.sonarsource.com/java/), [SpotBugs](https://spotbugs.readthedocs.io/), [PMD](https://pmd.github.io/)
> Última actualización: 2026-02-26

---

## Instrucciones para el Agente

Eres un agente de revisión de código Java. Tu rol es analizar código fuente aplicando las reglas documentadas a continuación, equivalentes a un análisis de SonarQube.

**Protocolo de reporte:**

Para cada hallazgo reporta:

- **ID de regla** (ej: S2068)
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
- Considera el framework (Spring Boot, Hibernate, Jakarta EE) al evaluar las reglas
- Responde siempre en **español**

---

## 1. VULNERABILITIES — Seguridad

> 🔴 Prioridad máxima. Cada hallazgo aquí es un riesgo de seguridad real.

### 1.1 Blocker

#### S2068 — Credenciales hardcodeadas

**Severidad**: Blocker · **Tags**: cwe
**Problema**: Contraseñas y credenciales embebidas en código fuente exponen accesos no autorizados.

```java
// ❌ Noncompliant
String password = "Admin123";
String dbUrl = "jdbc:postgresql://user:password@localhost/db";

// ✅ Compliant
String password = System.getenv("DB_PASSWORD");
String dbUrl = System.getenv("DATABASE_URL");
```

**Impacto**: Cualquier persona con acceso al código fuente obtiene las credenciales.

#### S2115 — Conexión a BD sin contraseña

**Severidad**: Blocker · **Tags**: cwe
**Problema**: Connection strings con password vacío permiten acceso sin autenticación.

```java
// ❌ Noncompliant
String url = "jdbc:mysql://localhost/db?user=admin&password=";
Connection conn = DriverManager.getConnection(url);

// ✅ Compliant
String url = "jdbc:mysql://localhost/db";
String username = System.getenv("DB_USER");
String password = System.getenv("DB_PASSWORD");
Connection conn = DriverManager.getConnection(url, username, password);
```

**Impacto**: Acceso no autenticado a la base de datos.

#### S3649 — SQL Injection

**Severidad**: Blocker · **Tags**: cwe, injection
**Problema**: Concatenación de SQL con datos de usuario sin parameterización permite inyección SQL.

```java
// ❌ Noncompliant
String userId = request.getParameter("id");
String sql = "SELECT * FROM users WHERE id = " + userId;
Statement stmt = connection.createStatement();
ResultSet rs = stmt.executeQuery(sql);

// ✅ Compliant
String userId = request.getParameter("id");
String sql = "SELECT * FROM users WHERE id = ?";
PreparedStatement pstmt = connection.prepareStatement(sql);
pstmt.setString(1, userId);
ResultSet rs = pstmt.executeQuery();
```

**Impacto**: Acceso no autorizado a datos, modificación de BD, ejecución de comandos arbitrarios.

#### S5131 — XXE Vulnerability

**Severidad**: Blocker · **Tags**: cwe, xml
**Problema**: Parseo de XML con resolución de entidades externas permite XXE attacks.

```java
// ❌ Noncompliant
DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
DocumentBuilder builder = factory.newDocumentBuilder();
Document doc = builder.parse(new InputSource(userInput));

// ✅ Compliant
DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
DocumentBuilder builder = factory.newDocumentBuilder();
Document doc = builder.parse(new InputSource(userInput));
```

**Impacto**: Lectura de ficheros del servidor, SSRF, DoS.

#### S6251 — Contraseñas en logs

**Severidad**: Blocker · **Tags**: cwe, sensitive-data
**Problema**: Registrar contraseñas o tokens en logs expone credenciales.

```java
// ❌ Noncompliant
logger.info("User login with password: " + password);
logger.debug("API Key: " + apiKey);

// ✅ Compliant
logger.info("User login successful");
logger.debug("API authentication completed");
// O usar redacción:
logger.info("User login with password: " + maskPassword(password));
```

**Impacto**: Exposición de credenciales en logs o sistemas de monitoreo.

### 1.2 Critical

#### S2053 — Hashing de contraseñas débil

**Severidad**: Critical · **Tags**: cwe, crypto
**Problema**: Usar hashing débil (MD5, SHA-1) o sin salt para contraseñas.

```java
// ❌ Noncompliant
String hash = MessageDigest.getInstance("MD5").digest(password.getBytes());
String hash = BCrypt.hashpw(password, BCrypt.gensalt(4)); // salt rounds bajo

// ✅ Compliant
String hash = BCrypt.hashpw(password, BCrypt.gensalt(12)); // 12+ rounds
// O con Spring Security:
PasswordEncoder encoder = new BCryptPasswordEncoder(12);
String hash = encoder.encode(password);
```

**Impacto**: Rainbow tables pueden descifrar contraseñas débiles en segundos.

#### S4423 — Protocolos SSL/TLS débiles

**Severidad**: Critical · **Tags**: cwe, crypto
**Problema**: Usar protocolos SSL/TLS antiguos o desactivar validación de certificados.

```java
// ❌ Noncompliant
HttpsURLConnection conn = (HttpsURLConnection) url.openConnection();
conn.setHostnameVerifier((hostname, session) -> true); // desactiva verificación

// ✅ Compliant
HttpsURLConnection conn = (HttpsURLConnection) url.openConnection();
conn.setHostnameVerifier(HttpsURLConnection.getDefaultHostnameVerifier());
// O con Spring RestTemplate:
RestTemplate restTemplate = new RestTemplate();
// certifica automáticamente
```

**Impacto**: Man-in-the-middle attacks, intercepción de datos.

#### S4830 — Validación de certificados TLS desactivada

**Severidad**: Critical · **Tags**: cwe, crypto
**Problema**: Ignorar errores de validación de certificados SSL/TLS.

```java
// ❌ Noncompliant
TrustManager[] trustAllCerts = new TrustManager[]{
    new X509TrustManager() {
        public java.security.cert.X509Certificate[] getAcceptedIssuers() { return null; }
        public void checkClientTrusted(X509Certificate[] certs, String authType) {}
        public void checkServerTrusted(X509Certificate[] certs, String authType) {}
    }
};

// ✅ Compliant
// Usar sistema de certificados estándar de Java
SSLContext context = SSLContext.getInstance("TLSv1.3");
context.init(null, null, null);
HttpsURLConnection conn = (HttpsURLConnection) url.openConnection();
conn.setSSLSocketFactory(context.getSocketFactory());
```

**Impacto**: MITM attacks, interception de datos sensibles.

#### S5344 — Algoritmo criptográfico obsoleto

**Severidad**: Critical · **Tags**: cwe, crypto
**Problema**: Usar algoritmos criptográficos débiles o deprecados (DES, SHA-1).

```java
// ❌ Noncompliant
Cipher cipher = Cipher.getInstance("DES/ECB/PKCS5Padding");
MessageDigest digest = MessageDigest.getInstance("SHA-1");

// ✅ Compliant
Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
MessageDigest digest = MessageDigest.getInstance("SHA-256");
// O mejor aún:
SecureRandom random = new SecureRandom();
byte[] nonce = new byte[96 / 8];
random.nextBytes(nonce);
```

**Impacto**: Descifrado de datos encriptados, comprometimiento de confidencialidad.

---

## 2. SECURITY HOTSPOTS

#### J-HOT-01 — Reflexión para acceso a métodos privados

**Severidad**: Critical
```java
// ❌ Sensitive — potencial para circumvention de seguridad
Method method = clazz.getDeclaredMethod("privateMethod");
method.setAccessible(true);
method.invoke(obj);
```

#### J-HOT-02 — Deserialización de datos de usuario

**Severidad**: Critical
```java
// ❌ Sensitive — ObjectInputStream puede ejecutar código arbitrario
ObjectInputStream ois = new ObjectInputStream(userInput);
Object obj = ois.readObject();
```

#### J-HOT-03 — Runtime.exec() con entrada de usuario

**Severidad**: Critical
```java
// ❌ Sensitive — inyección de comandos
String cmd = "rm -rf " + userPath;
Runtime.getRuntime().exec(cmd);

// ✅ Compliant
ProcessBuilder pb = new ProcessBuilder("rm", "-rf", sanitizedPath);
pb.start();
```

---

## 3. BUGS

### 3.1 Blocker

#### J-BUG-01 — Null Pointer Exception

**Severidad**: Blocker
```java
// ❌ Noncompliant
String name = user.getName(); // user puede ser null
System.out.println(name.length());

// ✅ Compliant
if (user != null && user.getName() != null) {
    System.out.println(user.getName().length());
} else {
    logger.warn("User or name is null");
}
// O mejor:
Optional<User> userOpt = getUserById(id);
userOpt.ifPresent(u -> System.out.println(u.getName().length()));
```

**Impacto**: NullPointerException en runtime.

#### J-BUG-02 — Resource leak (File, Connection)

**Severidad**: Blocker
```java
// ❌ Noncompliant — resource no se cierra si hay excepción
FileInputStream fis = new FileInputStream("file.txt");
byte[] data = new byte[1024];
fis.read(data);
fis.close();

// ✅ Compliant — try-with-resources garantiza cierre
try (FileInputStream fis = new FileInputStream("file.txt")) {
    byte[] data = new byte[1024];
    fis.read(data);
} // fis se cierra automáticamente
```

**Impacto**: File descriptors no liberados, agotamiento de recursos.

#### J-BUG-03 — Concurrent Modification Exception

**Severidad**: Blocker
```java
// ❌ Noncompliant
List<String> items = new ArrayList<>(Arrays.asList("a", "b", "c"));
for (String item : items) {
    if (item.equals("b")) items.remove(item); // modifica durante iteración
}

// ✅ Compliant
Iterator<String> it = items.iterator();
while (it.hasNext()) {
    if (it.next().equals("b")) it.remove();
}
// O mejor:
items.removeIf(item -> item.equals("b"));
```

**Impacto**: ConcurrentModificationException, comportamiento impredecible.

### 3.2 Major

#### J-BUG-04 — Raw types en generics

**Severidad**: Major
```java
// ❌ Noncompliant
List items = new ArrayList(); // raw type
items.add("string");
items.add(123);
String str = (String) items.get(1); // ClassCastException

// ✅ Compliant
List<String> items = new ArrayList<>();
items.add("string");
// items.add(123); // compilation error — previene errores
String str = items.get(0); // sin cast
```

**Impacto**: ClassCastException en runtime, pérdida de type safety.

#### J-BUG-05 — Checked exception no manejada

**Severidad**: Major
```java
// ❌ Noncompliant
public void readFile() {
    FileReader reader = new FileReader("file.txt"); // IOException no manejada
    // ...
}

// ✅ Compliant
public void readFile() throws FileNotFoundException {
    try (FileReader reader = new FileReader("file.txt")) {
        // ...
    } catch (FileNotFoundException e) {
        logger.error("File not found", e);
        throw e; // o manejar apropiadamente
    }
}
```

**Impacto**: Excepciones no capturadas, crash de aplicación.

---

## 4. CODE SMELLS

### 4.1 Critical

#### J-SMELL-01 — Método muy largo (> 50 líneas)

**Severidad**: Critical
```java
// ❌ Noncompliant
public void processOrder(Order order) {
    // 100 líneas de lógica mezclada
    validateOrder(order);
    calculateTax(order);
    applyDiscount(order);
    saveOrder(order);
    sendNotification(order);
    // ... más código
}

// ✅ Compliant
public void processOrder(Order order) {
    validate(order);
    calculate(order);
    save(order);
    notifyCustomer(order);
}

private void calculate(Order order) {
    applyTaxCalculation(order);
    applyDiscountLogic(order);
}
```

**Impacto**: Difícil de testear, mantener y entender.

#### J-SMELL-02 — Complejidad ciclomática muy alta (> 10)

**Severidad**: Critical
```java
// ❌ Noncompliant
public String getStatus(User user) {
    if (user.isActive()) {
        if (user.hasPermission()) {
            if (user.isVerified()) {
                if (user.hasSubscription()) {
                    return "ACTIVE";
                } else {
                    return "INACTIVE_NO_SUB";
                }
            } else {
                return "UNVERIFIED";
            }
        } else {
            return "NO_PERMISSION";
        }
    } else {
        return "INACTIVE";
    }
}

// ✅ Compliant
public String getStatus(User user) {
    if (!user.isActive()) return "INACTIVE";
    if (!user.hasPermission()) return "NO_PERMISSION";
    if (!user.isVerified()) return "UNVERIFIED";
    if (!user.hasSubscription()) return "INACTIVE_NO_SUB";
    return "ACTIVE";
}
```

**Impacto**: Difícil de testear, propenso a bugs.

### 4.2 Major

#### J-SMELL-03 — Variables no usadas

**Severidad**: Major
```java
// ❌ Noncompliant
public void process() {
    String unusedVariable = "test";
    int count = 0;
    // count no se usa
}

// ✅ Compliant
public void process() {
    int count = calculateItems();
    logger.info("Processed {} items", count);
}
```

#### J-SMELL-04 — Campos públicos mutables

**Severidad**: Major
```java
// ❌ Noncompliant
public class User {
    public String name;
    public int age;
}

// ✅ Compliant
public class User {
    private final String name;
    private final int age;
    
    public User(String name, int age) {
        this.name = name;
        this.age = age;
    }
    
    public String getName() { return name; }
    public int getAge() { return age; }
}
```

---

## 5. REGLAS DE ARQUITECTURA

#### ARCH-01 — Inyección de dependencias obligatoria

**Severidad**: Blocker
```java
// ❌ Noncompliant — acoplamiento fuerte
@Service
public class OrderService {
    private UserRepository userRepo = new UserRepository(); // new en clase
    
    public void create(Order order) {
        userRepo.save(order);
    }
}

// ✅ Compliant — inyección en constructor
@Service
public class OrderService {
    private final UserRepository userRepo;
    
    public OrderService(UserRepository userRepo) {
        this.userRepo = userRepo;
    }
}
```

**Impacto**: Facilita testing, desacoplamiento, mantenibilidad.

#### ARCH-02 — Repositorio pattern en Spring Boot

**Severidad**: Critical
```java
// ✅ Compliant — hexagonal architecture
// 1. Interface en domain/
public interface UserRepository {
    Optional<User> findById(Long id);
    void save(User user);
}

// 2. Implementación en infrastructure/
@Repository
public class JpaUserRepository implements UserRepository {
    @Autowired private UserJpaRepository jpaRepo;
    
    @Override
    public Optional<User> findById(Long id) {
        return jpaRepo.findById(id).map(UserEntity::toDomain);
    }
}

// 3. Spring Data JPA (infraestructura)
@Repository
interface UserJpaRepository extends JpaRepository<UserEntity, Long> {
}

// 4. Uso en service
@Service
public class UserService {
    private final UserRepository repository;
    public UserService(UserRepository repository) {
        this.repository = repository;
    }
}
```

**Impacto**: Independencia de framework, testabilidad, clean architecture.

#### ARCH-03 — No retornar entidades JPA de controllers

**Severidad**: Critical
```java
// ❌ Noncompliant — expone JPA entity
@GetMapping("/{id}")
public UserEntity getUser(@PathVariable Long id) {
    return userRepo.findById(id).orElseThrow();
}

// ✅ Compliant — retorna DTO
@GetMapping("/{id}")
public UserResponse getUser(@PathVariable Long id) {
    User user = userService.findById(id).orElseThrow();
    return UserResponse.from(user);
}
```

**Impacto**: Previene serialización de campos internos, lazy loading issues, vulnerabilidades.

---

## Referencia rápida de severidades

| Severidad | Acción | Bloquea merge |
|---|---|---|
| **Blocker** | Corregir inmediatamente | ✅ Sí |
| **Critical** | Corregir antes de merge | ✅ Sí |
| **Major** | Corregir en el sprint actual | 🟡 Depende |
| **Minor** | Backlog técnico | ❌ No |
