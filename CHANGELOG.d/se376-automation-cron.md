---
version_bump: patch
section: Fixed
---

### Fixed

- **automation-scheduler (SE-376)**: parser cron real (listas, rangos, pasos, nombres, OR dia-mes/dia-semana, busqueda 4 años); el dia de la semana ya no se desplaza un dia, '*/15' y los rangos se programan; horas en hora local y next_run en UTC comparado como fecha; create rechaza schedules invalidos con exit 2; la CLI sale con 1/2 en no encontrado/uso; run y run-due actualizan run_count y last_status; las tareas once se ejecutan una sola vez.

