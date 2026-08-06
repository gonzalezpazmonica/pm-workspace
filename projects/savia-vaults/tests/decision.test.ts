/* Tests for decision records (SE-309). */

import { describe, it, expect } from 'vitest';
import {
  createDecisionRecord,
  validateDecision,
  DecisionState,
} from '../src/knowledge/decision.js';

describe('DecisionRecord', () => {
  it('creates a valid decision record', () => {
    const rec = createDecisionRecord({
      category: 'architecture',
      scenario: 'Choose storage for scheduler',
      reasoning: 'SE-304 needs concurrency and persistence',
      outcome: 'JSON TaskStore',
      confidence: 0.85,
      decisionMaker: 'savia',
      entities: ['scheduler'],
    });
    expect(rec.id).toBeDefined();
    expect(rec.category).toBe('architecture');
    expect(rec.outcome).toBe('JSON TaskStore');
    expect(rec.confidence).toBe(0.85);
    expect(rec.state).toBe('proposed');
    expect(rec.created_at).toBeDefined();
  });

  it('defaults state to proposed', () => {
    const rec = createDecisionRecord({
      category: 'config',
      scenario: 's',
      reasoning: 'r',
      outcome: 'o',
      confidence: 0.5,
      decisionMaker: 'savia',
    });
    expect(rec.state).toBe('proposed');
  });

  it('accepts explicit state', () => {
    const rec = createDecisionRecord({
      category: 'config',
      scenario: 's',
      reasoning: 'r',
      outcome: 'o',
      confidence: 0.5,
      decisionMaker: 'savia',
      state: 'accepted',
    });
    expect(rec.state).toBe('accepted');
  });

  it('defaults entities to empty array', () => {
    const rec = createDecisionRecord({
      category: 'config',
      scenario: 's',
      reasoning: 'r',
      outcome: 'o',
      confidence: 0.5,
      decisionMaker: 'savia',
    });
    expect(rec.entities).toEqual([]);
  });
});

describe('validateDecision', () => {
  it('passes a complete record', () => {
    const rec = createDecisionRecord({
      category: 'architecture',
      scenario: 's',
      reasoning: 'r',
      outcome: 'o',
      confidence: 0.8,
      decisionMaker: 'savia',
    });
    const errors = validateDecision(rec);
    expect(errors).toEqual([]);
  });

  it('flags missing category', () => {
    const rec = createDecisionRecord({
      category: '',
      scenario: 's',
      reasoning: 'r',
      outcome: 'o',
      confidence: 0.8,
      decisionMaker: 'savia',
    });
    const errors = validateDecision(rec);
    expect(errors.some(e => e.includes('category'))).toBe(true);
  });

  it('flags missing outcome', () => {
    const rec = createDecisionRecord({
      category: 'config',
      scenario: 's',
      reasoning: 'r',
      outcome: '',
      confidence: 0.8,
      decisionMaker: 'savia',
    });
    const errors = validateDecision(rec);
    expect(errors.some(e => e.includes('outcome'))).toBe(true);
  });

  it('flags confidence out of range', () => {
    const rec = createDecisionRecord({
      category: 'config',
      scenario: 's',
      reasoning: 'r',
      outcome: 'o',
      confidence: 1.5,
      decisionMaker: 'savia',
    });
    const errors = validateDecision(rec);
    expect(errors.some(e => e.includes('confidence'))).toBe(true);
  });

  it('accepts all valid states', () => {
    for (const state of ['proposed', 'accepted', 'rejected'] as DecisionState[]) {
      const rec = createDecisionRecord({
        category: 'config',
        scenario: 's',
        reasoning: 'r',
        outcome: 'o',
        confidence: 0.5,
        decisionMaker: 'savia',
        state,
      });
      expect(validateDecision(rec)).toEqual([]);
    }
  });
});
