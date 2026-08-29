---
entity: {type: document, id: robotics-criterio-20260828}
title: "Criterio en robótica — cómo evaluar y recomendar robots (general + domésticos) · 2026-08-28"
doc_type: domain-knowledge
status: published
confidentiality: N1
source: "Savia Domains RBT — síntesis de criterio experto (sin experimentos con hardware)"
tags: [robotics, criterio, evaluacion, domesticos, robotica, recomendacion, privacy]
created_at: 2026-08-28
---

# Criterio en robótica — cómo evaluar y recomendar cualquier robot

> El objetivo no es listar robots: es tener **criterio** para juzgarlos y
> recomendar cuál incorporar (hogar o general). Este documento es el marco de
> evaluación + el conocimiento doméstico aplicado. CRIT-001: la privacidad y
> la soberanía de datos son una dimensión de evaluación, no una nota a pie.

---

## 1. Marco de evaluación universal (9 dimensiones)

Vale para CUALQUIER robot (industrial, humanoide, doméstico, de servicio).
Puntuación 1-5 por dimensión; la recomendación sale de la media ponderada
según el uso.

| # | Dimensión | Qué mide | Cómo se evalúa |
|---|---|---|---|
| 1 | **Capacidad de tarea** | qué tareas hace, con qué calidad y **fiabilidad** (tasa de éxito real, no la demo) | pruebas de terceros, reviews de propietarios, espec de mantenimiento (¿se atasca cada X?) |
| 2 | **Autonomía e inteligencia** | navegación, percepción, planificación, adaptación (aprendizaje/actualización) | mapa: LiDAR/VSLAM; evita obstáculos de verdad; auto-rescate; SLAM en exteriores |
| 3 | **Mecánica/actuación** | DOF, payload, precisión, velocidad, robustez, desgaste | espec + reviews de desgaste (motores, correas, batería a 1-2 años) |
| 4 | **Sensórica** | sensores para la tarea y robustez al entorno | visión, IMU, encoders, F/T, táctil; fallo en condiciones reales (alfombras, luz, lluvia) |
| 5 | **Seguridad** | estándares, interacción humano-robot, fall-safe, responsabilidad | ISO 10218 / ISO/TS 15066 (cobots); límites de fuerza/velocidad; comportamiento ante personas/mascotas |
| 6 | **Software/ecosistema** | SDK/API, ROS2, open vs cerrado, actualizaciones, reparabilidad | ¿se puede integrar/programar? ¿actualizaciones obligatorias que rompen? ¿piezas/coste de reparación? |
| 7 | **Datos y soberanía (CRIT-001)** | a dónde van los datos (mapas, vídeo, audio, patrones de vida), dependencia cloud, control local | **Filtro clave**: ¿funciona sin nube? ¿los datos de casa salen? ¿términos/retirada de servicio? |
| 8 | **Economía** | CAPEX + OPEX (consumibles, mantenimiento, batería) + coste de propiedad a 3 años | precio + coste real de mantenimiento; obsolescencia |
| 9 | **Despliegue** | instalación, huella, ruido, energía, encaje en el hogar | mapa del hogar, ruido (dB), consumos, seguridad en casa (niños/mascotas) |

**Regla de decisión**: un robot se **descarta** si falla en 5 (seguridad) o en 7
(soberanía de datos) en un caso que exige esas garantías. Las demás dimensiones
se ponderan por uso.

---

## 2. Taxonomía de robots domésticos (2026)

| Categoría | Madurez | Líderes de mercado (2026) | Tareas |
|---|---|---|---|
| **Limpieza de suelos** (aspirador+fregona) | **Madura** (el único mercado masivo) | Roborock (S8/S9/Curv/Qrevo), Dreame (X50/Freo), Narwal, iRobot (Roomba Combo), Ecovacs (Deebot), Eufy | aspirar/fregar por zonas, auto-vacía, auto-limpia mopa |
| **Limpieza de cristales** | Media | Hobot, Ecovacs Winbot, Dreame A1/Bot | fregar cristales/vidrio (con cuerda de seguridad) |
| **Jardín/césped** | Media-alta | Husqvarna Automower, Worx Landroid, Segway Navimow, Echo Robotics | cortar césped, bordes, pendientes; Navimow RTK sin cable |
| **Cocina (chef/asistente)** | Baja (caro) / emergente | Moley (robot cocina, muy caro) · asistentes humanoides en ciernes (1X Neo, Tesla Optimus, Unitree R2/G1) · electrodomésticos "inteligentes" (Thermomix NO es robot) | cocinar, preparar, servir; aún sin madurez doméstica |
| **Cuidado de mascotas** | Media | Litter-Robot, Petkit/Petlibro (comederos), furbo (cámara) | arenero auto-limpiable, alimentación, monitorización |
| **Piscina** | Media | Dolphin (Maytronics), Beatbot | limpiar paredes/suelo de piscina |
| **Seguridad/patrulla** | Media | cámaras móviles, robots de patrulla indoor/outdoor | vigilancia, rondas |
| **Atención/asistencia personas** | Baja-emergente | asistentes humanoides en ciernes; telepresencia (Temi, Ava) | acompañar, supervisar, recordatorios |

**Lectura de mercado 2026**: el único segmento **maduro y fiable** es la
limpieza de suelos. Los humanoides domésticos (cocina, cuidado) son
**promesas**: altos precios, baja fiabilidad, maduración pendiente. El criterio
honesto es: hoy se compra un robot de suelos y quizá césped/cristal/mascota;
los humanoides de casa son para esperar o para un segundo hogar de pruebas.

---

## 3. Criterio aplicado por categoría (qué mirar, qué descarta)

### 3.1 Limpieza de suelos (la compra recomendable hoy)
- **Navegación**: LiDAR + VSLAM (evita mejor que solo VSLAM); mapa por estancias,
  zonas prohibidas, reconoce alfombras (sube el cepillo), auto-rescate.
- **Aspirado**: succión (Pa — cuidado: el marketing miente; mirar reviews de
  alfombra), cepillo sin enredos (mascotas).
- **Fregado**: mopa rotatoria/por vibración + auto-limpieza en base; detección
  de moqueta (no mojar).
- **Base**: auto-vaciado, auto-limpieza, secado; capacidad del depósito.
- **Autonomía**: mAh → cobertura por carga; vuelve a cargar y reanuda.
- **Ruido**: dB real (más alto de lo anunciado).
- **Datos**: los mapas de tu casa y los vídeos van a la nube del fabricante
  en la mayoría. **Filtro CRIT-001**: ¿hay modo local / sin cuenta?
- **Fiabilidad**: reviews de propietarios a 6-12 meses (atascos, soporte).

### 3.2 Césped
- **Navegación**: RTK GPS sin cable de borde (Navimow) vs cable guía
  (Automower/Landroid). Pendiente máx, islas, corredores estrechos.
- **Seguridad**: detección de obstáculos (cuchilla con protección), trabajo
  nocturno.
- **Datos**: mapas y geolocalización → nube; filtro CRIT-001.

### 3.3 Cristales / piscina / mascotas
- Cristal: adherencia, cordón de seguridad, cobertura de bordes.
- Piscina: filtrado de escombros, navegación de paredes, facilidad de limpieza
  del filtro.
- Mascotas: ruido, seguridad del mecanismo (nunca piezas que atrapen), datos
  de vídeo del interior de casa.

### 3.4 Humanoides domésticos / cocina (emergente — criterio de espera)
- **Criterio**: madurez = fiabilidad real en tareas cotidianas + seguridad
  físico + coste + soporte. Ninguno cumple hoy (2026) para cocinar en casa de
  forma fiable.
- Qué vigilar cuando lleguen: DOF de brazos, autonomía de batería (min de
  operación), seguridad de interacción (fuerza/velocidad limitadas), modo local
  (datos de vídeo/audio de casa), precio+coste de reparación, garantía.
- **Decisión honesta**: si la prioridad es tareas domésticas reales HOY, un
  humanoid no es una compra racional; un robot de suelos sí.

---

## 4. El filtro olvidado: datos y soberanía (CRIT-001)

La mayoría de los robots domésticos **envían mapas, vídeo y patrones de vida
a la nube del fabricante**. Esto importa doble en casa:
- **Privacidad del hogar**: el mapa de tu casa + cámaras + audio es dato N3/N4.
- **Dependencia**: si el fabricante retira el servicio o sube el plan, el robot
  pierde funciones (obsolescencia forzada).

**Filtro de evaluación** (aplicar a cualquier candidato):
1. ¿Funciona el robot con **nube caída**? (offline = sí/no)
2. ¿Dónde van mapas/vídeo/audio? ¿se pueden desactivar?
3. ¿Cuenta obligatoria? ¿los datos se pueden borrar/exportar?
4. ¿El fabricante tiene historial de retirada de servicios / suscripciones?
5. ¿Es posible control local (LAN) o API local?

**Regla CRIT-001**: ante opciones equivalentes, gana la que mantiene los datos
del hogar en infraestructura propia (o el mínimo egress justificado y
consentido).

---

## 5. Metodología de recomendación (perfil → robot)

```
1. Definir PERFIL del hogar: superficie y plantas · tipo de suelo (madera,
   moqueta, baldosa) · mascotas/niños · jardín/piscina · hábitos (fregar?
   cocinar?) · presupuesto · requisito de privacidad (local-first?).
2. Ponderar las 9 dimensiones según el perfil (ej. con mascotas → fiabilidad
   de cepillo y auto-rescate; con privacidad estricta → soberanía de datos).
3. Pre-filtrar: descartar lo que falla en seguridad o soberanía.
4. Comparar 2-4 candidatos por categoría en las dimensiones ponderadas.
5. Emitir recomendación: modelo(s) + por qué + alternativas + coste total a
   3 años + riesgos (soporte, obsolescencia).
```

---

## 6. Ejemplo aplicado (perfil típico)

**Perfil**: casa 90 m² en una planta, suelo mixto, 1 perro, sin jardín ni
piscina, presupuesto medio, fregado deseado, privacidad importante.

| Candidato (categoría suelos) | Naveg. | Fiabilidad | Fregado | Auto-base | Datos | Nota |
|---|---|---|---|---|---|---|
| Roborock (gama media-alta, LiDAR) | 5 | 4 | 4 (rotatorio, auto-limpieza) | sí | nube (modo local parcial en algunos modelos vía app/hack) | recomendado si el perfil acepta nube |
| Dreame (X-series) | 5 | 4 | 5 | sí | nube | alternativo potente |
| iRobot Roomba Combo | 4 | 4 | 3 | sí | nube + suscripción | buena marca, fregado menor |
| Marca local-first / sin nube | 3 | 3 | 3 | a veces | **local** | elige si soberanía es prioridad (menor ecosistema) |

**Recomendación** (para ese perfil): un **Roborock/Dreame de gama media-alta
con mopa rotatoria y auto-limpieza**, SI se acepta la nube con egress de
mapas (o se limita con modo local). Si la privacidad es estricta, buscar la
opción local-first aunque pierda ecosistema. **No recomendar** un humanoide de
casa para tareas reales hoy (madurez insuficiente).

---

## 7. Fuentes y estado

- [CONOCIMIENTO] — síntesis de criterio experto sobre el mercado 2026;
  las cifras concretas (succión, dB, autonomía, precios) deben verificarse en
  reviews actuales de terceros antes de una compra (no se hicieron experimentos
  con hardware).
- Se recomienda, antes de comprar, contrastar 2-3 reviews de propietarios a
  6-12 meses y el estado del "modo local" del modelo concreto.

## 8. Próximos pasos (sin experimentos)

- Mantener esta base de criterio como documento vivo de la cúpula RBT.
- Cuando la operadora pida "qué robot para mi casa", aplicar §5 con su perfil
  real y emitir recomendación (esta capacidad es el uso previsto).
