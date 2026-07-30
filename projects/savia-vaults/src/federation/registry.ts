import * as fs from 'node:fs';
import * as path from 'node:path';
import type { FederatedDome } from './types.js';

export class FederationRegistry {
  private domes: Map<string, FederatedDome> = new Map();
  private configPath: string;

  constructor(configDir: string) {
    this.configPath = path.join(configDir, 'federation.json');
    this.load();
  }

  private load(): void {
    try {
      if (fs.existsSync(this.configPath)) {
        const data = JSON.parse(fs.readFileSync(this.configPath, 'utf-8'));
        if (Array.isArray(data)) for (const d of data) if (d.id) this.domes.set(d.id, { ...this.defaults(), ...d });
      }
    } catch { /* empty registry */ }
  }

  private save(): void {
    const dir = path.dirname(this.configPath);
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(this.configPath, JSON.stringify([...this.domes.values()], null, 2));
  }

  private defaults(): Partial<FederatedDome> { return { timeout: 5000, enabled: true, weight: 1.0, tags: [], status: 'unknown' }; }

  add(dome: FederatedDome): void {
    if (!dome.id || !dome.url) throw new Error('Dome must have id and url');
    this.domes.set(dome.id, { ...this.defaults(), ...dome }); this.save();
  }

  remove(id: string): boolean { const r = this.domes.delete(id); if (r) this.save(); return r; }
  get(id: string): FederatedDome | undefined { return this.domes.get(id); }
  list(): FederatedDome[] { return [...this.domes.values()]; }
  listEnabled(): FederatedDome[] { return this.list().filter(d => d.enabled); }
  getHealthy(): FederatedDome[] { return this.listEnabled().filter(d => d.status === 'healthy' || d.status === 'degraded'); }
  updateStatus(id: string, status: FederatedDome['status']): void {
    const dome = this.domes.get(id); if (dome) { dome.status = status; dome.lastHealthCheck = new Date().toISOString(); this.save(); }
  }
  clear(): void { this.domes.clear(); this.save(); }
  get count(): number { return this.domes.size; }
}
