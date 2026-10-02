//! Strict JSON parsing: UTF-8 only, duplicate keys rejected.
//!
//! `serde_json::from_slice::<Value>` silently keeps the last duplicate key; a hashed
//! document must never have two readings, so duplicates are an error here.

use serde::de::{self, DeserializeSeed, Deserializer, MapAccess, SeqAccess, Visitor};
use serde_json::{Map, Number, Value};
use std::fmt;

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum JsonError {
    #[error("invalid JSON: {0}")]
    Syntax(String),
}

/// Parses `bytes` as a single JSON document, rejecting duplicate object keys.
pub fn parse_strict(bytes: &[u8]) -> Result<Value, JsonError> {
    let mut de = serde_json::Deserializer::from_slice(bytes);
    let value = StrictValue.deserialize(&mut de).map_err(|e| JsonError::Syntax(e.to_string()))?;
    de.end().map_err(|e| JsonError::Syntax(e.to_string()))?;
    Ok(value)
}

struct StrictValue;

impl<'de> DeserializeSeed<'de> for StrictValue {
    type Value = Value;
    fn deserialize<D: Deserializer<'de>>(self, d: D) -> Result<Value, D::Error> {
        d.deserialize_any(StrictVisitor)
    }
}

struct StrictVisitor;

impl<'de> Visitor<'de> for StrictVisitor {
    type Value = Value;

    fn expecting(&self, f: &mut fmt::Formatter) -> fmt::Result {
        f.write_str("a JSON value")
    }
    fn visit_unit<E>(self) -> Result<Value, E> {
        Ok(Value::Null)
    }
    fn visit_bool<E>(self, v: bool) -> Result<Value, E> {
        Ok(Value::Bool(v))
    }
    fn visit_i64<E>(self, v: i64) -> Result<Value, E> {
        Ok(Value::Number(v.into()))
    }
    fn visit_u64<E>(self, v: u64) -> Result<Value, E> {
        Ok(Value::Number(v.into()))
    }
    fn visit_f64<E: de::Error>(self, v: f64) -> Result<Value, E> {
        Number::from_f64(v).map(Value::Number).ok_or_else(|| E::custom("non-finite number"))
    }
    fn visit_str<E>(self, v: &str) -> Result<Value, E> {
        Ok(Value::String(v.to_owned()))
    }
    fn visit_string<E>(self, v: String) -> Result<Value, E> {
        Ok(Value::String(v))
    }
    fn visit_seq<A: SeqAccess<'de>>(self, mut seq: A) -> Result<Value, A::Error> {
        let mut items = Vec::new();
        while let Some(item) = seq.next_element_seed(StrictValue)? {
            items.push(item);
        }
        Ok(Value::Array(items))
    }
    fn visit_map<A: MapAccess<'de>>(self, mut map: A) -> Result<Value, A::Error> {
        let mut out = Map::new();
        while let Some(key) = map.next_key::<String>()? {
            if out.contains_key(&key) {
                return Err(de::Error::custom(format!("duplicate key `{key}`")));
            }
            let value = map.next_value_seed(StrictValue)?;
            out.insert(key, value);
        }
        Ok(Value::Object(out))
    }
}

#[cfg(test)]
#[path = "json.test.rs"]
mod tests;
