/* Decision records for SaviaVaults (SE-309).
 *
 * A decision is a first-class knowledge node: category, scenario, reasoning,
 * outcome, confidence, decision maker, and a lifecycle state. Adopted from the
 * graph-native accountability pattern (record_decision) — deterministic, no LLM.
 */

import { randomUUID } from 'node:crypto';

export type DecisionState = 'proposed' | 'accepted' | 'rejected';

export interface ProvenanceRef {
  agent: string;
  source: string;
  timestamp: string;
  confidence: number;
}

export interface DecisionRecord {
  id: string;
  category: string;
  scenario: string;
  reasoning: string;
  outcome: string;
  confidence: number;
  entities: string[];
  decision_maker: string;
  state: DecisionState;
  state_reason?: string;
  created_at: string;
  updated_at: string;
  provenance?: ProvenanceRef;
}

export interface DecisionInput {
  category: string;
  scenario: string;
  reasoning: string;
  outcome: string;
  confidence: number;
  decisionMaker: string;
  entities?: string[];
  state?: DecisionState;
  stateReason?: string;
  provenance?: ProvenanceRef;
}

export function createDecisionRecord(input: DecisionInput): DecisionRecord {
  const now = new Date().toISOString();
  return {
    id: randomUUID(),
    category: input.category,
    scenario: input.scenario,
    reasoning: input.reasoning,
    outcome: input.outcome,
    confidence: input.confidence,
    entities: input.entities ?? [],
    decision_maker: input.decisionMaker,
    state: input.state ?? 'proposed',
    state_reason: input.stateReason,
    created_at: now,
    updated_at: now,
    provenance: input.provenance,
  };
}

export function validateDecision(rec: DecisionRecord): string[] {
  const errors: string[] = [];
  if (!rec.category || rec.category.trim() === '') {
    errors.push('missing required field: category');
  }
  if (!rec.outcome || rec.outcome.trim() === '') {
    errors.push('missing required field: outcome');
  }
  if (rec.confidence < 0 || rec.confidence > 1) {
    errors.push('confidence must be in [0, 1]');
  }
  if (!['proposed', 'accepted', 'rejected'].includes(rec.state)) {
    errors.push(`invalid state: ${rec.state}`);
  }
  return errors;
}
