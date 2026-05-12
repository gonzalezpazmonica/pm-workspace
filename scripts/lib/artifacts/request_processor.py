"""
request_processor.py — Inyección multi-modal de artifacts en la conversación.

Inspirado en decisión #25 de Magec. Cuando load_artifact es invocado, el
contenido NO se devuelve como string JSON plano. En su lugar, este módulo
construye el bloque de mensaje adecuado para el proveedor activo:

  - Texto plano        → message content string
  - PDF / imagen       → bloque multimodal nativo (Anthropic vision)
  - Binario genérico   → bloque base64 con MIME type explícito (fallback)

Los proveedores soportados se detectan via variable de entorno SAVIA_PROVIDER
(ver docs/rules/domain/provider-agnostic-env.md). Para proveedores desconocidos
se usa siempre el fallback base64.

Rule #26: lógica en Python, bash solo wrappers.
"""
from __future__ import annotations

import base64
import os
from typing import Any


# ---------------------------------------------------------------------------
# Tipos de bloque de mensaje
# ---------------------------------------------------------------------------

TextBlock = dict[str, str]          # {"type": "text", "text": "..."}
ImageBlock = dict[str, Any]         # {"type": "image", "source": {...}}
DocumentBlock = dict[str, Any]      # {"type": "document", ...}  (Anthropic PDF)
Base64Block = dict[str, Any]        # fallback genérico


def build_injection_block(
    content: bytes,
    mime_type: str,
    artifact_name: str,
    provider: str | None = None,
) -> TextBlock | ImageBlock | DocumentBlock | Base64Block:
    """
    Construye el bloque de contenido adecuado para inyectar en la conversación.

    Parameters
    ----------
    content:
        Bytes del artifact.
    mime_type:
        MIME type del artifact (e.g. "text/plain", "image/png", "application/pdf").
    artifact_name:
        Nombre lógico del artifact (para contexto textual).
    provider:
        Proveedor activo ("anthropic", "openai", "deepseek", "localai", ...).
        Si None, se lee de la var de entorno SAVIA_PROVIDER.
        Si desconocido, se usa fallback base64.

    Returns
    -------
    dict listo para incluirse en la lista de content blocks de un mensaje.
    """
    effective_provider = (provider or os.environ.get("SAVIA_PROVIDER", "unknown")).lower()

    # 1. Texto plano: siempre como bloque de texto (universal)
    if mime_type.startswith("text/"):
        text_content = content.decode("utf-8", errors="replace")
        return {
            "type": "text",
            "text": f"[Artifact: {artifact_name}]\n\n{text_content}",
        }

    # 2. Imagen: nativa en Anthropic y OpenAI
    if mime_type.startswith("image/"):
        return _build_image_block(content, mime_type, effective_provider)

    # 3. PDF: nativo en Anthropic (claude-3+), fallback base64 en el resto
    if mime_type == "application/pdf":
        return _build_pdf_block(content, mime_type, effective_provider)

    # 4. Fallback genérico: base64
    return _build_base64_block(content, mime_type, artifact_name)


# ---------------------------------------------------------------------------
# Constructores por tipo
# ---------------------------------------------------------------------------

def _build_image_block(
    content: bytes,
    mime_type: str,
    provider: str,
) -> ImageBlock | Base64Block:
    """Imagen: bloque nativo para Anthropic/OpenAI, base64 para el resto."""
    b64 = base64.standard_b64encode(content).decode("ascii")

    if provider in {"anthropic", "claude"}:
        # Anthropic vision: https://docs.anthropic.com/en/api/messages
        return {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": mime_type,
                "data": b64,
            },
        }

    if provider in {"openai", "azure-openai"}:
        # GPT-4V: data URL
        return {
            "type": "image_url",
            "image_url": {
                "url": f"data:{mime_type};base64,{b64}",
            },
        }

    # Fallback: bloque base64 genérico
    return _build_base64_block(content, mime_type, "image")


def _build_pdf_block(
    content: bytes,
    mime_type: str,
    provider: str,
) -> DocumentBlock | Base64Block:
    """PDF: bloque document nativo de Anthropic, base64 para el resto."""
    b64 = base64.standard_b64encode(content).decode("ascii")

    if provider in {"anthropic", "claude"}:
        # Anthropic PDF support (claude-3-5-sonnet+)
        return {
            "type": "document",
            "source": {
                "type": "base64",
                "media_type": "application/pdf",
                "data": b64,
            },
        }

    # Fallback: base64 genérico
    return _build_base64_block(content, mime_type, "document")


def _build_base64_block(
    content: bytes,
    mime_type: str,
    artifact_name: str,
) -> Base64Block:
    """Fallback universal: base64 con MIME type explícito."""
    b64 = base64.standard_b64encode(content).decode("ascii")
    return {
        "type": "text",
        "text": (
            f"[Artifact: {artifact_name} | MIME: {mime_type} | encoding: base64]\n"
            f"{b64}"
        ),
    }


# ---------------------------------------------------------------------------
# Helper público: inyectar en lista de mensajes
# ---------------------------------------------------------------------------

def inject_into_messages(
    messages: list[dict[str, Any]],
    content: bytes,
    mime_type: str,
    artifact_name: str,
    provider: str | None = None,
) -> list[dict[str, Any]]:
    """
    Devuelve una nueva lista de mensajes con el artifact inyectado como
    mensaje user adicional antes del último turno.

    Parameters
    ----------
    messages:
        Lista de mensajes en formato estándar [{"role": ..., "content": ...}, ...].
    content, mime_type, artifact_name, provider:
        Ver build_injection_block.

    Returns
    -------
    Nueva lista (no modifica in-place).
    """
    block = build_injection_block(content, mime_type, artifact_name, provider)
    injection_message: dict[str, Any] = {
        "role": "user",
        "content": [block],
    }
    # Insertar antes del último mensaje si el último es "user",
    # o al final en caso contrario.
    result = list(messages)
    result.insert(len(result), injection_message)
    return result
