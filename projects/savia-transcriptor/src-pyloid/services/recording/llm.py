"""OpenAI-compatible LLM provider (chat completions with streaming).

A single provider class covers OpenAI, Groq, OpenRouter, LM Studio, and
Ollama — Ollama exposes a `/v1/chat/completions` endpoint that follows the
same SSE delta format. Presets only differ in default endpoint / API-key
requirement; the wire protocol is identical.
"""

from __future__ import annotations

import json
from typing import Callable, Iterable, Optional

import httpx

from services.logger import get_logger
from services.transcription import CancelToken

log = get_logger("llm")

_TIMEOUT = httpx.Timeout(connect=10.0, read=120.0, write=30.0, pool=10.0)


class LLMConnectionError(RuntimeError):
    """Network or HTTP error talking to the LLM endpoint."""


class LLMStreamCancelled(Exception):
    """Raised when a streaming chat is cancelled via its CancelToken."""


class OpenAICompatibleProvider:
    """Talks the OpenAI Chat Completions wire format. Streams via SSE."""

    def __init__(
        self,
        endpoint: str,
        api_key: Optional[str],
        default_model: str,
        transport: Optional[httpx.BaseTransport] = None,
    ) -> None:
        self._endpoint = endpoint.rstrip("/")
        self._api_key = api_key or None
        self._default_model = default_model
        self._transport = transport

    # ------------------------------------------------------------------ public

    def chat(
        self,
        messages: list[dict],
        model: Optional[str] = None,
        on_stream: Optional[Callable[[str], None]] = None,
        cancel_token: Optional[CancelToken] = None,
    ) -> str:
        """Send a chat completion, streaming tokens to `on_stream` if given.
        Returns the full assembled assistant message."""
        if cancel_token is not None and cancel_token.is_cancelled:
            raise LLMStreamCancelled()
        payload = {
            "model": model or self._default_model,
            "messages": messages,
            "stream": True,
        }
        url = f"{self._endpoint}/chat/completions"
        headers = self._auth_headers()

        text_parts: list[str] = []

        client = self._client()
        try:
            with client.stream("POST", url, json=payload, headers=headers) as resp:
                if resp.status_code >= 400:
                    body = b""
                    try:
                        body = resp.read()
                    except Exception:
                        pass
                    raise LLMConnectionError(
                        f"LLM endpoint returned {resp.status_code}: {body.decode('utf-8', 'replace')[:200]}"
                    )
                for line in resp.iter_lines():
                    if cancel_token is not None and cancel_token.is_cancelled:
                        raise LLMStreamCancelled()
                    chunk = _parse_sse_line(line)
                    if chunk is None:
                        continue
                    if chunk == "[DONE]":
                        break
                    if chunk:
                        text_parts.append(chunk)
                        if on_stream is not None:
                            on_stream(chunk)
                            if cancel_token is not None and cancel_token.is_cancelled:
                                raise LLMStreamCancelled()
        except httpx.HTTPError as exc:
            raise LLMConnectionError(str(exc)) from exc
        finally:
            client.close()

        return "".join(text_parts)

    def list_models(self) -> list[str]:
        url = f"{self._endpoint}/models"
        try:
            with self._client() as client:
                resp = client.get(url, headers=self._auth_headers())
            if resp.status_code >= 400:
                raise LLMConnectionError(
                    f"GET {url} returned {resp.status_code}"
                )
            data = resp.json()
        except httpx.HTTPError as exc:
            raise LLMConnectionError(str(exc)) from exc
        items = data.get("data", []) if isinstance(data, dict) else []
        return [item.get("id") for item in items if isinstance(item, dict) and item.get("id")]

    def test_connection(self) -> tuple[bool, Optional[str]]:
        try:
            self.list_models()
            return True, None
        except LLMConnectionError as exc:
            return False, str(exc)

    # ------------------------------------------------------------------ helpers

    def _client(self) -> httpx.Client:
        kwargs = {"timeout": _TIMEOUT}
        if self._transport is not None:
            kwargs["transport"] = self._transport
        return httpx.Client(**kwargs)

    def _auth_headers(self) -> dict[str, str]:
        h = {"Content-Type": "application/json"}
        if self._api_key:
            h["Authorization"] = f"Bearer {self._api_key}"
        return h


def _parse_sse_line(raw: str | bytes) -> Optional[str]:
    """Decode one SSE line. Returns the content delta, the sentinel '[DONE]',
    or None for keepalives / blank lines."""
    if isinstance(raw, bytes):
        line = raw.decode("utf-8", "replace")
    else:
        line = raw
    line = line.strip()
    if not line or not line.startswith("data:"):
        return None
    payload = line[len("data:"):].strip()
    if payload == "[DONE]":
        return "[DONE]"
    try:
        obj = json.loads(payload)
    except json.JSONDecodeError:
        return None
    choices = obj.get("choices") or []
    if not choices:
        return None
    delta = choices[0].get("delta") or {}
    return delta.get("content") or ""
