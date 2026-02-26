# Language Packs (16 lenguajes)

> Guía completa de incorporación: `docs/guia-incorporacion-lenguajes.md`

| Lenguaje | Conventions | Rules | Agent | Layer Matrix |
|---|---|---|---|---|
| C#/.NET | `dotnet-conventions.md` | `csharp-rules.md` | `dotnet-developer` | `layer-assignment-matrix.md` |
| TypeScript/Node.js | `typescript-conventions.md` | `typescript-rules.md` | `typescript-developer` | `layer-assignment-matrix-typescript.md` |
| Angular | `angular-conventions.md` | (usa typescript-rules) | `frontend-developer` | `layer-assignment-matrix-angular.md` |
| React | `react-conventions.md` | (usa typescript-rules) | `frontend-developer` | `layer-assignment-matrix-react.md` |
| Java/Spring Boot | `java-conventions.md` | `java-rules.md` | `java-developer` | `layer-assignment-matrix-java.md` |
| Python | `python-conventions.md` | `python-rules.md` | `python-developer` | `layer-assignment-matrix-python.md` |
| Go | `go-conventions.md` | `go-rules.md` | `go-developer` | `layer-assignment-matrix-go.md` |
| Rust | `rust-conventions.md` | `rust-rules.md` | `rust-developer` | `layer-assignment-matrix-rust.md` |
| PHP/Laravel | `php-conventions.md` | `php-rules.md` | `php-developer` | `layer-assignment-matrix-php.md` |
| Swift/iOS | `swift-conventions.md` | `swift-rules.md` | `mobile-developer` | — |
| Kotlin/Android | `kotlin-conventions.md` | `kotlin-rules.md` | `mobile-developer` | — |
| Ruby/Rails | `ruby-conventions.md` | `ruby-rules.md` | `ruby-developer` | — |
| VB.NET | `vbnet-conventions.md` | (usa csharp-rules) | `dotnet-developer` | (usa .NET matrix) |
| COBOL | `cobol-conventions.md` | `cobol-rules.md` | `cobol-developer` | — |
| Terraform/IaC | `terraform-conventions.md` | `terraform-rules.md` | `terraform-developer` | — |
| Flutter/Dart | `flutter-conventions.md` | `flutter-rules.md` | `mobile-developer` | — |

## Detección automática

Al cargar un proyecto (`/context:load`), detectar el Language Pack por archivos presentes:

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
