#!/usr/bin/env python3
"""SPEC-050 Phase 1: Reaction Engine — maps pipeline events to agent handoffs."""
import json
import sys

DEFAULT_REACTIONS = {
    "ci-failure": {
        "auto": True,
        "action": "send-to-agent",
        "max_retries": 2,
        "escalate_after": 3,
        "agent_type": "developer",
    },
    "review-changes-requested": {
        "auto": True,
        "action": "send-to-agent",
        "max_retries": 1,
        "escalate_after": 2,
        "agent_type": "developer",
    },
    "test-failure": {
        "auto": True,
        "action": "send-to-agent",
        "max_retries": 2,
        "escalate_after": 3,
        "agent_type": "test-engineer",
    },
    "approved-and-green": {
        "auto": False,
        "action": "notify",
        "max_retries": 0,
        "escalate_after": 0,
        "agent_type": None,
    },
}

MODEL_LADDER = ["haiku", "sonnet", "opus"]


def parse_context(raw: str) -> dict:
    """Parse context JSON, return dict or empty dict on failure."""
    try:
        ctx = json.loads(raw)
        if not isinstance(ctx, dict):
            return {}
        return ctx
    except (json.JSONDecodeError, TypeError):
        return {}


def select_model(attempt: int) -> str:
    """Select model tier based on attempt number."""
    idx = min(attempt - 1, len(MODEL_LADDER) - 1)
    return MODEL_LADDER[max(0, idx)]


def build_qa_fail_handoff(event: str, ctx: dict, reaction: dict, attempt: int) -> dict:
    """Build QA Fail handoff template (#3 from handoff-templates.md)."""
    return {
        "handoff_type": "qa-fail",
        "from": "reaction-engine",
        "to": reaction["agent_type"],
        "verdict": "FAIL",
        "event": event,
        "failures": [{"error": ctx.get("logs", "No logs provided")}],
        "context": {
            "pr_url": ctx.get("pr_url", ""),
            "agent": ctx.get("agent", reaction["agent_type"]),
            "total_tests": ctx.get("total_tests", 0),
            "passed": ctx.get("passed", 0),
            "failed": ctx.get("failed", 0),
            "attempt": attempt,
        },
        "model": select_model(attempt),
    }


def build_escalation_handoff(event: str, ctx: dict, attempt: int) -> dict:
    """Build Escalation handoff template (#4 from handoff-templates.md)."""
    return {
        "handoff_type": "escalation",
        "from": "reaction-engine",
        "to": "HUMAN",
        "reason": "max_retries_exceeded",
        "event": event,
        "attempts": [
            {
                "attempt": i + 1,
                "model": select_model(i + 1),
                "result": "failed",
            }
            for i in range(attempt)
        ],
        "recommendation": f"Human review needed for {event} after {attempt} attempts",
        "pr_url": ctx.get("pr_url", ""),
        "files_affected": ctx.get("files_affected", []),
    }


def build_notify(event: str, ctx: dict) -> dict:
    """Build notification output (no agent re-invocation)."""
    return {
        "handoff_type": "notify",
        "event": event,
        "message": f"Event '{event}' detected. No automatic action configured.",
        "pr_url": ctx.get("pr_url", ""),
    }


def react(event_type: str, context_raw: str) -> dict:
    """Main reaction logic. Returns JSON-serializable recommendation."""
    ctx = parse_context(context_raw)
    attempt = max(1, int(ctx.get("attempt", 1)))

    reaction = DEFAULT_REACTIONS.get(event_type)
    if reaction is None:
        return {
            "handoff_type": "unknown",
            "event": event_type,
            "error": f"Unknown event type: {event_type}",
            "suggestion": "Supported events: " + ", ".join(sorted(DEFAULT_REACTIONS)),
        }

    # Check if escalation is needed
    if reaction["escalate_after"] > 0 and attempt >= reaction["escalate_after"]:
        return build_escalation_handoff(event_type, ctx, attempt)

    # Non-auto events just notify
    if not reaction["auto"]:
        return build_notify(event_type, ctx)

    # Auto events: send-to-agent with QA Fail handoff
    return build_qa_fail_handoff(event_type, ctx, reaction, attempt)


def main() -> None:
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Usage: reaction-engine-core.py <event> <json>"}))
        sys.exit(1)

    event_type = sys.argv[1]
    context_raw = sys.argv[2]
    result = react(event_type, context_raw)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
