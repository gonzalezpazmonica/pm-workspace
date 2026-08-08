"""Tests for slice 10 — OpenAICompatibleProvider (chat + streaming + cancel)."""

import json

import httpx
import pytest

from services.recording.llm import (
    LLMConnectionError,
    LLMStreamCancelled,
    OpenAICompatibleProvider,
)
from services.transcription import CancelToken


def _sse(events: list[dict | str]) -> bytes:
    """Encode a list of dicts (and the literal '[DONE]') as an SSE body."""
    parts = []
    for ev in events:
        if isinstance(ev, str):
            parts.append(f"data: {ev}\n\n".encode("utf-8"))
        else:
            parts.append(f"data: {json.dumps(ev)}\n\n".encode("utf-8"))
    return b"".join(parts)


def _delta(content: str, finish: str | None = None) -> dict:
    return {
        "choices": [
            {"index": 0, "delta": {"content": content}, "finish_reason": finish}
        ]
    }


# ---------- chat (streaming) ----------

class TestChatStreaming:
    def test_assembles_streaming_tokens(self):
        def handler(request: httpx.Request) -> httpx.Response:
            body = _sse([_delta("Hello"), _delta(" world"), _delta("", "stop"), "[DONE]"])
            return httpx.Response(200, content=body,
                                  headers={"content-type": "text/event-stream"})

        provider = OpenAICompatibleProvider(
            endpoint="http://fake/v1", api_key="sk-test", default_model="m",
            transport=httpx.MockTransport(handler),
        )
        tokens: list[str] = []
        text = provider.chat(
            messages=[{"role": "user", "content": "hi"}],
            on_stream=tokens.append,
        )
        assert text == "Hello world"
        assert tokens == ["Hello", " world"]

    def test_authorization_header_sent(self):
        seen: dict = {}

        def handler(request: httpx.Request) -> httpx.Response:
            seen["auth"] = request.headers.get("authorization")
            return httpx.Response(200,
                                  content=_sse([_delta("ok"), "[DONE]"]),
                                  headers={"content-type": "text/event-stream"})

        provider = OpenAICompatibleProvider(
            endpoint="http://fake/v1", api_key="sk-mytestkey1234567890", default_model="m",
            transport=httpx.MockTransport(handler),
        )
        provider.chat(messages=[{"role": "user", "content": "x"}])
        assert seen["auth"] == "Bearer sk-mytestkey1234567890"

    def test_no_authorization_when_api_key_blank(self):
        seen: dict = {}

        def handler(request: httpx.Request) -> httpx.Response:
            seen["auth"] = request.headers.get("authorization")
            return httpx.Response(200,
                                  content=_sse([_delta("ok"), "[DONE]"]),
                                  headers={"content-type": "text/event-stream"})

        provider = OpenAICompatibleProvider(
            endpoint="http://fake/v1", api_key=None, default_model="m",
            transport=httpx.MockTransport(handler),
        )
        provider.chat(messages=[{"role": "user", "content": "x"}])
        # Ollama and other local servers expect no Authorization header at all.
        assert seen["auth"] is None

    def test_cancellation_mid_stream(self):
        def handler(request: httpx.Request) -> httpx.Response:
            body = _sse([_delta("one"), _delta(" two"), _delta(" three"), "[DONE]"])
            return httpx.Response(200, content=body,
                                  headers={"content-type": "text/event-stream"})

        provider = OpenAICompatibleProvider(
            endpoint="http://fake/v1", api_key=None, default_model="m",
            transport=httpx.MockTransport(handler),
        )
        token = CancelToken()
        # Cancel after the first token arrives.
        seen: list[str] = []

        def on_chunk(chunk: str) -> None:
            seen.append(chunk)
            token.cancel()

        with pytest.raises(LLMStreamCancelled):
            provider.chat(
                messages=[{"role": "user", "content": "go"}],
                on_stream=on_chunk,
                cancel_token=token,
            )
        # Only the first token should have been delivered before cancellation.
        assert seen == ["one"]

    def test_http_error_raises_llmconnectionerror(self):
        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(401, json={"error": {"message": "bad key"}})

        provider = OpenAICompatibleProvider(
            endpoint="http://fake/v1", api_key="sk-wrong", default_model="m",
            transport=httpx.MockTransport(handler),
        )
        with pytest.raises(LLMConnectionError) as exc:
            provider.chat(messages=[{"role": "user", "content": "x"}])
        assert "401" in str(exc.value)


# ---------- list_models / test_connection ----------

class TestListAndProbe:
    def test_list_models(self):
        def handler(request: httpx.Request) -> httpx.Response:
            assert request.url.path.endswith("/v1/models")
            return httpx.Response(200, json={
                "data": [{"id": "gpt-4o-mini"}, {"id": "llama3.2"}],
            })

        provider = OpenAICompatibleProvider(
            endpoint="http://fake/v1", api_key=None, default_model="x",
            transport=httpx.MockTransport(handler),
        )
        models = provider.list_models()
        assert "gpt-4o-mini" in models
        assert "llama3.2" in models

    def test_test_connection_ok(self):
        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(200, json={"data": [{"id": "m"}]})

        provider = OpenAICompatibleProvider(
            endpoint="http://fake/v1", api_key=None, default_model="m",
            transport=httpx.MockTransport(handler),
        )
        ok, err = provider.test_connection()
        assert ok is True
        assert err is None

    def test_test_connection_failure(self):
        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(403, json={"error": {"message": "nope"}})

        provider = OpenAICompatibleProvider(
            endpoint="http://fake/v1", api_key="bad", default_model="m",
            transport=httpx.MockTransport(handler),
        )
        ok, err = provider.test_connection()
        assert ok is False
        assert err is not None and "403" in err
