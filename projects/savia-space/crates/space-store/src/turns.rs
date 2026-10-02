//! Previews, messages, attempts and raw outputs (all inside the caller's transaction).

use crate::store::StoreError;
use rusqlite::{OptionalExtension, Transaction, params};
use space_contracts::Sha256Hex;
use space_contracts::model::{MessageStatus, Role};
use uuid::Uuid;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PreviewRow {
    pub id: Uuid,
    pub session_id: Uuid,
    pub run_id: Uuid,
    pub request_hash: Sha256Hex,
    pub manifest_hash: Sha256Hex,
    pub payload_hash: Sha256Hex,
    pub manifest: String,
    pub body: Vec<u8>,
    pub expires_at: String,
    pub consumed: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MessageRow {
    pub id: Uuid,
    pub run_id: Option<Uuid>,
    pub role: Role,
    pub status: MessageStatus,
    pub created_sequence: u64,
    pub text: String,
    pub citations: String,
    pub manifest_id: Option<Uuid>,
    /// Validation report (JSON) of an assistant message, once validated.
    pub validation: Option<String>,
}

fn enum_str<T: serde::Serialize>(v: T) -> String {
    serde_json::to_value(v).ok().and_then(|v| v.as_str().map(str::to_owned)).unwrap_or_default()
}

fn enum_from<T: serde::de::DeserializeOwned>(s: String) -> Result<T, StoreError> {
    serde_json::from_value(serde_json::Value::String(s)).map_err(|e| StoreError::Corrupt(e.to_string()))
}

fn uuid(s: &str) -> Result<Uuid, StoreError> {
    Uuid::parse_str(s).map_err(|e| StoreError::Corrupt(e.to_string()))
}

fn hash(s: String) -> Result<Sha256Hex, StoreError> {
    Sha256Hex::try_from(s).map_err(StoreError::Corrupt)
}

pub fn insert_preview(tx: &Transaction<'_>, p: &PreviewRow) -> Result<(), StoreError> {
    tx.execute(
        "INSERT INTO previews(id, session_id, run_id, request_hash, manifest_hash, payload_hash, manifest, body,
                              expires_at, consumed)
         VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
        params![
            p.id.to_string(),
            p.session_id.to_string(),
            p.run_id.to_string(),
            p.request_hash.as_str(),
            p.manifest_hash.as_str(),
            p.payload_hash.as_str(),
            p.manifest,
            p.body,
            p.expires_at,
            p.consumed as i64
        ],
    )?;
    Ok(())
}

pub fn get_preview(tx: &Transaction<'_>, id: Uuid) -> Result<Option<PreviewRow>, StoreError> {
    type Raw = (String, String, String, String, String, String, String, Vec<u8>, String, i64);
    let raw: Option<Raw> = tx
        .query_row(
            "SELECT id, session_id, run_id, request_hash, manifest_hash, payload_hash, manifest, body, expires_at,
                    consumed FROM previews WHERE id = ?1",
            [id.to_string()],
            |r| {
                Ok((
                    r.get(0)?,
                    r.get(1)?,
                    r.get(2)?,
                    r.get(3)?,
                    r.get(4)?,
                    r.get(5)?,
                    r.get(6)?,
                    r.get(7)?,
                    r.get(8)?,
                    r.get(9)?,
                ))
            },
        )
        .optional()?;
    raw.map(|(id, sid, rid, rh, mh, ph, manifest, body, exp, consumed)| {
        Ok(PreviewRow {
            id: uuid(&id)?,
            session_id: uuid(&sid)?,
            run_id: uuid(&rid)?,
            request_hash: hash(rh)?,
            manifest_hash: hash(mh)?,
            payload_hash: hash(ph)?,
            manifest,
            body,
            expires_at: exp,
            consumed: consumed != 0,
        })
    })
    .transpose()
}

pub fn get_preview_by_run(tx: &Transaction<'_>, run_id: Uuid) -> Result<Option<PreviewRow>, StoreError> {
    let id: Option<String> =
        tx.query_row("SELECT id FROM previews WHERE run_id = ?1", [run_id.to_string()], |r| r.get(0)).optional()?;
    match id {
        Some(id) => get_preview(tx, uuid(&id)?),
        None => Ok(None),
    }
}

/// Marks a preview consumed. Returns `false` if it was already consumed.
pub fn consume_preview(tx: &Transaction<'_>, id: Uuid) -> Result<bool, StoreError> {
    let n = tx.execute("UPDATE previews SET consumed = 1 WHERE id = ?1 AND consumed = 0", [id.to_string()])?;
    Ok(n == 1)
}

pub fn count_live_previews(tx: &Transaction<'_>, session_id: Uuid, now: &str) -> Result<u64, StoreError> {
    let n: i64 = tx.query_row(
        "SELECT COUNT(*) FROM previews WHERE session_id = ?1 AND consumed = 0 AND expires_at > ?2",
        params![session_id.to_string(), now],
        |r| r.get(0),
    )?;
    Ok(n as u64)
}

#[allow(clippy::too_many_arguments)]
pub fn insert_message(
    tx: &Transaction<'_>,
    id: Uuid,
    session_id: Uuid,
    run_id: Option<Uuid>,
    role: Role,
    status: MessageStatus,
    created_sequence: u64,
    text: &str,
    manifest_id: Option<Uuid>,
) -> Result<(), StoreError> {
    tx.execute(
        "INSERT INTO messages(id, session_id, run_id, role, status, created_sequence, text, manifest_id)
         VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
        params![
            id.to_string(),
            session_id.to_string(),
            run_id.map(|r| r.to_string()),
            enum_str(role),
            enum_str(status),
            created_sequence as i64,
            text,
            manifest_id.map(|m| m.to_string())
        ],
    )?;
    Ok(())
}

pub fn finalize_message(
    tx: &Transaction<'_>,
    id: Uuid,
    status: MessageStatus,
    text: &str,
    citations_json: &str,
) -> Result<(), StoreError> {
    tx.execute(
        "UPDATE messages SET status = ?2, text = ?3, citations = ?4 WHERE id = ?1",
        params![id.to_string(), enum_str(status), text, citations_json],
    )?;
    Ok(())
}

pub fn set_message_validation(tx: &Transaction<'_>, id: Uuid, report_json: &str) -> Result<(), StoreError> {
    tx.execute("UPDATE messages SET validation = ?2 WHERE id = ?1", params![id.to_string(), report_json])?;
    Ok(())
}

pub fn append_message_text(tx: &Transaction<'_>, id: Uuid, text: &str) -> Result<(), StoreError> {
    tx.execute("UPDATE messages SET text = text || ?2 WHERE id = ?1", params![id.to_string(), text])?;
    Ok(())
}

pub fn get_message(tx: &Transaction<'_>, id: Uuid) -> Result<Option<MessageRow>, StoreError> {
    let mut stmt = tx.prepare(
        "SELECT id, run_id, role, status, created_sequence, text, citations, manifest_id, validation FROM messages WHERE id = ?1",
    )?;
    let mut rows = message_rows(&mut stmt, params![id.to_string()])?;
    Ok(rows.pop())
}

/// A message only if it belongs to `session_id` (history is never taken from another session).
pub fn get_session_message(tx: &Transaction<'_>, session_id: Uuid, id: Uuid) -> Result<Option<MessageRow>, StoreError> {
    let mut stmt = tx.prepare(
        "SELECT id, run_id, role, status, created_sequence, text, citations, manifest_id, validation FROM messages
         WHERE id = ?1 AND session_id = ?2",
    )?;
    let mut rows = message_rows(&mut stmt, params![id.to_string(), session_id.to_string()])?;
    Ok(rows.pop())
}

/// Most recent `limit` messages with `created_sequence < before`, returned in ascending order.
pub fn list_messages(
    tx: &Transaction<'_>,
    session_id: Uuid,
    before: u64,
    limit: u64,
) -> Result<Vec<MessageRow>, StoreError> {
    let before = before.min(i64::MAX as u64) as i64;
    let mut stmt = tx.prepare(
        "SELECT id, run_id, role, status, created_sequence, text, citations, manifest_id, validation FROM messages
         WHERE session_id = ?1 AND created_sequence < ?2 ORDER BY created_sequence DESC LIMIT ?3",
    )?;
    let mut rows = message_rows(&mut stmt, params![session_id.to_string(), before, limit as i64])?;
    rows.reverse();
    Ok(rows)
}

fn message_rows(stmt: &mut rusqlite::Statement<'_>, p: impl rusqlite::Params) -> Result<Vec<MessageRow>, StoreError> {
    type Raw = (String, Option<String>, String, String, i64, String, String, Option<String>, Option<String>);
    let raws: Vec<Raw> = stmt
        .query_map(p, |r| {
            Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, r.get(4)?, r.get(5)?, r.get(6)?, r.get(7)?, r.get(8)?))
        })?
        .collect::<Result<_, _>>()?;
    raws.into_iter()
        .map(|(id, run, role, status, seq, text, citations, manifest, validation)| {
            Ok(MessageRow {
                id: uuid(&id)?,
                run_id: run.as_deref().map(uuid).transpose()?,
                role: enum_from(role)?,
                status: enum_from(status)?,
                created_sequence: seq as u64,
                text,
                citations,
                manifest_id: manifest.as_deref().map(uuid).transpose()?,
                validation,
            })
        })
        .collect()
}

pub fn insert_attempt(
    tx: &Transaction<'_>,
    id: Uuid,
    run_id: Uuid,
    state: &str,
    epoch: u64,
    now: &str,
) -> Result<(), StoreError> {
    tx.execute(
        "INSERT INTO attempts(id, run_id, state, epoch, started_at) VALUES(?1, ?2, ?3, ?4, ?5)",
        params![id.to_string(), run_id.to_string(), state, epoch as i64, now],
    )?;
    Ok(())
}

pub fn set_attempt_state(
    tx: &Transaction<'_>,
    run_id: Uuid,
    state: &str,
    ended_at: Option<&str>,
) -> Result<(), StoreError> {
    tx.execute(
        "UPDATE attempts SET state = ?2, ended_at = COALESCE(?3, ended_at) WHERE run_id = ?1",
        params![run_id.to_string(), state, ended_at],
    )?;
    Ok(())
}

pub fn attempt_state(tx: &Transaction<'_>, run_id: Uuid) -> Result<Option<String>, StoreError> {
    Ok(tx.query_row("SELECT state FROM attempts WHERE run_id = ?1", [run_id.to_string()], |r| r.get(0)).optional()?)
}

pub fn store_output(tx: &Transaction<'_>, run_id: Uuid, raw: &[u8]) -> Result<(), StoreError> {
    tx.execute("INSERT INTO outputs(run_id, raw) VALUES(?1, ?2)", params![run_id.to_string(), raw])?;
    Ok(())
}

pub fn load_output(tx: &Transaction<'_>, run_id: Uuid) -> Result<Option<Vec<u8>>, StoreError> {
    Ok(tx.query_row("SELECT raw FROM outputs WHERE run_id = ?1", [run_id.to_string()], |r| r.get(0)).optional()?)
}

pub fn non_terminal_runs(tx: &Transaction<'_>) -> Result<Vec<(Uuid, Uuid)>, StoreError> {
    let mut stmt = tx.prepare(
        "SELECT id, session_id FROM runs WHERE state NOT IN ('COMPLETED', 'FAILED', 'CANCELLED', 'INTERRUPTED')",
    )?;
    let raws: Vec<(String, String)> = stmt.query_map([], |r| Ok((r.get(0)?, r.get(1)?)))?.collect::<Result<_, _>>()?;
    raws.into_iter().map(|(r, s)| Ok((uuid(&r)?, uuid(&s)?))).collect()
}

#[cfg(test)]
#[path = "turns.test.rs"]
mod tests;
