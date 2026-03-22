"""Text utilities for voice output — sentence splitting and cleanup."""

import re

SENTENCE_END = re.compile(r'(?<=[.!?])\s+|(?<=[.!?])$')


def split_sentences(text):
    """Split text into sentences at . ! ? boundaries."""
    parts = SENTENCE_END.split(text)
    return [p for p in parts if p]


def split_into_voice_chunks(text, max_chars=250):
    """Split long text into voice-friendly chunks."""
    if len(text) <= max_chars:
        return [text] if text else []
    chunks = []
    sentences = split_sentences(text)
    current = ""
    for s in sentences:
        if len(current) + len(s) > max_chars and current:
            chunks.append(current.strip())
            current = s
        else:
            current += " " + s if current else s
    if current.strip():
        chunks.append(current.strip())
    return chunks


def clean_for_voice(text):
    """Strip markdown and formatting for natural speech."""
    if not text:
        return ""
    for ch in ["**", "*", "##", "#", "`", "```", "- "]:
        text = text.replace(ch, "")
    lines = text.split("\n")
    text = " ".join(
        l.strip() for l in lines
        if l.strip() and not l.strip().startswith(("```", "---"))
    )
    return text.strip()
