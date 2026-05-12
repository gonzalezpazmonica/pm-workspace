"""Validator contract — JSON Schema."""
from __future__ import annotations
from pydantic import BaseModel, Field


class ValidationError(BaseModel):
    path: str
    message: str


class ValidationResult(BaseModel):
    valid: bool
    errors: list[ValidationError] = Field(default_factory=list)
