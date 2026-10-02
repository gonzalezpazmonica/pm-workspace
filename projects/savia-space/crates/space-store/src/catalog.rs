//! Listing and small aggregates: sessions, runs, captures, selections, web sessions.

use crate::store::{SessionRow, StoreError};
use rusqlite::{OptionalExtension, Transaction, params};
use space_contracts::Sha256Hex;
use space_contracts::clock::parse_utc_millis;
use space_contracts::model::{ErrorCode, RunState};
use uuid::Uuid;

fn uuid(s: &str) -> Result<Uuid, StoreError> {
    Uuid::parse_str(s).map_err(|e| StoreError::Corrupt(e.to_string()))
}

fn from_str<T: serde::de::DeserializeOwned>(s: String) -> Result<T, StoreError> {
    serde_json::from_value(serde_json::Value::String(s)).map_err(|e| StoreError::Corrupt(e.to_string()))
}

pub fn list_sessions(tx: &Transaction<'_>, project_id: Uuid, limit: u64) -> Result<Vec<SessionRow>, StoreError> {
    let mut stmt = tx.prepare(
        "SELECT id, project_id, title, revision, state, created_at, updated_at FROM sessions
         WHERE project_id = ?1 ORDER BY updated_at DESC, id DESC LIMIT ?2",
    )?;
    type Raw = (String, String, String, i64, String, String, String);
    let raws: Vec<Raw> = stmt
        .query_map(params![project_id.to_string(), limit as i64], |r| {
            Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, r.get(4)?, r.get(5)?, r.get(6)?))
        })?
        .collect::<Result<_, _>>()?;
    raws.into_iter()
        .map(|(id, p, title, rev, state, c, u)| {
            Ok(SessionRow {
                id: uuid(&id)?,
                project_id: uuid(&p)?,
                title,
                revision: rev as u64,
                state,
                created_at: c,
                updated_at: u,
            })
        })
        .collect()
}

/// `(run_id, state, revision, terminal_reason, created_at)`, newest first.
pub type RunSummary = (Uuid, RunState, u64, Option<ErrorCode>, String);

pub fn list_runs(tx: &Transaction<'_>, session_id: Uuid, limit: u64) -> Result<Vec<RunSummary>, StoreError> {
    let mut stmt = tx.prepare(
        "SELECT id, state, revision, terminal_reason, created_at FROM runs WHERE session_id = ?1
         ORDER BY created_at DESC, id DESC LIMIT ?2",
    )?;
    type Raw = (String, String, i64, Option<String>, String);
    let raws: Vec<Raw> = stmt
        .query_map(params![session_id.to_string(), limit as i64], |r| {
            Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, r.get(4)?))
        })?
        .collect::<Result<_, _>>()?;
    raws.into_iter()
        .map(|(id, state, rev, reason, created)| {
            Ok((uuid(&id)?, from_str(state)?, rev as u64, reason.map(from_str).transpose()?, created))
        })
        .collect()
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CaptureRow {
    pub id: Uuid,
    pub project_id: Uuid,
    pub session_id: Option<Uuid>,
    pub dome_id: String,
    pub resource_id: String,
    pub title: String,
    pub content_hash: Sha256Hex,
    pub text_base: String,
    pub obtained_at: String,
}

pub fn insert_capture(tx: &Transaction<'_>, c: &CaptureRow) -> Result<(), StoreError> {
    tx.execute(
        "INSERT INTO captures(id, project_id, session_id, dome_id, resource_id, title, content_hash, text_base,
                              obtained_at)
         VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
        params![
            c.id.to_string(),
            c.project_id.to_string(),
            c.session_id.map(|s| s.to_string()),
            c.dome_id,
            c.resource_id,
            c.title,
            c.content_hash.as_str(),
            c.text_base,
            c.obtained_at
        ],
    )?;
    Ok(())
}

pub fn get_capture(tx: &Transaction<'_>, id: Uuid) -> Result<Option<CaptureRow>, StoreError> {
    type Raw = (String, String, Option<String>, String, String, String, String, String, String);
    let raw: Option<Raw> = tx
        .query_row(
            "SELECT id, project_id, session_id, dome_id, resource_id, title, content_hash, text_base, obtained_at
             FROM captures WHERE id = ?1",
            [id.to_string()],
            |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, r.get(4)?, r.get(5)?, r.get(6)?, r.get(7)?, r.get(8)?)),
        )
        .optional()?;
    raw.map(|(id, p, s, dome, res, title, hash, text, at)| {
        Ok(CaptureRow {
            id: uuid(&id)?,
            project_id: uuid(&p)?,
            session_id: s.as_deref().map(uuid).transpose()?,
            dome_id: dome,
            resource_id: res,
            title,
            content_hash: Sha256Hex::try_from(hash).map_err(StoreError::Corrupt)?,
            text_base: text,
            obtained_at: at,
        })
    })
    .transpose()
}

/// Binds an orphan capture to a session (keeps it alive with the session).
pub fn bind_capture(tx: &Transaction<'_>, id: Uuid, session_id: Uuid) -> Result<(), StoreError> {
    tx.execute(
        "UPDATE captures SET session_id = ?2 WHERE id = ?1 AND (session_id IS NULL OR session_id = ?2)",
        params![id.to_string(), session_id.to_string()],
    )?;
    Ok(())
}

/// Removes captures never bound to a session and obtained before `cutoff`.
pub fn purge_orphan_captures(tx: &Transaction<'_>, cutoff: &str) -> Result<usize, StoreError> {
    Ok(tx.execute("DELETE FROM captures WHERE session_id IS NULL AND obtained_at < ?1", [cutoff])?)
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SelectionRow {
    pub id: Uuid,
    pub revision: u64,
    pub refs: String,
}

/// Replaces the session selection with CAS on its revision (0 = no selection yet).
pub fn put_selection(
    tx: &Transaction<'_>,
    session_id: Uuid,
    expected: u64,
    refs_json: &str,
) -> Result<Option<u64>, StoreError> {
    let current = get_selection(tx, session_id)?.map(|s| s.revision).unwrap_or(0);
    if current != expected {
        return Ok(None);
    }
    tx.execute(
        "INSERT INTO selections(session_id, id, revision, refs) VALUES(?1, ?2, ?3, ?4)
         ON CONFLICT(session_id) DO UPDATE SET id = excluded.id, revision = excluded.revision, refs = excluded.refs",
        params![session_id.to_string(), Uuid::now_v7().to_string(), (expected + 1) as i64, refs_json],
    )?;
    Ok(Some(expected + 1))
}

pub fn get_selection(tx: &Transaction<'_>, session_id: Uuid) -> Result<Option<SelectionRow>, StoreError> {
    let raw: Option<(String, i64, String)> = tx
        .query_row("SELECT id, revision, refs FROM selections WHERE session_id = ?1", [session_id.to_string()], |r| {
            Ok((r.get(0)?, r.get(1)?, r.get(2)?))
        })
        .optional()?;
    raw.map(|(id, rev, refs)| Ok(SelectionRow { id: uuid(&id)?, revision: rev as u64, refs })).transpose()
}

pub fn insert_web_session(tx: &Transaction<'_>, token_hash: &Sha256Hex, now: &str) -> Result<(), StoreError> {
    tx.execute(
        "INSERT INTO web_sessions(token_hash, created_at, last_used_at) VALUES(?1, ?2, ?2)",
        params![token_hash.as_str(), now],
    )?;
    Ok(())
}

/// Valid if not revoked, idle less than `idle_ms` and younger than `max_ms`. Touches `last_used_at`.
pub fn web_session_valid(
    tx: &Transaction<'_>,
    token_hash: &Sha256Hex,
    now: &str,
    idle_ms: i64,
    max_ms: i64,
) -> Result<bool, StoreError> {
    let row: Option<(String, String, i64)> = tx
        .query_row(
            "SELECT created_at, last_used_at, revoked FROM web_sessions WHERE token_hash = ?1",
            [token_hash.as_str()],
            |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
        )
        .optional()?;
    let Some((created, last, revoked)) = row else { return Ok(false) };
    let (Some(c), Some(l), Some(n)) = (parse_utc_millis(&created), parse_utc_millis(&last), parse_utc_millis(now))
    else {
        return Ok(false);
    };
    let ok = revoked == 0 && n - l <= idle_ms && n - c <= max_ms;
    if ok {
        tx.execute(
            "UPDATE web_sessions SET last_used_at = ?2 WHERE token_hash = ?1",
            params![token_hash.as_str(), now],
        )?;
    }
    Ok(ok)
}

pub fn revoke_web_session(tx: &Transaction<'_>, token_hash: &Sha256Hex) -> Result<(), StoreError> {
    tx.execute("UPDATE web_sessions SET revoked = 1 WHERE token_hash = ?1", [token_hash.as_str()])?;
    Ok(())
}

pub fn revoke_all_web_sessions(tx: &Transaction<'_>) -> Result<(), StoreError> {
    tx.execute("UPDATE web_sessions SET revoked = 1", [])?;
    Ok(())
}

#[cfg(test)]
#[path = "catalog.test.rs"]
mod tests;
