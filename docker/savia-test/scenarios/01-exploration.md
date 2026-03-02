# Scenario 01 — Exploration Track

Elena (AI Product Manager) defines outcomes and writes specs.

## Step 1
- **Role**: Elena
- **Command**: pbi-jtbd

```prompt
Eres Savia. Elena necesita definir los Jobs-to-be-Done para la SocialApp. Ejecuta pbi-jtbd para analizar los outcomes principales. Outcomes esperados: O-001 User Onboarding (registro, login, perfil), O-002 Content Publishing (crear posts, media, hashtags), O-003 Social Graph (follow, unfollow, sugerencias), O-004 Timeline Feed (feed personalizado, real-time updates), O-005 Notifications (push, in-app, email digest).
```

## Step 2
- **Role**: Elena
- **Command**: pbi-prd

```prompt
Eres Savia. Elena genera el PRD para el outcome O-001 User Onboarding de SocialApp. Ejecuta pbi-prd. Debe incluir: problema a resolver, métricas de éxito (registro completado <2min, retención D1>60%), alcance MVP (email+social login, perfil básico, avatar), fuera de alcance (2FA, enterprise SSO), dependencias técnicas (API Gateway, MongoDB users collection, servicio auth).
```

## Step 3
- **Role**: Elena
- **Command**: flow-spec

```prompt
Eres Savia. Elena crea la primera spec ejecutable desde el outcome O-001. Ejecuta flow-spec para generar la spec SPEC-001 "User Registration Flow". La spec debe tener 5 secciones: Outcome (registro en <2min), Functional (formulario email/password, OAuth Google/Apple, validación), Technical (POST /api/v1/auth/register, MongoDB users, JWT tokens, bcrypt), Dependencies (API Gateway config, email service), DoD (unit tests >80%, integration test registro completo, security review passwords).
```

## Step 4
- **Role**: Elena
- **Command**: flow-spec

```prompt
Eres Savia. Elena crea la spec SPEC-002 "User Profile Management" vinculada al outcome O-001. Ejecuta flow-spec. Outcome: usuario completa perfil en <1min. Functional: editar nombre, bio, avatar (upload imagen <5MB), ubicación opcional. Technical: PUT /api/v1/users/:id, GridFS para avatars, cache Redis perfil. Dependencies: storage service, image resize. DoD: unit tests, load test 100 perfiles/s, responsive Ionic.
```

## Step 5
- **Role**: Elena
- **Command**: flow-spec

```prompt
Eres Savia. Elena crea la spec SPEC-003 "Create Post" vinculada al outcome O-002 Content Publishing. Ejecuta flow-spec. Outcome: publicar post en <3s. Functional: texto 280 chars, imagen opcional, hashtags auto-detect, mention @user. Technical: POST /api/v1/posts, MongoDB posts collection, RabbitMQ event post.created, fanout a followers. Dependencies: media service, notification service. DoD: unit tests, integration test post→feed, load test 500 posts/min.
```
