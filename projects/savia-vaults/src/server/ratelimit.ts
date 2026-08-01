// Rate limiter: token bucket per client
export class RateLimiter {
  private maxTokens: number;
  private refillRate: number;
  private clients: Map<string, { tokens: number; lastRefill: number; lastAccess: number }> = new Map();

  constructor(maxPerMinute: number) {
    this.maxTokens = maxPerMinute;
    this.refillRate = maxPerMinute / 60000;
    this.startCleanup();
  }

  allow(clientId: string): boolean {
    const now = Date.now();
    let bucket = this.clients.get(clientId);

    if (!bucket) {
      bucket = { tokens: this.maxTokens, lastRefill: now, lastAccess: now };
      this.clients.set(clientId, bucket);
    }

    const elapsed = now - bucket.lastRefill;
    bucket.tokens = Math.min(this.maxTokens, bucket.tokens + elapsed * this.refillRate);
    bucket.lastRefill = now;
    bucket.lastAccess = now;

    if (bucket.tokens >= 1) {
      bucket.tokens -= 1;
      return true;
    }

    return false;
  }

  private startCleanup(): void {
    const interval = setInterval(() => {
      const now = Date.now();
      for (const [id, bucket] of this.clients) {
        if (now - bucket.lastAccess > 10 * 60 * 1000) {
          this.clients.delete(id);
        }
      }
    }, 5 * 60 * 1000);

    if (interval.unref) interval.unref();
  }
}
