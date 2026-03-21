"""Pre-search query sanitization — strips PII, project names, internal data."""
import re, os


def _load_blocklist():
    """Build blocklist from workspace config (CLAUDE.local.md, profiles)."""
    terms = set()
    # Project names from projects/
    projects_dir = os.path.join(os.getcwd(), "projects")
    if os.path.isdir(projects_dir):
        for name in os.listdir(projects_dir):
            if os.path.isdir(os.path.join(projects_dir, name)):
                terms.add(name.lower())
    # Org URL from pm-config.local.md
    local_cfg = os.path.join(os.getcwd(), ".claude/rules/pm-config.local.md")
    if os.path.isfile(local_cfg):
        with open(local_cfg) as f:
            for line in f:
                m = re.match(r'^\s*\w+\s*=\s*"([^"]+)"', line)
                if m:
                    val = m.group(1)
                    if "azure" in val.lower() or "@" in val:
                        terms.add(val.lower())
    # Team member names from active profiles
    profiles_dir = os.path.join(os.getcwd(), ".claude/profiles/users")
    if os.path.isdir(profiles_dir):
        for slug in os.listdir(profiles_dir):
            terms.add(slug.lower())
            # Extract name from identity.md
            identity = os.path.join(profiles_dir, slug, "identity.md")
            if os.path.isfile(identity):
                with open(identity) as f:
                    for line in f:
                        if line.startswith("name:"):
                            name = line.split(":", 1)[1].strip().strip('"')
                            for part in name.split():
                                if len(part) > 2:
                                    terms.add(part.lower())
    return terms


def sanitize(query):
    """Remove PII and internal data from query. Returns (clean_query, warnings)."""
    warnings = []
    clean = query

    # Load dynamic blocklist
    blocklist = _load_blocklist()

    # Remove blocked terms (case-insensitive)
    for term in blocklist:
        if len(term) < 3:
            continue
        pattern = re.compile(re.escape(term), re.IGNORECASE)
        if pattern.search(clean):
            warnings.append(f"Removed internal term: '{term[:3]}...'")
            clean = pattern.sub("", clean)

    # Remove email addresses
    email_re = re.compile(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}')
    if email_re.search(clean):
        warnings.append("Removed email address")
        clean = email_re.sub("", clean)

    # Remove IP addresses (private ranges)
    ip_re = re.compile(
        r'(192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+)')
    if ip_re.search(clean):
        warnings.append("Removed internal IP")
        clean = ip_re.sub("", clean)

    # Remove Azure DevOps URLs (with or without protocol)
    az_re = re.compile(r'(https?://)?dev\.azure\.com/[^\s]+', re.IGNORECASE)
    if az_re.search(clean):
        warnings.append("Removed Azure DevOps URL")
        clean = az_re.sub("", clean)

    # Remove connection strings
    conn_re = re.compile(
        r'(Server|Data Source|jdbc|mongodb\+srv)=[^\s;]+', re.IGNORECASE)
    if conn_re.search(clean):
        warnings.append("Removed connection string")
        clean = conn_re.sub("", clean)

    # Collapse whitespace
    clean = re.sub(r'\s+', ' ', clean).strip()

    if not clean:
        warnings.append("Query empty after sanitization — aborting search")

    return clean, warnings


def classify_category(query):
    """Classify query into search category for TTL and engine selection."""
    q = query.lower()
    if any(w in q for w in ["cve", "vulnerability", "exploit", "advisory"]):
        return "cve"
    if any(w in q for w in ["version", "release", "update", "changelog"]):
        return "versions"
    if any(w in q for w in ["docs", "documentation", "api", "reference"]):
        return "docs"
    if any(w in q for w in ["paper", "arxiv", "research", "study"]):
        return "academic"
    if any(w in q for w in ["github", "stack overflow", "code", "library"]):
        return "code"
    return "general"
