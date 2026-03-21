"""Heuristic reranker for web search results — zero dependencies."""
import re

# Authoritative domains get a boost
AUTHORITY_DOMAINS = {
    "docs.microsoft.com": 0.15, "learn.microsoft.com": 0.15,
    "developer.mozilla.org": 0.15, "docs.python.org": 0.15,
    "docs.oracle.com": 0.12, "docs.aws.amazon.com": 0.12,
    "cloud.google.com": 0.12, "docs.github.com": 0.12,
    "stackoverflow.com": 0.10, "github.com": 0.08,
    "arxiv.org": 0.12, "pubmed.ncbi.nlm.nih.gov": 0.12,
    "nvd.nist.gov": 0.15, "cve.mitre.org": 0.15,
    "owasp.org": 0.12, "cheatsheetseries.owasp.org": 0.12,
}


def _keyword_score(query, text):
    """Score based on keyword overlap between query and text."""
    if not text:
        return 0
    q_words = set(re.findall(r'\w{3,}', query.lower()))
    t_words = set(re.findall(r'\w{3,}', text.lower()))
    if not q_words:
        return 0
    overlap = len(q_words & t_words)
    return min(overlap / len(q_words), 1.0) * 0.35


def _authority_score(url):
    """Score based on domain authority."""
    if not url:
        return 0
    for domain, boost in AUTHORITY_DOMAINS.items():
        if domain in url.lower():
            return boost
    return 0


def _snippet_quality(snippet):
    """Score based on snippet informativeness."""
    if not snippet:
        return 0
    score = 0
    # Has code block or backtick
    if '`' in snippet or 'code' in snippet.lower():
        score += 0.1
    # Has version number
    if re.search(r'v?\d+\.\d+', snippet):
        score += 0.05
    # Reasonable length (not too short, not just a title)
    if 50 < len(snippet) < 500:
        score += 0.1
    return min(score, 0.25)


def rerank(query, results, threshold=0.15, top_k=5):
    """Rerank results by heuristic relevance score.

    Args:
        query: Search query string
        results: List of {title, url, snippet} dicts
        threshold: Minimum score to include (0.0-1.0)
        top_k: Maximum results to return

    Returns:
        Sorted list of results with added _score field
    """
    scored = []
    for r in results:
        title = r.get("title", "")
        url = r.get("url", "")
        snippet = r.get("snippet", r.get("content", ""))

        s = 0
        s += _keyword_score(query, title) * 1.5  # title match weighted
        s += _keyword_score(query, snippet)
        s += _authority_score(url)
        s += _snippet_quality(snippet)

        r_copy = dict(r)
        r_copy["_score"] = round(s, 3)
        scored.append(r_copy)

    scored.sort(key=lambda x: x["_score"], reverse=True)
    filtered = [r for r in scored if r["_score"] >= threshold]
    return filtered[:top_k]
