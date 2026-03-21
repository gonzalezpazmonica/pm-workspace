"""Detect context gaps in user queries that could benefit from web search.

A gap is a question about external/public information that pm-workspace
doesn't have locally: library versions, API docs, CVEs, best practices.
"""
import re

# Patterns that signal a gap in context (external knowledge needed)
GAP_PATTERNS = [
    # Version/release questions
    (r'(?:qué|cuál|what)\s+(?:versión|version|release)', 'versions',
     'version or release info'),
    (r'(?:última|latest|current|actual)\s+(?:versión|version)', 'versions',
     'latest version check'),
    # Documentation gaps
    (r'(?:cómo|how)\s+(?:se\s+)?(?:configura|configure|setup|instala|install)',
     'docs', 'configuration/setup docs'),
    (r'(?:cuál|what)\s+(?:es\s+)?(?:la\s+)?(?:sintaxis|syntax|api|endpoint)',
     'docs', 'API/syntax reference'),
    (r'(?:documentación|documentation|docs)\s+(?:de|for|about)',
     'docs', 'documentation lookup'),
    # Security/CVE gaps
    (r'(?:vulnerab|cve|exploit|advisory|security\s+issue)', 'cve',
     'security advisory check'),
    (r'(?:es\s+)?(?:vulnerable|seguro|safe|secure)\s', 'cve',
     'security assessment'),
    # Technology comparison
    (r'(?:mejor|best|recommend|recomienda|alternativ)', 'general',
     'technology comparison'),
    (r'(?:diferencia|difference|vs|versus|comparar|compare)', 'general',
     'technology comparison'),
    # Error/issue lookup
    (r'(?:error|exception|stack\s*trace|traceback)\s+(?:de|from|in)\s+\w+',
     'code', 'error lookup'),
    (r'(?:issue|bug|problema)\s+(?:con|with|in)\s+(?:la\s+)?(?:librería|library|package)',
     'code', 'library issue lookup'),
    # Framework/library questions
    (r'(?:soporte|support|compatible)\s+(?:para|for|with)', 'docs',
     'compatibility check'),
    (r'(?:deprecated|obsolet|end.of.life|eol)', 'versions',
     'deprecation check'),
]

# Signals that the query is internal (NOT a web search candidate)
INTERNAL_SIGNALS = [
    r'^/\w+',                          # slash command
    r'(?:sprint|backlog|pbi|task)\s',  # PM terminology
    r'(?:equipo|team|capacity)',        # team management
    r'(?:proyecto|project)\s+\w+',     # project reference
    r'(?:commit|push|merge|pr|branch)', # git operations
]


def detect_gap(query):
    """Analyze query for context gaps that web search could resolve.

    Returns:
        dict with keys: needs_search, category, reason, confidence
        or None if no gap detected
    """
    q = query.strip().lower()

    # Check for internal signals first (no web search needed)
    for pattern in INTERNAL_SIGNALS:
        if re.search(pattern, q, re.IGNORECASE):
            return None

    # Check gap patterns
    for pattern, category, reason in GAP_PATTERNS:
        if re.search(pattern, q, re.IGNORECASE):
            return {
                'needs_search': True,
                'category': category,
                'reason': reason,
                'confidence': 0.7,
                'query': query.strip(),
            }

    # Heuristic: questions with "?" about external tech
    if '?' in q and not any(re.search(p, q) for p in INTERNAL_SIGNALS):
        tech_words = re.findall(
            r'\b(?:react|angular|vue|django|flask|spring|dotnet|'
            r'express|nextjs|nuxt|laravel|rails|rust|go|kotlin|'
            r'swift|terraform|docker|kubernetes|k8s|aws|azure|gcp|'
            r'postgresql|mongodb|redis|kafka|rabbitmq|elasticsearch|'
            r'graphql|grpc|openapi|swagger|oauth|jwt|cors|webpack|'
            r'vite|eslint|prettier|jest|pytest|xunit|nunit)\b', q)
        if tech_words:
            return {
                'needs_search': True,
                'category': 'docs',
                'reason': f'question about external tech: {", ".join(tech_words)}',
                'confidence': 0.5,
                'query': query.strip(),
            }

    return None


def format_suggestion(gap):
    """Format a search suggestion for the user."""
    if not gap:
        return None
    cat = gap['category']
    conf = int(gap['confidence'] * 100)
    return (
        f"🌐 Detectado gap de contexto: {gap['reason']}\n"
        f"   Categoría: {cat} · Confianza: {conf}%\n"
        f"   ¿Busco en la web? → /web-research \"{gap['query']}\""
    )
