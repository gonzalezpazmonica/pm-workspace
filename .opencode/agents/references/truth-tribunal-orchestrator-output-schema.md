# Truth Tribunal — Output Schema Reference

## .truth.crc artifact

Write {report_path}.truth.crc with the following YAML fields:

- tribunal_id: "TT-{YYYYMMDD-HHMMSS}"
- report_path, report_type, iteration, destination_tier
- weighted_score: 0-100
- verdict: PUBLISHABLE | CONDITIONAL | ITERATE | ESCALATE | NOT_EVALUABLE
- vetos: list of {judge, reason}
- judges: factuality, source_traceability, hallucination, coherence, calibration, completeness, compliance — each with score, confidence, verdict, findings[]
- aggregation: abstentions, total_findings, critical_findings
- feedback_for_generator: populated only if verdict is ITERATE

## Weights per report type

See docs/rules/domain/truth-tribunal-weights.md for the canonical weight table.
Profiles: default, executive, compliance, audit, digest, subjective.
