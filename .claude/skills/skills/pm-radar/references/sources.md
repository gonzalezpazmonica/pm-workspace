# pm-radar — Fuentes (20+)


### Correo
1. **mail-zenith** — browser-daemon cuenta Zenith Industries, inbox + enviados (48h)
2. **mail-vass** — browser-daemon cuenta VASS, inbox + enviados (48h)
3. **mail-attachments** — adjuntos Excel/PDF/Word digeridos (SPEC-M01)

### Calendarios
4. **calendar-zenith-72h** — eventos Outlook Zenith próximas 72h
5. **calendar-vass-72h** — eventos Outlook VASS próximas 72h
6. **team-vacations** — ausencias y vacaciones del equipo (SPEC-V01)

### Teams
7. **chats-dms** — DMs sin responder de stakeholders altos
8. **chats-grupos** — chats grupales con @menciones o pendientes
9. **chat-reuniones** — chats asociados a reuniones
10. **teams-attachments** — adjuntos compartidos en Teams (SPEC-T03)
11. **teams-channels** — canales con actividad sin leer (SPEC-T01)

### Transcripciones
12. **sharepoint-recordings** — grabaciones SharePoint + VTTs procesados (SPEC-S01)

### OneDrive
13. **recent-files-zenith** — ficheros recientes OneDrive Zenith (SPEC-O01)
14. **recent-files-vass** — ficheros recientes OneDrive VASS personal (SPEC-O02)
15. **documentos-local** — cambios recientes en `Documentos/` local

### DevOps (read-only)
16. **PBIs enriched** — PAT `$HOME/.azure/{proyecto}-devops-pat`, WIQL Sprint actual + anteriores abiertos, enriquecido con revisions/history (SPEC-R02)
17. **pipelines** — estado builds/releases últimas 24h (SPEC-D02)
18. **PRs+branches** — PRs abiertos asignados/a revisar + ramas activas (SPEC-D03)
19. **tasks-progress** — progreso de tasks vs estimación (CompletedWork/OriginalEstimate)

### Repos locales
20. **git-sweep** — barrido de repos locales (commits sin push, branches huérfanas, dirty trees) (SPEC-D01)

### State
21. **state.json** — `~/.savia/pm-radar/state.json` (items gestionados, feedback loop) (SPEC-P01)

### PM local
22. **PENDING.md** — tareas aplazadas por Monica en `projects/{proyecto}/<area-monica>/notes/PENDING.md`
23. **meetings** — digests en `projects/{proyecto}/meetings/`
24. **decisions** — decisiones escritas en `projects/{proyecto}/decisions/`
25. **risks** — riesgos abiertos en `projects/{proyecto}/risks/`
26. **roadmap** — `projects/{proyecto}/roadmap/roadmap-*.md`
