---
name: patterns-python
description: Patrones de arquitectura para Python (Django, FastAPI, Flask)
context_cost: low
---

# Patrones — Python

## 1. MVT — Django (⭐ Recomendado para full-stack)

**Folder Structure**:
```
project/
├── apps/
│   └── app_name/
│       ├── models.py       → Data models (ORM)
│       ├── views.py        → Business logic + response
│       ├── urls.py          → URL routing
│       ├── forms.py         → Form validation
│       ├── admin.py         → Admin interface config
│       ├── serializers.py   → DRF serializers (si API)
│       ├── templates/       → HTML templates
│       └── tests/
├── config/ or project/     → Settings, root URLs
├── static/                 → CSS, JS, images
└── manage.py
```

**Detection Markers**:
- `manage.py` en raíz → Django
- `models.py`, `views.py`, `urls.py` en cada app
- `settings.py` con `INSTALLED_APPS`
- Django REST Framework: `serializers.py`, `viewsets.py`

## 2. Modular — FastAPI (⭐ Recomendado para APIs)

**Folder Structure**:
```
app/
├── api/
│   ├── routes/           → Endpoint routers
│   ├── dependencies.py   → Dependency injection
│   └── middleware.py      → Middleware
├── core/
│   ├── config.py         → Settings (pydantic BaseSettings)
│   └── security.py       → Auth logic
├── models/               → SQLAlchemy/Pydantic models
├── schemas/              → Pydantic request/response schemas
├── services/             → Business logic
├── repositories/         → Data access layer
└── main.py               → FastAPI app creation
```

**Detection Markers**:
- `FastAPI()` instance en `main.py`
- Pydantic models: `class X(BaseModel)`
- `@router.get/post/put/delete` decorators
- `Depends()` para dependency injection
- async/await usage

## 3. Clean Architecture (Python)

**Detection Markers**:
- Carpetas: `domain/`, `application/`, `infrastructure/`, `presentation/`
- Interfaces con ABC (Abstract Base Class)
- Repository pattern con ABC
- Use cases como clases independientes

## 4. Layered (Flask)

**Detection Markers**:
- `Flask(__name__)` instance
- Blueprints para modularización
- `@app.route` decorators
- Sin estructura de capas estricta (Flask es micro)

## 5. Hexagonal (Python)

**Detection Markers**:
- Carpetas: `ports/`, `adapters/`
- ABC interfaces como ports
- Inyección de dependencias manual o con `dependency-injector`

## Tools de Enforcement
- **import-linter**: Define contratos de imports entre capas
- **pytestarch**: Tests de arquitectura (inspirado en ArchUnit)
- **pylint-import-modules**: Restricción de imports
- **mypy**: Type checking estricto
- **ruff**: Linting rápido con reglas de imports

## Anti-patterns comunes
- Fat views (lógica de negocio en views.py)
- Queries N+1 en Django ORM (falta select_related/prefetch_related)
- Circular imports entre apps
- Settings hardcodeados (en lugar de environment variables)
- Models.py con 1000+ líneas (falta modularización)
