# /sheets-sync — Sincronizar Sheets y Azure DevOps

**Descripción:** Sincroniza tareas entre Google Sheets y Azure DevOps en ambas direcciones: push (Sheets→DevOps), pull (DevOps→Sheets), o ambas.

**Uso:**
```
/sheets-sync {proyecto} {direccion}
```

**Parámetros:**
- `{proyecto}` (obligatorio) — Nombre del proyecto (ej: `alpha`)
- `{direccion}` (obligatorio) — `push`, `pull`, o `both`

## Razonamiento

1. Leer estado actual de ambas fuentes
2. Detectar cambios (delta)
3. Aplicar cambios según dirección
4. Registrar conflictos (mismo item modificado en ambos)
5. Mostrar resumen de sincronización

## Ejecución

**push** → Sheets → Azure DevOps (actualizaciones de status)
**pull** → Azure DevOps → Sheets (tareas nuevas, cambios)
**both** → Bidireccional (resolver conflictos primero)

Campos sincronizados:
- Status (To Do, In Progress, Done, Blocked)
- Assignee
- Estimate (SP)
- Sprint

## Template de Output

```
🔄 Sincronización: {proyecto} {direccion}

✅ {N} items sincronizados
   {M} cambios aplicados
   {K} conflictos resueltos

📋 Cambios:
   • Tarea AB#123 → Status: Done
   • Tarea AB#124 → Assignee: Alice

🚀 Listo para /sheets-report
```
