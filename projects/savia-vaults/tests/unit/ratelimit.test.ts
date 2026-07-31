// Unit tests: Rate limiter
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { RateLimiter } from '../../src/server/ratelimit.js';

describe('RateLimiter', () => {
  let limiter: RateLimiter;

  beforeEach(() => {
    vi.useFakeTimers();
    limiter = new RateLimiter(10); // 10 per minute for fast testing
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('allows first request', () => {
    expect(limiter.allow('client-1')).toBe(true);
  });

  it('allows up to max requests', () => {
    for (let i = 0; i < 10; i++) {
      expect(limiter.allow('client-1')).toBe(true);
    }
  });

  it('blocks after max requests', () => {
    for (let i = 0; i < 10; i++) limiter.allow('client-1');
    expect(limiter.allow('client-1')).toBe(false);
  });

  it('refills tokens over time', () => {
    for (let i = 0; i < 10; i++) limiter.allow('client-1');
    expect(limiter.allow('client-1')).toBe(false);

    vi.advanceTimersByTime(6000); // 6 seconds = 1 token at 10/min
    expect(limiter.allow('client-1')).toBe(true);
  });

  it('tracks different clients independently', () => {
    for (let i = 0; i < 10; i++) limiter.allow('client-1');
    expect(limiter.allow('client-1')).toBe(false);
    expect(limiter.allow('client-2')).toBe(true);
  });

  it('cleans up stale entries', () => {
    limiter.allow('stale-client');
    vi.advanceTimersByTime(11 * 60 * 1000); // 11 minutes
    // Trigger cleanup interval
    vi.advanceTimersByTime(5 * 60 * 1000);
    // After cleanup, stale client should be gone and new request gets full tokens
    expect(limiter.allow('stale-client')).toBe(true);
  });
});
