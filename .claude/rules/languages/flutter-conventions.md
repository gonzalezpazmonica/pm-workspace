---
paths:
  - "**/*.dart"
  - "**/pubspec.yaml"
---

# Regla: Convenciones y Prácticas Flutter/Dart
# ── Aplica a todos los proyectos Flutter en este workspace ──────────────────────

## Verificación obligatoria en cada tarea

Antes de dar una tarea por terminada, ejecutar siempre en este orden:

```bash
flutter analyze                                # 1. ¿Análisis estático sin issues?
dart format --set-exit-if-changed .           # 2. ¿Formato correcto?
flutter test                                   # 3. ¿Pasan los tests?
flutter build apk --release (Android)         # 4. Build release exitoso
flutter build ios --release (iOS)              # 5. Build release exitoso
```

## Convenciones de código Dart

- **Naming:** `PascalCase` para clases, `camelCase` para variables/funciones, `kebab-case` para ficheros
- **Null safety:** Obligatorio — no usar `late` sin documentar; `?` para nullable types
- **Type annotations:** Obligatorias en parámetros y return types; nunca `dynamic`
- **Constants:** `const` siempre que sea posible; `final` para variables que no cambian
- **Formatting:** DartFormatter (integrado); `dart format` antes de commit
- **Imports:** Agrupar (dart, paquetes, locales); usar `show`/`hide` para claridad
- **Comments:** Documentar tipos, funciones públicas; explicar "por qué", no "qué"

## Arquitectura Clean Architecture por Feature

```
lib/
├── main.dart
├── config/
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── colors.dart
│   ├── routes/
│   │   └── app_router.dart
│   └── constants.dart
├── core/
│   ├── error/
│   │   └── failures.dart
│   ├── network/
│   │   └── api_client.dart
│   └── utils/
│       └── extensions.dart
└── features/
    └── {feature}/
        ├── data/
        │   ├── datasources/
        │   │   ├── local_data_source.dart
        │   │   └── remote_data_source.dart
        │   ├── models/
        │   │   └── user_model.dart
        │   └── repositories/
        │       └── user_repository_impl.dart
        ├── domain/
        │   ├── entities/
        │   │   └── user.dart
        │   ├── repositories/
        │   │   └── user_repository.dart
        │   └── usecases/
        │       └── get_users_usecase.dart
        └── presentation/
            ├── pages/
            │   └── users_page.dart
            ├── widgets/
            │   └── user_card.dart
            ├── controllers/
            │   └── users_controller.dart
            └── providers.dart
```

## Riverpod — State Management (preferido)

Riverpod es superior a Provider, BLoC para Flutter moderno:

```dart
// Providers simples
final nameProvider = StateProvider<String>((ref) => 'Guest');

// Providers asincronos
final usersProvider = FutureProvider<List<User>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getUsers();
});

// State Notifier para lógica compleja
class UsersNotifier extends StateNotifier<List<User>> {
  UsersNotifier(this._repository) : super([]);
  
  final UserRepository _repository;
  
  Future<void> loadUsers() async {
    state = await _repository.getUsers();
  }
}

final usersNotifierProvider = StateNotifierProvider<UsersNotifier, List<User>>(
  (ref) => UsersNotifier(ref.watch(userRepositoryProvider)),
);

// En Widget
@override
Widget build(BuildContext context, WidgetRef ref) {
  final users = ref.watch(usersProvider);
  
  return users.when(
    data: (userList) => ListView(children: [
      for (final user in userList) UserCard(user: user)
    ]),
    loading: () => CircularProgressIndicator(),
    error: (err, stack) => ErrorWidget(error: err),
  );
}
```

## Widgets y UI

- **Stateless > Stateful:** Preferir stateless; usar Riverpod para estado
- **Builders:** `Builder`, `Consumer`, `ConsumerWidget` según necesidad
- **Key naming:** Usar para testing; names que reflejen propósito
- **Composición:** Extractar widgets pequeños; máximo 200 líneas por widget
- **Material vs Cupertino:** Decidir consistencia; no mezclar estilos

```dart
class UserListPage extends ConsumerWidget {
  const UserListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: usersAsync.when(
        data: (users) => UserListView(users: users),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorView(error: error.toString()),
      ),
    );
  }
}

class UserListView extends StatelessWidget {
  final List<User> users;
  
  const UserListView({Key? key, required this.users}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) => UserCard(user: users[index]),
    );
  }
}
```

## Modelos y Serialización

```dart
// Usar Freezed para inmutabilidad y serialización automática
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required int id,
    required String name,
    required String email,
    @Default('') String avatar,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

// Uso
final user = User(id: 1, name: 'John', email: 'john@example.com');
final userMap = user.toJson();
```

## Acceso a datos con Repository Pattern

```dart
// Interface en domain/
abstract class UserRepository {
  Future<List<User>> getUsers();
  Future<User> getUserById(int id);
}

// Implementación en data/
class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remote;
  final UserLocalDataSource local;

  UserRepositoryImpl({required this.remote, required this.local});

  @override
  Future<List<User>> getUsers() async {
    try {
      final users = await remote.getUsers();
      await local.cacheUsers(users);
      return users;
    } catch (e) {
      return local.getCachedUsers();
    }
  }
}

// Provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl(
    remote: ref.watch(userRemoteDataSourceProvider),
    local: ref.watch(userLocalDataSourceProvider),
  );
});
```

## Tests — Widget Testing

```dart
void main() {
  group('UserListPage', () {
    testWidgets('displays users when data is loaded', (WidgetTester tester) async {
      // Arrange
      final testUsers = [
        User(id: 1, name: 'Alice', email: 'alice@example.com'),
        User(id: 2, name: 'Bob', email: 'bob@example.com'),
      ];
      
      // Act
      await tester.pumpWidget(
        ProviderContainer(
          overrides: [
            usersProvider.overrideWithValue(AsyncValue.data(testUsers)),
          ],
          child: MaterialApp(home: UserListPage()),
        ),
      );

      // Assert
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('shows loading spinner while fetching', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderContainer(
          overrides: [
            usersProvider.overrideWithValue(const AsyncValue.loading()),
          ],
          child: const MaterialApp(home: UserListPage()),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
```

## Gestión de dependencias (pub.dev)

```bash
flutter pub add {paquete}                     # añadir
flutter pub get                                # instalar
flutter pub outdated                           # actualizar disponibles
flutter pub upgrade                            # actualizar todo
flutter pub audit                              # vulnerabilidades
```

Paquetes recomendados:
- **State:** `riverpod`, `flutter_riverpod`
- **Networking:** `dio`, `http`
- **Serialización:** `json_serializable`, `freezed`
- **BD local:** `hive`, `sqflite`, `isar`
- **Testing:** `mocktail`, `integration_test`

## Migraciones y BD local (Hive)

```dart
// Inicializar
import 'package:hive/hive.dart';

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(UserAdapter());
  runApp(MyApp());
}

// Usar
final box = await Hive.openBox<User>('users');
box.add(user);
final users = box.values.toList();
```

## Logging y Debug

```dart
import 'package:flutter_logs/flutter_logs.dart';

FlutterLogs.initLogs(
  logLevelsEnabled: [LogLevel.INFO, LogLevel.WARNING, LogLevel.ERROR],
);

FlutterLogs.logInfo(
  log: 'Loaded ${users.length} users',
  logLevel: LogLevel.INFO,
);
```

## Build y Deploy

### Android
```bash
flutter build apk --release                    # APK
flutter build appbundle --release              # App Bundle (Google Play)
```

### iOS
```bash
flutter build ios --release                    # Framework
cd ios && fastlane beta                        # Deploy con Fastlane
```

### Web
```bash
flutter build web --release
firebase deploy                                # Deploy a Firebase Hosting
```

## Configuración del proyecto

```yaml
# pubspec.yaml
name: my_app
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  riverpod: ^2.4.0
  freezed_annotation: ^2.4.0
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
  freezed: ^2.4.0
```

## Hooks recomendados para proyectos Flutter

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "cd $(git rev-parse --show-toplevel) && flutter analyze 2>&1 | head -20"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "flutter test --reporter=expanded 2>&1 | tail -30"
    }]
  }
}
```
