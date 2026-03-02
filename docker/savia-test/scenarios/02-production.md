# Scenario 02 — Production Track

Intake + decompose + building. Ana (Front), Isabel (Back).

## Step 1
- **Role**: Mónica
- **Command**: flow-intake

```prompt
Eres Savia. Mónica ejecuta el intake continuo moviendo specs de Spec-Ready a Production. Ejecuta flow-intake. Specs disponibles: SPEC-001 (User Registration), SPEC-002 (User Profile), SPEC-003 (Create Post). Valida acceptance criteria de cada spec, verifica capacidad del equipo (Ana WIP 0/2, Isabel WIP 0/2), asigna: SPEC-001 back a Isabel, front a Ana. SPEC-002 y SPEC-003 quedan en Spec-Ready esperando capacidad.
```

## Step 2
- **Role**: Isabel
- **Command**: pbi-decompose

```prompt
Eres Savia. Isabel descompone SPEC-001 "User Registration Flow" en tasks técnicas. Ejecuta pbi-decompose. Backend tasks: T-001 Setup auth microservice scaffold (2h), T-002 POST /api/v1/auth/register endpoint + validation (4h), T-003 MongoDB user model + bcrypt hashing (3h), T-004 JWT token generation + refresh (4h), T-005 OAuth Google provider integration (3h), T-006 Unit tests auth service (3h). Total estimado: 19h.
```

## Step 3
- **Role**: Ana
- **Command**: pbi-decompose

```prompt
Eres Savia. Ana descompone SPEC-001 "User Registration Flow" parte frontend. Ejecuta pbi-decompose. Frontend tasks: T-007 Registration page Ionic component (3h), T-008 Form validation + error handling (2h), T-009 OAuth buttons Google/Apple (3h), T-010 Auth service integration + JWT storage (2h), T-011 Registration flow E2E test (2h). Total estimado: 12h. Ana es mid-junior, Isabel revisa sus PRs.
```

## Step 4
- **Role**: Isabel
- **Command**: spec-contract

```prompt
Eres Savia. Isabel genera el contrato de API para SPEC-001 antes de implementar. El contrato define: POST /api/v1/auth/register (body: email, password, name; response: 201 {user, token}), POST /api/v1/auth/login (body: email, password; response: 200 {user, token, refreshToken}), POST /api/v1/auth/oauth/google (body: idToken; response: 200 {user, token}). Ana usará mocks basados en este contrato mientras Isabel implementa el backend real.
```

## Step 5
- **Role**: Mónica
- **Command**: flow-board

```prompt
Eres Savia. Mónica visualiza el tablero dual-track del proyecto SocialApp. Ejecuta flow-board. Debe mostrar: Exploration track con SPEC-002 y SPEC-003 en Spec-Ready, 2 outcomes pendientes (O-003, O-004). Production track con SPEC-001 en Building, tasks asignadas a Ana (T-007..T-011 front) e Isabel (T-001..T-006 back). Alerta si WIP limits excedidos. Muestra cycle time acumulado.
```
