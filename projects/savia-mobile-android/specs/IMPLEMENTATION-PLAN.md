# Savia Mobile — Plan de Implantación

## Visión General

5 fases, 6 meses estimados. Cada fase produce un entregable desplegable.

```
Fase 0 ──→ Fase 1 ──→ Fase 2 ──→ Fase 3 ──→ Fase 4
Foundation   Chat MVP   Dashboard   SSH+Hybrid  Launch
(2 sem)     (3 sem)    (2 sem)     (3 sem)     (2 sem)
```

---

## Fase 0: Foundation (Semanas 1-2)

**Objetivo**: Proyecto Android funcional con CI/CD, arquitectura limpia y pantalla vacía.

### Entregables
1. Proyecto Android Studio con Kotlin DSL (build.gradle.kts)
2. Módulos: `:app`, `:domain`, `:data`, `:presentation`
3. Hilt configurado en todos los módulos
4. Room database con migraciones (schema export habilitado)
5. Jetpack Compose theme con Material 3 + colores Savia
6. Navigation Compose con 3 destinos (chat, dashboard, settings)
7. GitHub Actions pipeline: lint → test → build
8. Signing config para debug y release
9. .gitignore, README, LICENSE

### Criterios de aceptación
- `./gradlew assembleDebug` compila sin errores
- `./gradlew testDebugUnitTest` ejecuta (aunque sea 0 tests)
- Pipeline CI pasa en verde
- App se instala y muestra pantalla de navegación

### Tareas técnicas
| ID | Tarea | Estimación |
|----|-------|-----------|
| T-001 | Crear proyecto con Android Studio template | 2h |
| T-002 | Configurar módulos Clean Architecture | 4h |
| T-003 | Configurar Hilt en todos los módulos | 3h |
| T-004 | Crear Room database + DAOs vacíos | 3h |
| T-005 | Crear theme Compose (colores, tipografía) | 2h |
| T-006 | Configurar Navigation Compose (3 tabs) | 2h |
| T-007 | Crear pipeline GitHub Actions | 3h |
| T-008 | Configurar signing y ProGuard básico | 2h |
| T-009 | Tests de smoke (app arranca, navegación funciona) | 2h |

---

## Fase 1: Chat MVP (Semanas 3-5)

**Objetivo**: Chat funcional con Claude API, streaming, y persistencia local.

### Entregables
1. Pantalla de chat con burbujas user/assistant
2. Integración Claude Messages API con streaming SSE
3. System prompt con identidad Savia cargado desde assets
4. Almacenamiento seguro de API key (Tink + Keystore)
5. Historial de conversaciones en Room
6. Markdown rendering en mensajes
7. Input por texto y voz (Android STT)
8. Indicador de "Savia está escribiendo..."

### Criterios de aceptación
- Usuario introduce API key → se almacena cifrada
- Enviar mensaje → respuesta streaming aparece palabra por palabra
- Cerrar app → reabrir → conversación anterior visible
- Sin API key → mensaje de error claro
- Voice input transcribe y envía

### Tareas técnicas
| ID | Tarea | Estimación |
|----|-------|-----------|
| T-010 | Retrofit + OkHttp client para Claude API | 4h |
| T-011 | Modelo de datos: MessageRequest/Response | 2h |
| T-012 | SSE streaming parser para deltas | 6h |
| T-013 | ChatViewModel + StateFlow | 4h |
| T-014 | ChatScreen composable (burbujas, input) | 6h |
| T-015 | Markdown renderer (Markwon en Compose) | 4h |
| T-016 | Room entities + DAOs (Conversation, Message) | 3h |
| T-017 | Tink encryption para API key | 4h |
| T-018 | Pantalla de configuración API key | 2h |
| T-019 | Voice input con SpeechRecognizer | 3h |
| T-020 | System prompt builder (assets/savia-identity) | 2h |
| T-021 | Tests unitarios ChatViewModel | 4h |
| T-022 | Tests unitarios API client (mock server) | 4h |

---

## Fase 2: Dashboard + Offline (Semanas 6-7)

**Objetivo**: Dashboard con métricas PM y modo offline.

### Entregables
1. Dashboard con tarjetas de quick actions
2. Radar chart de health (6 dimensiones)
3. Cache offline de últimas 50 conversaciones
4. Cache de último snapshot de workspace
5. Indicador online/offline en status bar
6. Pull-to-refresh en dashboard
7. Badges con valores actualizados en quick actions

### Criterios de aceptación
- Dashboard muestra 5 quick actions con valores
- Tap en quick action → abre chat con query pre-rellenada
- Sin internet → datos cacheados visibles con indicador
- Reconexión → auto-refresh de datos

### Tareas técnicas
| ID | Tarea | Estimación |
|----|-------|-----------|
| T-023 | DashboardScreen composable | 4h |
| T-024 | QuickActionCard composable | 2h |
| T-025 | Radar chart con Canvas Compose | 6h |
| T-026 | WorkspaceSnapshot Room entity + DAO | 2h |
| T-027 | Offline cache manager (expiración 30d) | 3h |
| T-028 | Network connectivity observer | 2h |
| T-029 | Pull-to-refresh integration | 1h |
| T-030 | Pre-filled query system para quick actions | 2h |
| T-031 | Tests dashboard ViewModel | 3h |

---

## Fase 3: SSH + Hybrid Mode (Semanas 8-10)

**Objetivo**: Conexión SSH al pm-workspace del usuario y modo híbrido.

### Entregables
1. Connection manager con perfiles
2. SSH client con Apache MINA SSHD
3. Generación de keypair Ed25519
4. Ejecución remota de comandos (workspace-health, sprint-status)
5. Auto-detección: API first, fallback SSH
6. Pantalla de gestión de conexiones
7. Test de conexión con indicador visual

### Criterios de aceptación
- Crear perfil SSH → generar keypair → test conexión → verde
- Ejecutar `workspace-health.sh --json` via SSH → parsear y mostrar
- Si SSH falla → fallback transparente a Claude API
- Múltiples perfiles guardados y switcheables

### Tareas técnicas
| ID | Tarea | Estimación |
|----|-------|-----------|
| T-032 | Apache MINA SSHD integration | 6h |
| T-033 | Ed25519 keypair generation | 3h |
| T-034 | SSH command executor (streaming stdout) | 4h |
| T-035 | ConnectionProfile Room entity + DAO | 2h |
| T-036 | ConnectionManagerScreen composable | 4h |
| T-037 | HybridRepository (API + SSH fallback) | 4h |
| T-038 | Connection test with visual feedback | 2h |
| T-039 | SSH key storage with Tink encryption | 3h |
| T-040 | Tests SSH client (mock server) | 4h |
| T-041 | Tests hybrid fallback logic | 3h |

---

## Fase 4: Polish + Launch (Semanas 11-12)

**Objetivo**: App lista para Play Store con onboarding, notificaciones y calidad de producción.

### Entregables
1. Onboarding flow (3 pantallas)
2. Notificaciones push (sprint deadlines, health alerts)
3. Home screen widget (Glance)
4. Settings completa (theme, idioma, conexión, datos)
5. Dark mode + Material You dynamic colors
6. Biometric lock opcional
7. Play Store listing (screenshots, descripción, privacy policy)
8. Staged rollout: internal → closed beta → production

### Criterios de aceptación
- Primer uso → onboarding guiado → primera conversación
- Widget en home screen actualiza cada 30 min
- Crash rate < 1%, ANR < 0.5%
- App size < 20MB (AAB)
- Todas las strings traducidas ES/EN

### Tareas técnicas
| ID | Tarea | Estimación |
|----|-------|-----------|
| T-042 | OnboardingFlow composable (3 screens) | 3h |
| T-043 | NotificationManager + WorkManager | 4h |
| T-044 | Glance widget (health score) | 4h |
| T-045 | SettingsScreen completa | 3h |
| T-046 | BiometricPrompt integration | 2h |
| T-047 | Strings ES/EN completas | 3h |
| T-048 | ProGuard rules finales + baseline profiles | 3h |
| T-049 | Play Store assets (screenshots, graphics) | 4h |
| T-050 | Privacy policy + Terms of Service | 3h |
| T-051 | Internal testing → closed beta | 2h |
| T-052 | Performance profiling + optimization | 4h |
| T-053 | Security audit final | 3h |
| T-054 | Staged rollout a producción | 2h |

---

## Resumen de Esfuerzo

| Fase | Duración | Tareas | Horas estimadas |
|------|----------|--------|----------------|
| Fase 0: Foundation | 2 semanas | 9 | ~23h |
| Fase 1: Chat MVP | 3 semanas | 13 | ~48h |
| Fase 2: Dashboard | 2 semanas | 9 | ~25h |
| Fase 3: SSH+Hybrid | 3 semanas | 10 | ~35h |
| Fase 4: Launch | 2 semanas | 13 | ~40h |
| **Total** | **12 semanas** | **54 tareas** | **~171h** |

## Riesgos del Plan

| Riesgo | Impacto | Mitigación |
|--------|---------|-----------|
| Streaming SSE complejo en Android | Alto | Spike técnico en T-012 con prueba de concepto |
| Apache MINA SSHD en Android | Medio | Fallback a mwiede/jsch fork si problemas |
| Play Store review rechaza | Medio | Pre-review checklist, cumplir todas las policies |
| Claude API rate limits | Bajo | Cola local, exponential backoff, cache agresivo |
| Tink deprecation path | Bajo | Tink es mantenido por Google, muy estable |
