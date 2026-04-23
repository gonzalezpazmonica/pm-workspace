---
id: SE-056
title: SE-056 — Python SBOM + virtualenv enforcement
status: IMPLEMENTED
origin: output/audit-arquitectura-20260420.md §4.8
author: Savia
priority: Media
effort: M 8h
gap_link: 5 py scripts sin requirements.txt, reproducibilidad frágil
approved_at: "2026-04-22"
applied_at: "2026-04-22"
batches: [23]
expires: "2026-05-20"
---

# SE-056 — Python SBOM + virtualenv enforcement

## Purpose

pm-workspace tiene N scripts Python (`scripts/*.py`, `projects/*/*.py`) con imports 3P (sentence_transformers, numpy, opencv, faiss, piper, etc.) sin `requirements.txt` declarativo. Resultado: "funciona en mi máquina" + drift silencioso cuando alguien sube una nueva dep sin registrarla.

Gap identificado en audit 2026-04-20 §4.8.

## Scope (Slice 1)

`scripts/python-sbom.sh`:
- Escanea imports en `scripts/*.py` + `projects/*/*.py`
- Filtra stdlib (lista curada)
- Cruza con `requirements.txt` si existe
- Reporta missing vs declared
- Modo `--check` para CI (exit 1 si drift)
- Modo `--venv` para instrucciones virtualenv aislado (`.savia-venv`)

## Acceptance criteria

- Script `--help`, `--json`, `--check`, `--venv`, exit 0/1/2
- Tests BATS ≥ 15, score ≥ 80
- Detecta 3P imports reales en repo actual
- Instrucciones venv referencian `$HOME/.savia-venv`
- Zero egress

## Slicing

- Slice 1 (esta PR): audit + report
- Slice 2: auto-generar requirements.txt desde imports detectados
- Slice 3: CI enforcement (fail PR si drift)
- Slice 4: venv bootstrap automatizado en `readiness-check.sh`

## Referencias

- audit-arquitectura-20260420.md §4.8
- docs/rules/domain/security-scanners.md (catálogo)
