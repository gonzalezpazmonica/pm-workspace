# Drill de Restauracion — Savia Workspace

## Objetivo
Restaurar el workspace completo en un entorno limpio (contenedor o VM)
y verificar que todos los componentes arrancan correctamente.

## RTO objetivo
<=60 minutos para workspace operativo (sesion arranca, hooks registrados, memoria funcional).

## Prerrequisitos
- Ubuntu 22.04+ limpio
- Acceso al repositorio (git clone)
- jq, python3, nodejs 20+, npm, bats
- Tokens y credenciales locales restaurados desde backup AEGIS o vault

## Procedimiento

### Paso 1: Clonar el repositorio
```bash
cd ~
git clone https://github.com/gonzalezpazmonica/pm-workspace.git savia
cd savia
```

### Paso 2: Restaurar activos identitarios
Desde backup AEGIS o espejo cifrado, restaurar en las ubicaciones correctas:
- `data/relacion/` — libro de la relacion (ledger.jsonl)
- `.claude/external-memory/auto/` — memoria persistente
- `.claude/rules/pm-config.local.md` — configuracion local (gitignored)
- `~/.savia/preferences.yaml` — preferencias del operador
- `CONSTITUCION.md`, `CRITERIO.md` — si tienen versiones locales distintas

### Paso 3: Instalar dependencias
```bash
cd ~/savia
bash .opencode/install.sh
```

### Paso 4: Instalar dependencias npm y python
```bash
npm install --prefix .opencode
pip install -r scripts/requirements.txt 2>/dev/null || true
```

### Paso 5: Verificar integridad del ledger
```bash
bash scripts/verify-ledger-chain.sh
```
Salida esperada: "Chain integrity: OK" con exit 0.

### Paso 6: Verificar salud de memoria
```bash
bash scripts/memory-liveness-check.sh
```

### Paso 7: Verificar arranque de sesion
Abrir sesion OpenCode en el workspace y verificar:
- Savia se presenta con identidad cargada
- CONSTITUCION.md se carga sin errores
- Memoria responde (savia-memory funciona)
- Hooks registrados (ver logs de SessionStart)

### Paso 8: Ejecutar battery de tests
```bash
bash scripts/audit-all-bats.sh
```

### Paso 9: Registrar el drill
```bash
echo "| $(date +%Y-%m-%d) | $(whoami) | ${DURATION:-N/A} | ${RTO:-N/A} | ${RESULT:-PENDING} | Manual drill |" >> docs/restore-drill-log.md
```

## Verificaciones de integridad
- [ ] `git status` limpio tras restaurar
- [ ] `bash scripts/verify-ledger-chain.sh` exit 0
- [ ] `bash scripts/memory-liveness-check.sh` exit 0
- [ ] Sesion OpenCode arranca y Savia responde
- [ ] CONSTITUCION.md integro
- [ ] `bash scripts/tracked-vs-nivel.sh` exit 0 (sin leaks N3+)

## Solucion de problemas
- Si el ledger no restaura: verificar que el backup AEGIS es reciente
- Si la cadena de hashes esta rota: el backup esta corrupto, restaurar desde copia anterior
- Si Savia no arranca: verificar `~/.savia/preferences.yaml` y credenciales
- Si los hooks no se ejecutan: verificar `.claude/settings.json` contra `.opencode/settings.json`
