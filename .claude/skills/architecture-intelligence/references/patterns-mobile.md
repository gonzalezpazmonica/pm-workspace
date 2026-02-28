---
name: patterns-mobile
description: Patrones de arquitectura para Swift (iOS), Kotlin (Android) y Flutter
context_cost: low
---

# Patrones — Mobile (Swift / Kotlin / Flutter)

---

## Swift (iOS)

### 1. MVVM (⭐ Recomendado)

**Folder Structure**:
```
App/
├── Models/              → Data models, DTOs
├── ViewModels/          → Presentation logic, state
├── Views/               → SwiftUI views or UIKit VCs
├── Services/            → Network, storage, auth
├── Repositories/        → Data access abstraction
└── Coordinator/         → Navigation (optional)
```

**Detection Markers**:
- `*ViewModel` classes con `@Published` properties
- `ObservableObject` protocol conformance
- SwiftUI: `@StateObject`, `@ObservedObject`, `@EnvironmentObject`
- Combine: `AnyPublisher`, `sink`, `assign`

### 2. VIPER (apps complejas)

**Detection Markers**:
- Carpetas por módulo: `View/`, `Interactor/`, `Presenter/`, `Entity/`, `Router/`
- Protocols definiendo contratos entre componentes
- Router/Wireframe para navegación
- Cada módulo auto-contenido

### 3. Clean Architecture (The Composable Architecture - TCA)

**Detection Markers**:
- `import ComposableArchitecture`
- `Reducer`, `Store`, `Effect`, `Action`, `State`
- Composición de reducers

**iOS Tools**: SwiftLint, SwiftFormat, XCTest, Quick/Nimble

---

## Kotlin (Android)

### 1. MVVM (⭐ Recomendado — Google official)

**Folder Structure**:
```
app/src/main/java/com/example/
├── ui/
│   └── feature/
│       ├── FeatureFragment.kt
│       ├── FeatureViewModel.kt
│       └── FeatureAdapter.kt
├── data/
│   ├── local/            → Room database, DAOs
│   ├── remote/           → Retrofit services
│   └── repository/       → Repository implementations
├── domain/
│   ├── model/            → Domain models
│   ├── repository/       → Repository interfaces
│   └── usecase/          → Use cases
└── di/                   → Hilt modules
```

**Detection Markers**:
- `ViewModel` classes extending `androidx.lifecycle.ViewModel`
- `@HiltViewModel` annotation
- `StateFlow`, `LiveData`, `MutableStateFlow`
- Room: `@Entity`, `@Dao`, `@Database`
- Retrofit: `@GET`, `@POST`, `interface ApiService`
- Coroutines: `viewModelScope.launch`, `suspend fun`

### 2. MVI (Model-View-Intent)

**Detection Markers**:
- `sealed class Intent`, `sealed class State`
- Unidirectional data flow
- Orbit-MVI, MVIKotlin libraries

**Android Tools**: Detekt (lint), MockK (testing), Turbine (Flow testing)

---

## Flutter

### 1. MVVM + GetX (⭐ Recomendado para rapidez)

**Folder Structure**:
```
lib/
├── app/
│   ├── modules/          → Feature modules
│   │   └── home/
│   │       ├── bindings/
│   │       ├── controllers/  → GetxController (ViewModel)
│   │       └── views/
│   ├── routes/           → Route definitions
│   └── data/
│       ├── models/       → Data models
│       ├── providers/    → API providers
│       └── repositories/ → Data access
└── main.dart
```

**Detection Markers GetX**: `GetxController`, `Get.put()`, `Obx()`, `GetMaterialApp`

### 2. BLoC Pattern

**Detection Markers**:
- `flutter_bloc` package
- `*Bloc` classes, `*Event`, `*State` sealed classes
- `BlocProvider`, `BlocBuilder`, `BlocListener`

### 3. Provider Pattern

**Detection Markers**:
- `ChangeNotifier` classes
- `Provider.of<T>()`, `Consumer<T>`
- `MultiProvider` en widget tree

### 4. Clean Architecture (Flutter)

**Detection Markers**:
- `domain/`, `data/`, `presentation/` layers
- Use case classes con `call()` method
- Repository interfaces en domain

**Flutter Tools**: flutter_test, mockito, flutter_lints, very_good_analysis

---

## Anti-patterns comunes (cross-mobile)
- Business logic en Views/Activities/Widgets
- No separation de networking de UI
- State management inconsistente (mezclar patrones)
- Deep widget/view hierarchy sin composition
- Falta de offline-first para datos críticos
