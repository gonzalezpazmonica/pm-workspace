#!/usr/bin/env bash
# savia-hub-sync.sh — status / push / pull / flight de SaviaHub (skill savia-hub-sync)
# Uso: bash scripts/savia-hub-sync.sh {status | push [--yes] [--force] | pull [--force] | flight on|off}
# Exit: 0 ok · 1 uso · 2 hub no inicializado · 3 sin remote · 4 modo vuelo activo
#       5 remote inalcanzable · 6 fichero local rastreado (fuga) · 7 remote por delante · 8 conflicto
set -uo pipefail

HUB="${SAVIA_HUB_PATH:-$HOME/.savia-hub}"
CFG="$HUB/.savia-hub-config.md"
QUEUE="$HUB/.sync-queue.jsonl"
LOCAL_ONLY=(.savia-hub-config.md .sync-queue.jsonl)
NET_TIMEOUT="${SAVIA_HUB_NET_TIMEOUT:-20}"
export GIT_TERMINAL_PROMPT=0

die() { echo "ERROR: $2" >&2; exit "$1"; }
g() { git -C "$HUB" "$@"; }

set_cfg() {  # set_cfg clave valor — crea la config mínima si falta
  [ -f "$CFG" ] || printf -- '---\nversion: 1\nflight_mode: false\nlast_sync: null\n---\n' > "$CFG"
  if grep -q "^$1:" "$CFG"; then sed -i "s|^$1:.*|$1: $2|" "$CFG"
  else sed -i "1a $1: $2" "$CFG"; fi
}
has_remote() { g remote get-url origin >/dev/null 2>&1; }
in_flight() { grep -q '^flight_mode: true' "$CFG" 2>/dev/null; }
net_fetch() { timeout "$NET_TIMEOUT" git -C "$HUB" fetch -q origin 2>/dev/null; }
remote_branch() { g rev-parse --verify -q "refs/remotes/origin/$BR" >/dev/null; }
require_remote() {  # require_remote <force>: remote, modo vuelo y red, en ese orden
  has_remote || die 3 "Remote no configurado — solo modo local. Nada que sincronizar."
  if in_flight && [ "$1" != 1 ]; then die 4 "Modo vuelo activo: sync bloqueado (flight off o --force)"; fi
  net_fetch || die 5 "Remote inalcanzable ($(g remote get-url origin)). Sin cambios en el remote; usa flight on si sigues sin red."
}
mark_synced() { set_cfg last_sync "\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""; [ -f "$QUEUE" ] && : > "$QUEUE"; return 0; }

g rev-parse --verify -q HEAD >/dev/null 2>&1 || die 2 "SaviaHub no inicializado en $HUB (bash scripts/savia-hub-init.sh)"
BR="$(g branch --show-current)"; BR="${BR:-main}"
CMD="${1:-}"; shift || true
YES=0; FORCE=0
for a in "$@"; do
  case "$a" in --yes) YES=1 ;; --force) FORCE=1 ;; on|off) MODE="$a" ;; *) die 1 "argumento desconocido: $a" ;; esac
done

case "$CMD" in
status)
  pending=$(g status --porcelain | wc -l)
  echo "Ruta:        $HUB"
  echo "Flight mode: $(in_flight && echo ON || echo OFF)"
  echo "Last sync:   $(sed -n 's/^last_sync: *//p' "$CFG" 2>/dev/null | tr -d '"')"
  echo "Clientes:    $(find "$HUB/clients" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l) · Users: $(find "$HUB/users" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
  echo "Pendientes:  $pending cambios sin commit"
  if ! has_remote; then echo "Sync:        solo local (sin remote configurado)"
  elif ! net_fetch; then echo "Sync:        remote inalcanzable ($(g remote get-url origin)) — estado desconocido"
  elif ! remote_branch; then echo "Sync:        remote sin rama $BR — todo pendiente de push"
  else
    ahead=$(g rev-list --count "origin/$BR..HEAD"); behind=$(g rev-list --count "HEAD..origin/$BR")
    if [ "$ahead$behind$pending" = 000 ]; then echo "Sync:        sincronizado con origin/$BR"
    else echo "Sync:        $ahead commits por subir, $behind por bajar, $pending sin commit"; fi
  fi ;;
push)
  require_remote "$FORCE"
  for f in "${LOCAL_ONLY[@]}"; do
    [ -z "$(g ls-files -- "$f")" ] || die 6 "$f está rastreado por git: contiene config local y no debe subir. git rm --cached $f"
  done
  if remote_branch; then
    [ "$(g rev-list --count "HEAD..origin/$BR")" -eq 0 ] || die 7 "El remote tiene cambios nuevos: ejecuta pull antes de push"
    files=$( { g diff --name-only "origin/$BR..HEAD"; g status --porcelain | cut -c4-; } | sort -u)
  else
    files=$( { g ls-tree -r --name-only HEAD; g status --porcelain | cut -c4-; } | sort -u)
  fi
  if [ -z "$files" ]; then echo "Nada que sincronizar"; mark_synced; exit 0; fi
  echo "Se van a subir $(echo "$files" | wc -l) ficheros a origin/$BR:"; echo "$files" | sed 's/^/  /'
  if [ "$YES" != 1 ]; then echo "Vista previa: nada subido. Confirma con el PM y repite con --yes."; exit 0; fi
  g add -A
  if ! g diff --cached --quiet; then
    g commit -q -m "[savia-hub] sync: $(g diff --cached --name-only | wc -l) ficheros" || die 1 "git commit falló"
  fi
  timeout "$NET_TIMEOUT" git -C "$HUB" push -q -u origin "HEAD:refs/heads/$BR" 2>&1 \
    || die 5 "Push fallido: remote inalcanzable o rechazado. Commit local conservado."
  mark_synced; echo "Sincronizado: origin/$BR al día" ;;
pull)
  require_remote "$FORCE"
  if ! remote_branch; then echo "Remote sin rama $BR: nada que bajar"; mark_synced; exit 0; fi
  if [ "$(g rev-list --count "HEAD..origin/$BR")" -eq 0 ]; then echo "Ya actualizado"; mark_synced; exit 0; fi
  if [ -n "$(g status --porcelain)" ]; then
    g add -A && g commit -q -m "[savia-hub] local: cambios previos al pull" || die 1 "no se pudo commitear lo local"
  fi
  if ! g rebase -q "origin/$BR" >/dev/null 2>&1; then
    conflicts=$(g diff --name-only --diff-filter=U)
    g rebase --abort || echo "AVISO: rebase --abort falló; revisa $HUB a mano" >&2
    echo "Conflicto en:"; echo "$conflicts" | sed 's/^/  /'
    die 8 "Conflicto: NUNCA se auto-resuelve. Rebase abortado; tu versión local intacta. El PM decide (local, remoto o merge manual)."
  fi
  mark_synced; echo "Actualizado desde origin/$BR" ;;
flight)
  case "${MODE:-}" in
  on)  set_cfg flight_mode true; echo "Modo vuelo activado: push y pull bloqueados" ;;
  off) set_cfg flight_mode false; echo "Modo vuelo desactivado; no se ha sincronizado nada: ejecuta pull y luego push." ;;
  *) die 1 "uso: flight on|off" ;;
  esac ;;
*) die 1 "uso: savia-hub-sync.sh {status | push [--yes] [--force] | pull [--force] | flight on|off}" ;;
esac
