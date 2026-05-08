# Orgchart Mermaid Template

> Plantilla para generar organigramas con `graph TB` y subgraphs por equipo.

## Convenciones

- Nodo raíz: departamento con responsable (si existe)
- Subgraph por equipo: nombre del equipo como título
- Leads: sufijo ` ★` y rol como subtítulo
- Miembros: @handle con rol como subtítulo
- IDs de nodo: `DEPT`, `SQ_{team}_{handle}` (sin @, sin guiones)

## Plantilla base

```mermaid
graph TB
    DEPT["🏢 {dept_name}<br/><i>Responsable: {responsable}</i>"]

    subgraph squad1["{team1_name}"]
        SQ_T1_handle1["@handle1<br/>{role1} ★"]
        SQ_T1_handle2["@handle2<br/>{role2}"]
    end

    subgraph squad2["{team2_name}"]
        SQ_T2_handle3["@handle3<br/>{role3} ★"]
        SQ_T2_handle4["@handle4<br/>{role4}"]
    end

    DEPT --- squad1
    DEPT --- squad2
```

## Reglas de generación

1. Leer `teams/{dept}/dept.md` para nombre y responsable
2. Leer `teams/{dept}/{team}/team.md` para cada equipo
3. Miembros con rol en `lead:` llevan ★
4. IDs sin caracteres especiales: `@ana` → `SQ_T1_ana`
5. Solo usar @handles, NUNCA nombres reales (regla PII-Free)
6. Capacity total del equipo se muestra en el subgraph title si >0

## Ejemplo real (SoftwareEngineering)

```mermaid
graph TB
    DEPT["🏢 SoftwareEngineering<br/><i>Responsable: —</i>"]

    subgraph squad1["Squad1 (cap: 2.0)"]
        SQ_S1_eduardo["@eduardo<br/>tech-lead ★"]
        SQ_S1_daniel["@daniel<br/>tech-lead ★"]
    end

    subgraph squad2["Squad2 (cap: 2.0)"]
        SQ_S2_ana["@ana<br/>tech-lead ★"]
        SQ_S2_bernardo["@bernardo<br/>tech-lead ★"]
    end

    DEPT --- squad1
    DEPT --- squad2
```
