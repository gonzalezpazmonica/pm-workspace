//! JSON Canonicalization Scheme (RFC 8785) restricted to integers.
//!
//! Hashed documents (request, manifest, provider body) only carry integers in the safe range
//! ±(2^53 − 1). That keeps number serialization trivial and identical across Rust, TypeScript
//! and Python; floats are rejected instead of being formatted. Object keys are sorted by their
//! UTF-16 code units, as RFC 8785 requires (not by Rust `str` ordering).

use serde_json::Value;

/// Largest integer every JSON implementation represents exactly (2^53 − 1).
pub const MAX_SAFE_INTEGER: i64 = 9_007_199_254_740_991;

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum JcsError {
    #[error("non-integer number in a canonical document")]
    NonInteger,
    #[error("integer outside the safe range ±(2^53 − 1)")]
    UnsafeInteger,
}

/// Returns the canonical UTF-8 bytes of `value`.
pub fn canonicalize(value: &Value) -> Result<Vec<u8>, JcsError> {
    let mut out = String::new();
    write_value(value, &mut out)?;
    Ok(out.into_bytes())
}

fn write_value(value: &Value, out: &mut String) -> Result<(), JcsError> {
    match value {
        Value::Null => out.push_str("null"),
        Value::Bool(true) => out.push_str("true"),
        Value::Bool(false) => out.push_str("false"),
        Value::Number(n) => {
            let i = match (n.as_i64(), n.as_u64()) {
                (Some(i), _) => i,
                (None, Some(_)) => return Err(JcsError::UnsafeInteger),
                (None, None) => return Err(JcsError::NonInteger),
            };
            if !(-MAX_SAFE_INTEGER..=MAX_SAFE_INTEGER).contains(&i) {
                return Err(JcsError::UnsafeInteger);
            }
            out.push_str(&i.to_string());
        }
        Value::String(s) => write_string(s, out),
        Value::Array(items) => {
            out.push('[');
            for (idx, item) in items.iter().enumerate() {
                if idx > 0 {
                    out.push(',');
                }
                write_value(item, out)?;
            }
            out.push(']');
        }
        Value::Object(map) => {
            let mut entries: Vec<(&String, &Value)> = map.iter().collect();
            entries.sort_by(|(a, _), (b, _)| a.encode_utf16().cmp(b.encode_utf16()));
            out.push('{');
            for (idx, (key, item)) in entries.into_iter().enumerate() {
                if idx > 0 {
                    out.push(',');
                }
                write_string(key, out);
                out.push(':');
                write_value(item, out)?;
            }
            out.push('}');
        }
    }
    Ok(())
}

/// ECMAScript `JSON.stringify` string escaping, which RFC 8785 adopts.
fn write_string(s: &str, out: &mut String) {
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\u{08}' => out.push_str("\\b"),
            '\u{0C}' => out.push_str("\\f"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
}

#[cfg(test)]
#[path = "jcs.test.rs"]
mod tests;
