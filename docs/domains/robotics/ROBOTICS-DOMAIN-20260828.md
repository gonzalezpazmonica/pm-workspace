---
entity: {type: document, id: robotics-domain-20260828}
title: "Robótica — Destilación de dominio (Savia Domains RBT) · 2026-08-28"
doc_type: domain-knowledge
status: published
confidentiality: N1
source: "Savia Domains (L23 RBT) + research internet 2026-08-28"
tags: [robotics, humanoids, ros2, lerobot, vla, perception, actuators, cross-domain]
created_at: 2026-08-28
---

# Robótica — Destilación de dominio

> Cúpula **RBT** (Savia Domains). Conocimiento N1 de referencia, abierto.
> Incorpora cross-dominio: **AID** (IA), **SFT** (programación), **ELC**
> (electrónica), **POW** (electricidad). CRIT-001: el stack open-source puede
> operar 100% local (sin dependencia cloud).
>
> **Provenance**: [VERIFICADO] = contrastado en fuente (2026-08-28) ·
> [CONOCIMIENTO] = de base del dominio, pendiente de re-verificar al usarlo.

## 1. Estado del arte 2026 — humanoides y comercialización

| Categoría | Actores principales | Nota |
|---|---|---|
| Humanoides | **Unitree** (G1/H1/R2 — precios bajos, sim abierta, soporte LeRobot) · **Figure** (02/03, partnership OpenAI) · **Tesla Optimus** · **1X Neo** (androide doméstico) · **Agility Digit** (warehouse/logística) · **Boston Dynamics Atlas** (eléctrico) · **Apptronik Apollo** · **Sanctuary Phoenix** (telepresencia) | [CONOCIMIENTO] el landscape 2026 está dominado por la carrera humanoide; verificar precios/stats al usar |
| Quadrúpedos | Unitree Go2/W1/A1 · Boston Dynamics Spot | [CONOCIMIENTO] |
| Industrial / cobot | ABB, KUKA, Fanuc, Universal Robots, **Franka Emika** (open API) | [CONOCIMIENTO] |
| Logística / AMR | Digit, warehouse AMR, drones FPV (DJI) | [CONOCIMIENTO] |
| Robótica de aprendizaje | **HuggingFace LeRobot** (open), Open X-Embodiment (datasets) | [VERIFICADO] LeRobot ICLR 2026 |

**Señales 2026** (prensa, [CONOCIMIENTO] — fuente de baja confianza, verificar):
humanoides propuestos para patrullaje fronterizo (DHS, 2026-08-21) · NVIDIA
DRIVE + LiDAR Apollo para vehículos autónomos (2026-08-08) · China impone
controles de exportación de drones (2026-08-06) y amplía mina de tierras
raras +50% (2026-08-10) — los materiales son cuello de botella de actuadores.

## 2. Stack open source (el más relevante para Savia)

| Capa | Herramienta | Nota |
|---|---|---|
| Middleware | **ROS 2** (Humble/Iron/Jazzy), DDS, ROS 1 (legacy) | [CONOCIMIENTO] |
| Simulación | Gazebo · MuJoCo · Isaac Sim/Lab · Webots | [CONOCIMIENTO] |
| Planificación/movimiento | MoveIt 2, OMPL, control_msgs, RViz, URDF/xacro | [CONOCIMIENTO] |
| **Robot learning** | **LeRobot (HF)**: hardware-agnostic, LeRobotDataset (Parquet+MP4), entrenamiento/inferencia unificada | [VERIFICADO] |
| Datasets | Hugging Face Hub (leRobot/*), Open X-Embodiment | [VERIFICADO] |
| Benchmark | LIBERO, MetaWorld, EnvHub (simuladores distribuibles) | [VERIFICADO] |
| Hardware soportado | SO-100, LeKiwi, Koch, HopeJR, OMX, EarthRover, Reachy2, OpenARM, **Unitree G1**, Franka, UR5e, AgileX Piper, ARX5, ALOHA (3rd party) | [VERIFICADO] (LeRobot README) |

## 3. IA para robótica (cross-dominio AID)

**VLA — Vision-Language-Action** (políticas que mapean visión+instrucción→acción):
[VERIFICADO, LeRobot] Pi0 / Pi0Fast / Pi0.5 · GR00T N1.7 · SmolVLA · XVLA ·
EO-1 · MolmoAct2 · WALL-OSS · EVO1. Modelos open-weight descargables y
entrenables localmente (CRIT-001).

**Imitation learning**: [VERIFICADO] ACT · Diffusion Policy · VQ-BeT ·
Multitask DiT.

**Reinforcement learning**: [VERIFICADO] HIL-SERL (humano-en-el-bucle) ·
TDMPC (+QC-FQL).

**World models**: [VERIFICADO] VLA-JEPA · LingBot-VA · FastWAM.

**Reward models** (para RL sin reward manual): [VERIFICADO] SARM · TOPReward ·
Robometer.

**Percepción** ([CONOCIMIENTO]): SLAM, detección/segmentación, estimación de
pose, visión RGB-D. Cruce con cúpula AID.

## 4. Programación (cross-dominio SFT)

- **C++** — nodes ROS 2, control en tiempo real, RTPS/DDS QoS.
- **Python** — investigación/ML (PyTorch, LeRobot), scripting de alto nivel.
- **microPython/C** — firmware embebido (RP2040, ESP32, STM32).
- Patrones clave: arquitectura de nodos pub/sub, transform trees (TF2),
  async, determinismo de control (frecuencias fijas), sim-to-real.

## 5. Electrónica (cross-dominio ELC)

- **Sensores**: cámara RGB-D (Intel RealSense), LiDAR (Ouster, Hesai),
  IMU, encoders (magnético/óptico), fuerza/par (F/T), táctil, profundidad.
- **Actuadores**: servo (SG90/FS90, hobby), BLDC con control **FOC**,
  **harmonic drives** (transmisiones de precisión para humanoides),
  belt-driven (SO-100: motores + correas + férulas), actuadores lineales.
- **Controladores**: microcontroladores (RP2040/ESP32/STM32), single-board
  (Raspberry Pi, Jetson para percepción), motor drivers (ODrive, ESC),
  puentes H, encoders magnéticos AS5600, comunicación I²C/CAN/UART.

## 6. Electricidad / potencia (cross-dominio POW)

- **Baterías**: LiPo/Li-ion, BMS, gestión térmica. Humanoides: ~1-2 kWh
  (verificar por modelo).
- **Power electronics**: ESCs (BLDC), conversión DC-DC (buck/boost), carga
  segura, protecciones de sobrecorriente.
- **Diseño de presupuesto de potencia**: picos de torque vs consumo medio;
  la eficiencia del control (FOC) define la autonomía.

## 7. Implicaciones para Savia (CRIT-001 · soberanía)

- **Todo el stack de aprendizaje de robots es local-first**: ROS 2, sim
  (MuJoCo/Isaac), LeRobot y los VLA open-weight se ejecutan en
  infraestructura propia; sin envío de datos a cloud.
- **Hardware abierto**: SO-100 (brazo de bajo coste) + LeRobot = puerta de
  entrada al dominio reproducible con <200€ (cruce con ELC/POW).
- **Soberanía**: modelos VLA abiertos (Pi0, GR00T N1.7, SmolVLA) descargables
  vía Ollama/HF local — alinea con el roadmap de soberanía de inferencia
  (L26/L27 y SE-348).
- **Oportunidad de formación**: LeRobot ofrece tutorial de robot learning
  gratuito (espacio HF) — material para la cúpula y para futuras skills de
  Savia de digestión/evaluación robótica.

## 8. Cúpulas relacionadas

| Cúpula | Relación |
|---|---|
| AID (IA y datos) | VLA, RL, world models, reward models, percepción |
| SFT (Ing. de software) | ROS 2, C++/Python, arquitectura de nodos, tests |
| ELC (Electrónica) | sensores, actuadores, controladores, FOC |
| POW (Electricidad) | baterías, potencia, ESCs, BMS |

## 9. Fuentes (estado de verificación)

- **LeRobot (HuggingFace)**: `github.com/huggingface/lerobot` README + ICLR
  2026 paper (arXiv 2602.22818) — [VERIFICADO 2026-08-28].
- Noticias 2026-08 (robotics.news + señales): humanoid border patrol, NVIDIA
  DRIVE+Apollo lidar, drone export controls, rare earths — [CONOCIMIENTO],
  fuente de baja confianza; verificar en fuente primaria antes de usar.
- Landscape humanoides (Unitree, Figure, Tesla, 1X, Agility, Boston, etc.) —
  [CONOCIMIENTO], verificar stats al usar.

## 10. Próximos pasos sugeridos

- Digestión profunda de 1-2 subdominios (VLA para humanoides · sim-to-real)
  en la cúpula RBT.
- Evaluar un primer prototipo local (SO-100/LeRobot o sim MuJoCo) como
  experimento Labs (CRIT-001).
- Mapear a skills de Savia (digestión/evaluación robótica).
