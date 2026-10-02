//! Retention: private state is deleted after `retention_days` without turns (default 30, 7–365).
//!
//! A session with a non-terminal run is never purged (recovery owns it). Captures not bound to
//! a session hold private note text, so they live only one day. Expired cookie sessions go too.

use crate::store::StoreError;
use rusqlite::{Transaction, params};
use space_contracts::clock::format_utc_millis;

const DAY_MS: i64 = 86_400_000;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Purged {
    pub sessions: usize,
    pub orphan_captures: usize,
    pub web_sessions: usize,
    pub idempotency: usize,
}

pub fn purge(tx: &Transaction<'_>, now_ms: i64, retention_days: u32, web_max_ms: i64) -> Result<Purged, StoreError> {
    let cutoff = format_utc_millis(now_ms - i64::from(retention_days) * DAY_MS);
    let sessions = tx.execute(
        "DELETE FROM sessions WHERE COALESCE(last_turn_at, updated_at) < ?1
           AND NOT EXISTS (SELECT 1 FROM runs WHERE runs.session_id = sessions.id
                           AND runs.state NOT IN ('COMPLETED', 'FAILED', 'CANCELLED', 'INTERRUPTED'))",
        params![cutoff],
    )?;
    let orphan_captures = tx.execute(
        "DELETE FROM captures WHERE session_id IS NULL AND obtained_at < ?1",
        params![format_utc_millis(now_ms - DAY_MS)],
    )?;
    let web_sessions = tx.execute(
        "DELETE FROM web_sessions WHERE revoked = 1 OR created_at < ?1",
        params![format_utc_millis(now_ms - web_max_ms)],
    )?;
    let idempotency = tx.execute("DELETE FROM idempotency WHERE created_at < ?1", params![cutoff])?;
    Ok(Purged { sessions, orphan_captures, web_sessions, idempotency })
}

#[cfg(test)]
#[path = "retention.test.rs"]
mod tests;
