//! Savia Space domain: context assembly, validation, provider port and runtime.

pub use space_contracts::clock;
pub mod context;
pub mod decoder;
pub mod provider;
pub mod runtime;
pub mod validation;

#[cfg(test)]
#[path = "lib.test.rs"]
mod tests;
