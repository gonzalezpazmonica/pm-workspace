import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { execSync } from 'node:child_process';

interface BackupEntry {
  id: string;
  vault: string;
  timestamp: string;
  size: number;
  file: string;
}

export class BackupManager {
  private backupsDir: string;

  constructor(backupsDir?: string) {
    this.backupsDir = backupsDir || path.join(os.homedir(), '.savia-vaults', 'backups');
    fs.mkdirSync(this.backupsDir, { recursive: true });
  }

  create(vaultPath: string, vaultName: string): BackupEntry {
    const ts = new Date().toISOString().replace(/[:.]/g, '-');
    const id = `${vaultName}-${ts}`;
    const tarFile = path.join(this.backupsDir, `${id}.tar.gz`);

    const vaultDir = path.dirname(vaultPath);
    const vaultBase = path.basename(vaultPath);

    try {
      execSync(`tar -czf "${tarFile}" -C "${vaultDir}" "${vaultBase}"`, { stdio: 'pipe' });
    } catch {
      throw new Error(`Failed to create backup of ${vaultPath}`);
    }

    const stat = fs.statSync(tarFile);
    const entry: BackupEntry = {
      id,
      vault: vaultName,
      timestamp: new Date().toISOString(),
      size: stat.size,
      file: tarFile,
    };

    this.syncToNextcloud(tarFile, id);

    return entry;
  }

  private syncToNextcloud(tarFile: string, _id: string): void {
    const ncDir = process.env.SAVIA_BACKUP_NEXTCLOUD_DIR;
    if (ncDir && fs.existsSync(ncDir)) {
      try {
        const dest = path.join(ncDir, path.basename(tarFile));
        fs.copyFileSync(tarFile, dest);
      } catch {
        // Non-fatal: local backup succeeded
      }
    }

    const ncUrl = process.env.NEXTCLOUD_URL;
    const ncUser = process.env.NEXTCLOUD_USER;
    const ncPass = process.env.NEXTCLOUD_PASS;
    if (ncUrl && ncUser && ncPass) {
      try {
        const fileName = path.basename(tarFile);
        const content = fs.readFileSync(tarFile);
        const auth = Buffer.from(`${ncUser}:${ncPass}`).toString('base64');
        const webdavUrl = `${ncUrl}/remote.php/dav/files/${ncUser}/SaviaVaults/${fileName}`;
        execSync(`curl -s -X PUT -H "Authorization: Basic ${auth}" --data-binary @- "${webdavUrl}"`, {
          input: content,
          stdio: 'pipe',
          timeout: 30000,
        });
      } catch {
        // Non-fatal
      }
    }
  }

  list(): BackupEntry[] {
    const entries: BackupEntry[] = [];
    if (!fs.existsSync(this.backupsDir)) return entries;

    const files = fs.readdirSync(this.backupsDir).filter(f => f.endsWith('.tar.gz')).sort().reverse();
    for (const f of files) {
      const fullPath = path.join(this.backupsDir, f);
      const stat = fs.statSync(fullPath);
      const parts = f.replace('.tar.gz', '').split('-');
      const id = parts.join('-');
      entries.push({
        id,
        vault: parts[0] || 'unknown',
        timestamp: stat.birthtime.toISOString(),
        size: stat.size,
        file: fullPath,
      });
    }
    return entries;
  }

  restore(backupId: string, targetDir: string): string {
    const tarFile = path.join(this.backupsDir, `${backupId}.tar.gz`);
    if (!fs.existsSync(tarFile)) {
      throw new Error(`Backup ${backupId} not found`);
    }

    fs.mkdirSync(targetDir, { recursive: true });

    try {
      execSync(`tar -xzf "${tarFile}" -C "${targetDir}"`, { stdio: 'pipe' });
    } catch {
      throw new Error(`Failed to restore backup ${backupId}`);
    }

    return targetDir;
  }

  status(): { backupsDir: string; count: number; nextcloudConfigured: boolean } {
    const entries = this.list();
    const ncConfigured = !!(process.env.SAVIA_BACKUP_NEXTCLOUD_DIR || process.env.NEXTCLOUD_URL);
    return {
      backupsDir: this.backupsDir,
      count: entries.length,
      nextcloudConfigured: ncConfigured,
    };
  }
}
