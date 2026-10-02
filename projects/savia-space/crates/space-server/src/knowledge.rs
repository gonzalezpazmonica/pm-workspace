//! Knowledge port: search candidates and read notes with the person's own access.
//!
//! `Fixtures` serves the synthetic N1 corpus embedded in the binary. `Vaults` (see `vaults.rs`)
//! talks to savia-vaults over MCP with the person's reader token.

use crate::vaults::Vaults;
use space_contracts::Sha256Hex;

pub const FIXTURE_DOME: &str = "fixtures";

const CORPUS: &[(&str, &str)] = &[
    ("huerto-riego.md", include_str!("../../../fixtures/n1/notes/huerto-riego.md")),
    ("huerto-cultivos.md", include_str!("../../../fixtures/n1/notes/huerto-cultivos.md")),
    ("huerto-asamblea.md", include_str!("../../../fixtures/n1/notes/huerto-asamblea.md")),
];

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Hit {
    pub dome_id: String,
    pub resource_id: String,
    pub heading: String,
    pub snippet: String,
    pub degraded: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Note {
    pub dome_id: String,
    pub resource_id: String,
    pub title: String,
    pub text_base: String,
    pub content_hash: Sha256Hex,
}

#[derive(Debug, thiserror::Error)]
pub enum KnowledgeError {
    #[error("knowledge source unavailable: {0}")]
    Unavailable(String),
}

pub enum Knowledge {
    Fixtures,
    Vaults(Box<Vaults>),
}

/// CRLF and CR become LF; nothing else changes (no Unicode normalization).
pub fn normalize_text(s: &str) -> String {
    s.replace("\r\n", "\n").replace('\r', "\n")
}

pub fn title_of(text: &str, fallback: &str) -> String {
    text.lines()
        .find(|l| !l.trim().is_empty())
        .map(|l| l.trim_start_matches('#').trim().to_owned())
        .filter(|t| !t.is_empty())
        .unwrap_or_else(|| fallback.to_owned())
}

pub fn snippet_of(text: &str, max_chars: usize) -> String {
    let flat = text.split_whitespace().collect::<Vec<_>>().join(" ");
    flat.chars().take(max_chars).collect()
}

impl Knowledge {
    pub fn fixtures() -> Self {
        Self::Fixtures
    }

    pub async fn search(&self, queries: &[String], domes: &[String], limit: usize) -> Result<Vec<Hit>, KnowledgeError> {
        match self {
            Self::Fixtures => {
                if !domes.iter().any(|d| d == FIXTURE_DOME) {
                    return Ok(vec![]);
                }
                let terms: Vec<String> = queries
                    .iter()
                    .flat_map(|q| q.split_whitespace().map(str::to_lowercase).collect::<Vec<_>>())
                    .filter(|t| t.chars().count() > 2)
                    .collect();
                let mut scored: Vec<(usize, &str, &str)> = CORPUS
                    .iter()
                    .map(|(id, text)| {
                        let lower = text.to_lowercase();
                        (terms.iter().map(|t| lower.matches(t.as_str()).count()).sum(), *id, *text)
                    })
                    .filter(|(score, _, _)| *score > 0)
                    .collect();
                scored.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(b.1)));
                Ok(scored
                    .into_iter()
                    .take(limit)
                    .map(|(_, id, text)| Hit {
                        dome_id: FIXTURE_DOME.into(),
                        resource_id: id.into(),
                        heading: title_of(text, id),
                        snippet: snippet_of(text, 480),
                        degraded: true,
                    })
                    .collect())
            }
            Self::Vaults(v) => v.search(queries, domes, limit).await,
        }
    }

    pub async fn read(&self, dome: &str, resource: &str) -> Result<Option<Note>, KnowledgeError> {
        match self {
            Self::Fixtures => Ok((dome == FIXTURE_DOME)
                .then(|| CORPUS.iter().find(|(id, _)| *id == resource))
                .flatten()
                .map(|(id, text)| {
                    let text_base = normalize_text(text);
                    Note {
                        dome_id: FIXTURE_DOME.into(),
                        resource_id: (*id).into(),
                        title: title_of(&text_base, id),
                        content_hash: Sha256Hex::of_bytes(text_base.as_bytes()),
                        text_base,
                    }
                })),
            Self::Vaults(v) => v.read(dome, resource).await,
        }
    }
}

#[cfg(test)]
#[path = "knowledge.test.rs"]
mod tests;
