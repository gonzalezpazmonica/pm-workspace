# wellbeing-guardian — Dominio

## Por que existe esta skill

La IA intensifica el trabajo de 3 formas: expansion de tareas, difuminacion de limites trabajo-vida y multitasking cognitivo (HBR/Berkeley Haas, 2026). Sin intervencion proactiva, los desarrolladores trabajan sin pausas, fuera de horario y acumulan fatiga cognitiva que degrada la calidad del codigo. Esta skill implementa recordatorios de descanso, alertas fuera de horario y nudges de work-life balance configurables por usuario.

## Conceptos de dominio

- **Estrategia de descanso**: patron de foco/descanso elegido por el usuario (pomodoro 25/5, 52-17, 5-50 o custom), que determina cuando sugerir pausas
- **Nudge**: sugerencia no bloqueante que informa al usuario sin interrumpir su trabajo, con frecuencia maxima de 1 cada 25 minutos
- **Break compliance score**: ratio de descansos tomados vs esperados (0-100%), que alimenta burnout-radar como senal individual
- **Silence weekends**: flag que desactiva todas las notificaciones en fin de semana, respetando la desconexion digital

## Reglas de negocio que implementa

- Regla 20-20-20: cada 20min mirar a 6m durante 20s (fatiga visual, INSST Espana)
- INSST: pausa 10-15min por cada 60-90min de pantalla
- Principio foundacional #5: el humano decide (nudges son sugerencias, nunca bloqueos)
- Wellbeing config (wellbeing-config.md): esquema de horario, estrategias y umbrales

## Relacion con otras skills

- **Upstream**: `profile-setup` (workflow.md del perfil contiene la configuracion de wellbeing)
- **Downstream**: `burnout-radar` (consume break_compliance_score como senal individual para el heat map)
- **Downstream**: `sustainable-pace` (wellbeing_factor alimenta la formula de ritmo sostenible)
- **Paralelo**: `daily-routine` (rutina diaria complementa wellbeing con micro-pausas)

## Decisiones clave

- Nudges informativos, NUNCA bloqueantes: respetar la autonomia del usuario es mas importante que forzar descansos
- Escalado inverso: si el usuario ignora 3 nudges seguidos, reducir frecuencia en vez de insistir
- Datos de horario solo en perfil local (gitignored): la informacion de habitos de trabajo es privada
- Estrategias basadas en evidencia cientifica (pomodoro, 52-17, 5-50): no inventar patrones arbitrarios
