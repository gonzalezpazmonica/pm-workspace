# DevOps Validation — Dominio

## Por que existe esta skill

Conectar un proyecto a pm-workspace requiere que Azure DevOps tenga la configuracion
Agile correcta. Sin validacion previa, los comandos WIQL fallan silenciosamente o
devuelven datos incompletos. Esta skill audita 8 checks y genera un plan de remediacion.

## Conceptos de dominio

- **Ideal Agile config**: configuracion de referencia de Azure DevOps (proceso Agile, tipos, estados, campos)
- **8 checks**: conectividad, proyecto, proceso, tipos, estados, campos, backlog, iteraciones
- **Remediacion**: plan de acciones manuales en Azure DevOps UI para corregir gaps detectados
- **PASS/WARN/FAIL**: tres niveles de resultado por check; FAIL bloquea, WARN informa

## Reglas de negocio que implementa

- PM Config (pm-config.md): constantes de organizacion, proyecto y equipo Azure DevOps
- MCP Migration (mcp-migration.md): equivalencia entre REST/CLI y MCP tools para CRUD
- SDLC Gates (sdlc-gates.md): puertas de transicion que dependen de campos y estados correctos

## Relacion con otras skills

- **Upstream**: project-new (al crear proyecto, se invoca validacion automaticamente)
- **Downstream**: azure-devops-queries (depende de configuracion validada para WIQL correctas)
- **Paralelo**: flow-setup (configura Savia Flow como alternativa a Azure DevOps)

## Decisiones clave

- Validacion antes del primer comando operativo: prevenir errores silenciosos desde el inicio
- Remediacion manual obligatoria: Azure DevOps no permite cambiar proceso via API, solo UI
- JSON como formato de reporte: parseable por otros comandos para automatizar seguimiento
