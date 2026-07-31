// Unit tests: Circuit Breaker
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { CircuitBreaker } from '../../../src/federation/circuit-breaker.js';

describe('CircuitBreaker', () => {
  let cb: CircuitBreaker;

  beforeEach(() => { vi.useFakeTimers(); cb = new CircuitBreaker(3, 60000, 2000); });
  afterEach(() => { vi.useRealTimers(); });

  it('starts CLOSED', () => {
    expect(cb.allow('dome-1')).toBe(true);
  });

  it('opens after threshold failures', () => {
    cb.recordFailure('dome-1'); cb.recordFailure('dome-1'); cb.recordFailure('dome-1');
    expect(cb.allow('dome-1')).toBe(false);
    expect(cb.getState('dome-1')).toBe('OPEN');
  });

  it('resets failures on success', () => {
    cb.recordFailure('dome-1'); cb.recordFailure('dome-1');
    cb.recordSuccess('dome-1');
    cb.recordFailure('dome-1');
    expect(cb.allow('dome-1')).toBe(true); // only 1 consecutive failure after reset
  });

  it('goes HALF_OPEN after cooldown', () => {
    for (let i = 0; i < 3; i++) cb.recordFailure('dome-1');
    expect(cb.allow('dome-1')).toBe(false);
    vi.advanceTimersByTime(61000);
    expect(cb.allow('dome-1')).toBe(true); // HALF_OPEN allows probe
    expect(cb.getState('dome-1')).toBe('HALF_OPEN');
  });

  it('closes after successful probe', () => {
    for (let i = 0; i < 3; i++) cb.recordFailure('dome-1');
    vi.advanceTimersByTime(61000);
    cb.recordProbeSuccess('dome-1');
    expect(cb.getState('dome-1')).toBe('CLOSED');
    expect(cb.allow('dome-1')).toBe(true);
  });

  it('reopens after failed probe', () => {
    for (let i = 0; i < 3; i++) cb.recordFailure('dome-1');
    vi.advanceTimersByTime(61000);
    cb.recordProbeFailure('dome-1');
    expect(cb.getState('dome-1')).toBe('OPEN');
    expect(cb.allow('dome-1')).toBe(false);
  });

  it('tracks multiple domes independently', () => {
    for (let i = 0; i < 3; i++) cb.recordFailure('dome-1');
    expect(cb.allow('dome-1')).toBe(false);
    expect(cb.allow('dome-2')).toBe(true);
  });

  it('can be reset for a dome', () => {
    for (let i = 0; i < 3; i++) cb.recordFailure('dome-1');
    cb.reset('dome-1');
    expect(cb.allow('dome-1')).toBe(true);
    expect(cb.getState('dome-1')).toBe('CLOSED');
  });
});
