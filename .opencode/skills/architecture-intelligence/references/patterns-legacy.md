---
name: patterns-legacy
description: Patrones de arquitectura para COBOL y VB.NET
context_cost: low
---

# Patrones — Legacy (COBOL / VB.NET)

---

## COBOL

### Estructura Canónica

```cobol
IDENTIFICATION DIVISION.    → Metadata del programa
ENVIRONMENT DIVISION.       → Config de ficheros y sistema
DATA DIVISION.              → Declaración de variables
  WORKING-STORAGE SECTION.  → Variables locales
  FILE SECTION.             → Record layouts
PROCEDURE DIVISION.         → Código ejecutable
  PERFORM SECTION-A.        → Llamadas a secciones
```

### Patrones Comunes

**1. Vertical Model (monolítico)**
- Un programa maneja toda la lógica
- Detection: programa >1000 líneas sin CALL statements
- Riesgo: mantenimiento imposible a largo plazo

**2. One Access Program per Table**
- Un COBOL program por tabla/fichero → interfaz de acceso
- Detection: programas con naming `*-ACCESS`, `*-IO`, `*-CRUD`
- Beneficio: encapsulación de acceso a datos

**3. Batch Processing**
- Detection: JCL files, SORT steps, sequential file processing
- Pattern: READ → PROCESS → WRITE en loop
- Detection: `PERFORM UNTIL END-OF-FILE`

**4. CICS Transaction**
- Detection: `EXEC CICS` statements
- Online transaction processing
- Screen maps (BMS)

### Patrones de Modernización

**API Wrapper**: Exponer lógica COBOL via REST
- Detection: middleware como MicroFocus, IBM CICS Web Services
- No requiere reescritura del COBOL

**Strangler Fig**: Reemplazar módulos gradualmente
- Nuevas funcionalidades en lenguaje moderno
- COBOL como backend hasta completar migración

**Rewrite incremental**: Módulo por módulo a Java/.NET
- Herramientas: Modern Systems COBOL-2-Java, Micro Focus

### Anti-patterns COBOL
- GO TO spaghetti (en lugar de PERFORM structured)
- Programas >5000 líneas sin modularización
- Hardcoded values en PROCEDURE DIVISION
- Falta de copybooks para record layouts compartidos

---

## VB.NET

### Patrones (idénticos a C#/.NET)

VB.NET comparte el ecosistema .NET completo. Los patrones son los mismos que C#:

**1. Clean Architecture** (⭐ Recomendado) → Ver `patterns-dotnet.md`
**2. MVVM** para WPF/WinForms
**3. Layered Architecture** (tradicional)

### Folder Structure

```
MyApp/
├── MyApp.Presentation/   → WinForms, WPF, ASP.NET
├── MyApp.Business/       → Business logic layer
├── MyApp.Data/           → Data access (EF, ADO.NET)
└── MyApp.Common/         → Shared utilities
```

### Detection Markers VB.NET
- Extensiones `.vb` en lugar de `.cs`
- `Imports` en lugar de `using`
- `Sub Main()` como entry point
- `Module` keyword (módulos estáticos)
- `Dim`, `As`, `ByRef`, `ByVal` keywords
- `.vbproj` project files

### VB.NET-Specific Considerations
- Verboso pero legible (My.Computer, My.Application)
- Interoperable 100% con C# en mismo .sln
- Mismas herramientas: NetArchTest, ArchUnitNET, NuGet
- Visual Studio con soporte completo

### Patrones de Modernización VB.NET
- **Migrate to C#**: Herramientas como SharpDevelop, Code Converter
- **Incremental**: Nuevos proyectos en C#, existentes en VB.NET
- **Shared library**: Core en C#, UI legacy en VB.NET

### Anti-patterns VB.NET
- Code-behind monolítico (todo en Form1.vb)
- DataSet tipados como capa de negocio
- Falta de DI (new everywhere)
- Mezcla de lógica UI y negocio en event handlers
