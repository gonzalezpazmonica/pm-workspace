/* Tests for decision state management (SE-309). */

import { describe, it, expect } from 'vitest';
import {
  promote,
  getActiveState,
  DecisionStateLog,
} from '../src/knowledge/decision-state.js';
import { createDecisionRecord, DecisionRecord } from '../src/knowledge/decision.js';

function makeDecision(state = 'accepted' as const): DecisionRecord {
  return createDecisionRecord({
    category: 'config',
    scenario: 's',
    reasoning: 'r',
    outcome: 'o',
    confidence: 0.8,
    decisionMaker: 'savia',
    state,
  });
}

describe('promote', () => {
  it('applies a new state with reason and timestamp', () => {
    const rec = makeDecision('accepted');
    const promoted = promote(rec, 'rejected', 'superseded by SE-309', 'savia');
    expect(promoted.record.state).toBe('rejected');
    expect(promoted.record.state_reason).toBe('superseded by SE-309');
    expect(promoted.record.updated_at).toBeDefined();
  });

  it('returns a new record (immutable)', () => {
    const rec = makeDecision('accepted');
    const promoted = promote(rec, 'rejected', 'reason', 'savia');
    expect(promoted).not.toBe(rec);
    expect(rec.state).toBe('accepted'); // original unchanged
  });

  it('logs the state change', () => {
    const rec = makeDecision('accepted');
    const log = promote(rec, 'rejected', 'reason', 'savia');
    expect(log.history.length).toBeGreaterThanOrEqual(1);
    expect(log.history[0].from).toBe('accepted');
    expect(log.history[0].to).toBe('rejected');
  });
});

describe('getActiveState', () => {
  it('returns the latest state (last mark wins)', () => {
    const rec = makeDecision('accepted');
    const log = promote(rec, 'rejected', 'first', 'savia');
    const log2 = promote(log.record, 'accepted', 'actually fine', 'savia');
    expect(getActiveState(log2).state).toBe('accepted');
    expect(getActiveState(log2).state_reason).toBe('actually fine');
  });

  it('keeps full history (nothing deleted)', () => {
    const rec = makeDecision('accepted');
    const log1 = promote(rec, 'rejected', 'one', 'savia');
    const log2 = promote(log1.record, 'accepted', 'two', 'savia', log1.history);
    const log3 = promote(log2.record, 'rejected', 'three', 'savia', log2.history);
    expect(log3.history.length).toBe(3);
    expect(log3.history.map(h => h.to)).toEqual(['rejected', 'accepted', 'rejected']);
  });
});
