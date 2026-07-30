// Circuit Breaker for federated domes (SE-283 Slice 4)
// States: CLOSED (normal) → OPEN (after N failures) → HALF_OPEN (probe after cooldown) → CLOSED (on success)
export class CircuitBreaker {
  private failures: Map<string, number> = new Map();
  private state: Map<string, 'CLOSED' | 'OPEN' | 'HALF_OPEN'> = new Map();
  private openedAt: Map<string, number> = new Map();
  private threshold: number;
  private cooldownMs: number;

  constructor(threshold = 5, cooldownMs = 300000, _probeTimeout = 2000) {
    this.threshold = threshold; this.cooldownMs = cooldownMs;
  }

  allow(domeId: string): boolean {
    const s = this.state.get(domeId) || 'CLOSED';
    if (s === 'CLOSED') return true;
    if (s === 'HALF_OPEN') return true; // allow probe
    if (s === 'OPEN') {
      const opened = this.openedAt.get(domeId) || 0;
      if (Date.now() - opened > this.cooldownMs) {
        this.state.set(domeId, 'HALF_OPEN'); return true;
      }
      return false;
    }
    return true;
  }

  recordSuccess(domeId: string): void { this.failures.set(domeId, 0); }
  recordFailure(domeId: string): void {
    const f = (this.failures.get(domeId) || 0) + 1; this.failures.set(domeId, f);
    if (f >= this.threshold) { this.state.set(domeId, 'OPEN'); this.openedAt.set(domeId, Date.now()); }
  }

  recordProbeSuccess(domeId: string): void { this.state.set(domeId, 'CLOSED'); this.failures.set(domeId, 0); }
  recordProbeFailure(domeId: string): void { this.state.set(domeId, 'OPEN'); this.openedAt.set(domeId, Date.now()); }

  getState(domeId: string): string { return this.state.get(domeId) || 'CLOSED'; }
  reset(domeId: string): void { this.state.delete(domeId); this.failures.delete(domeId); this.openedAt.delete(domeId); }
}
