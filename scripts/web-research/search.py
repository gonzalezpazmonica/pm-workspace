"""Search orchestrator — cache → SearxNG (auto-start) → Claude WebSearch.

3-layer search with automatic fallback:
  Layer 1: Local cache (offline, 0 tokens)
  Layer 2: SearxNG via Docker (auto-started, private)
  Layer 3: Claude Code WebSearch/WebFetch (built-in tools)
"""
import importlib

cache = importlib.import_module('scripts.web-research.cache')
sanitizer = importlib.import_module('scripts.web-research.sanitizer')
rerank_mod = importlib.import_module('scripts.web-research.rerank')
searxng = importlib.import_module('scripts.web-research.searxng')

# Engine presets by category
ENGINE_PRESETS = {
    'docs': 'google,duckduckgo,bing,brave',
    'code': 'github,stackoverflow,gitlab',
    'cve': 'google,duckduckgo',
    'academic': 'arxiv,google scholar,pubmed,semantic scholar',
    'versions': 'google,duckduckgo,bing',
    'general': 'google,duckduckgo,bing,brave',
}


def search(query, category=None, max_results=5, cache_only=False):
    """Execute search with 3-layer fallback.

    Args:
        query: Raw search query (will be sanitized)
        category: Optional category override
        max_results: Maximum results
        cache_only: If True, only check cache (offline mode)

    Returns:
        dict: {results, source, category, cached, sanitized_query, warnings}
    """
    # 1. Sanitize
    clean, warnings = sanitizer.sanitize(query)
    if not clean:
        return {
            'results': [], 'source': 'aborted', 'category': None,
            'cached': False, 'sanitized_query': '',
            'warnings': warnings,
        }

    # 2. Classify
    cat = category or sanitizer.classify_category(clean)
    engines = ENGINE_PRESETS.get(cat, ENGINE_PRESETS['general'])

    # 3. Cache check
    cached = cache.get(clean, category=cat)
    if cached:
        results = cached.get('results', [])
        return {
            'results': results, 'source': 'cache', 'category': cat,
            'cached': True, 'sanitized_query': clean,
            'warnings': warnings,
            'cache_info': cached.get('_cache', {}),
        }

    if cache_only:
        return {
            'results': [], 'source': 'cache-miss', 'category': cat,
            'cached': False, 'sanitized_query': clean,
            'warnings': warnings + ['Cache-only mode: no online search'],
        }

    # 4. SearxNG (auto-start Docker if needed)
    results = searxng.search(clean, engines=engines, max_results=max_results*2)

    if results:
        # Rerank
        ranked = rerank_mod.rerank(clean, results, top_k=max_results)
        # Cache
        cache.put(clean, ranked, category=cat, source='searxng')
        return {
            'results': ranked, 'source': 'searxng', 'category': cat,
            'cached': False, 'sanitized_query': clean,
            'warnings': warnings,
        }

    # 5. Fallback: signal caller to use Claude WebSearch
    return {
        'results': None, 'source': 'needs-websearch', 'category': cat,
        'cached': False, 'sanitized_query': clean,
        'warnings': warnings + ['SearxNG unavailable, use WebSearch tool'],
    }
