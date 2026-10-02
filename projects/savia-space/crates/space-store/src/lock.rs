//! Exclusive instance lock on the private state directory (OS file lock).

use std::fs::{File, OpenOptions, TryLockError};
use std::path::Path;

#[derive(Debug, thiserror::Error)]
pub enum LockError {
    #[error("another Savia Space instance holds the state directory")]
    Held,
    #[error("cannot open lock file: {0}")]
    Io(#[from] std::io::Error),
}

/// Held for the life of the process; the OS releases it on drop or crash.
#[derive(Debug)]
pub struct InstanceLock {
    _file: File,
}

impl InstanceLock {
    pub fn acquire(state_dir: &Path) -> Result<Self, LockError> {
        let file = OpenOptions::new().create(true).truncate(false).write(true).open(state_dir.join("lock"))?;
        match file.try_lock() {
            Ok(()) => Ok(Self { _file: file }),
            Err(TryLockError::WouldBlock) => Err(LockError::Held),
            Err(TryLockError::Error(e)) => Err(LockError::Io(e)),
        }
    }
}

#[cfg(test)]
#[path = "lock.test.rs"]
mod tests;
