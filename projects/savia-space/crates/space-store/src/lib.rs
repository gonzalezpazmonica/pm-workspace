//! Durable private state of Savia Space: SQLite journal and instance lock.

pub mod catalog;
pub mod lock;
pub mod retention;
pub mod store;
pub mod turns;

pub use lock::{InstanceLock, LockError};
pub use rusqlite::Transaction;
pub use store::{
    IdemKey, IdemOutcome, SCHEMA_VERSION, SessionRow, Store, StoreError, append_event, bump_session, idem_lookup,
    idem_record, insert_run, run_state, set_run_state,
};

#[cfg(test)]
#[path = "lib.test.rs"]
mod tests;
