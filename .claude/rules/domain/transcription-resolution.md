# Transcription Resolution — Correccion de errores ASR en transcripciones

> Los transcriptores de IA (Teams, Meet, Zoom) cometen errores foneticos sistematicos:
> acrónimos mal transcritos, nombres deformados, terminos tecnicos irreconocibles.
> Esta regla define como detectarlos y resolverlos usando contexto del proyecto.

---

## Cuando aplica

Siempre que meeting-digest procese una transcripcion (VTT, TXT, DOCX, pegado directo).
Se ejecuta como **Fase 0** del pipeline, ANTES de la extraccion (Fase 1).

## Fuentes del diccionario de proyecto

Cargar en este orden antes de procesar la transcripcion:

1. `projects/{p}/agent-memory/meeting-digest/phonetic-map.md` — correcciones aprendidas (maxima prioridad)
2. `projects/{p}/GLOSSARY.md` — terminos de dominio, acronimos, entornos
3. `projects/{p}/team/TEAM.md` — nombres completos, handles, roles
4. `projects/{p}/ARCHITECTURE.md` — componentes, servicios, modulos
5. `projects/{p}/ENVIRONMENTS.md` — nombres de entornos y sus alias
6. `projects/{p}/business-rules/STAKEHOLDERS.md` — personas externas

## 4 heuristicas de deteccion

**H1 — Termino no reconocido**: palabra que no esta en vocabulario comun ni en
diccionario del proyecto. Ejemplo: "Saret" en contexto .NET.

**H2 — Match fonetico con phonetic-map**: termino coincide con una variante
conocida en el phonetic-map del proyecto. Ejemplo: "Cuba" → QA.

**H3 — Contexto incongruente**: palabra existe en espanol pero no encaja en
contexto tecnico. Ejemplo: "Cuba" en "bloqueado en Cuba" — un pais en contexto
de despliegue sugiere un entorno (QA).

**H4 — Nombre deformado**: nombre propio que no aparece en TEAM.md ni STAKEHOLDERS.md
pero tiene distancia Levenshtein ≤ 2 de alguno conocido. Ejemplo: "Giner" → "Gines".

## Scoring de resolucion

Para cada gap detectado, calcular confianza:

- **Base**: 70% si match en phonetic-map, 50% si match en glossary/team, 30% si solo contexto
- **Bonus contexto**: +10% si la frase completa encaja con el termino resuelto
- **Bonus historial**: +5% si la misma correccion se aplico antes con exito
- **Penalizacion**: -15% si multiples candidatos equiprobables

## Decision por confianza

- **≥ 80%**: resolver automaticamente (transparente, sin marca)
- **50-79%**: resolver con marca visible → `QA [?Cuba]` (PM puede revisar)
- **< 50%**: dejar original con marca → `Cuba [?]` (gap no resuelto)

## phonetic-map.md — Diccionario aprendido por proyecto

Ruta: `projects/{p}/agent-memory/meeting-digest/phonetic-map.md`
Nivel: N4 (gitignored, datos de proyecto).

Formato por seccion tematica (Entornos, Personas, Terminos tecnicos, Integraciones):
```
- {ASR_escribe} → {termino_real} | {confianza}% | {fuente} | {ultima_fecha}
```

Entradas sin resolucion:
```
- {ASR_escribe} → [?] | sin resolucion | reportado {fecha}
```

## Aprendizaje por correccion de la PM

Cuando la PM corrige una transcripcion en la conversacion:

1. Detectar la correccion (patron: "X no, es Y" / "se refiere a Y" / correccion directa)
2. Anadir o actualizar entrada en phonetic-map.md del proyecto
3. Si ya existia: recovery +5% confianza (techo: confianza original)
4. En proximas transcripciones: resolver automaticamente

## Decay

- 3 rechazos consecutivos de la PM a una resolucion: -5% confianza
- Floor: 30% (nunca se borra, solo baja prioridad)
- Sin uso 90 dias: marcar como `[stale]`, no borrar

## Integracion con memoria

- **Auto-prime**: al detectar contexto de transcripcion, cargar phonetic-map + GLOSSARY
  del proyecto activo (dominios: `product`, `team`, `architecture`)
- **Memory-save**: gaps no resueltos se guardan como type=entity, concept=transcription-gap
  para futuras busquedas hibridas
- **Hybrid search**: si H1 no encuentra match local, buscar en memory store por similitud

## Prohibido

- NUNCA resolver un nombre propio sin candidato en TEAM.md o STAKEHOLDERS.md
- NUNCA eliminar un termino original sin resolucion (siempre preservar el texto ASR)
- NUNCA aplicar correcciones de un proyecto a otro (phonetic-map es por proyecto)
