"""structured_doc — reusable tooling library for structured Savia documents.

See docs/structured-doc.md for usage. Spec: SPEC-STRUCTURED-DOC-TOOLING.

Public API:
    register_type / get_type / list_types  (registry)
    Result, Success, Failure               (result.py)
    Finding, FindingsReport                (findings.py)
    parse_document                         (parser)
    lint_document                          (linter)
    diff_documents                         (differ)
    validate_document                      (validator)
"""
from .registry import register_type, get_type, list_types, DocType
from .result import Result, Success, Failure
from .findings import Finding, FindingsReport, Severity
from .parser.handler import parse_document
from .linter.handler import lint_document
from .differ.handler import diff_documents
from .validator.handler import validate_document

__all__ = [
    "register_type", "get_type", "list_types", "DocType",
    "Result", "Success", "Failure",
    "Finding", "FindingsReport", "Severity",
    "parse_document", "lint_document", "diff_documents", "validate_document",
]
