//! Savia Space contracts: strict JSON, canonical form, hashes and shared types.

pub mod clock;
pub mod hash;
pub mod jcs;
pub mod json;
pub mod model;

pub use hash::Sha256Hex;

#[cfg(test)]
#[path = "lib.test.rs"]
mod tests;
