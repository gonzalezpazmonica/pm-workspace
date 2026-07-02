---
id: SE-240
title: "Mobile security pipeline — MobSF + Frida + Objection para APK/IPA analysis"
status: IMPLEMENTED
priority: P2
effort: L (20h — S1 5h + S2 6h + S3 5h + S4 4h)
origin: Análisis defensivo hackingtool-plugin (AKCodez, 2026-06-28)
author: Savia
related:
  - mobile-developer agent
  - android-autonomous-debugger skill
  - adversarial-security skill
  - security-attacker/defender/auditor agents
  - SE-245 (dynamic-web-security-testing)
proposed_at: "2026-06-28"
resolved_at: "2026-07-02"
implementation_pr: "#890"
era: 237
tools_from_hackingtool:
  - MobSF
  - Frida
  - Objection
---

# SE-240 — Mobile security pipeline

## Problema

El agente `mobile-developer` genera código Swift/Kotlin/Flutter y el skill
`android-autonomous-debugger` automatiza builds y pruebas funcionales contra dispositivos
físicos. Sin embargo, no existe ningún pipeline de análisis de seguridad del APK resultante:

- No hay análisis estático del binario (permisos excesivos, código ofuscado, strings sensibles)
- No hay análisis dinámico (tráfico de red en runtime, hooks de funciones críticas)
- El `security-judge` del Code Review Court evalúa código fuente, no el binario compilado
- Un APK puede tener vulnerabilidades invisibles en el código fuente: libs de terceros
  compiladas, configuración del manifest, certificados embebidos

Proyectos con componente mobile generados por Savia quedan sin cobertura de seguridad
en la fase de artefacto binario.

## Tesis

Un skill `mobile-security-pipeline` que coordina tres herramientas: MobSF para análisis
estático y dinámico del APK, Frida para instrumentación en runtime, y Objection para
exploración interactiva de seguridad. El skill actúa sobre el artefacto compilado y es
invocable tras un build exitoso o como auditoría periódica.

## Herramientas

| Herramienta | Qué hace | Modo de uso en Savia | Offline |
|---|---|---|---|
| MobSF | Análisis estático + dinámico de APK/IPA/APPX | API local; imagen Docker `opensecurity/mobile-security-framework-mobsf` | Sí (Docker local) |
| Frida | Instrumentación dinámica de aplicaciones en ejecución | Scripts Python via `frida-tools`; requiere dispositivo/emulador ADB conectado | Sí (binarios locales) |
| Objection | Shell interactivo sobre Frida con comandos de pentest preconfigurados | `objection -g <package> explore` | Sí (pip install local) |

MobSF es el eje central. Frida/Objection se invocan sólo en análisis dinámico con dispositivo
disponible. El análisis estático con MobSF funciona sin dispositivo.

## Diseño

### Fases del pipeline

```
Fase 1: Estático (sin dispositivo) — siempre disponible
  → MobSF static analysis: manifest, permisos, strings, libs vulnerables,
     certificate pinning, exported components, hardcoded secrets

Fase 2: Dinámico (requiere ADB) — opcional
  → MobSF dynamic analysis: tráfico HTTP/HTTPS, actividad de archivo, logs
  → Frida hooks: interceptar funciones de crypto, networking, auth
  → Objection: bypass de root detection, SSL pinning disable, memory dump

Fase 3: Informe consolidado
  → JSON + HTML en output/security/mobile-{package}-YYYYMMDD/
  → Severidades: CRITICAL / HIGH / MEDIUM / LOW / INFO
  → Clasificadas por OWASP Mobile Top 10 2024
```

### Integración en pipeline Savia

```
Trigger: post-build | manual /mobile-security-scan | CI on-demand
Requiere: APK/IPA path | package name | [ADB device opcional]
```

**Script orquestador**: `scripts/security/mobile-security-pipeline.sh`
- Arranca MobSF vía Docker si no está corriendo
- Ejecuta análisis estático siempre
- Detecta dispositivo ADB; si disponible, ejecuta fase dinámica
- Las variables de entorno de Android SDK/JDK se leen desde el entorno del usuario
  (definidas en CLAUDE.md — no hardcodeadas en el script)

### Skill nueva: `.opencode/skills/mobile-security-pipeline/SKILL.md`

Coordina las tres fases e integra con `android-autonomous-debugger` para obtener el
APK path automáticamente. Output: resumen de findings + path al report completo (N3).

### Confidencialidad

Reports en `output/security/mobile-*/` (N3, git-ignorado). El APK analizado no se sube
a ningún servicio externo — MobSF corre completamente en local vía Docker.

### Umbrales conservadores

- Bloqueante: CRITICAL y HIGH con CVSS >= 7.0
- MEDIUM y LOW: informativo, no bloquean el pipeline
- Falsos positivos conocidos de libs Google/Firebase: declarar en `.mobsf-suppress.json`

## Slices

**S1 — MobSF static analysis script (5h)**
- `scripts/security/mobile-security-pipeline.sh` con sólo fase estática
- Docker pull de MobSF, API upload, poll resultado
- Report JSON en `output/security/`
- Tests: APK de muestra (DIVA Android) → findings esperados presentes

**S2 — Integración Frida + Objection para fase dinámica (6h)**
- Detección de dispositivo ADB (`adb devices`)
- Scripts Frida predefinidos: SSL unpin, root bypass detection, crypto hooks
- Integración con android-autonomous-debugger para gestión del emulador
- Documentación de prerequisitos (Frida server en dispositivo)

**S3 — Skill mobile-security-pipeline + comando (5h)**
- `.opencode/skills/mobile-security-pipeline/SKILL.md`
- `/mobile-security-scan [apk_path]` command en `.opencode/commands/`
- Integración con output de buildAndPublish para obtener APK automáticamente
- OWASP Mobile Top 10 mapping en el report

**S4 — CI integration + BATS tests (4h)**
- Workflow GitHub Actions opcional (manual trigger)
- BATS tests con APK fixtures conocidos (DIVA-Android)
- Documentación de setup offline (MobSF Docker, Frida binarios locales)

## Criterios de aceptación

- [ ] MobSF static analysis sobre DIVA-Android.apk detecta >= 5 findings CRITICAL/HIGH conocidos
- [ ] El script no sube el APK a ningún servicio externo
- [ ] Report HTML generado en `output/security/mobile-*/` con naming YYYYMMDD
- [ ] `output/security/` verificado en .gitignore antes de escribir cualquier report
- [ ] Con ADB disconnected, el pipeline completa la fase estática sin error
- [ ] Frida script de SSL unpinning funciona contra DIVA en emulador Android
- [ ] OWASP Mobile Top 10 categorías presentes en el report
- [ ] Skill invocable con `/mobile-security-scan ./app.apk`
- [ ] MobSF corre en Docker local sin requerir cuenta ni API key externa

## Qué NO incluye

- Análisis de seguridad de iOS IPA en entorno Linux (extensión futura)
- Pentest dinámico avanzado con Frida scripting personalizado por proyecto — eso es SE-245
- Análisis de seguridad del código fuente Swift/Kotlin — lo hace el security-judge existente
- Certificación OWASP MASVS checklist completo — auditoría manual
