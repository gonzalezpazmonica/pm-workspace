//! SHA-256 hashes as 64 lowercase hex characters.

use crate::jcs::{self, JcsError};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fmt;

/// A SHA-256 digest in lowercase hex. Construction validates the format.
#[derive(Clone, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(try_from = "String", into = "String")]
pub struct Sha256Hex(String);

impl Sha256Hex {
    /// Hashes raw bytes.
    pub fn of_bytes(bytes: &[u8]) -> Self {
        Self(hex::encode(Sha256::digest(bytes)))
    }

    /// Hashes the JCS form of a JSON value.
    pub fn of_canonical(value: &serde_json::Value) -> Result<Self, JcsError> {
        Ok(Self::of_bytes(&jcs::canonicalize(value)?))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl TryFrom<String> for Sha256Hex {
    type Error = String;
    fn try_from(s: String) -> Result<Self, String> {
        let ok = s.len() == 64 && s.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b));
        if ok { Ok(Self(s)) } else { Err("hash must be 64 lowercase hex characters".into()) }
    }
}

impl From<Sha256Hex> for String {
    fn from(h: Sha256Hex) -> String {
        h.0
    }
}

impl fmt::Display for Sha256Hex {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

#[cfg(test)]
#[path = "hash.test.rs"]
mod tests;
