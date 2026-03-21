"""Format web research results for context injection with inline citations."""
import time


def format_results(query, results, cache_info=None, max_tokens=500):
    """Format search results as markdown context block with citations.

    Args:
        query: Original search query
        results: List of {title, url, snippet} dicts
        cache_info: Optional {hit: bool, age_hours: float}
        max_tokens: Approximate token budget (4 chars ≈ 1 token)

    Returns:
        (context_block, citations_footer)
    """
    if not results:
        return "", ""

    max_chars = max_tokens * 4
    cache_tag = ""
    if cache_info and cache_info.get("hit"):
        hrs = cache_info.get("age_hours", 0)
        cache_tag = f" · Cache: hit ({hrs}h ago)"
    else:
        cache_tag = " · Cache: miss"

    header = (
        f'## Web Research: "{query}"\n'
        f'Resultados: {len(results)}{cache_tag}\n'
    )
    char_count = len(header)

    numbered = []
    citations = []
    for i, r in enumerate(results, 1):
        title = r.get("title", "Sin título")
        url = r.get("url", "")
        snippet = r.get("snippet", r.get("content", ""))
        # Truncate snippet to ~3 lines
        if len(snippet) > 200:
            snippet = snippet[:197] + "..."

        entry = f'{i}. **{title}**\n   {snippet}\n'
        citation = f'[web:{i}] {url}'

        entry_len = len(entry)
        if char_count + entry_len > max_chars and numbered:
            break
        numbered.append(entry)
        citations.append(citation)
        char_count += entry_len

    context = header + "\n" + "\n".join(numbered)
    footer = "📚 " + " · ".join(citations)

    return context, footer


def format_citation_ref(index):
    """Return inline citation marker."""
    return f"[web:{index}]"


def format_no_results(query, reason=""):
    """Format message when search returns no results."""
    msg = f'⚠️ Web research: sin resultados para "{query}"'
    if reason:
        msg += f"\n   Motivo: {reason}"
    msg += "\n   Intenta reformular la búsqueda o usa /web-research manualmente."
    return msg


def format_cache_stats(stats):
    """Format cache statistics for display."""
    lines = [
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        "📦 Web Research Cache",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        f"  Entradas ................. {stats['entries']}",
        f"  Tamaño ................... {stats['size_mb']} MB / {stats['max_mb']} MB",
    ]
    if stats.get("categories"):
        lines.append("  Categorías:")
        for cat, count in sorted(stats["categories"].items()):
            lines.append(f"    {cat}: {count}")
    lines.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    return "\n".join(lines)
