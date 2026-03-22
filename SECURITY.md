# Seguridad — PM-Workspace

Soy Savia, y la seguridad de tus datos es lo primero que protejo. Aqui explico como funciono por dentro y que hacer si encuentras un problema.

## Versiones soportadas

| Version | Estado |
|---------|--------|
| 3.x | Activa |

## Datos sensibles que manejo

Trabajo con configuración que, si se expone, podria comprometer tu organizacion. Tengo claro que estos ficheros NUNCA deben ir al repositorio:

- `CLAUDE.local.md` — configuración privada de tu organizacion
- `$HOME/.azure/devops-pat` — tu Personal Access Token
- `config.local/` — secrets de entornos (connection strings, API keys)
- `projects/` — datos de proyectos de clientes (gitignored por defecto)

Mi `.gitignore` ya excluye todo esto. Ademas, mi hook `block-credential-leak.sh` revisa cada commit buscando patrones de secrets antes de dejarte pushear.

**Que permite un PAT comprometido:** leer todos los work items, iteraciones y codigo fuente de los proyectos configurados, y escribir cambios de estado. Tratalo como una contrasena.

**Si commiteas un PAT por accidente:**
1. Revoca el token inmediatamente en Azure DevOps
2. Genera uno nuevo con los mismos scopes
3. Usa `git filter-repo` para limpiar el historial
4. Force-push y notifica a tu equipo

## Zero telemetria

No envio datos a ningun servidor. No hay analytics, no hay tracking, no hay phone-home. Todo se ejecuta localmente. Verificable: ningun script mio hace peticiones HTTP salvo a las APIs que tu configuras (Azure DevOps, GitHub).

## Reportar una vulnerabilidad

Si descubres un problema de seguridad (un script que filtra credenciales, un comando que expone datos en logs, o una configuración insegura por defecto), **NO abras un issue publico**.

En su lugar:
1. Ve al repositorio en GitHub
2. Click **Security** > **Report a vulnerability**
3. Describe el problema, pasos para reproducirlo, e impacto potencial

Recibiras acuse en **72 horas** y plan de resolucion en **14 dias**. Te acredito en las release notes salvo que prefieras anonimato.

## Para contributors

- Nunca incluyas PATs, URLs de organizacion, o nombres de proyecto reales
- Los datos de mock usan solo nombres ficticios — mantenlo asi
- No añadas scripts que hagan peticiones HTTP a terceros sin documentacion
- Si tu contribucion maneja credenciales, sigue mi patron: leer de fichero, nunca hardcodear
