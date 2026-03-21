"""Post-command follow-up suggestions — inspired by FAIR-Perplexica."""

# Static command adjacency map: after command X, suggest Y
FOLLOW_UPS = {
    'sprint-status': [
        ('/board-flow', 'ver cuellos de botella'),
        ('/risk-predict', 'predicción de completitud'),
        ('/team-workload', 'balance de carga del equipo'),
    ],
    'sprint-plan': [
        ('/capacity-forecast', 'previsión de capacidad'),
        ('/dependency-map', 'dependencias entre items'),
        ('/sprint-autoplan', 'composición óptima automática'),
    ],
    'pr-review': [
        ('/spec-verify', 'verificar contra spec'),
        ('/security-audit', 'auditoría de seguridad'),
        ('/comprehension-report', 'documentar modelo mental'),
    ],
    'project-audit': [
        ('/project-release-plan', 'plan de release priorizado'),
        ('/debt-analyze', 'análisis de deuda técnica'),
        ('/arch-health', 'salud arquitectónica'),
    ],
    'spec-generate': [
        ('/spec-review', 'revisar completitud'),
        ('/security-review', 'review de seguridad pre-impl'),
        ('/feasibility-probe', 'validar viabilidad'),
    ],
    'debt-analyze': [
        ('/debt-prioritize', 'priorizar por impacto'),
        ('/debt-budget', 'presupuesto de deuda'),
        ('/debt-track', 'registrar hallazgos'),
    ],
    'web-research': [
        ('/tech-research', 'investigación profunda'),
        ('/arch-compare', 'comparar arquitecturas'),
        ('/adr-create', 'documentar decisión'),
    ],
    'sprint-review': [
        ('/sprint-retro', 'preparar retrospectiva'),
        ('/sprint-release-notes', 'generar release notes'),
        ('/outcome-track', 'tracking de outcomes'),
    ],
    'backlog-prioritize': [
        ('/sprint-autoplan', 'planificar sprint'),
        ('/feature-impact', 'análisis de impacto'),
        ('/epic-plan', 'planificación de épica'),
    ],
    'security-audit': [
        ('/security-pipeline', 'pipeline adversarial completo'),
        ('/threat-model', 'modelo de amenazas'),
        ('/dependencies-audit', 'auditoría de dependencias'),
    ],
}


def get_suggestions(command_name, max_suggestions=3):
    """Get follow-up command suggestions after executing a command.

    Args:
        command_name: Name of the command just executed (without /)
        max_suggestions: Maximum suggestions to return

    Returns:
        List of (command, description) tuples, or empty list
    """
    clean = command_name.lstrip('/').strip()
    suggestions = FOLLOW_UPS.get(clean, [])
    return suggestions[:max_suggestions]


def format_suggestions(command_name):
    """Format suggestions as a displayable block."""
    suggestions = get_suggestions(command_name)
    if not suggestions:
        return ""
    lines = ["💡 Siguientes pasos:"]
    for cmd, desc in suggestions:
        lines.append(f"   → {cmd} ({desc})")
    return "\n".join(lines)
