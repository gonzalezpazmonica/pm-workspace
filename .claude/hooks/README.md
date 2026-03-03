# Hooks: Salvaguardas Programáticas No Eludibles

Los hooks en pm-workspace son mecanismos de seguridad programática que garantizan la integridad del flujo de trabajo. Actúan como controles automatizados que no pueden ser omitidos, protegiendo la calidad del código, la seguridad de credenciales y la coherencia con las especificaciones del proyecto.

## Seguridad (4)

### block-credential-leak.sh
Detecta secretos hardcodeados antes del commit. Escanea cambios para identificar patrones de credenciales, claves API y tokens sensibles, previniendo filtraciones involuntarias.

### block-force-push.sh
Previene force-push a ramas principales (main/master). Bloquea operaciones destructivas que podrían sobrescribir historial colaborativo.

### block-infra-destructive.sh
Bloquea operaciones `terraform destroy` sin aprobación explícita. Requiere confirmación manual para evitar destrucción accidental de infraestructura.

### validate-bash-global.sh
Previene operaciones bash destructivas. Valida scripts para evitar comandos peligrosos como `rm -rf /` o modificaciones de archivos del sistema.

## Puertas de Calidad (4)

### plan-gate.sh
Bloquea implementación sin especificación aprobada. Verifica que exista documentación de diseño validada antes de proceder con cambios de código.

### tdd-gate.sh
Refuerza Test-Driven Development: pruebas primero, código después. Rechaza commits que contengan implementación sin tests correspondientes.

### stop-quality-gate.sh
Puerta de calidad final antes del commit. Ejecuta validaciones finales: linting, type checking, y verificación de estándares de proyecto.

### scope-guard.sh
Verifica que archivos staged coincidan con el scope de la especificación. Previene cambios fuera del alcance documentado.

## Integración de Agent (3)

### agent-hook-premerge.sh
Puerta de calidad pre-merge que valida: credenciales filtradas, TODOs pendientes y marcadores de conflicto. Ejecuta antes de fusionar cambios.

### agent-trace-log.sh
Rastrea ejecución del agent registrando tokens consumidos y duración de operaciones. Proporciona visibilidad sobre el uso de recursos de automatización.

### session-init.sh
Inicialización de sesión (~300 tokens). Configura el entorno y estado inicial para ejecución consistente de agents.

## Flujo de Desarrollo (3)

### pre-commit-review.sh
Revisión de código contra reglas de dominio antes del commit. Valida adherencia a patrones establecidos y convenciones del proyecto.

### post-edit-lint.sh
Auto-lint automático después de editar archivos. Aplica correcciones de formato y estilo inmediatamente tras modificaciones.

### prompt-hook-commit.sh
Validación de mensaje de commit semántico. Asegura que mensajes sigan convenciones y contengan información estructurada requerida.

## Registro y Configuración

Todos los hooks están registrados en `settings.json` del proyecto. Esta configuración centralizada permite habilitar, deshabilitar o personalizar comportamientos según necesidades específicas del espacio de trabajo.

---

**Inspirado en:** [claude-code-templates](https://github.com/anthropics/claude-code-templates) — Sistema de categorización de hooks para flujos de trabajo profesionales.
