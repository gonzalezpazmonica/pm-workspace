# Hooks: Salvaguardas Programáticas No Eludibles

Los hooks en pm-workspace son mecanismos de seguridad programática que garantizan la integridad del flujo de trabajo. Actúan como controles automatizados que no pueden ser omitidos, protegiendo la calidad del código, la seguridad de credenciales y la coherencia con las especificaciones del proyecto.

## Seguridad (7)

### block-credential-leak.sh
Detecta secretos hardcodeados antes del commit. Escanea cambios para identificar patrones de credenciales, claves API y tokens sensibles, previniendo filtraciones involuntarias.

### block-force-push.sh
Previene force-push a ramas principales (main/master). Bloquea operaciones destructivas que podrían sobrescribir historial colaborativo.

### block-infra-destructive.sh
Bloquea operaciones `terraform destroy` sin aprobación explícita. Requiere confirmación manual para evitar destrucción accidental de infraestructura.

### validate-bash-global.sh
Previene operaciones bash destructivas. Valida scripts para evitar comandos peligrosos como `rm -rf /`, `chmod 777`, `curl | bash`, `sudo`, y auto-aprobación de PRs.

### android-adb-validate.sh
Valida comandos ADB antes de ejecución en dispositivos Android. Previene operaciones destructivas como `adb shell rm -rf` o acceso a datos sensibles del dispositivo. Registra todas las operaciones ADB en log de auditoría.

### block-project-whitelist.sh
Protege la privacidad entre proyectos. Bloquea lecturas y escrituras a directorios de proyectos que no estén en la whitelist del workspace actual.

### compliance-gate.sh
Gate de compliance que bloquea commits con violaciones. Verifica links de comparación en CHANGELOG, tamaño de ficheros (≤150 líneas para workspace files), frontmatter YAML en comandos y sincronización de READMEs.

## Puertas de Calidad (4)

### plan-gate.sh
Bloquea implementación sin especificación aprobada. Verifica que exista documentación de diseño validada antes de proceder con cambios de código.

### tdd-gate.sh
Refuerza Test-Driven Development: pruebas primero, código después. Rechaza commits que contengan implementación sin tests correspondientes.

### stop-quality-gate.sh
Puerta de calidad final antes del commit. Ejecuta validaciones finales: linting, type checking, y verificación de estándares de proyecto.

### scope-guard.sh
Verifica que archivos staged coincidan con el scope de la especificación. Previene cambios fuera del alcance documentado.

## Integración de Agent (4)

### agent-hook-premerge.sh
Puerta de calidad pre-merge que valida: credenciales filtradas, TODOs pendientes y marcadores de conflicto. Ejecuta antes de fusionar cambios.

### agent-dispatch-validate.sh
Valida el contexto antes de lanzar sub-agentes (Task tool). Verifica que exista especificación aprobada, que el scope sea apropiado y que no se excedan los límites de anidamiento.

### agent-trace-log.sh
Rastrea ejecución del agent registrando tokens consumidos y duración de operaciones. Proporciona visibilidad sobre el uso de recursos de automatización.

### session-init.sh
Inicialización de sesión (~300 tokens). Configura el entorno y estado inicial para ejecución consistente de agents.

## Flujo de Desarrollo (4)

### pre-commit-review.sh
Revisión de código contra reglas de dominio antes del commit. Valida adherencia a patrones establecidos y convenciones del proyecto.

### post-edit-lint.sh
Auto-lint automático después de editar archivos. Aplica correcciones de formato y estilo inmediatamente tras modificaciones.

### prompt-hook-commit.sh
Validación de mensaje de commit semántico. Asegura que mensajes sigan convenciones, valida que CHANGELOG tenga links de comparación cuando se modifica, y verifica longitud de primera línea (≤72 chars).

### memory-auto-capture.sh
Captura automática de contexto en memoria persistente después de ediciones. Registra patrones de cambio y decisiones arquitectónicas para sesiones futuras.

## Registro y Configuración

Todos los hooks están registrados en `settings.json` del proyecto. Esta configuración centralizada permite habilitar, deshabilitar o personalizar comportamientos según necesidades específicas del espacio de trabajo.

---

**Inspirado en:** [claude-code-templates](https://github.com/anthropics/claude-code-templates) — Sistema de categorización de hooks para flujos de trabajo profesionales.
