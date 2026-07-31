import * as fs from 'node:fs';
import * as path from 'node:path';
import type { VaultConfig } from '../types.js';

export class SecurityError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'SecurityError';
  }
}

export class VaultSecurity {
  private config: VaultConfig;
  private defaultAllowed: Set<string>;
  private defaultDenied: Set<string>;

  constructor(config: VaultConfig) {
    this.config = config;
    this.defaultAllowed = new Set(['.md', '.yaml', '.yml', '.json', '.txt', '.canvas', '.base']);
    this.defaultDenied = new Set(['.git', '.obsidian', 'node_modules', '.savia-vault', '.trash']);
  }

  resolve(relativePath: string): string {
    const normalized = path.normalize(relativePath);
    const resolved = path.resolve(this.config.path, normalized);

    if (!resolved.startsWith(path.resolve(this.config.path))) {
      throw new SecurityError('Path traversal blocked');
    }

    if (normalized.startsWith('..') || normalized.includes('../')) {
      throw new SecurityError('Path traversal blocked');
    }

    return resolved;
  }

  checkDenied(absPath: string): void {
    const parts = absPath.split(path.sep);
    const custom = new Set(this.config.deniedPaths.map(d => d.toLowerCase()));

    for (const part of parts) {
      if (this.defaultDenied.has(part)) {
        throw new SecurityError(`Access denied: ${part}`);
      }
      if (custom.has(part.toLowerCase())) {
        throw new SecurityError(`Access denied: ${part}`);
      }
    }
  }

  checkSymlink(absPath: string): void {
    try {
      const lstat = fs.lstatSync(absPath);
      if (lstat.isSymbolicLink()) {
        const target = fs.realpathSync(absPath);
        const resolved = path.resolve(this.config.path);
        if (!target.startsWith(resolved)) {
          throw new SecurityError('Symlink points outside vault boundary');
        }
      }
    } catch (e: unknown) {
      if (e instanceof SecurityError) throw e;
    }
  }

  checkExtension(absPath: string): void {
    const ext = path.extname(absPath).toLowerCase();
    const allowed = this.config.allowedExtensions.length > 0
      ? new Set(this.config.allowedExtensions.map(e => e.toLowerCase()))
      : this.defaultAllowed;

    if (!allowed.has(ext)) {
      throw new SecurityError(`Extension not allowed: ${ext}`);
    }
  }

  checkDepth(relativePath: string): void {
    const parts = relativePath.split(path.sep).filter(p => p !== '' && p !== '.');
    if (parts.length > this.config.maxDepth) {
      throw new SecurityError(`Path exceeds max depth of ${this.config.maxDepth}`);
    }
  }

  guardRead(relativePath: string): string {
    this.checkDepth(relativePath);
    const absPath = this.resolve(relativePath);
    this.checkDenied(absPath);

    if (fs.existsSync(absPath)) {
      this.checkSymlink(absPath);
      this.checkExtension(absPath);
      const stat = fs.statSync(absPath);
      if (stat.size > this.config.maxFileSize) {
        throw new SecurityError(`File exceeds max size of ${this.config.maxFileSize}`);
      }
    }

    return absPath;
  }

  guardWrite(relativePath: string): string {
    this.checkDepth(relativePath);
    const absPath = this.resolve(relativePath);
    this.checkDenied(absPath);

    const dir = path.dirname(absPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    return absPath;
  }
}
