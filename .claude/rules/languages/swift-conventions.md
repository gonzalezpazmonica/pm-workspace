---
paths:
  - "**/*.swift"
  - "**/Package.swift"
---

# Regla: Convenciones y Prácticas Swift/iOS
# ── Aplica a todos los proyectos Swift e iOS en este workspace ──────────────────────

## Verificación obligatoria en cada tarea

Antes de dar una tarea por terminada, ejecutar siempre en este orden:

```bash
xcodebuild build -scheme [Scheme] -configuration Release          # 1. ¿Compila sin warnings?
swiftformat --lint --recursive .                                   # 2. ¿Respeta el formato?
swiftlint --strict                                                 # 3. ¿Pasa linting?
xcodebuild test -scheme [Scheme]Test -configuration Debug         # 4. ¿Pasan los tests?
```

## Convenciones de código Swift

- **async/await** siempre — NUNCA `DispatchQueue`, closures o `Combine` para código secuencial
- **async throws** para operaciones que pueden fallar — estructurado y seguro
- **Optional binding** con `guard let` / `if let`, NO usar `!` forzado excepto en inicialización
- **Nombres**: camelCase para variables/funciones, PascalCase para tipos
- **Acceso**: `private` por defecto, `fileprivate` solo cuando sea necesario, `internal` explícito
- **Error handling**: tipos `Error` personalizados con enums, NUNCA strings genéricos
- **Valores inmutables**: preferir `let` sobre `var`, usar `struct` sobre `class` por defecto
- **Extensions**: agrupar por protocolo en archivos separados (e.g., `FileName+Protocol.swift`)

## Arquitectura MVVM-C con SwiftUI

```
├── Features/
│   └── [Feature]/
│       ├── Presentation/
│       │   ├── ViewModels/
│       │   │   └── [Feature]ViewModel.swift
│       │   ├── Views/
│       │   │   ├── [Feature]View.swift
│       │   │   └── [SubView]View.swift
│       │   └── Coordinators/
│       │       └── [Feature]Coordinator.swift
│       ├── Domain/
│       │   ├── Entities/
│       │   │   └── [Entity].swift
│       │   └── Usecases/
│       │       └── [Usecase].swift
│       └── Data/
│           ├── Repositories/
│           │   └── [Repository]Implementation.swift
│           └── DataSources/
│               ├── Local/
│               └── Remote/
├── Core/
│   ├── DI/
│   │   └── DIContainer.swift
│   ├── Network/
│   │   ├── APIClient.swift
│   │   └── URLSessionAPIClient.swift
│   └── Utilities/
└── App/
    └── [AppName]App.swift
```

## SwiftUI y Reactive

- **@StateObject**: para ViewModels, crear UNA vez por View
- **@ObservedObject**: para dependencias inyectadas
- **@EnvironmentObject**: para contexto global (autenticación, temas)
- **@State**: SOLO para UI local, NUNCA lógica de negocio
- Preferir `@Binding` sobre pasar ViewModel entero a subvistas
- Evitar `AnyView` — usar genéricos `<Content: View>`

```swift
// Bien
@MainActor
final class UserViewModel: ObservableObject {
    @Published var users: [User] = []
    
    func fetchUsers() async {
        do {
            self.users = try await repository.getUsers()
        } catch {
            self.handleError(error)
        }
    }
}

// Mal
var users: [User] = [] // no observable
loadUsers()  // síncrono
```

## Tests con XCTest

- Tests unitarios: `[Target]Tests`
- Tests de UI: `[Target]UITests`
- Nombrar: `test_[dado]_[cuando]_[espera]`
- Usar `XCTestCase` con métodos setUp/tearDown
- Mockear: `URLSession`, `UserDefaults`, dependencias externas
- NO hacer network calls en tests unitarios

```bash
xcodebuild test -scheme [Scheme]Tests -configuration Debug        # unitarios
xcodebuild test -scheme [Scheme]UITests -configuration Debug      # UI
xcodebuild test -scheme [Scheme]Tests -only-testing "[Target]"    # por clase
```

## SPM - Swift Package Manager

```bash
# Añadir dependencia
swift package add [package-url] --branch main

# Actualizar
swift package update

# Limpiar caché
rm -rf .build
```

- Declarar dependencias en `Package.swift` con versiones mínimas
- NUNCA usar `.branch("main")` en producción — usar `.upToNextMajor()` o tags específicos
- Verificar licencias y seguridad antes de añadir
- Preferir SPM sobre CocoaPods y Carthage

## Formato y Linting

```bash
swiftformat --recursive . --config .swiftformat
swiftlint --config .swiftlint.yml
```

Configurar en proyecto:
- `.swiftformat`: indentación (4 espacios), saltos de línea
- `.swiftlint.yml`: reglas de estilo, extensiones máximas, complejidad

```yaml
# .swiftlint.yml ejemplo
included:
  - Sources
excluded:
  - .build
  - Pods

line_length: 120
identifier_name:
  min_length: 3
  max_length: 40
function_parameter_count: 5
```

## Gestión de dependencias y actualizaciones

```bash
swift package describe                    # ver dependencias
swift package show-dependencies          # árbol de dependencias
swift package update                      # actualizar
```

- Auditar antes de actualizar: cambios breaking, actualizaciones de seguridad
- Mantener versiones mínimas compatibles
- Documentar migraciones en CHANGELOG.md

## Despliegue a App Store

```bash
xcodebuild archive -scheme [Scheme] -configuration Release \
  -derivedDataPath .build -archivePath ./app.xcarchive

xcodebuild -exportArchive -archivePath ./app.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath ./ipa
```

- **Signing**: certificados en Apple Developer Portal
- **Provisioning profiles**: automáticos vía Xcode (recomendado)
- **App Store Connect**: revisar metadata, keywords, descripción
- **Versioning**: `CFBundleShortVersionString` (público), `CFBundleVersion` (build)
- NUNCA commitear certificados o profiles

## Hooks recomendados para proyectos Swift/iOS

Añadir en `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "cd $(git rev-parse --show-toplevel) && swiftlint --strict 2>&1 | head -10"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "xcodebuild test -scheme [Scheme]Tests -configuration Debug -quiet"
    }]
  }
}
```

---

## Reglas de Análisis Estático

> Equivalente a análisis SwiftLint para Swift. Aplica en code review y pre-commit.

### Vulnerabilities (Blocker)

#### SWIFT-SEC-01 — Credenciales hardcodeadas
**Severidad**: Blocker
```swift
// ❌ Noncompliant
let apiKey = "sk-1234567890abcdef"
let password = "SuperSecret123"

// ✅ Compliant
let apiKey = Bundle.main.infoDictionary?["API_KEY"] as? String
let password = Keychain.read(key: "db_password")
```

#### SWIFT-SEC-02 — URL scheme sin validación
**Severidad**: Blocker
```swift
// ❌ Noncompliant
if let url = URL(string: userInput) {
    UIApplication.shared.open(url)  // podría abrir URL maliciosa
}

// ✅ Compliant
let allowed = ["https", "http"]
if let url = URL(string: userInput),
   allowed.contains(url.scheme ?? "") {
    UIApplication.shared.open(url)
}
```

### Bugs (Major)

#### SWIFT-BUG-01 — Force unwrap (!) sin null checking
**Severidad**: Major
```swift
// ❌ Noncompliant
let user = getUser()!  // crash si nil

// ✅ Compliant
guard let user = getUser() else { return }
// o
if let user = getUser() { process(user) }
```

#### SWIFT-BUG-02 — Retain cycle en closures
**Severidad**: Major
```swift
// ❌ Noncompliant
apiClient.fetch { result in
    self.data = result  // captura fuerte de self
}

// ✅ Compliant
apiClient.fetch { [weak self] result in
    self?.data = result  // captura débil de self
}
```

### Code Smells (Critical)

#### SWIFT-SMELL-01 — Función/método > 50 líneas
**Severidad**: Critical
Funciones de más de 50 líneas deben dividirse en funciones más pequeñas con responsabilidad única.

#### SWIFT-SMELL-02 — Complejidad ciclomática > 10
**Severidad**: Critical
Usar early returns, extraer métodos y simplificar condicionales.

### Arquitectura

#### SWIFT-ARCH-01 — Main thread violations
**Severidad**: Critical
Código Swift no debe actualizar la UI desde un hilo no-principal.
```swift
// ❌ Noncompliant
DispatchQueue.global().async {
    let data = fetchData()
    self.label.text = data  // actualizar UI en background thread
}

// ✅ Compliant
Task { @MainActor in
    let data = try await fetchData()
    self.label.text = data  // garantizado en main thread
}
```
