import * as fs from 'node:fs';
import * as path from 'node:path';
import { simpleGit } from 'simple-git';
import type { VaultConfig } from '../types.js';

export class MCPVaultServer {
  constructor(config: VaultConfig) {
    this.initVault(config);
  }

  private initVault(config: VaultConfig): void {
    const vp = config.path;
    fs.mkdirSync(vp, { recursive: true });

    if (!fs.existsSync(path.join(vp, 'INDEX.md'))) {
      fs.writeFileSync(path.join(vp, 'INDEX.md'), `# ${config.name}\n\nVault index.\n`);
    }

    if (!fs.existsSync(path.join(vp, 'MAP.md'))) {
      fs.writeFileSync(path.join(vp, 'MAP.md'), `# ${config.name} — Routing Map\n\n`);
    }

    const git = simpleGit(vp);
    git.checkIsRepo().then(isRepo => {
      if (!isRepo) {
        git.init().then(() => {
          git.addConfig('user.name', 'savia-vaults');
          git.addConfig('user.email', 'vaults@localhost');
          git.add('.').then(() => {
            git.commit('Initial commit: vault created');
          });
        });
      }
    }).catch(() => {});
  }
}
