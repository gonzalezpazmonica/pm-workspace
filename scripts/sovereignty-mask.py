#!/usr/bin/env python3
"""
sovereignty-mask.py — Reversible data masking for cloud LLM processing

Replaces sensitive entities (names, companies, projects, IPs, etc.) with
consistent fictional substitutes. Maintains a mapping table so the output
from the LLM can be unmasked back to real values.

Usage:
  echo "text" | python3 sovereignty-mask.py mask --glossary path/to/GLOSSARY.md
  echo "text" | python3 sovereignty-mask.py unmask --map path/to/mask-map.json

The mask-map.json is stored locally (N4, never in git) and contains the
bidirectional mapping between real and masked values.

AUDITABILITY: every mask/unmask operation is logged to mask-audit.jsonl
"""

import sys
import json
import re
import os
import hashlib
from datetime import datetime, timezone
from pathlib import Path

# --- Fictional replacement pools ---
# These are consistent: same input always maps to same output within a session
PERSON_POOL = [
    "Alice Chen", "Bob Martinez", "Carol Smith", "David Kim",
    "Elena Rossi", "Frank Weber", "Grace Liu", "Henry Jones",
    "Irene Patel", "James Wilson", "Karen Brown", "Leo Garcia",
    "Maria Santos", "Nick Taylor", "Olivia Moore", "Peter Clark",
    "Quinn Adams", "Rosa Diaz", "Sam Cooper", "Tina Fischer",
    "Uma Sharma", "Victor Ruiz", "Wendy Park", "Xavier Dupont",
    "Yuki Tanaka", "Zara Ahmed", "Andre Blanc", "Beth Morgan",
    "Chris Novak", "Dana Reeves", "Erik Holm", "Fiona West",
]
COMPANY_POOL = [
    "Acme Corp", "Zenith Industries", "Nova Systems", "Apex Global",
    "Stellar Tech", "Orion Labs", "Pinnacle Inc", "Vertex Solutions",
    "Atlas Group", "Summit Corp", "Beacon Ltd", "Crest Dynamics",
]
PROJECT_POOL = [
    "Project Aurora", "Project Beacon", "Project Catalyst",
    "Project Delta", "Project Echo", "Project Falcon",
    "Project Genesis", "Project Horizon", "Project Iris",
]
IP_POOL = [
    "198.51.100.10", "198.51.100.20", "198.51.100.30",  # RFC 5737 TEST-NET-2
    "203.0.113.10", "203.0.113.20", "203.0.113.30",      # RFC 5737 TEST-NET-3
]
SYSTEM_POOL = [
    "CoreSystem", "DataHub", "FlowEngine", "PlatformX",
    "ServiceBridge", "TaskRunner", "WorkBench", "SyncModule",
    "NetRelay", "LogStream", "CacheGrid", "AuthGate",
    "QueueMaster", "IndexCore", "MetricHub", "ConfigVault",
]


def load_glossary(glossary_path):
    """Load project glossary and extract entities by category."""
    entities = {
        "person": [], "company": [], "project": [],
        "system": [], "ip": [], "environment": [],
        "stakeholder_role": [], "acronym": [],
    }
    if not glossary_path or not os.path.exists(glossary_path):
        return entities

    current_category = None
    with open(glossary_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith('## '):
                header = line[3:].strip().lower()
                for cat in entities:
                    if cat in header or header in cat:
                        current_category = cat
                        break
            elif line.startswith('- ') and current_category:
                # Extract term before | or : separator
                term = line[2:].split('|')[0].split(':')[0].strip()
                term = re.sub(r'\*\*([^*]+)\*\*', r'\1', term)  # Remove bold
                if term and len(term) > 1:
                    entities[current_category].append(term)
    return entities


def build_mask_map(entities, existing_map=None):
    """Build deterministic mapping from real -> masked values."""
    mask_map = existing_map or {}
    reverse_map = {v: k for k, v in mask_map.items()}

    pool_index = {
        "person": 0, "company": 0, "project": 0,
        "system": 0, "ip": 0,
    }
    pools = {
        "person": PERSON_POOL, "company": COMPANY_POOL,
        "project": PROJECT_POOL, "system": SYSTEM_POOL,
        "ip": IP_POOL,
    }

    for category, terms in entities.items():
        pool = pools.get(category)
        if not pool:
            continue
        for term in terms:
            if term not in mask_map:
                idx = pool_index.get(category, 0) % len(pool)
                masked = pool[idx]
                # Ensure no collision
                while masked in reverse_map:
                    idx += 1
                    if idx > len(pool) * 2:
                        # Generate deterministic unique fallback via hash
                        masked = f"{pool[0]}-{idx}"
                        while masked in reverse_map:
                            idx += 1
                            masked = f"{pool[0]}-{idx}"
                        break
                    masked = pool[idx % len(pool)]
                mask_map[term] = masked
                reverse_map[masked] = term
                pool_index[category] = idx + 1

    # Auto-detect IPs in text and mask them
    return mask_map


def mask_ips_in_text(text, mask_map):
    """Find and mask private IPs not already in the map."""
    ip_pattern = r'\b(192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+)\b'
    ip_idx = len([k for k in mask_map if re.match(r'\d+\.', k)])

    def replace_ip(match):
        nonlocal ip_idx
        real_ip = match.group(0)
        if real_ip not in mask_map:
            masked = IP_POOL[ip_idx % len(IP_POOL)]
            mask_map[real_ip] = masked
            ip_idx += 1
        return mask_map[real_ip]

    return re.sub(ip_pattern, replace_ip, text)


def mask_text(text, mask_map):
    """Apply masking — longest match first to avoid partial replacements."""
    # Sort by length descending (mask "Juan Garcia Lopez" before "Juan Garcia")
    sorted_terms = sorted(mask_map.keys(), key=len, reverse=True)
    import re as _re
    for real_term in sorted_terms:
        pattern = _re.compile(_re.escape(real_term), _re.IGNORECASE)
        text = pattern.sub(mask_map[real_term], text)
    # Also mask auto-detected IPs
    text = mask_ips_in_text(text, mask_map)
    return text


def unmask_text(text, mask_map):
    """Reverse masking — replace masked values with real ones."""
    reverse = {v: k for k, v in mask_map.items()}
    sorted_masked = sorted(reverse.keys(), key=len, reverse=True)
    for masked_term in sorted_masked:
        if masked_term in text:
            text = text.replace(masked_term, reverse[masked_term])
    return text


def audit_log(operation, input_preview, map_size, output_path):
    """Log operation for auditability."""
    audit_dir = os.environ.get('CLAUDE_PROJECT_DIR', os.getcwd())
    audit_file = os.path.join(audit_dir, 'output', 'data-sovereignty-validation', 'mask-audit.jsonl')
    os.makedirs(os.path.dirname(audit_file), exist_ok=True)
    entry = {
        "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "operation": operation,
        "input_chars": len(input_preview),
        "entities_mapped": map_size,
        "map_file": str(output_path) if output_path else "none",
    }
    try:
        with open(audit_file, 'a', encoding='utf-8') as f:
            f.write(json.dumps(entry) + '\n')
    except Exception:
        pass


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ('-h', '--help'):
        print("Usage:")
        print("  echo 'text' | python3 sovereignty-mask.py mask --glossary GLOSSARY.md [--map map.json]")
        print("  echo 'text' | python3 sovereignty-mask.py unmask --map map.json")
        print("  python3 sovereignty-mask.py show-map --map map.json")
        sys.exit(0)

    action = sys.argv[1]
    glossary_path = None
    map_path = None

    # Parse args
    i = 2
    while i < len(sys.argv):
        if sys.argv[i] == '--glossary' and i + 1 < len(sys.argv):
            glossary_path = sys.argv[i + 1]; i += 2
        elif sys.argv[i] == '--map' and i + 1 < len(sys.argv):
            map_path = sys.argv[i + 1]; i += 2
        else:
            i += 1

    # Default map path
    if not map_path:
        project_dir = os.environ.get('CLAUDE_PROJECT_DIR', os.getcwd())
        map_path = os.path.join(project_dir, 'config.local', 'savia-shield', 'mask-map.json')

    if action == 'mask':
        text = sys.stdin.read()
        existing_map = {}
        if os.path.exists(map_path):
            with open(map_path, 'r', encoding='utf-8') as f:
                existing_map = json.load(f)

        entities = load_glossary(glossary_path)
        mask_map = build_mask_map(entities, existing_map)
        masked_text = mask_text(text, mask_map)

        # Save map
        os.makedirs(os.path.dirname(map_path), exist_ok=True)
        old_umask = os.umask(0o177)
        tmp_path = map_path + '.tmp'
        with open(tmp_path, 'w', encoding='utf-8') as f:
            json.dump(mask_map, f, indent=2, ensure_ascii=False)
        os.replace(tmp_path, map_path)  # atomic rename
        os.umask(old_umask)
        os.chmod(map_path, 0o600)

        audit_log('mask', text[:200], len(mask_map), map_path)
        print(masked_text)

    elif action == 'unmask':
        text = sys.stdin.read()
        if not os.path.exists(map_path):
            print("ERROR: mask-map.json not found at", map_path, file=sys.stderr)
            print(text)  # Return original if no map
            sys.exit(1)

        with open(map_path, 'r', encoding='utf-8') as f:
            mask_map = json.load(f)

        unmasked_text = unmask_text(text, mask_map)
        audit_log('unmask', text[:200], len(mask_map), map_path)
        print(unmasked_text)

    elif action == 'show-map':
        if os.path.exists(map_path):
            with open(map_path, 'r', encoding='utf-8') as f:
                mask_map = json.load(f)
            print(f"Mask map: {len(mask_map)} entries")
            print(f"Location: {map_path}")
            # SEC-022: Only show fictional names by default, real names need --reveal
            reveal = '--reveal' in sys.argv
            print("---")
            if reveal:
                print("WARNING: showing real entity names")
                for real, masked in sorted(mask_map.items()):
                    print(f"  {real:30s} -> {masked}")
            else:
                for real, masked in sorted(mask_map.items()):
                    redacted = real[0] + '*' * (len(real)-1) if len(real) > 1 else '*'
                    print(f"  {redacted:30s} -> {masked}")
                print("\nUse --reveal to show real entity names")
        else:
            print("No mask map found at", map_path)

    else:
        print(f"Unknown action: {action}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
