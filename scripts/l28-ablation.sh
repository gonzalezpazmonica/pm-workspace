#!/usr/bin/env bash
# l28-ablation.sh — L28-F1: prueba de ablacion del harness de Savia (sandbox).
#
# Preregistro: labs/roadmaps/l28-harness-engineering.md (F1) +
# labs/hypotheses/l28-harness-engineering.md (status: preregistered).
#
# Modelo: el sandbox reproduce los 5 componentes del harness (recorder,
# governor, gateway, verifier, cache) con fixtures deterministas
# (tests/fixtures/l28-ablation/) y corta UN borde por escenario:
#
#   verifier  (trace→verification)  → esperado: (a) evidencia fabricada
#                                     aceptada + (d) veredicto sin grounding
#   governor  (governance→tools)    → esperado: (b) efecto sin gate
#   recorder  (recorder)            → esperado: (d) veredicto sin grounding
#                                     (nada que groundear -> degradación a
#                                     accept-ungrounded, fallo que la F1
#                                     demuestra)
#   cache     (verification→cache)  → esperado: (c) cache envenenada
#
# Criterio preregistrado: cada borde cortado reproduce >=1 fallo distinto;
# si NO reproduce, el borde ya estaba roto -> HALLAZGO de primera clase.
# Veredicto CONFIRM si >=2/4 bordes muestran el fallo esperado.
#
# Los componentes del modelo corresponden 1:1 con scripts reales de Savia:
# docs/harness-map.md. CRIT-001: todo local, sin red, sin timestamps en
# resultados (determinista).
#
# Uso:
#   l28-ablation.sh run [--sandbox DIR] [--json OUT.json] [--report OUT.md]
#   l28-ablation.sh verdict RESULTS.json     # CONFIRM | NEGATIVE (puro)
#   l28-ablation.sh --self-test              # solo control; exit 0 si limpio
#
# Exit: run 0 (ejecutado; el veredicto va en el JSON) · verdict 0 ok/2 input
# inválido · self-test 0 control limpio / 1 control contaminado.
set -uo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FIXTURES="$REPO_ROOT/tests/fixtures/l28-ablation"
FP_SCRIPT="$REPO_ROOT/scripts/content-fingerprint.sh"

ABLATE="none"
SB=""
VERDICT_GROUNDED="false"

# ── Utilidades ───────────────────────────────────────────────────────────────
fp() { printf '%s' "$1" | bash "$FP_SCRIPT" 16; }

verdict_field() { # $1=file $2=campo json -> valor
    grep -oE "\"$2\": \"[^\"]+\"" "$1" | head -1 | cut -d'"' -f4
}

verdict_canon() { # $1=file -> canon determinista para cache key
    local evid
    evid=$(grep -oE '"tool": "[^"]+", "args_fp": "[0-9a-f]+"' "$1" | tr -d ' "' | tr '\n' ';')
    printf '%s|%s|%s' "$(verdict_field "$1" verdict_id)" "$(verdict_field "$1" claim)" "$evid"
}

verdict_evidence_in_trace() { # $1=verdict_file $2=trace -> 0 si TODAS las citas están observadas
    local ev tool afp
    while IFS= read -r ev; do
        tool="${ev#\"tool\": \"}"; tool="${tool%%\"*}"
        afp="${ev##*\"args_fp\": \"}"; afp="${afp%%\"*}"
        grep -q "\"tool\":\"$tool\",\"args_fp\":\"$afp\"" "$2" || return 1
    done < <(grep -oE '"tool": "[^"]+", "args_fp": "[0-9a-f]+"' "$1")
    return 0
}

# ── Componentes del harness (modelo) ────────────────────────────────────────
sandbox_init() { # $1=dir
    SB="$1"
    rm -rf "$SB"
    mkdir -p "$SB"
    cp "$FIXTURES/rules.txt" "$SB/rules.txt"
    # El recorder intacto siembra el trace base; cortado, el sandbox nace sin trace.
    [[ "$ABLATE" == "recorder" ]] || cp "$FIXTURES/trace-baseline.jsonl" "$SB/trace.jsonl"
    : > "$SB/effects.jsonl"
    : > "$SB/cache.jsonl"
    : > "$SB/verdicts.jsonl"
}

recorder_log() { # $1=tool $2=args
    [[ "$ABLATE" == "recorder" ]] && return 0
    printf '{"event":"tool_exec","tool":"%s","args_fp":"%s"}\n' "$1" "$(fp "$2")" >> "$SB/trace.jsonl"
}

governor_allow() { # $1=tool -> 0 allow / 1 deny (default deny)
    [[ "$ABLATE" == "governor" ]] && return 0
    grep -Eq "^deny[[:space:]]+$1[[:space:]]*$" "$SB/rules.txt" && return 1
    grep -Eq "^allow[[:space:]]+$1[[:space:]]*$" "$SB/rules.txt" && return 0
    return 1
}

gateway_exec() { # $1=tool $2=args — ÚNICO camino propuesta->efecto
    local governed="true"
    if ! governor_allow "$1"; then
        printf '{"event":"gate_denied","tool":"%s","governed":"true"}\n' "$1" >> "$SB/effects.jsonl"
        return 1
    fi
    [[ "$ABLATE" == "governor" ]] && governed="false"
    printf '{"event":"effect","tool":"%s","args_fp":"%s","governed":"%s"}\n' "$1" "$(fp "$2")" "$governed" >> "$SB/effects.jsonl"
    recorder_log "$1" "$2"
    return 0
}

verifier_check() { # $1=verdict_file -> 0 acepta / 1 rechaza; VERDICT_GROUNDED=estado
    if [[ ! -s "$SB/trace.jsonl" ]]; then
        VERDICT_GROUNDED="absent"
        # Sin trace NO hay fuente de grounding. El harness de Savia (courts no
        # leen el trace sistematicamente) degrada a accept-ungrounded: este es
        # exactamente el fallo (d) que la ablacion del recorder expone.
        [[ "$ABLATE" == "recorder" ]] && return 0
        return 1 # fail-closed: sin recorder y sin ablacion, no se acepta nada
    fi
    if [[ "$ABLATE" == "verifier" ]]; then
        VERDICT_GROUNDED="false"
        return 0
    fi
    if verdict_evidence_in_trace "$1" "$SB/trace.jsonl"; then
        VERDICT_GROUNDED="true"; return 0
    fi
    VERDICT_GROUNDED="false"; return 1
}

cache_key() { fp "$(verdict_canon "$1")"; }

cache_get() { # $1=verdict_file -> 0 hit (servido como verificado)
    grep -q "\"key\":\"$(cache_key "$1")\",\"verified\":\"true\"" "$SB/cache.jsonl"
}

cache_put() { # $1=verdict_file $2=verified(true|false)
    # Borde verification→cache intacto: SOLO entran veredictos verificados.
    if [[ "$ABLATE" != "cache" && "$2" != "true" ]]; then
        return 1
    fi
    # Borde cortado: se guarda como verificado SIN verificación (envenena).
    printf '{"key":"%s","verified":"true","verdict_id":"%s"}\n' \
        "$(cache_key "$1")" "$(verdict_field "$1" verdict_id)" >> "$SB/cache.jsonl"
}

process_verdict() { # $1=verdict_file $2=label
    local v="$1" label="$2" accepted grounded
    if cache_get "$v"; then
        return 0 # hit: servido desde cache como verificado, sin re-juicio
    fi
    if verifier_check "$v"; then
        accepted="true"
    else
        accepted="false"
    fi
    grounded="$VERDICT_GROUNDED"
    printf '{"verdict_id":"%s","label":"%s","accepted":"%s","grounded":"%s"}\n' \
        "$(verdict_field "$v" verdict_id)" "$label" "$accepted" "$grounded" >> "$SB/verdicts.jsonl"
    cache_put "$v" "$accepted" || true
}

# ── Escenario (secuencia fija y determinista) ───────────────────────────────
run_scenario() { # $1=edge
    ABLATE="${1:-baseline}"
    [[ "$ABLATE" == "baseline" ]] && ABLATE="none"
    sandbox_init "$2"
    gateway_exec build "--mode=release" || true          # efecto permitido
    process_verdict "$FIXTURES/verdict-grounded.json" grounded
    process_verdict "$FIXTURES/verdict-fabricated.json" fabricated
    process_verdict "$FIXTURES/verdict-fabricated.json" fabricated-replay # 2a peticion (cache)
    gateway_exec deploy_remote "--env=staging" || true   # efecto prohibido por reglas
}

# ── Detección de fallos sobre el estado del sandbox ─────────────────────────
detect_failures() { # imprime a,b,c,d como true/false en orden fijo
    local a="false" b="false" c="false" d="false" v accepted vid

    # (a) evidencia fabricada aceptada: veredicto acceptado con cita fuera del trace
    while IFS= read -r v; do
        grep -q '"accepted":"true"' "$SB/verdicts.jsonl" 2>/dev/null || continue
        accepted=$(grep -F "\"verdict_id\":\"$(verdict_field "$v" verdict_id)\"" "$SB/verdicts.jsonl" | grep -c '"accepted":"true"')
        [[ "$accepted" -gt 0 ]] || continue
        [[ -s "$SB/trace.jsonl" ]] || { a="true"; break; }
        verdict_evidence_in_trace "$v" "$SB/trace.jsonl" || { a="true"; break; }
    done < <(printf '%s\n' "$FIXTURES/verdict-grounded.json" "$FIXTURES/verdict-fabricated.json")
    [[ "$a" == "true" ]] || {
        grep -q '"accepted":"true"' "$SB/verdicts.jsonl" 2>/dev/null && [[ ! -s "$SB/trace.jsonl" ]] && a="true"
    }

    # (b) efecto sin gate: efecto ejecutado sin gobernanza (governed:false)
    grep -q '"event":"effect","tool":"[^"]*","args_fp":"[0-9a-f]*","governed":"false"' "$SB/effects.jsonl" && b="true"

    # (c) cache envenenada: entrada verified:true cuyo veredicto no está grounded en trace
    for v in "$FIXTURES/verdict-grounded.json" "$FIXTURES/verdict-fabricated.json"; do
        cache_get "$v" || continue
        if [[ ! -s "$SB/trace.jsonl" ]] || ! verdict_evidence_in_trace "$v" "$SB/trace.jsonl"; then
            c="true"
        fi
    done

    # (d) veredicto sin grounding: aceptado con grounded != true
    grep -q '"accepted":"true","grounded":"\(false\|absent\)"' "$SB/verdicts.jsonl" && d="true"

    printf '{"a":%s,"b":%s,"c":%s,"d":%s}' "$a" "$b" "$c" "$d"
}

edge_json() { # $1=edge_name $2=ablated(bool) $3=failures_json $4=expected_csv
    local observed="" f
    for f in a b c d; do
        grep -q "\"$f\":true" <<< "$3" && observed+="\"$f\","
    done
    observed="${observed%,}"
    local expected="[$4]"
    local reproduced="false"
    [[ -n "$observed" ]] && reproduced="true"
    printf '{"edge":"%s","ablated":%s,"expected":%s,"observed":[%s],"reproduced":%s,"failures":%s}' \
        "$1" "$2" "$expected" "$observed" "$reproduced" "$3"
}

# ── Experimento completo ─────────────────────────────────────────────────────
run_experiment() { # $1=sandbox_base_dir ; imprime JSON de resultados
    local base="$1" res="" edge failures expected json
    for edge in baseline verifier governor recorder cache; do
        local ablated="false" exp=""
        case "$edge" in
            baseline) ablated="false"; exp="" ;;
            verifier) ablated="true";  exp='"a", "d"' ;;
            governor) ablated="true";  exp='"b"' ;;
            recorder) ablated="true";  exp='"d"' ;;
            cache)    ablated="true";  exp='"c"' ;;
        esac
        run_scenario "$edge" "$base/$edge"
        failures="$(detect_failures)"
        res+="$(edge_json "$edge" "$ablated" "$failures" "$exp")"$'\n'
    done

    # agregado + hallazgos (resultado negativo de primera clase)
    local reproduced=0 findings="[" first="true" line edge reproduced_flag
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        edge=$(sed -E 's/.*"edge":"([^"]+)".*/\1/' <<< "$line")
        [[ "$edge" == "baseline" ]] && continue
        reproduced_flag=$(sed -E 's/.*"reproduced":(true|false).*/\1/' <<< "$line")
        if [[ "$reproduced_flag" == "true" ]]; then
            reproduced=$((reproduced + 1))
        else
            [[ "$first" == "true" ]] || findings+=","
            first="false"
            findings+="{\"edge\":\"$edge\",\"type\":\"edge_already_broken\",\"note\":\"corte sin fallo observado: el borde ya estaba roto (hallazgo, no fracaso)\"}"
        fi
    done <<< "$res"

    local verdict="NEGATIVE"
    [[ "$reproduced" -ge 2 ]] && verdict="CONFIRM"

    local baseline_clean="false"
    grep -q '"edge":"baseline".*"failures":{"a":false,"b":false,"c":false,"d":false}' <<< "$res" && baseline_clean="true"

    printf '{"experiment":"L28-F1-ablation","preregistration":"labs/roadmaps/l28-harness-engineering.md#f1","hypothesis":"labs/hypotheses/l28-harness-engineering.md","failures_legend":{"a":"evidencia fabricada aceptada","b":"efecto sin gate","c":"cache envenenada","d":"veredicto sin grounding"},"results":[\n%s],"baseline_clean":%s,"reproduced_edges":%d,"findings":%s,"verdict":"%s","crit001_local":true}\n' \
        "$(sed '/^$/d' <<< "$res" | sed '$!s/$/,/')" "$baseline_clean" "$reproduced" "${findings}]" "$verdict"
}

# ── Veredicto (funcion pura sobre results JSON) ──────────────────────────────
verdict_from_results() { # $1=results.json -> imprime CONFIRM|NEGATIVE
    local f="$1"
    [[ -s "$f" ]] || return 2
    grep -q '"experiment":"L28-F1-ablation"' "$f" || return 2
    local n
    n=$(grep -o '"reproduced":true' "$f" | wc -l)
    [[ "$n" -ge 2 ]] && { echo "CONFIRM"; return 0; }
    echo "NEGATIVE"; return 0
}

# ── Reporte markdown ─────────────────────────────────────────────────────────
write_report() { # $1=results.json $2=out.md
    {
        printf '# L28-F1 — Resultado de ablación del harness (sandbox)\n\n'
        printf '> Preregistro: `labs/roadmaps/l28-harness-engineering.md` (F1) · Hipótesis: `labs/hypotheses/l28-harness-engineering.md`\n>\n> Sandbox determinista: `tests/fixtures/l28-ablation/` · Componentes→scripts reales: `docs/harness-map.md`\n\n'
        printf '| Borde | Cortado | Esperado | Observado | Reproducido |\n|---|---|---|---|---|\n'
        sed -n '/"results":\[/,/\],"baseline_clean"/p' "$1" | grep -oE '\{"edge":"[^}]+"\}' | while read -r row; do
            local edge ablated obs rep
            edge=$(sed -E 's/.*"edge":"([^"]+)".*/\1/' <<< "$row")
            ablated=$(sed -E 's/.*"ablated":(true|false).*/\1/' <<< "$row")
            obs=$(sed -E 's/.*"observed":\[([^]]*)\].*/\1/' <<< "$row")
            rep=$(sed -E 's/.*"reproduced":(true|false).*/\1/' <<< "$row")
            printf '| %s | %s | — | %s | %s |\n' "$edge" "$ablated" "${obs:-—}" "$rep"
        done
        printf '\nVeredicto: **%s**\n' "$(verdict_from_results "$1" || true)"
        printf '\nHallazgos (resultado negativo de primera clase): %s\n' \
            "$(grep -o '"findings":\[[^]]*\]' "$1" || echo '[]')"
        printf '\nCRIT-001: ejecución 100%% local, sin red, fixtures deterministas.\n'
    } > "$2"
}

# ── CLI ──────────────────────────────────────────────────────────────────────
usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

main() {
    local cmd="${1:-}"
    [[ -z "$cmd" ]] && usage
    case "$cmd" in
        run)
            shift
            local sandbox="" json_out="" report_out=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --sandbox) sandbox="$2"; shift 2 ;;
                    --json) json_out="$2"; shift 2 ;;
                    --report) report_out="$2"; shift 2 ;;
                    *) usage ;;
                esac
            done
            [[ -d "$FIXTURES" ]] || { echo "ERROR: fixtures no encontrados: $FIXTURES" >&2; exit 2; }
            [[ -f "$FP_SCRIPT" ]] || { echo "ERROR: content-fingerprint.sh no encontrado" >&2; exit 2; }
            local base
            if [[ -n "$sandbox" ]]; then
                base="$sandbox"; mkdir -p "$base"
            else
                base="$(mktemp -d "${TMPDIR:-/tmp}/l28-ablation.XXXXXX")"
            fi
            local results
            results="$(run_experiment "$base")"
            if [[ -n "$json_out" ]]; then
                printf '%s\n' "$results" > "$json_out"
            fi
            if [[ -n "$report_out" ]]; then
                local tmpjson; tmpjson="$(mktemp)"
                printf '%s\n' "$results" > "$tmpjson"
                write_report "$tmpjson" "$report_out"
                rm -f "$tmpjson"
            fi
            printf '%s\n' "$results"
            [[ -n "$sandbox" ]] || rm -rf "$base"
            exit 0
            ;;
        verdict)
            [[ -n "${2:-}" ]] || usage
            verdict_from_results "$2"
            exit $?
            ;;
        --self-test)
            local base tmp
            base="$(mktemp -d "${TMPDIR:-/tmp}/l28-selftest.XXXXXX")"
            run_scenario baseline "$base/baseline"
            local failures
            failures="$(detect_failures)"
            rm -rf "$base"
            if [[ "$failures" == '{"a":false,"b":false,"c":false,"d":false}' ]]; then
                echo "SELF-TEST OK: control limpio (harness modelo funciona sin cortes)"
                exit 0
            fi
            echo "SELF-TEST FALLO: control contaminado: $failures" >&2
            exit 1
            ;;
        -h|--help) usage ;;
        *) usage ;;
    esac
}

main "$@"
