---
version_bump: minor
section: Added
---

### Added

- SE-308 Savia Transcriptor: app de escritorio que captura reuniones automaticamente. Fork de VoiceFlow + VAD auto-trigger (silero-vad), screenshots periodicos (mss), transcripcion local (faster-whisper). Integracion con Savia via skill transcriptor-digest + comando /transcriptor.

### Fixed

- confidentiality-scan.sh: excluye decoradores `@server.` (falso positivo de email en server.py del fork).
