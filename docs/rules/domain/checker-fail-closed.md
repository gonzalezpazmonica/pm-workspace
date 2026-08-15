---
context_tier: L2
token_budget: 1100
---

# Checker Fail-Closed + Negative Controls

> Regla para TODO checker/script/gate casero en pm-workspace. Aplica a hooks,
> grep-gates, runners de mutación manual, y cualquier script de verificación
> que no sea herramienta off-the-shelf (pytest/mypy/tsc/go vet/clippy…).
> Inspirado en el principio "prove it can fail before trusting its pass" de
> AmazingAng/old-coder (MIT) y en el bug de cache de bytecode de su propio
> demo de mutación.

## Por qué

El gauntlet de verificación es tan fiable como sus checkers. Las herramientas
off-the-shelf se han ganado su comportamiento de fallo con años de uso. Los
checks caseros no. El modo de fallo peligroso es **fail-open**: nada crashea,
la capa imprime "pass", y una verificación rota se queda verde para siempre —
nunca aparece como alarma porque precisamente está rota.

## Reglas duras

1. **Fail closed.** Un crash, un input ilegible, un exit code inesperado, o un
   item saltado en silencio dentro del código del gate es fallo duro de la
   capa, nunca pass. Prohibido: `|| true`, `2>/dev/null`, bare fallthrough.
   `set -e` (o `set -uo pipefail`) arriba, y spell out de exit codes ambiguos.

2. **El trap del grep que debe no-encontrar nada.** rc 1 (sin matches) es el
   único pass. rc 0 significa que el patrón prohibido existe → fallo. rc ≥ 2
   significa que el check se rompió (input ilegible, patrón malo) → fallo.
   Si rc ≥ 2 no falla, un fichero ilegible se convierte en pass vacío.

3. **Negative control antes de confiar en el pass.** Corre el checker una vez
   contra un input malo conocido (fixture) y mira que falle. Esto demuestra
   que un caso malo alcanza el path de fallo del checker. No demuestra que el
   checker reconoce toda violación de la restricción que dice imponer — un
   grep gate puede fallar cerrado perfectamente y aun así custodiar un typo
   en lugar de un behavior. Cuando la cobertura del gate es más estrecha que
   la regla que sirve, dilo donde se escribe la regla.

4. **Probar que el control no es vacío.** El negative control se valida como
   un test: quita o rompe temporalmente la defensa que valida, y mira que el
   control pasa a rojo. Un control que pasa con la defensa quitada no mide
   nada. Es una prueba de una vez, no una capa permanente extra.

## Caso canónico: runner de mutación manual

Un runner de mutación hand-rolled debe **probar que ejecutó cada mutante**.
El defecto conocido: dos mutantes idénticos escritos en el mismo segundo
comparten cache de bytecode, y el runner reporta kills que nunca ejecutó.
Ese defecto solo puede inflar el score → la capa se queda verde precisamente
porque está rota. Guard equivalente: mtime pinning, chequeo de cache que
aborta el run, y EVIDENCE dice qué check prueba la ejecución.

## Aplicación en pm-workspace

- Hooks (`.claude/hooks/*.sh`): aplican reglas 1-2. Un hook que devuelve 0
  cuando no pudo leer su input es una puerta abierta.
- `scripts/mutation-audit.sh`: Slice 2 (runner real) debe implementar el
  guard de ejecución de mutantes antes de reportar kills.
- Cualquier `grep`-gate nuevo en hooks o skills: documentar el exit-code
  matrix (0/1/≥2) y su negative control.

## Referencias

- Skill: `.claude/skills/evidence-first-development/SKILL.md` + `references/gauntlet.md`
- Skill: `.claude/skills/mutation-audit/SKILL.md`
- Ref: AmazingAng/old-coder (MIT) — "checker note" y "manual mutation procedure"
