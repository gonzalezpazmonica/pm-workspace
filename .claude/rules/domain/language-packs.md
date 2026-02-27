# Language Packs (16 lenguajes)

> Guía completa de incorporación: `docs/guia-incorporacion-lenguajes.md`
> Ficheros de convenciones y reglas: `.claude/rules/languages/`

| Lenguaje | Conventions | Rules | Agent | Layer Matrix |
|---|---|---|---|---|
| C#/.NET | `languages/dotnet-conventions.md` | `languages/csharp-rules.md` | `dotnet-developer` | `layer-assignment-matrix.md` |
| TypeScript/Node.js | `languages/typescript-conventions.md` | `languages/typescript-rules.md` | `typescript-developer` | `layer-assignment-matrix-typescript.md` |
| Angular | `languages/angular-conventions.md` | (usa typescript-rules) | `frontend-developer` | `layer-assignment-matrix-angular.md` |
| React | `languages/react-conventions.md` | (usa typescript-rules) | `frontend-developer` | `layer-assignment-matrix-react.md` |
| Java/Spring Boot | `languages/java-conventions.md` | `languages/java-rules.md` | `java-developer` | `layer-assignment-matrix-java.md` |
| Python | `languages/python-conventions.md` | `languages/python-rules.md` | `python-developer` | `layer-assignment-matrix-python.md` |
| Go | `languages/go-conventions.md` | `languages/go-rules.md` | `go-developer` | `layer-assignment-matrix-go.md` |
| Rust | `languages/rust-conventions.md` | `languages/rust-rules.md` | `rust-developer` | `layer-assignment-matrix-rust.md` |
| PHP/Laravel | `languages/php-conventions.md` | `languages/php-rules.md` | `php-developer` | `layer-assignment-matrix-php.md` |
| Swift/iOS | `languages/swift-conventions.md` | `languages/swift-rules.md` | `mobile-developer` | — |
| Kotlin/Android | `languages/kotlin-conventions.md` | `languages/kotlin-rules.md` | `mobile-developer` | — |
| Ruby/Rails | `languages/ruby-conventions.md` | `languages/ruby-rules.md` | `ruby-developer` | — |
| VB.NET | `languages/vbnet-conventions.md` | (usa csharp-rules) | `dotnet-developer` | (usa .NET matrix) |
| COBOL | `languages/cobol-conventions.md` | `languages/cobol-rules.md` | `cobol-developer` | — |
| Terraform/IaC | `languages/terraform-conventions.md` | `languages/terraform-rules.md` | `terraform-developer` | — |
| Flutter/Dart | `languages/flutter-conventions.md` | `languages/flutter-rules.md` | `mobile-developer` | — |

## Detección automática

Al cargar un proyecto (`/context-load`), detectar el Language Pack por archivos presentes:

| Archivo | Language Pack |
|---|---|
| `*.csproj` / `*.sln` | C#/.NET |
| `package.json` + `angular.json` | Angular |
| `package.json` + `next.config.*` / `vite.config.*` | React |
| `package.json` (genérico) | TypeScript/Node.js |
| `pom.xml` / `build.gradle` | Java/Spring Boot |
| `requirements.txt` / `pyproject.toml` | Python |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `composer.json` | PHP/Laravel |
| `*.xcodeproj` / `Package.swift` | Swift/iOS |
| `build.gradle.kts` + `AndroidManifest.xml` | Kotlin/Android |
| `Gemfile` | Ruby/Rails |
| `*.vbproj` | VB.NET |
| `*.cbl` / `*.cob` | COBOL |
| `*.tf` / `main.tf` | Terraform/IaC |
| `pubspec.yaml` | Flutter/Dart |
