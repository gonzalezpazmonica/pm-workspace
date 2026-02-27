---
paths:
  - "**/*.py"
---

# Reglas de Análisis Estático Python — Knowledge Base para Agente de Revisión

> Fuente: [Bandit](https://bandit.readthedocs.io/), [Ruff](https://docs.astral.sh/ruff/rules/), [SonarPython](https://rules.sonarsource.com/python/)
> Última actualización: 2026-02-26

---

## Instrucciones para el Agente

Eres un agente de revisión de código Python. Tu rol es analizar código fuente aplicando las reglas documentadas a continuación, equivalentes a un análisis de SonarQube + Bandit.

**Protocolo de reporte:**

Para cada hallazgo reporta:

- **ID de regla** (ej: S2068)
- **Severidad** (Blocker / Critical / Major / Minor)
- **Línea(s) afectada(s)**
- **Descripción del problema**
- **Sugerencia de corrección con código**

**Priorización obligatoria:**

1. Primero: **Vulnerabilities** y **Security Hotspots** — riesgo de seguridad
2. Después: **Bugs** — comportamiento incorrecto en runtime
3. Finalmente: **Code Smells** — mantenibilidad y deuda técnica

**Directivas de contexto:**

- Aplica las reglas **en contexto** — no reportes falsos positivos obvios
- Si un patrón es intencional y está documentado (comentario explícito), no lo reportes
- Considera el framework (FastAPI, Django) al evaluar las reglas
- Responde siempre en **español**

---

## 1. VULNERABILITIES — Seguridad

> 🔴 Prioridad máxima. Cada hallazgo aquí es un riesgo de seguridad real.

### 1.1 Blocker

#### S2068 — Credenciales hardcodeadas

**Severidad**: Blocker · **Tags**: cwe, sensitive-data
**Problema**: Contraseñas y credenciales embebidas en código fuente exponen accesos no autorizados.

```python
# ❌ Noncompliant
DATABASE_PASSWORD = "SuperSecret123"
API_KEY = "sk-1234567890abcdef"
db_url = "postgresql://user:password@localhost/db"

# ✅ Compliant
import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_PASSWORD = os.getenv("DATABASE_PASSWORD")
API_KEY = os.getenv("API_KEY")
db_url = os.getenv("DATABASE_URL")
```

**Impacto**: Cualquier persona con acceso al código fuente obtiene las credenciales.

#### S2077 — SQL Injection

**Severidad**: Blocker · **Tags**: cwe, injection
**Problema**: Construcción de queries SQL sin parameterización permite inyección SQL.

```python
# ❌ Noncompliant
user_id = request.args.get("id")
query = f"SELECT * FROM users WHERE id = {user_id}"
result = db.execute(query)

# ✅ Compliant
user_id = request.args.get("id")
query = "SELECT * FROM users WHERE id = %s"
result = db.execute(query, (user_id,))

# O con ORM:
user = User.query.filter_by(id=user_id).first()
```

**Impacto**: Acceso no autorizado a datos, modificación de BD, ejecución de comandos.

#### S5131 — XXE Vulnerability

**Severidad**: Blocker · **Tags**: cwe, xml
**Problema**: Parseo de XML sin desactivar entidades externas permite XXE attacks.

```python
# ❌ Noncompliant
import xml.etree.ElementTree as ET
tree = ET.parse(user_input)
root = tree.getroot()

# ✅ Compliant
from defusedxml import ElementTree as DefusedET
tree = DefusedET.parse(user_input)
root = tree.getroot()
```

**Impacto**: Lectura de ficheros del servidor, SSRF, DoS.

#### S6252 — Pickle deserialization insegura

**Severidad**: Blocker · **Tags**: cwe, deserialization
**Problema**: pickle.loads() con datos de usuario permite ejecución arbitraria de código.

```python
# ❌ Noncompliant
import pickle
data = request.data
obj = pickle.loads(data)  # arbitrary code execution

# ✅ Compliant
import json
data = request.data
obj = json.loads(data)  # seguro, usa JSON

# Si debe usar pickle:
import pickle
import io

class RestrictedPickle(pickle.Unpickler):
    def find_class(self, module, name):
        if module.startswith("os") or module.startswith("subprocess"):
            raise pickle.UnpicklingError(f"Forbidden module: {module}")
        return super().find_class(module, name)

obj = RestrictedPickle(io.BytesIO(data)).load()
```

**Impacto**: Ejecución arbitraria de código, compromiso total del sistema.

#### S5323 — Path traversal

**Severidad**: Blocker · **Tags**: cwe, path-traversal
**Problema**: Usar entrada de usuario directamente en rutas de archivo sin validación.

```python
# ❌ Noncompliant
import os
filename = request.args.get("file")
filepath = os.path.join("/uploads", filename)
with open(filepath, "r") as f:
    content = f.read()

# ✅ Compliant
import os
from pathlib import Path

filename = request.args.get("file")
base_dir = Path("/uploads").resolve()
filepath = (base_dir / filename).resolve()
if not str(filepath).startswith(str(base_dir)):
    raise ValueError("Path traversal detected")
with open(filepath, "r") as f:
    content = f.read()
```

**Impacto**: Lectura de archivos arbitrarios del servidor.

### 1.2 Critical

#### S2053 — Hashing de contraseñas débil

**Severidad**: Critical · **Tags**: cwe, crypto
**Problema**: Usar hashing débil (MD5, SHA-1) o sin salt para contraseñas.

```python
# ❌ Noncompliant
import hashlib
password_hash = hashlib.md5(password.encode()).hexdigest()

# ✅ Compliant
from argon2 import PasswordHasher
ph = PasswordHasher()
password_hash = ph.hash(password)

# O con bcrypt:
import bcrypt
password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt(12))
```

**Impacto**: Rainbow tables pueden descifrar contraseñas débiles en segundos.

#### S5647 — Weak crypto algorithms

**Severidad**: Critical · **Tags**: cwe, crypto
**Problema**: Usar algoritmos criptográficos débiles (DES, MD5, SHA-1).

```python
# ❌ Noncompliant
from Crypto.Cipher import DES
cipher = DES.new(key, DES.MODE_ECB)

# ✅ Compliant
from Crypto.Cipher import AES
cipher = AES.new(key, AES.MODE_GCM)
```

**Impacto**: Descifrado de datos encriptados.

#### S4823 — Validación de certificados TLS desactivada

**Severidad**: Critical · **Tags**: cwe, crypto
**Problema**: Ignorar validación de certificados SSL/TLS en requests HTTP.

```python
# ❌ Noncompliant
import requests
response = requests.get("https://api.example.com", verify=False)

# ✅ Compliant
import requests
response = requests.get("https://api.example.com")  # verify=True por defecto
```

**Impacto**: MITM attacks, interception de datos sensibles.

#### S5673 — SSRF Vulnerability

**Severidad**: Critical · **Tags**: cwe, ssrf
**Problema**: Hacer HTTP requests a URLs proporcionadas por usuario sin validación.

```python
# ❌ Noncompliant
import requests
url = request.args.get("url")
response = requests.get(url)  # puede apuntar a localhost, servicios internos

# ✅ Compliant
import requests
from urllib.parse import urlparse

url = request.args.get("url")
parsed = urlparse(url)
if parsed.hostname in ["localhost", "127.0.0.1", "0.0.0.0"]:
    raise ValueError("SSRF detected")
allowed_domains = ["api.example.com", "cdn.example.com"]
if parsed.hostname not in allowed_domains:
    raise ValueError("Domain not allowed")
response = requests.get(url, timeout=5)
```

**Impacto**: Acceso a servicios internos, escaneo de red.

---

## 2. SECURITY HOTSPOTS

#### PY-HOT-01 — eval() o exec() con entrada de usuario

**Severidad**: Critical
```python
# ❌ Sensitive — ejecución arbitraria de código
user_code = request.args.get("code")
result = eval(user_code)

# ✅ Compliant — usar ejecutores seguros
import ast
import operator

user_code = request.args.get("code")
try:
    tree = ast.parse(user_code, mode='eval')
    # validar que solo contiene operaciones seguras
except SyntaxError:
    raise ValueError("Invalid expression")
```

#### PY-HOT-02 — Logging de datos sensibles

**Severidad**: Critical
```python
# ❌ Sensitive
import logging
logger.info(f"User login with password: {password}")
logger.debug(f"API Key: {api_key}")

# ✅ Compliant
import logging
logger.info("User login successful")
logger.debug("API authentication completed")
```

#### PY-HOT-03 — Usar random en lugar de secrets para criptografía

**Severidad**: Critical
```python
# ❌ Sensitive
import random
token = ''.join([random.choice("abcdef0123456789") for _ in range(32)])

# ✅ Compliant
import secrets
token = secrets.token_hex(16)
```

---

## 3. BUGS

### 3.1 Blocker

#### PY-BUG-01 — Mutable default arguments

**Severidad**: Blocker
```python
# ❌ Noncompliant
def add_user(name, roles=[]):
    roles.append("user")
    return {"name": name, "roles": roles}

# Problema: la misma lista se comparte entre llamadas
result1 = add_user("Alice")  # ["user"]
result2 = add_user("Bob")    # ["user", "user"] — bug!

# ✅ Compliant
def add_user(name, roles=None):
    if roles is None:
        roles = []
    roles.append("user")
    return {"name": name, "roles": roles}
```

**Impacto**: Comportamiento impredecible, bugs intermitentes difíciles de debuggear.

#### PY-BUG-02 — Bare except

**Severidad**: Blocker
```python
# ❌ Noncompliant
try:
    result = risky_operation()
except:  # captura TODO, incluso KeyboardInterrupt
    print("Error occurred")

# ✅ Compliant
try:
    result = risky_operation()
except (ValueError, IOError) as e:
    logger.error(f"Operation failed: {e}")
except Exception as e:
    logger.critical(f"Unexpected error: {e}")
    raise
```

**Impacto**: Enmascaramiento de errores, comportamiento impredecible.

#### PY-BUG-03 — Type errors sin type hints

**Severidad**: Blocker
```python
# ❌ Noncompliant
def calculate_total(items):
    return sum(items)  # asume que items es iterable de números

calculate_total("abc")  # TypeError en runtime

# ✅ Compliant
from typing import List, Union

def calculate_total(items: List[Union[int, float]]) -> Union[int, float]:
    return sum(items)

# mypy detecta errores en compile-time
calculate_total("abc")  # mypy error: Argument 1 has incompatible type
```

**Impacto**: Errores en runtime fáciles de evitar con type checking.

### 3.2 Major

#### PY-BUG-04 — Async forEach pattern

**Severidad**: Major
```python
# ❌ Noncompliant
async def process_items(items):
    for item in items:
        await process(item)  # ejecuta secuencialmente, desperdicia concurrencia

# ✅ Compliant
import asyncio

async def process_items(items):
    await asyncio.gather(*[process(item) for item in items])
```

**Impacto**: Pobre rendimiento en operaciones async.

#### PY-BUG-05 — Returning None implícitamente

**Severidad**: Major
```python
# ❌ Noncompliant
def find_user(name):
    for user in users:
        if user.name == name:
            return user
    # None implícito si no encuentra

# ✅ Compliant
from typing import Optional

def find_user(name: str) -> Optional[User]:
    for user in users:
        if user.name == name:
            return user
    return None  # explícito
```

**Impacto**: Sorpresas en valores None, bugs silenciosos.

---

## 4. CODE SMELLS

### 4.1 Critical

#### PY-SMELL-01 — Función muy larga (> 50 líneas)

**Severidad**: Critical
```python
# ❌ Noncompliant
def process_order(order):
    # 100+ líneas de lógica mezclada
    validate_order(order)
    calculate_tax(order)
    apply_discount(order)
    save_order(order)
    send_notification(order)
    # ...

# ✅ Compliant
def process_order(order):
    validate(order)
    calculate(order)
    save(order)
    notify(order)

def calculate(order):
    calculate_tax(order)
    apply_discount(order)
```

**Impacto**: Difícil de testear, mantener y entender.

#### PY-SMELL-02 — Complejidad ciclomática muy alta (> 10)

**Severidad**: Critical
```python
# ❌ Noncompliant
def get_status(user):
    if user.is_active:
        if user.has_permission:
            if user.is_verified:
                if user.has_subscription:
                    return "ACTIVE"
                else:
                    return "INACTIVE_NO_SUB"
            else:
                return "UNVERIFIED"
        else:
            return "NO_PERMISSION"
    else:
        return "INACTIVE"

# ✅ Compliant
def get_status(user):
    if not user.is_active:
        return "INACTIVE"
    if not user.has_permission:
        return "NO_PERMISSION"
    if not user.is_verified:
        return "UNVERIFIED"
    if not user.has_subscription:
        return "INACTIVE_NO_SUB"
    return "ACTIVE"
```

**Impacto**: Difícil de testear, propenso a bugs.

### 4.2 Major

#### PY-SMELL-03 — Variables no usadas

**Severidad**: Major
```python
# ❌ Noncompliant
def process():
    unused_variable = "test"
    count = 0
    # count no se usa

# ✅ Compliant
def process():
    count = calculate_items()
    logger.info(f"Processed {count} items")
```

#### PY-SMELL-04 — Imports no usados

**Severidad**: Major
```python
# ❌ Noncompliant
import os
import sys
import json

def get_data():
    return {"status": "ok"}

# ✅ Compliant
import json

def get_data():
    return json.loads('{"status": "ok"}')
```

---

## 5. REGLAS DE ARQUITECTURA

#### ARCH-01 — Dependency injection obligatoria

**Severidad**: Blocker
```python
# ❌ Noncompliant — acoplamiento fuerte
from database import Database

class UserService:
    def __init__(self):
        self.db = Database()  # new en clase

    def create_user(self, name):
        self.db.insert("users", {"name": name})

# ✅ Compliant — inyección en constructor
from typing import Protocol

class UserRepository(Protocol):
    def insert(self, table: str, data: dict) -> None: ...

class UserService:
    def __init__(self, repository: UserRepository):
        self.repository = repository

    def create_user(self, name: str) -> None:
        self.repository.insert("users", {"name": name})
```

**Impacto**: Facilita testing, desacoplamiento, mantenibilidad.

#### ARCH-02 — No mezclar lógica de negocio con framework

**Severidad**: Critical
```python
# ❌ Noncompliant — FastAPI en la lógica de negocio
from fastapi import FastAPI, Request

def create_order(request: Request) -> dict:
    order_data = request.json()
    user_id = request.headers.get("user-id")
    # lógica de negocio aquí
    return {"order_id": 123}

# ✅ Compliant — separación de concerns
# api/orders.py
from fastapi import APIRouter, Request
from application import CreateOrderUseCase

router = APIRouter()

@router.post("/orders")
async def create_order(request: Request):
    order_data = await request.json()
    user_id = request.headers.get("user-id")
    use_case = CreateOrderUseCase(repository)
    result = use_case.execute(order_data, user_id)
    return result

# application/create_order.py
class CreateOrderUseCase:
    def __init__(self, repository: OrderRepository):
        self.repository = repository
    
    def execute(self, order_data: dict, user_id: str) -> dict:
        # lógica de negocio sin dependencias de framework
        order = self.repository.create(order_data, user_id)
        return {"order_id": order.id}
```

**Impacto**: Independencia de framework, testabilidad, clean architecture.

#### ARCH-03 — Repository pattern en FastAPI/Django

**Severidad**: Critical
```python
# ✅ Compliant — hexagonal architecture
# domain/user.py
from dataclasses import dataclass
from typing import Protocol, Optional

@dataclass
class User:
    id: str
    name: str
    email: str

class UserRepository(Protocol):
    def find_by_id(self, user_id: str) -> Optional[User]: ...
    def save(self, user: User) -> None: ...

# infrastructure/user_repository.py
from sqlalchemy.orm import Session
from infrastructure.models import UserModel
from domain.user import User, UserRepository

class SqlAlchemyUserRepository(UserRepository):
    def __init__(self, db: Session):
        self.db = db
    
    def find_by_id(self, user_id: str) -> Optional[User]:
        model = self.db.query(UserModel).filter_by(id=user_id).first()
        if not model:
            return None
        return User(id=model.id, name=model.name, email=model.email)

# application/user_service.py
class UserService:
    def __init__(self, repository: UserRepository):
        self.repository = repository
    
    def get_user(self, user_id: str) -> Optional[User]:
        return self.repository.find_by_id(user_id)

# api/users.py
@router.get("/users/{user_id}")
async def get_user(user_id: str, service: UserService = Depends()):
    user = service.get_user(user_id)
    if not user:
        raise HTTPException(status_code=404)
    return user
```

**Impacto**: Independencia de framework, testabilidad, clean architecture.

---

## Referencia rápida de severidades

| Severidad | Acción | Bloquea merge |
|---|---|---|
| **Blocker** | Corregir inmediatamente | ✅ Sí |
| **Critical** | Corregir antes de merge | ✅ Sí |
| **Major** | Corregir en el sprint actual | 🟡 Depende |
| **Minor** | Backlog técnico | ❌ No |
