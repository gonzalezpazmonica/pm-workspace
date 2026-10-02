//! Incremental extraction of the top-level `text` value from a streamed JSON object.
//!
//! The model streams `ModelOutput` JSON. Only the public `text` may reach the screen while it
//! streams: never raw JSON, citations or other keys. Keys may come in any order; escapes and
//! surrogate pairs may be split across chunks.

pub const MAX_RAW_BYTES: usize = 32 * 1024;

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum DecodeError {
    #[error("model output exceeds 32 KiB")]
    TooLarge,
    #[error("malformed JSON string in model output")]
    Malformed,
}

#[derive(Default)]
enum Str {
    #[default]
    Plain,
    Escape,
    Unicode(String),
}

#[derive(Default)]
pub struct TextExtractor {
    raw: String,
    depth: u32,
    in_string: bool,
    str_state: Str,
    pending_high: Option<u16>,
    current: String,
    is_key: bool,
    expect_key: bool,
    last_key: String,
    value_is_text: bool,
    awaiting_value: bool,
}

impl TextExtractor {
    /// Feeds a chunk; returns the newly decoded characters of the `text` value.
    pub fn push(&mut self, chunk: &str) -> Result<String, DecodeError> {
        if self.raw.len() + chunk.len() > MAX_RAW_BYTES {
            return Err(DecodeError::TooLarge);
        }
        self.raw.push_str(chunk);
        let mut out = String::new();
        for c in chunk.chars() {
            if self.in_string {
                self.string_char(c, &mut out)?;
            } else {
                self.structural_char(c);
            }
        }
        Ok(out)
    }

    pub fn raw(&self) -> &str {
        &self.raw
    }

    fn structural_char(&mut self, c: char) {
        match c {
            '{' => {
                self.depth += 1;
                self.expect_key = self.depth == 1;
                self.awaiting_value = false;
            }
            '[' => {
                self.depth += 1;
                self.awaiting_value = false;
            }
            '}' | ']' => self.depth = self.depth.saturating_sub(1),
            ',' => self.expect_key = self.depth == 1,
            ':' => self.awaiting_value = self.depth == 1,
            '"' => {
                self.in_string = true;
                self.current.clear();
                self.is_key = self.expect_key && self.depth == 1;
                self.value_is_text = !self.is_key && self.awaiting_value && self.last_key == "text";
                self.expect_key = false;
                self.awaiting_value = false;
            }
            _ => {
                if !c.is_whitespace() {
                    self.awaiting_value = false;
                }
            }
        }
    }

    fn emit(&mut self, ch: char, out: &mut String) {
        if self.is_key {
            self.current.push(ch);
        } else if self.value_is_text {
            out.push(ch);
        }
    }

    fn emit_unit(&mut self, unit: u16, out: &mut String) -> Result<(), DecodeError> {
        match (self.pending_high.take(), unit) {
            (None, 0xD800..=0xDBFF) => self.pending_high = Some(unit),
            (None, 0xDC00..=0xDFFF) => return Err(DecodeError::Malformed),
            (None, u) => {
                let ch = char::from_u32(u as u32).ok_or(DecodeError::Malformed)?;
                self.emit(ch, out);
            }
            (Some(hi), 0xDC00..=0xDFFF) => {
                let cp = 0x10000 + (((hi as u32) - 0xD800) << 10) + ((unit as u32) - 0xDC00);
                let ch = char::from_u32(cp).ok_or(DecodeError::Malformed)?;
                self.emit(ch, out);
            }
            (Some(_), _) => return Err(DecodeError::Malformed),
        }
        Ok(())
    }

    fn string_char(&mut self, c: char, out: &mut String) -> Result<(), DecodeError> {
        match std::mem::take(&mut self.str_state) {
            Str::Plain => match c {
                '\\' => self.str_state = Str::Escape,
                '"' => {
                    if self.pending_high.is_some() {
                        return Err(DecodeError::Malformed);
                    }
                    self.in_string = false;
                    if self.is_key {
                        self.last_key = std::mem::take(&mut self.current);
                    }
                    self.value_is_text = false;
                }
                c => {
                    if self.pending_high.is_some() || (c as u32) < 0x20 {
                        return Err(DecodeError::Malformed);
                    }
                    self.emit(c, out);
                }
            },
            Str::Escape => {
                let simple = match c {
                    '"' => Some('"'),
                    '\\' => Some('\\'),
                    '/' => Some('/'),
                    'b' => Some('\u{08}'),
                    'f' => Some('\u{0C}'),
                    'n' => Some('\n'),
                    'r' => Some('\r'),
                    't' => Some('\t'),
                    'u' => None,
                    _ => return Err(DecodeError::Malformed),
                };
                match simple {
                    Some(ch) => {
                        if self.pending_high.is_some() {
                            return Err(DecodeError::Malformed);
                        }
                        self.emit(ch, out);
                    }
                    None => self.str_state = Str::Unicode(String::new()),
                }
            }
            Str::Unicode(mut hex) => {
                if !c.is_ascii_hexdigit() {
                    return Err(DecodeError::Malformed);
                }
                hex.push(c);
                if hex.len() == 4 {
                    let unit = u16::from_str_radix(&hex, 16).map_err(|_| DecodeError::Malformed)?;
                    self.emit_unit(unit, out)?;
                } else {
                    self.str_state = Str::Unicode(hex);
                }
            }
        }
        Ok(())
    }
}

#[cfg(test)]
#[path = "decoder.test.rs"]
mod tests;
