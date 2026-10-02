//! SQLite journal: sessions, events, runs, idempotency. Single writer; short transactions.

use rusqlite::{Connection, OptionalExtension, Transaction, params};
use space_contracts::Sha256Hex;
use space_contracts::model::{ErrorCode, Event, EventBody, PROTOCOL_VERSION, RunState};
use std::path::Path;
use uuid::Uuid;

pub const SCHEMA_VERSION: i64 = 1;

const MIGRATION_0001: &str = include_str!("../migrations/0001_init.sql");

#[derive(Debug, thiserror::Error)]
pub enum StoreError {
    #[error("database error: {0}")]
    Db(#[from] rusqlite::Error),
    #[error("database schema {0} is newer than this build supports")]
    SchemaTooNew(i64),
    #[error("run is already in a terminal state")]
    TerminalRun,
    #[error("stored data is corrupt: {0}")]
    Corrupt(String),
}

pub struct Store {
    pub(crate) conn: Connection,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SessionRow {
    pub id: Uuid,
    pub project_id: Uuid,
    pub title: String,
    pub revision: u64,
    pub state: String,
    pub created_at: String,
    pub updated_at: String,
}

impl Store {
    pub fn open(path: &Path) -> Result<Self, StoreError> {
        let conn = Connection::open(path)?;
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.pragma_update(None, "synchronous", "FULL")?;
        conn.pragma_update(None, "foreign_keys", "ON")?;
        conn.busy_timeout(std::time::Duration::from_secs(5))?;
        let mut store = Self { conn };
        store.migrate()?;
        Ok(store)
    }

    fn migrate(&mut self) -> Result<(), StoreError> {
        let tx = self.conn.transaction()?;
        tx.execute_batch("CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);")?;
        let current: Option<i64> = tx
            .query_row("SELECT CAST(value AS INTEGER) FROM meta WHERE key='schema_version'", [], |r| r.get(0))
            .optional()?;
        match current {
            None => {
                tx.execute_batch(MIGRATION_0001)?;
                tx.execute("INSERT INTO meta(key, value) VALUES('schema_version', ?1)", [SCHEMA_VERSION.to_string()])?;
            }
            Some(v) if v > SCHEMA_VERSION => return Err(StoreError::SchemaTooNew(v)),
            Some(_) => {}
        }
        tx.commit()?;
        Ok(())
    }

    pub fn schema_version(&self) -> i64 {
        self.conn
            .query_row("SELECT CAST(value AS INTEGER) FROM meta WHERE key='schema_version'", [], |r| r.get(0))
            .unwrap_or(0)
    }

    /// Reads a pragma as text (diagnostics and tests).
    pub fn pragma(&self, name: &str) -> String {
        self.conn
            .query_row(&format!("PRAGMA {name}"), [], |r| r.get::<_, rusqlite::types::Value>(0))
            .map(|v| match v {
                rusqlite::types::Value::Integer(i) => i.to_string(),
                rusqlite::types::Value::Text(t) => t,
                other => format!("{other:?}"),
            })
            .unwrap_or_default()
    }

    pub fn begin(&mut self) -> Result<Transaction<'_>, StoreError> {
        Ok(self.conn.transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)?)
    }

    pub fn create_session(&mut self, project_id: Uuid, title: &str, now: &str) -> Result<SessionRow, StoreError> {
        let id = Uuid::now_v7();
        self.conn.execute(
            "INSERT INTO sessions(id, project_id, title, revision, state, created_at, updated_at)
             VALUES(?1, ?2, ?3, 1, 'OPEN', ?4, ?4)",
            params![id.to_string(), project_id.to_string(), title, now],
        )?;
        self.get_session(id)?.ok_or_else(|| StoreError::Corrupt("session vanished".into()))
    }

    pub fn get_session(&self, id: Uuid) -> Result<Option<SessionRow>, StoreError> {
        Ok(self
            .conn
            .query_row(
                "SELECT id, project_id, title, revision, state, created_at, updated_at FROM sessions WHERE id = ?1",
                [id.to_string()],
                session_from_row,
            )
            .optional()?)
    }

    /// Highest committed sequence of a session (0 when empty).
    pub fn watermark(&self, session_id: Uuid) -> Result<u64, StoreError> {
        let w: i64 = self.conn.query_row(
            "SELECT COALESCE(MAX(sequence), 0) FROM events WHERE session_id = ?1",
            [session_id.to_string()],
            |r| r.get(0),
        )?;
        Ok(w as u64)
    }

    pub fn events_after(&self, session_id: Uuid, after: u64) -> Result<Vec<Event>, StoreError> {
        let mut stmt = self.conn.prepare(
            "SELECT event_id, sequence, run_id, occurred_at, body FROM events
             WHERE session_id = ?1 AND sequence > ?2 ORDER BY sequence",
        )?;
        let rows = stmt.query_map(params![session_id.to_string(), after as i64], |r| {
            Ok((
                r.get::<_, String>(0)?,
                r.get::<_, i64>(1)?,
                r.get::<_, Option<String>>(2)?,
                r.get::<_, String>(3)?,
                r.get::<_, String>(4)?,
            ))
        })?;
        let mut out = Vec::new();
        for row in rows {
            let (event_id, sequence, run_id, occurred_at, body) = row?;
            out.push(Event {
                protocol_version: PROTOCOL_VERSION,
                event_id: parse_uuid(&event_id)?,
                sequence: sequence as u64,
                session_id,
                run_id: run_id.as_deref().map(parse_uuid).transpose()?,
                occurred_at,
                body: serde_json::from_str(&body).map_err(|e| StoreError::Corrupt(e.to_string()))?,
            });
        }
        Ok(out)
    }
}

fn parse_uuid(s: &str) -> Result<Uuid, StoreError> {
    Uuid::parse_str(s).map_err(|e| StoreError::Corrupt(e.to_string()))
}

fn uuid_col(r: &rusqlite::Row<'_>, idx: usize) -> rusqlite::Result<Uuid> {
    let s: String = r.get(idx)?;
    Uuid::parse_str(&s)
        .map_err(|e| rusqlite::Error::FromSqlConversionFailure(idx, rusqlite::types::Type::Text, Box::new(e)))
}

fn session_from_row(r: &rusqlite::Row<'_>) -> rusqlite::Result<SessionRow> {
    Ok(SessionRow {
        id: uuid_col(r, 0)?,
        project_id: uuid_col(r, 1)?,
        title: r.get(2)?,
        revision: r.get::<_, i64>(3)? as u64,
        state: r.get(4)?,
        created_at: r.get(5)?,
        updated_at: r.get(6)?,
    })
}

/// Appends an event inside the caller's transaction and returns it with its sequence.
pub fn append_event(
    tx: &Transaction<'_>,
    session_id: Uuid,
    run_id: Option<Uuid>,
    body: &EventBody,
    now: &str,
) -> Result<Event, StoreError> {
    let next: i64 = tx.query_row(
        "SELECT COALESCE(MAX(sequence), 0) + 1 FROM events WHERE session_id = ?1",
        [session_id.to_string()],
        |r| r.get(0),
    )?;
    let event_id = Uuid::now_v7();
    let body_json = serde_json::to_string(body).map_err(|e| StoreError::Corrupt(e.to_string()))?;
    tx.execute(
        "INSERT INTO events(session_id, sequence, event_id, run_id, occurred_at, body)
         VALUES(?1, ?2, ?3, ?4, ?5, ?6)",
        params![session_id.to_string(), next, event_id.to_string(), run_id.map(|r| r.to_string()), now, body_json],
    )?;
    Ok(Event {
        protocol_version: PROTOCOL_VERSION,
        event_id,
        sequence: next as u64,
        session_id,
        run_id,
        occurred_at: now.to_owned(),
        body: body.clone(),
    })
}

/// Scope of an idempotency key: principal + operation + target.
#[derive(Clone, Copy, Debug)]
pub struct IdemKey<'a> {
    pub principal: &'a str,
    pub operation: &'a str,
    pub target: Option<&'a str>,
    pub key: &'a str,
}

#[derive(Debug, PartialEq, Eq)]
pub enum IdemOutcome {
    /// First time this key is seen in its scope.
    New,
    /// Same key and same request: return the stored response, do nothing else.
    Replay(String),
    /// Same key, different request.
    Conflict,
}

pub fn idem_lookup(tx: &Transaction<'_>, k: &IdemKey<'_>, request_hash: &Sha256Hex) -> Result<IdemOutcome, StoreError> {
    let row: Option<(String, String)> = tx
        .query_row(
            "SELECT request_hash, response FROM idempotency
             WHERE principal = ?1 AND operation = ?2 AND target = ?3 AND key = ?4",
            params![k.principal, k.operation, k.target.unwrap_or(""), k.key],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .optional()?;
    Ok(match row {
        None => IdemOutcome::New,
        Some((h, resp)) if h == request_hash.as_str() => IdemOutcome::Replay(resp),
        Some(_) => IdemOutcome::Conflict,
    })
}

pub fn idem_record(
    tx: &Transaction<'_>,
    k: &IdemKey<'_>,
    request_hash: &Sha256Hex,
    response: &str,
    now: &str,
) -> Result<(), StoreError> {
    tx.execute(
        "INSERT INTO idempotency(principal, operation, target, key, request_hash, response, created_at)
         VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7)",
        params![k.principal, k.operation, k.target.unwrap_or(""), k.key, request_hash.as_str(), response, now],
    )?;
    Ok(())
}

/// Compare-and-swap of the session revision. `None` when `expected` is stale.
/// `turn` also renews `last_turn_at`, the retention anchor.
pub fn bump_session(
    tx: &Transaction<'_>,
    id: Uuid,
    expected: u64,
    now: &str,
    turn: bool,
) -> Result<Option<u64>, StoreError> {
    let n = tx.execute(
        "UPDATE sessions SET revision = revision + 1, updated_at = ?3,
                last_turn_at = CASE WHEN ?4 THEN ?3 ELSE last_turn_at END
         WHERE id = ?1 AND revision = ?2",
        params![id.to_string(), expected as i64, now, turn],
    )?;
    Ok((n == 1).then_some(expected + 1))
}

fn state_str(s: RunState) -> String {
    serde_json::to_value(s).ok().and_then(|v| v.as_str().map(str::to_owned)).unwrap_or_default()
}

pub fn insert_run(
    tx: &Transaction<'_>,
    id: Uuid,
    session_id: Uuid,
    state: RunState,
    now: &str,
) -> Result<(), StoreError> {
    tx.execute(
        "INSERT INTO runs(id, session_id, revision, state, created_at, updated_at) VALUES(?1, ?2, 1, ?3, ?4, ?4)",
        params![id.to_string(), session_id.to_string(), state_str(state), now],
    )?;
    Ok(())
}

pub fn run_state(tx: &Transaction<'_>, id: Uuid) -> Result<Option<(RunState, u64)>, StoreError> {
    let row: Option<(String, i64)> = tx
        .query_row("SELECT state, revision FROM runs WHERE id = ?1", [id.to_string()], |r| Ok((r.get(0)?, r.get(1)?)))
        .optional()?;
    row.map(|(s, rev)| {
        serde_json::from_value(serde_json::Value::String(s))
            .map(|st| (st, rev as u64))
            .map_err(|e| StoreError::Corrupt(e.to_string()))
    })
    .transpose()
}

/// Moves a run to `state`, refusing to leave a terminal state. Returns the new revision.
pub fn set_run_state(
    tx: &Transaction<'_>,
    id: Uuid,
    state: RunState,
    reason: Option<ErrorCode>,
    now: &str,
) -> Result<u64, StoreError> {
    let (current, revision) = run_state(tx, id)?.ok_or_else(|| StoreError::Corrupt(format!("run {id} not found")))?;
    if current.is_terminal() {
        return Err(StoreError::TerminalRun);
    }
    let reason = reason.and_then(|r| serde_json::to_value(r).ok()).and_then(|v| v.as_str().map(str::to_owned));
    tx.execute(
        "UPDATE runs SET state = ?2, terminal_reason = ?3, revision = revision + 1, updated_at = ?4 WHERE id = ?1",
        params![id.to_string(), state_str(state), reason, now],
    )?;
    Ok(revision + 1)
}

#[cfg(test)]
#[path = "store.test.rs"]
mod tests;
