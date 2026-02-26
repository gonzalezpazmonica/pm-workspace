# Regla: Convenciones y Prácticas Python
# ── Aplica a todos los proyectos Python en este workspace ──

## Verificación obligatoria en cada tarea

```bash
ruff format --check .                          # 1. ¿Formato PEP 8?
ruff check .                                   # 2. ¿Linting sin warnings?
mypy . --strict                                # 3. ¿Type checking?
pytest -m unit -x --tb=short                   # 4. ¿Tests unitarios pasan?
```

Si hay tests de integración relevantes:
```bash
pytest -m integration -x --tb=short
```

## Convenciones de código Python

- **Naming:** `snake_case` (funciones/variables/módulos), `PascalCase` (clases), `UPPER_SNAKE_CASE` (constantes), `_prefijo` (privado)
- **Python version:** 3.12+ — usar `type` statements, `match/case`, f-strings, walrus operator donde mejore legibilidad
- **Type hints** obligatorios en todas las firmas públicas; `mypy --strict` habilitado
- **Inmutabilidad:** `@dataclass(frozen=True)` o Pydantic `BaseModel` para DTOs; `NamedTuple` para tuplas con nombre
- **Async:** `asyncio` + `async/await`; `httpx.AsyncClient` para HTTP async; nunca `requests` en código async
- **Error handling:** Excepciones específicas de dominio; nunca `except Exception` vacío; `raise ... from e` para encadenar
- **Imports:** stdlib → third-party → local (ruff organiza automáticamente); imports absolutos preferidos
- **Context managers:** `async with` / `with` para recursos (archivos, conexiones, locks)
- **List comprehensions** preferidas sobre `map()`/`filter()` cuando son legibles; nunca comprehensions anidadas de más de 2 niveles

## Frameworks Web

### FastAPI (preferido para APIs)
- Routers modulares por feature (`APIRouter`)
- Dependency injection con `Depends()`
- Pydantic models para request/response validation
- Background tasks con `BackgroundTasks`
- Middleware para logging, CORS, auth

### Django (apps completas)
- Django REST Framework para APIs
- Class-based views (preferidas para CRUD estándar)
- Django ORM + migraciones integradas
- Signals con moderación — preferir métodos explícitos

## Persistencia

### SQLAlchemy 2.0 (con FastAPI)
- Mapped classes con `DeclarativeBase` y type annotations
- `AsyncSession` para operaciones async
- Migraciones: Alembic
- Nunca modificar migraciones ya aplicadas
- `select()` + `execute()` style (no query legacy)

```bash
alembic revision --autogenerate -m "description" # generar migración
alembic upgrade head                             # aplicar
alembic downgrade -1                             # rollback
alembic history                                  # historial
```

### Django ORM (con Django)
```bash
python manage.py makemigrations                # generar migración
python manage.py migrate                       # aplicar
python manage.py showmigrations                # estado
```

## Tests

- **Framework:** pytest (siempre)
- **Unit tests:** `tests/unit/` con `@pytest.mark.unit`
- **Integration tests:** `tests/integration/` con `@pytest.mark.integration`
- **Fixtures:** `conftest.py` por directorio; `@pytest.fixture` para setup compartido
- **Mocking:** `unittest.mock.patch` o `pytest-mock`
- **API tests:** `httpx.AsyncClient` (FastAPI) o Django test client
- **DB tests:** `testcontainers-python` para PostgreSQL/Redis reales
- Naming: `test_{method}_{scenario}_{expected}`
- Cobertura: `pytest-cov` ≥ 80%

```bash
pytest -m unit -x                              # unitarios
pytest -m integration -x                       # integración
pytest --cov=src --cov-report=term-missing     # cobertura
pytest -k "test_create_user"                   # filtrar por nombre
```

## Gestión de dependencias

```bash
pip install {paquete}                          # instalar
pip list --outdated                            # obsoletos
pip-audit                                      # vulnerabilidades
pip freeze > requirements.txt                  # snapshot (si no usa pyproject.toml)
```

- **Preferir** `pyproject.toml` + `pip-tools` o `poetry` sobre `requirements.txt`
- **Siempre** pinear versiones exactas en producción
- **Separar** dependencias de producción y desarrollo

## Estructura de proyecto (FastAPI)

```
src/
├── domain/                  ← entidades, value objects, abstracciones (Protocol/ABC)
├── application/             ← use cases, DTOs (Pydantic), services
├── infrastructure/          ← SQLAlchemy repos, HTTP clients, caching (Redis), messaging
├── api/                     ← FastAPI routers, dependencies, middleware, schemas
└── core/                    ← config (pydantic-settings), logging, constants
tests/
├── unit/                    ← pytest + mock
├── integration/             ← testcontainers, httpx.AsyncClient
└── conftest.py              ← fixtures compartidas
alembic/                     ← migraciones de BD
pyproject.toml               ← dependencias y config
```

## Estructura de proyecto (Django)

```
project/
├── apps/
│   └── {app}/
│       ├── models.py        ← Django models
│       ├── serializers.py   ← DRF serializers
│       ├── views.py         ← ViewSets / APIViews
│       ├── urls.py          ← rutas del app
│       ├── services.py      ← lógica de negocio (no en views)
│       ├── admin.py
│       └── tests/
├── config/                  ← settings, urls, wsgi
├── manage.py
└── requirements/
    ├── base.txt
    ├── dev.txt
    └── prod.txt
```

## Deploy

```bash
# FastAPI
uvicorn src.api.main:app --host 0.0.0.0 --port 8000 --workers 4
# Django
gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 4
```

## Hooks recomendados

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "cd $(git rev-parse --show-toplevel) && ruff check --select E,F --quiet 2>&1 | head -10"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "pytest -m unit -x --tb=line -q 2>&1 | tail -20"
    }]
  }
}
```
