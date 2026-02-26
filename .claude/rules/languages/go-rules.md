# Reglas de Análisis Estático Go — Knowledge Base para Agente de Revisión

> Fuente: [go vet](https://golang.org/cmd/vet/), [staticcheck](https://staticcheck.io/), [gosec](https://github.com/securego/gosec)
> Última actualización: 2026-02-26

---

## Instrucciones para el Agente

Eres un agente de revisión de código Go. Tu rol es analizar código fuente aplicando las reglas documentadas a continuación, equivalentes a análisis de go vet, staticcheck y gosec.

**Protocolo de reporte:**

Para cada hallazgo reporta:

- **ID de regla** (ej: G201)
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
- Considera Go idioms y patterns al evaluar las reglas
- Responde siempre en **español**

---

## 1. VULNERABILITIES — Seguridad

> 🔴 Prioridad máxima. Cada hallazgo aquí es un riesgo de seguridad real.

### 1.1 Blocker

#### G201 — SQL Injection

**Severidad**: Blocker · **Tags**: cwe, injection
**Problema**: Concatenación de SQL con datos de usuario sin parameterización permite inyección SQL.

```go
// ❌ Noncompliant
userID := r.URL.Query().Get("id")
query := fmt.Sprintf("SELECT * FROM users WHERE id = %s", userID)
rows, err := db.Query(query)

// ✅ Compliant
userID := r.URL.Query().Get("id")
rows, err := db.Query("SELECT * FROM users WHERE id = ?", userID)
```

**Impacto**: Acceso no autorizado a datos, modificación de BD.

#### G202 — Command Injection

**Severidad**: Blocker · **Tags**: cwe, injection
**Problema**: Construcción de comandos shell con entrada de usuario permite inyección de comandos.

```go
// ❌ Noncompliant
userPath := r.URL.Query().Get("path")
cmd := exec.Command("sh", "-c", fmt.Sprintf("ls -la %s", userPath))
output, err := cmd.Output()

// ✅ Compliant
userPath := r.URL.Query().Get("path")
cmd := exec.Command("ls", "-la", userPath)
output, err := cmd.Output()
```

**Impacto**: Ejecución arbitraria de comandos en el servidor.

#### G203 — Credenciales hardcodeadas

**Severidad**: Blocker · **Tags**: cwe, sensitive-data
**Problema**: Contraseñas y credenciales embebidas en código fuente exponen accesos.

```go
// ❌ Noncompliant
const (
    DBPassword = "SuperSecret123"
    APIKey     = "sk-1234567890abcdef"
)

// ✅ Compliant
import "os"

var (
    DBPassword = os.Getenv("DB_PASSWORD")
    APIKey     = os.Getenv("API_KEY")
)
```

**Impacto**: Cualquier persona con acceso al código obtiene las credenciales.

#### G301 — Validación de certificados TLS desactivada

**Severidad**: Blocker · **Tags**: cwe, crypto
**Problema**: Ignorar errores de validación de certificados SSL/TLS en HTTPS.

```go
// ❌ Noncompliant
client := &http.Client{
    Transport: &http.Transport{
        TLSClientConfig: &tls.Config{
            InsecureSkipVerify: true,
        },
    },
}
resp, err := client.Get("https://api.example.com")

// ✅ Compliant
client := &http.Client{}  // usa validación estándar
resp, err := client.Get("https://api.example.com")
```

**Impacto**: MITM attacks, intercepción de datos sensibles.

#### G304 — Path traversal

**Severidad**: Blocker · **Tags**: cwe, path-traversal
**Problema**: Usar entrada de usuario directamente en rutas de archivo sin validación.

```go
// ❌ Noncompliant
filename := r.URL.Query().Get("file")
content, err := ioutil.ReadFile(filepath.Join("/uploads", filename))

// ✅ Compliant
import "path/filepath"

filename := r.URL.Query().Get("file")
basePath := "/uploads"
fullPath := filepath.Join(basePath, filename)
fullPath, _ := filepath.Abs(fullPath)
baseAbs, _ := filepath.Abs(basePath)

// Verificar que fullPath está dentro de basePath
if !strings.HasPrefix(fullPath, baseAbs) {
    return fmt.Errorf("path traversal detected")
}
content, err := ioutil.ReadFile(fullPath)
```

**Impacto**: Lectura de archivos arbitrarios del servidor.

### 1.2 Critical

#### G401 — Hashing débil para contraseñas

**Severidad**: Critical · **Tags**: cwe, crypto
**Problema**: Usar hashing débil (MD5, SHA-1) para contraseñas.

```go
// ❌ Noncompliant
import "crypto/md5"

hash := md5.Sum([]byte(password))
hashStr := fmt.Sprintf("%x", hash)

// ✅ Compliant
import "golang.org/x/crypto/bcrypt"

hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), 12)
```

**Impacto**: Rainbow tables pueden descifrar contraseñas en segundos.

#### G402 — Certificados TLS débiles

**Severidad**: Critical · **Tags**: cwe, crypto
**Problema**: Usar protocolos SSL/TLS antiguos o débiles.

```go
// ❌ Noncompliant
config := &tls.Config{
    MinVersion: tls.VersionSSL30,
}

// ✅ Compliant
config := &tls.Config{
    MinVersion: tls.VersionTLS13,
}
```

**Impacto**: Protocolo TLS puede ser downgradeado a versiones débiles.

#### G403 — Uso de insecure cryptographic algorithms

**Severidad**: Critical · **Tags**: cwe, crypto
**Problema**: Usar algoritmos criptográficos débiles (DES, MD5, RC4).

```go
// ❌ Noncompliant
import "crypto/des"

block, _ := des.NewCipher(key)

// ✅ Compliant
import "crypto/aes"

block, _ := aes.NewCipher(key)
```

**Impacto**: Descifrado de datos encriptados.

#### G602 — Deliberate integer overflow

**Severidad**: Critical · **Tags**: cwe, numeric
**Problema**: Operaciones matemáticas sin validación de overflow/underflow.

```go
// ❌ Noncompliant
func calculateTotal(prices []uint32) uint32 {
    var total uint32
    for _, price := range prices {
        total += price  // puede hacer overflow
    }
    return total
}

// ✅ Compliant
import "math"

func calculateTotal(prices []uint32) (uint64, error) {
    var total uint64
    for _, price := range prices {
        if total > math.MaxUint32-uint64(price) {
            return 0, fmt.Errorf("overflow detected")
        }
        total += uint64(price)
    }
    return total, nil
}
```

**Impacto**: Integer overflow puede causar comportamiento impredecible.

---

## 2. SECURITY HOTSPOTS

#### G104 — Errores no chequeados

**Severidad**: Critical
```go
// ❌ Sensitive
file, _ := os.Open("data.txt")  // error ignorado
_ = file.Close()

// ✅ Compliant
file, err := os.Open("data.txt")
if err != nil {
    return fmt.Errorf("failed to open file: %w", err)
}
defer file.Close()
```

#### G306 — Permisos inseguros en archivo/directorio

**Severidad**: Critical
```go
// ❌ Sensitive
os.WriteFile("secret.txt", []byte(data), 0666)  // world-readable

// ✅ Compliant
os.WriteFile("secret.txt", []byte(data), 0600)  // owner-only
```

#### G307 — Defer en loop

**Severidad**: Critical
```go
// ❌ Sensitive
for _, file := range files {
    f, _ := os.Open(file)
    defer f.Close()  // defer se ejecuta al final de la función, no del loop
}

// ✅ Compliant
for _, file := range files {
    f, _ := os.Open(file)
    f.Close()  // cierre explícito en el loop
}
// O mejor:
for _, file := range files {
    func() {
        f, _ := os.Open(file)
        defer f.Close()
    }()
}
```

---

## 3. BUGS

### 3.1 Blocker

#### G001 — Nil pointer dereference

**Severidad**: Blocker
```go
// ❌ Noncompliant
var user *User
name := user.Name  // panic si user es nil

// ✅ Compliant
var user *User
if user != nil {
    name := user.Name
}
// O mejor con Optional pattern:
user := findUser(id)
if user == nil {
    return fmt.Errorf("user not found")
}
name := user.Name
```

**Impacto**: Runtime panic, crash de aplicación.

#### G002 — Goroutine leak

**Severidad**: Blocker
```go
// ❌ Noncompliant
func fetchData(url string) string {
    ch := make(chan string)
    go func() {
        ch <- fetchFromURL(url)
    }()
    return <-ch  // si timeout ocurre, goroutine queda colgada
}

// ✅ Compliant
import "context"
import "time"

func fetchData(ctx context.Context, url string) (string, error) {
    ch := make(chan string, 1)  // buffer para que no cuelgue
    go func() {
        ch <- fetchFromURL(url)
    }()
    
    select {
    case result := <-ch:
        return result, nil
    case <-ctx.Done():
        return "", ctx.Err()
    }
}
```

**Impacto**: Memory leaks, agotamiento de recursos.

#### G003 — Race condition

**Severidad**: Blocker
```go
// ❌ Noncompliant
var counter int
go func() { counter++ }()
go func() { counter++ }()
// data race: acceso no sincronizado

// ✅ Compliant
var counter int
var mu sync.Mutex

go func() {
    mu.Lock()
    counter++
    mu.Unlock()
}()
go func() {
    mu.Lock()
    counter++
    mu.Unlock()
}()

// O mejor con atomic:
var counter atomic.Int32
go func() { counter.Add(1) }()
go func() { counter.Add(1) }()
```

**Impacto**: Comportamiento impredecible en concurrencia.

### 3.2 Major

#### G004 — Errores no chequeados en defer

**Severidad**: Major
```go
// ❌ Noncompliant
defer file.Close()  // error ignorado
defer db.Rollback()  // error no chequeado

// ✅ Compliant
defer func() {
    if err := file.Close(); err != nil {
        logger.Error("failed to close file", err)
    }
}()

defer func() {
    if err := db.Rollback(); err != nil {
        logger.Error("failed to rollback", err)
    }
}()
```

**Impacto**: Fallos silenciosos, estado inconsistente.

#### G005 — Error shadowing

**Severidad**: Major
```go
// ❌ Noncompliant
var data []byte
if file, err := os.Open("data.txt"); err == nil {
    data, err := ioutil.ReadAll(file)  // 'err' shadowed
    // error de ReadAll se pierde
}

// ✅ Compliant
file, err := os.Open("data.txt")
if err != nil {
    return fmt.Errorf("failed to open file: %w", err)
}
defer file.Close()

data, err := ioutil.ReadAll(file)
if err != nil {
    return fmt.Errorf("failed to read file: %w", err)
}
```

**Impacto**: Errores enmascarados, comportamiento inesperado.

---

## 4. CODE SMELLS

### 4.1 Critical

#### SM-01 — Función muy larga (> 50 líneas)

**Severidad**: Critical
```go
// ❌ Noncompliant
func processOrder(order *Order) error {
    // 100+ líneas de lógica mezclada
    if err := validateOrder(order); err != nil {
        return err
    }
    tax := calculateTax(order)
    discount := applyDiscount(order)
    if err := saveOrder(order); err != nil {
        return err
    }
    // ... más código
    return nil
}

// ✅ Compliant
func processOrder(order *Order) error {
    if err := validateOrder(order); err != nil {
        return err
    }
    calculateFinancials(order)
    if err := saveOrder(order); err != nil {
        return err
    }
    return notifyCustomer(order)
}

func calculateFinancials(order *Order) {
    order.Tax = calculateTax(order)
    order.Discount = applyDiscount(order)
}
```

**Impacto**: Difícil de testear, mantener y entender.

#### SM-02 — Complejidad ciclomática muy alta (> 10)

**Severidad**: Critical
```go
// ❌ Noncompliant
func getStatus(user *User) string {
    if user.IsActive {
        if user.HasPermission {
            if user.IsVerified {
                if user.HasSubscription {
                    return "ACTIVE"
                } else {
                    return "INACTIVE_NO_SUB"
                }
            } else {
                return "UNVERIFIED"
            }
        } else {
            return "NO_PERMISSION"
        }
    } else {
        return "INACTIVE"
    }
}

// ✅ Compliant
func getStatus(user *User) string {
    if !user.IsActive {
        return "INACTIVE"
    }
    if !user.HasPermission {
        return "NO_PERMISSION"
    }
    if !user.IsVerified {
        return "UNVERIFIED"
    }
    if !user.HasSubscription {
        return "INACTIVE_NO_SUB"
    }
    return "ACTIVE"
}
```

**Impacto**: Difícil de testear, propenso a bugs.

### 4.2 Major

#### SM-03 — Variables no usadas

**Severidad**: Major
```go
// ❌ Noncompliant
func process() error {
    count := 0  // nunca se usa
    data := readData()
    return nil
}

// ✅ Compliant
func process() error {
    data := readData()
    count := len(data)
    logger.Infof("Processed %d items", count)
    return nil
}
```

#### SM-04 — Imports no usados

**Severidad**: Major
```go
// ❌ Noncompliant
import (
    "encoding/json"
    "os"
    "time"
)

func getData() string {
    return "data"  // no usa ninguno de los imports
}

// ✅ Compliant
func getData() string {
    return "data"
}
```

---

## 5. REGLAS DE ARQUITECTURA

#### ARCH-01 — Interface-based dependency injection

**Severidad**: Blocker
```go
// ❌ Noncompliant
type OrderService struct {
    repo *PostgresRepository  // acoplamiento fuerte
}

func NewOrderService() *OrderService {
    return &OrderService{
        repo: &PostgresRepository{},  // new en la función
    }
}

// ✅ Compliant
type OrderRepository interface {
    Save(ctx context.Context, order *Order) error
    FindByID(ctx context.Context, id string) (*Order, error)
}

type OrderService struct {
    repo OrderRepository  // depende de interfaz
}

func NewOrderService(repo OrderRepository) *OrderService {
    return &OrderService{repo: repo}
}
```

**Impacto**: Facilita testing, desacoplamiento, mantenibilidad.

#### ARCH-02 — Clean layering architecture

**Severidad**: Critical
```go
// ✅ Compliant — Clean Architecture
// cmd/app/main.go — punto de entrada
func main() {
    repo := infrastructure.NewPostgresOrderRepository(db)
    service := application.NewOrderService(repo)
    handler := adapter.NewOrderHTTPHandler(service)
    // ...
}

// domain/order.go — entidades, interfaces
type Order struct {
    ID    string
    Total float64
}

type OrderRepository interface {
    Save(ctx context.Context, order *Order) error
}

// application/order_service.go — casos de uso
type OrderService struct {
    repo domain.OrderRepository
}

func (s *OrderService) CreateOrder(ctx context.Context, req CreateOrderRequest) (*Order, error) {
    // lógica de negocio sin dependencias de framework
}

// infrastructure/postgres_repository.go — implementación técnica
type PostgresOrderRepository struct {
    db *sql.DB
}

func (r *PostgresOrderRepository) Save(ctx context.Context, order *Order) error {
    // implementación con SQL
}

// adapter/http.go — HTTP handlers
type OrderHTTPHandler struct {
    service *application.OrderService
}

func (h *OrderHTTPHandler) CreateOrder(w http.ResponseWriter, r *http.Request) {
    // convertir HTTP → domain, delegar a service
}
```

**Impacto**: Independencia de framework, testabilidad, clean architecture.

#### ARCH-03 — Error wrapping con context

**Severidad**: Critical
```go
// ❌ Noncompliant
if err := saveUser(user); err != nil {
    return err  // pérdida de contexto
}

// ✅ Compliant
if err := saveUser(user); err != nil {
    return fmt.Errorf("failed to save user %s: %w", user.ID, err)
}
```

**Impacto**: Debugging más fácil, mejor traceabilidad.

---

## Referencia rápida de severidades

| Severidad | Acción | Bloquea merge |
|---|---|---|
| **Blocker** | Corregir inmediatamente | ✅ Sí |
| **Critical** | Corregir antes de merge | ✅ Sí |
| **Major** | Corregir en el sprint actual | 🟡 Depende |
| **Minor** | Backlog técnico | ❌ No |
