#!/usr/bin/env bats
# tests/test-ethical-principles-iah-coverage.bats
# SPEC-187 — Alineacion principios eticos Savia con marco IAH
# Verifica cobertura de los 4 principios nuevos §14-§17 y refinamientos §3/§4.

@test "savia-ethical-principles contiene 17 principios numerados" {
  count=$(grep -cE '^## [0-9]+\.' docs/rules/domain/savia-ethical-principles.md)
  [ "$count" -ge 17 ]
}

@test "principio 14 cubre sostenibilidad" {
  grep -A 30 '^## 14\.' docs/rules/domain/savia-ethical-principles.md | grep -qiE 'sostenibilidad|huella|carbono|energia'
}

@test "principio 15 cubre pluralismo cultural" {
  grep -A 30 '^## 15\.' docs/rules/domain/savia-ethical-principles.md | grep -qiE 'lengua|cultura|identidad local|pluralismo'
}

@test "principio 16 cubre robustez tecnica" {
  grep -A 30 '^## 16\.' docs/rules/domain/savia-ethical-principles.md | grep -qiE 'robustez|alucina|prompt injection|envenenamiento'
}

@test "principio 17 cubre explicabilidad como derecho" {
  grep -A 30 '^## 17\.' docs/rules/domain/savia-ethical-principles.md | grep -qiE 'explicabilidad|caja negra|lenguaje accesible'
}

@test "principio 3 menciona dominios criticos salud-justicia-empleo" {
  grep -A 50 '^## 3\.' docs/rules/domain/savia-ethical-principles.md | grep -qE 'salud.*justicia.*empleo|salud, justicia, empleo'
}

@test "principio 4 incluye obligacion activa de auditar sesgos" {
  grep -A 50 '^## 4\.' docs/rules/domain/savia-ethical-principles.md | grep -qiE 'obligacion activa|auditar|auditoria periodica'
}

@test "tabla de integracion incluye 17 principios" {
  count=$(grep -cE '^\| §[0-9]+' docs/rules/domain/savia-ethical-principles.md)
  [ "$count" -ge 17 ]
}

@test "lineas rojas siguen siendo 5 (no se anaden)" {
  count=$(grep -cE '^\| \*\*L[0-9]\*\*' docs/rules/domain/savia-ethical-principles.md)
  [ "$count" -eq 5 ]
}
