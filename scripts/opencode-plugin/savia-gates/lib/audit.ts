// audit.ts — append-only audit log for plugin decisions

import { mkdir, appendFile } from "node:fs/promises"

const AUDIT_DIR =
  process.env.SAVIA_AUDIT_DIR ?? `${process.env.HOME ?? ""}/.savia/audit`
const AUDIT_FILE = `${AUDIT_DIR}/savia-gates.jsonl`

let dirReady = false

export interface AuditRecord {
  event: string
  [k: string]: unknown
}

export async function auditLog(rec: AuditRecord): Promise<void> {
  if (!dirReady) {
    await mkdir(AUDIT_DIR, { recursive: true }).catch(() => {})
    dirReady = true
  }
  const line =
    JSON.stringify({ ts: new Date().toISOString(), pid: process.pid, ...rec }) +
    "\n"
  await appendFile(AUDIT_FILE, line).catch(() => {})
}
