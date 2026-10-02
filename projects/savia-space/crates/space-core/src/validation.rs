//! Deterministic validation of model output against the captured sources.
//!
//! A citation is verified only if its quote appears in the span text exactly, or after
//! collapsing whitespace on both sides. Nothing fuzzy, no second model.

use crate::context::SourceText;
use serde::Serialize;
use space_contracts::Sha256Hex;
use space_contracts::model::{Citation, ClaimSupport, ModelClaim, ModelOutput, QuoteMatch};
use uuid::Uuid;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "UPPERCASE")]
pub enum ValidationStatus {
    Pass,
    Fail,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(tag = "code", content = "index", rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Issue {
    SourceUncited(u8),
    IndexOutsideSelection(u8),
    QuoteNotFound(usize),
    ClaimWithoutVerifiedCitation(usize),
    UnsupportedClaim(usize),
    OutputOutOfLimits,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Validated {
    pub text: String,
    pub citations: Vec<Citation>,
    pub claims: Vec<ModelClaim>,
    pub status: ValidationStatus,
    pub issues: Vec<Issue>,
}

fn collapse_ws(s: &str) -> String {
    s.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn find_match(text: &str, quote: &str) -> QuoteMatch {
    if quote.is_empty() {
        QuoteMatch::None
    } else if text.contains(quote) {
        QuoteMatch::Exact
    } else if collapse_ws(text).contains(&collapse_ws(quote)) {
        QuoteMatch::Whitespace
    } else {
        QuoteMatch::None
    }
}

pub fn validate(output: &ModelOutput, sources: &[SourceText]) -> Validated {
    let mut issues = Vec::new();
    let mut citations = Vec::new();
    for (i, c) in output.citations.iter().enumerate() {
        let source = sources.iter().find(|s| s.index == c.source_index);
        let (verified_match, r#ref) = match source {
            Some(s) => (find_match(&s.text, &c.quote), Some(s.r#ref.clone())),
            None => {
                issues.push(Issue::IndexOutsideSelection(c.source_index));
                (QuoteMatch::None, None)
            }
        };
        if source.is_some() && verified_match == QuoteMatch::None {
            issues.push(Issue::QuoteNotFound(i));
        }
        if let Some(r#ref) = r#ref {
            citations.push(Citation {
                id: Uuid::now_v7(),
                source_index: c.source_index,
                r#ref,
                quote: c.quote.clone(),
                quote_hash: Sha256Hex::of_bytes(c.quote.as_bytes()),
                verified: verified_match != QuoteMatch::None,
                r#match: verified_match,
            });
        }
    }
    for s in sources {
        let cited = citations.iter().any(|c| c.source_index == s.index && c.verified);
        if !cited {
            issues.push(Issue::SourceUncited(s.index));
        }
    }
    for (i, claim) in output.claims.iter().enumerate() {
        match claim.support {
            ClaimSupport::Quoted | ClaimSupport::Inferred => {
                let ok = claim.citation_indexes.iter().any(|ci| {
                    output
                        .citations
                        .get(*ci as usize)
                        .and_then(|mc| {
                            citations.iter().find(|c| c.source_index == mc.source_index && c.quote == mc.quote)
                        })
                        .is_some_and(|c| c.verified)
                });
                if !ok {
                    issues.push(Issue::ClaimWithoutVerifiedCitation(i));
                }
            }
            ClaimSupport::Unsupported => issues.push(Issue::UnsupportedClaim(i)),
            ClaimSupport::Proposed => {}
        }
    }
    if output.validate().is_err() {
        issues.push(Issue::OutputOutOfLimits);
    }
    let status = if issues.is_empty() { ValidationStatus::Pass } else { ValidationStatus::Fail };
    Validated { text: output.text.clone(), citations, claims: output.claims.clone(), status, issues }
}

#[cfg(test)]
#[path = "validation.test.rs"]
mod tests;
