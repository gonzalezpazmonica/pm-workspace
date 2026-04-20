---
id: SPEC-017
title: SPEC-017: Dependency Sovereignty — USB Offline Installer
status: PROPOSED
origin_date: "2026-03-22"
migrated_at: "2026-04-18"
migrated_from: body-prose
---

# SPEC-017: Dependency Sovereignty — USB Offline Installer

> Status: **DRAFT** · Fecha: 2026-03-22
> Origen: Necesidad de despliegue 100% offline en maquinas sin internet
> Impacto: Savia funciona en cualquier maquina Linux con un pendrive

---

## Problema

pm-workspace + SaviaClaw dependen de ~15 componentes externos que se
descargan de internet: Python, pip packages, Whisper models, Kokoro TTS,
Ollama, LLMs, Node.js, Claude Code, ffmpeg, jq. Si no hay internet,
no hay Savia.

El script `savia-travel.sh` empaqueta el workspace pero NO las dependencias.
El script `emergency-plan.sh` cachea Ollama + 1 modelo pero NO el resto.

**Objetivo**: un pendrive USB de 32GB que contenga TODO lo necesario para
instalar Savia en una maquina Linux limpia sin conexión a internet.

---

## Inventario de dependencias (medido en Lima, 2026-03-22)

### Tier 1 — Core (minimo viable: voz + LLM local)

| Componente | Tamanio | Fuente |
|------------|---------|--------|
| pm-workspace repo (shallow) | ~20 MB | git clone --depth 1 |
| Python 3.12 standalone | ~60 MB | python-build-standalone (indygreg) |
| Pip wheels (torch CPU) | ~740 MB | pytorch.org/whl/cpu |
| Pip wheels (resto voice) | ~350 MB | ctranslate2, faster-whisper, numpy, silero, etc |
| Whisper model tiny | ~75 MB | huggingface Systran/faster-whisper-tiny |
| Whisper model base | ~142 MB | huggingface Systran/faster-whisper-base |
| Kokoro TTS 82M | ~313 MB | huggingface hexgrad/Kokoro-82M |
| Silero VAD | ~2 MB | incluido en pip wheels |
| Ollama binary (Linux x64) | ~200 MB | ollama.com/download |
| Ollama model qwen2.5:3b | ~2.0 GB | ollama pull |
| ffmpeg static | ~80 MB | johnvansickle.com/ffmpeg |
| jq static | ~2 MB | github.com/jqlang/jq |
| **Subtotal Tier 1** | **~4.0 GB** | |

### Tier 2 — Full (voz + LLM potente + Claude Code)

| Componente | Tamanio | Fuente |
|------------|---------|--------|
| Todo Tier 1 | ~4.0 GB | |
| Ollama model qwen2.5:7b | ~4.7 GB | ollama pull |
| Whisper model small | ~464 MB | huggingface Systran/faster-whisper-small |
| Node.js portable | ~120 MB | nodejs.org (LTS tarball) |
| Claude Code CLI (npm) | ~50 MB | @anthropic-ai/claude-code + deps |
| Savia-voice audio cache | ~15 MB | zeroclaw/savia-voice/cache/ |
| **Subtotal Tier 2** | **~9.3 GB** | |

### Tier 3 — Everything (incluye modelos grandes)

| Componente | Tamanio | Fuente |
|------------|---------|--------|
| Todo Tier 2 | ~9.3 GB | |
| Ollama model qwen2.5:14b | ~9.0 GB | ollama pull |
| Whisper model medium | ~1.5 GB | huggingface |
| **Subtotal Tier 3** | **~19.8 GB** | |

**USB recomendado**: 32 GB para Tier 2 con margen. 64 GB para Tier 3.

---

## Diseno

### Estructura del USB

```
SAVIA-USB/
├── install.sh                    ← Punto de entrada único
├── manifest.json                 ← Inventario con SHA256 de cada componente
├── tier.conf                     ← Tier seleccionado (1, 2 o 3)
│
├── core/                         ← Tier 1
│   ├── python/                   ← Python standalone (tarball)
│   ├── wheels/                   ← Pip wheels pre-descargados
│   ├── models/
│   │   ├── whisper-tiny/         ← faster-whisper tiny
│   │   ├── whisper-base/         ← faster-whisper base
│   │   ├── kokoro-82m/           ← Kokoro TTS
│   │   └── silero-vad.onnx
│   ├── ollama/
│   │   ├── ollama-linux-amd64    ← Binario
│   │   └── models/qwen2.5-3b/   ← Modelo GGUF exportado
│   ├── bin/
│   │   ├── ffmpeg                ← Static binary
│   │   └── jq                   ← Static binary
│   └── workspace/                ← pm-workspace shallow clone
│
├── full/                         ← Tier 2 (adicional)
│   ├── models/
│   │   ├── whisper-small/
│   │   └── ollama/qwen2.5-7b/
│   ├── node/                     ← Node.js portable
│   └── claude-code/              ← npm pack de Claude Code
│
└── extra/                        ← Tier 3 (adicional)
    └── models/
        ├── whisper-medium/
        └── ollama/qwen2.5-14b/
```

### Script de preparacion (en maquina CON internet)

`scripts/sovereignty-pack.sh` — ejecutar en maquina con internet:

```
sovereignty-pack.sh [--tier 1|2|3] [--dest /media/usb] [--arch amd64|arm64]
```

Fases:
1. **Detect** — detectar arquitectura, espacio USB disponible
2. **Download** — descargar componentes que faltan al cache local
3. **Verify** — SHA256 de cada componente
4. **Copy** — copiar al USB en estructura SAVIA-USB/
5. **Manifest** — generar manifest.json con hashes
6. **Test** — verificar que install.sh puede leer todo

Cache local: `~/.savia/sovereignty-cache/` — reutilizable entre builds.
Si un componente ya esta en cache con hash correcto, no se re-descarga.

### Script de instalación (en maquina SIN internet)

`SAVIA-USB/install.sh` — ejecutar desde el USB:

```
./install.sh [--prefix ~/.savia] [--tier 1|2|3] [--dry-run]
```

Fases:
1. **Verify** — comprobar manifest.json, SHA256 de cada fichero
2. **Python** — descomprimir Python standalone en prefix
3. **Venv** — crear venv, instalar wheels con `pip install --no-index --find-links`
4. **Models** — copiar modelos a ~/.cache/huggingface/hub/ (estructura correcta)
5. **Ollama** — instalar binario, importar modelo GGUF
6. **Bins** — copiar ffmpeg/jq a prefix/bin, anadir a PATH
7. **Node** — (Tier 2+) descomprimir Node.js, instalar Claude Code
8. **Workspace** — copiar pm-workspace a ~/claude/
9. **Config** — generar config por defecto (savia-voice, profiles)
10. **Verify** — test de humo: python, whisper, ollama, savia

### Formato de Ollama offline

Ollama no tiene import nativo de modelos pre-descargados.
Opciones investigadas:

**Opcion A — Copiar blobs directamente**:
- Copiar `~/.ollama/models/` del host origen al destino
- Ollama reconoce los modelos sin re-descargar
- Mas simple pero acoplado a la estructura interna de Ollama

**Opcion B — Modelo GGUF + Modelfile**:
- Exportar modelo como GGUF (ya esta en blobs/)
- Crear Modelfile con `FROM ./model.gguf`
- En destino: `ollama create qwen2.5:3b -f Modelfile`
- Mas portable pero requiere ollama corriendo

**Recomendacion**: Opcion A para simplicidad. Fallback a B si estructura cambia.

---

## Requisitos del script sovereignty-pack.sh

### Descarga de Python standalone

```bash
# python-build-standalone de indygreg (Gregory Szorc)
# Releases: github.com/indygreg/python-build-standalone/releases
# Formato: cpython-3.12.x+YYYYMMDD-x86_64-unknown-linux-gnu-install_only.tar.gz
PYTHON_URL="https://github.com/indygreg/python-build-standalone/releases/download/..."
```

### Descarga de pip wheels offline

```bash
# Descargar todos los wheels necesarios para offline install
pip download --dest wheels/ --no-cache-dir \
  --platform manylinux2014_x86_64 --python-versión 3.12 \
  --only-binary=:all: \
  faster-whisper silero-vad sounddevice numpy pyyaml websockets kokoro

# torch CPU-only requiere indice separado
pip download --dest wheels/ --no-cache-dir \
  --platform manylinux2014_x86_64 --python-versión 3.12 \
  --only-binary=:all: \
  --extra-index-url https://download.pytorch.org/whl/cpu \
  torch torchaudio
```

### Descarga de modelos Whisper

```bash
# Los modelos estan en repos HuggingFace como ficheros sueltos
# faster-whisper usa CTranslate2 format (model.bin + config.json + vocabulary)
huggingface-cli download Systran/faster-whisper-tiny --local-dir models/whisper-tiny/
```

### Descarga de ffmpeg static

```bash
# johnvansickle.com/ffmpeg — static builds Linux
curl -L "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz" \
  -o ffmpeg.tar.xz
```

---

## Implementación

### Fase 1 — sovereignty-pack.sh Tier 1 (1 sprint)

1. Crear `scripts/sovereignty-pack.sh` con fases download + verify + copy
2. Cache local en `~/.savia/sovereignty-cache/`
3. Manifest con SHA256
4. Solo componentes Tier 1 (voice + LLM 3b)
5. Crear `scripts/sovereignty-install.sh` (generado dentro del USB)

### Fase 2 — Tiers 2-3 + verificación (1 sprint)

1. Anadir Node.js, Claude Code, modelos grandes
2. install.sh con seleccion de tier
3. Test de humo post-instalación
4. Documentación usuario

### Fase 3 — Integración con travel-pack (< 1 sprint)

1. `savia-travel.sh` llama a sovereignty-pack para deps
2. Un solo comando: `savia-travel.sh pack --with-deps --dest /media/usb`
3. Perfil y datos cifrados (existente) + deps (sin cifrar, publicos)

---

## Criterios de aceptacion

- [ ] USB Tier 1 instala Savia funcional en maquina Linux sin internet
- [ ] Voz funciona offline: mic → whisper → LLM local → TTS → speaker
- [ ] Tiempo de instalación < 10 minutos en SSD
- [ ] Manifest verifica integridad de todos los ficheros antes de instalar
- [ ] sovereignty-pack.sh reutiliza cache (no re-descarga si ya tiene)
- [ ] install.sh es idempotente (se puede ejecutar multiples veces)
- [ ] Soporta x86_64 Linux (arm64 como stretch goal)

---

## Riesgos

| Riesgo | Mitigacion |
|--------|-----------|
| Ollama cambia estructura de modelos | Opcion B (GGUF import) como fallback |
| Python standalone no compatible | Pinear versión exacta, testar en CI |
| Pip wheels con deps nativas rotas | Usar manylinux2014, testar en container limpio |
| USB demasiado lento para modelos | Copiar a SSD primero, ejecutar desde ahi |
| Kokoro necesita torch que pesa 740MB | Investigar torch CPU slim o alternativa ONNX |

---

## Relación con scripts existentes

| Script existente | Que hace | Que falta |
|-----------------|----------|-----------|
| `savia-travel.sh` | Empaqueta workspace + perfil cifrado | NO incluye deps |
| `emergency-plan.sh` | Cachea Ollama + 1 modelo LLM | NO incluye Python, pip, whisper |
| `savia-travel-init.sh` | Bootstrap en maquina nueva | Asume internet disponible |

SPEC-017 completa el triangulo: travel (datos) + emergency (LLM) + sovereignty (todo).

---

## Presupuesto USB

| Tier | Contenido | Tamanio | USB minimo |
|------|-----------|---------|------------|
| 1 | Voz + LLM 3b | ~4 GB | 8 GB |
| 2 | + Claude Code + LLM 7b | ~9 GB | 16 GB |
| 3 | + LLM 14b + Whisper medium | ~20 GB | 32 GB |

Recomendacion: **USB 64 GB** para Tier 2 + SaviaOS booteable.

---

## Tier 4 — SaviaOS: Distro Linux booteable

### Concepto

USB con sistema operativo completo que arranca en cualquier PC x86_64.
Enciendes, eliges "boot from USB", y tienes Savia funcionando sin tocar
el disco duro del host. Zero instalación. Zero dependencia del SO existente.

### Base: Ubuntu minimal + live-build

Ubuntu minimal (server, sin GUI) como base porque:
- Kernel compatible con el 95% del hardware x86_64 (drivers incluidos)
- `live-build` es la herramienta oficial para crear ISOs/USBs live
- systemd para servicios (ollama, savia-voice daemon)
- Soporte UEFI + Legacy BIOS boot
- Comunidad enorme, hardware quirks documentados

### Componentes del live system

```
SaviaOS (USB booteable ~12-15 GB):
├── BOOT/                       ← GRUB + kernel + initramfs
│   ├── grub/grub.cfg           ← Menu: "SaviaOS" + "Boot from disk"
│   ├── vmlinuz                 ← Kernel Linux
│   └── initrd.img              ← Initramfs con drivers
├── LIVE/                       ← Sistema de ficheros comprimido
│   └── filesystem.squashfs     ← Ubuntu minimal + todo pre-instalado
├── SAVIA-USB/                  ← Datos Savia (igual que Tiers 1-3)
│   ├── workspace/
│   ├── models/
│   └── ...
└── persistence/                ← Particion para datos del usuario
    └── (ext4, creada en primer boot)
```

### Que incluye el squashfs

- Ubuntu 24.04 minimal (sin GUI, ~800 MB comprimido)
- Python 3.12 + venv con todas las deps de savia-voice
- Ollama pre-instalado como systemd service
- Node.js + Claude Code CLI
- ffmpeg, jq, git, curl, alsa-utils, pulseaudio
- Savia workspace en /opt/savia/
- Auto-login a usuario `savia` con bashrc que lanza Savia

### Boot sequence

```
1. BIOS/UEFI → USB → GRUB menu (3s timeout)
2. Kernel + initramfs → mount squashfs como overlay
3. systemd → start ollama.service + pulseaudio
4. Auto-login → .bashrc lanza Claude Code con savia-voice
5. "Hola, soy Savia. Estoy lista."
```

### Persistence

Primera particion: live system (read-only squashfs).
Segunda particion: ext4 para datos del usuario (profiles, memory, projects).
Los datos sobreviven reboots. Si el USB se pierde, solo se pierde lo que
no se haya sincronizado (backup cifrado a cloud cuando hay internet).

### Build script

`scripts/sovereignty-build-os.sh` — requiere Linux con live-build:

```
sovereignty-build-os.sh [--output savia-os.img] [--tier 2]
```

Fases:
1. `lb config` — configurar live-build (Ubuntu minimal, amd64)
2. Hooks: instalar Python, Ollama, Node, ffmpeg, jq
3. Hooks: copiar workspace, modelos, pip wheels
4. Hooks: configurar auto-login, systemd services, bashrc
5. `lb build` — generar imagen ISO/IMG
6. `dd` o Ventoy para flashear al USB

### Alternativa: Ventoy + ISO + datos

En vez de dd directo, usar Ventoy:
- Ventoy bootea cualquier ISO desde el USB
- Particion de datos separada con Savia completa
- Se puede tener SaviaOS + otras ISOs en el mismo USB
- El usuario puede actualizar la ISO sin perder datos

### Tamanio estimado

| Componente | Tamanio |
|------------|---------|
| Ubuntu minimal squashfs | ~800 MB |
| Python + venv (comprimido) | ~600 MB |
| Ollama + modelos (Tier 2) | ~5 GB |
| Whisper + Kokoro models | ~530 MB |
| Node.js + Claude Code | ~170 MB |
| Workspace + tools | ~100 MB |
| **Total squashfs** | **~7.2 GB** |
| Persistence partition | ~2-4 GB reservada |
| **Total USB** | **~10-12 GB** |

USB 64 GB recomendado (margen para persistence + datos del usuario).

### Implementación

#### Fase 4a — Prueba de concepto (1 sprint)

1. live-build con Ubuntu 24.04 minimal
2. Solo Python + Whisper + Ollama 3b (Tier 1)
3. Auto-login + bashrc con Claude Code -p (sin voz)
4. Testear en VM (QEMU) y en hardware real

#### Fase 4b — SaviaOS completo (1 sprint)

1. Anadir savia-voice daemon como systemd service
2. PulseAudio/PipeWire auto-config para mic+speaker
3. Persistence partition con firstboot wizard
4. Ventoy compatibility
5. Testear en 3+ hardware diferentes

### Riesgos adicionales

| Riesgo | Mitigacion |
|--------|-----------|
| Drivers de audio incompatibles | PulseAudio autodetect + fallback ALSA |
| UEFI Secure Boot | Firmar con shim (Ubuntu lo incluye) |
| GPU no soportada (nvidia) | CPU-only inference por defecto |
| USB 2.0 lento para squashfs | Copiar a RAM option en GRUB (si >8GB RAM) |
| Mantenimiento de la distro | Pin kernel + deps, rebuild trimestral |
