---
spec_id: SPEC-098
title: Workspace Bundle — Nidos with Optional Dev Server + Preview URL
status: Implemented
origin: BloopAI/vibe-kanban analysis (2026-04-15)
severity: Media
effort: ~6h
---

# SPEC-098: Workspace Bundle — Nidos con Dev Server + Preview URL

## Problema

`scripts/nidos.sh` crea un git worktree aislado por terminal (rama + filesystem),
pero el desarrollador tiene que arrancar manualmente el dev server (`npm run dev`,
`dotnet watch`, `python -m http.server`, etc.) cada vez que abre un nido. Para
features de frontend o web, el ciclo "edit → ver" requiere conocer el comando
de arranque del proyecto y saber en qué puerto está sirviendo.

vibe-kanban resuelve esto empaquetando rama + terminal + dev server + preview
browser por workspace. El desarrollador o agente de coding obtiene la URL
preview directamente, sin lookups.

pm-workspace ya tiene visual-qa-agent y web-e2e-tester que generan screenshots,
pero ambos asumen que el dev server ya está arriba. Falta el bundle.

## Solucion

Extender `scripts/nidos.sh` con un comando opcional `dev` que:

1. Detecta el tipo de proyecto en el nido (package.json, *.csproj, pyproject.toml,
   Cargo.toml, go.mod) consultando el Language Pack del proyecto
2. Lee el campo `dev_server` del CLAUDE.md del proyecto si existe, o usa
   defaults por Language Pack:

   ```yaml
   dev_server:
     command: "npm run dev"
     port: 5173
     ready_signal: "Local:"  # regex en stdout que indica server arriba
   ```

3. Lanza el dev server con `nohup` en background, capturando logs en
   `~/.savia/nidos/{name}/dev-server.log`
4. Espera al `ready_signal` (timeout 30s)
5. Registra PID en `~/.savia/nidos/{name}/dev-server.pid`
6. Imprime la preview URL accesible: `http://localhost:{port}`
7. `nidos.sh stop {name}` mata el dev server limpiamente antes de remove

## Comandos extendidos

```bash
nidos.sh create <name> --with-dev    # Crea nido + arranca dev server
nidos.sh dev <name> start             # Arranca dev server en nido existente
nidos.sh dev <name> stop              # Para dev server (preserva nido)
nidos.sh dev <name> url               # Imprime URL preview
nidos.sh dev <name> logs              # Tail del log
```

## Integracion con agentes

- **visual-qa-agent**: en lugar de exigir URL como parametro, puede usar
  `nidos.sh dev current url` para auto-descubrir
- **web-e2e-tester**: idem, automatiza Playwright contra la preview
- **frontend-developer**: tras implementar slice, sugiere
  `nidos.sh dev current url` para verificacion humana

## Detección por Language Pack

| Language Pack | Default dev command | Default port |
|--------------|--------------------|--------------|
| Angular | `npm run start` | 4200 |
| React (Vite) | `npm run dev` | 5173 |
| React (Next) | `npm run dev` | 3000 |
| TypeScript/Node | `npm run dev` | 3000 |
| Python/FastAPI | `uvicorn main:app --reload` | 8000 |
| Python/Django | `python manage.py runserver` | 8000 |
| Java/Spring | `./mvnw spring-boot:run` | 8080 |
| Go | `go run main.go` | 8080 |
| Rust/Axum | `cargo run` | 3000 |
| .NET | `dotnet watch run` | 5000 |
| PHP/Laravel | `php artisan serve` | 8000 |
| Ruby/Rails | `bin/rails server` | 3000 |

## Restricciones

- NO arrancar dev server si el puerto ya esta ocupado (avisa, no falla)
- NO ejecutar `npm install` ni equivalentes — exige que el nido este preparado
- Time-box arranque a 30s (`ready_signal` no detectado → kill + warn)
- NO logear contenido HTTP (privacidad) — solo stdout/stderr del proceso
- Ports asignados dinamicamente por nido si hay colision (puerto + N donde N es indice del nido)

## Reglas de negocio nuevas

- **NIDOS-DEV-01**: Cada nido puede tener AS MUCH 1 dev server activo
- **NIDOS-DEV-02**: Stop de nido siempre mata su dev server primero
- **NIDOS-DEV-03**: PID file invalida si proceso no existe → cleanup automatico
- **NIDOS-DEV-04**: Logs de dev server rotan a 10MB max, retencion 24h

## Hooks involucrados

- `nidos.sh stop` debe llamar `nidos.sh dev stop` antes de eliminar worktree
- `session-init.sh` puede mostrar URL preview si nido activo tiene dev server

## Acceptance criteria

- [ ] `nidos.sh dev <name> start` arranca dev server y devuelve URL en <30s
- [ ] `nidos.sh dev <name> url` devuelve URL accesible (HTTP 200 en root)
- [ ] `nidos.sh remove <name>` mata dev server limpiamente (no procesos zombi)
- [ ] visual-qa-agent puede consumir URL sin parametro explicito
- [ ] Tests BATS cubren los 12 Language Packs con mocks de comandos
- [ ] Gap de puerto (otro proceso usando 5173) → asigna 5174 sin fallar
- [ ] Documentado en `docs/scheduling-guide.md` o nuevo `docs/nidos-dev-server.md`

## Out of scope

- Browser preview embebido (vibe-kanban tiene Electron — fuera de filosofia CLI)
- Devtools / inspect mode (lo cubre el browser del usuario)
- Hot reload automatico (responsabilidad del framework)
- Multi-port por nido (UI + API + worker en el mismo nido) — futura iteracion

## Justificacion vs no hacer nada

Sin esta spec, cada agente frontend exige al humano que arranque el server,
verifique el puerto, y pase la URL como parametro. El ciclo "implementa →
verifica" pierde 1-2 min por iteracion. Con 5+ slices/PR, son 5-10 min de
overhead manual. Esta spec elimina ese overhead.

## Referencias

- BloopAI/vibe-kanban: pattern "workspace bundle"
- nidos-protocol.md: regla actual de aislamiento por terminal
- visual-qa-agent / web-e2e-tester: consumidores potenciales
