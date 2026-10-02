use super::*;
use crate::context::SourceText;
use space_contracts::Sha256Hex;
use space_contracts::model::{ClaimSupport, ModelCitation, ModelClaim, NoteSourceRef, Span};

fn src(index: u8, text: &str) -> SourceText {
    SourceText {
        index,
        title: format!("n{index}"),
        r#ref: NoteSourceRef {
            dome_id: "d".into(),
            resource_id: format!("r{index}"),
            content_hash: Sha256Hex::of_bytes(text.as_bytes()),
            span: Span { start: 0, end: text.chars().count() as u64 },
        },
        text: text.into(),
    }
}

fn cite(i: u8, q: &str) -> ModelCitation {
    ModelCitation { source_index: i, quote: q.into() }
}

fn claim(t: &str, s: ClaimSupport, idx: &[u8]) -> ModelClaim {
    ModelClaim { text: t.into(), support: s, citation_indexes: idx.to_vec() }
}

fn out(citations: Vec<ModelCitation>, claims: Vec<ModelClaim>) -> ModelOutput {
    ModelOutput { text: "Resumen.".into(), citations, claims }
}

#[test]
fn pass_when_every_source_has_a_verified_citation() {
    let s = [src(0, "El cielo es azul."), src(1, "La hierba es verde.")];
    let o =
        out(vec![cite(0, "cielo es azul"), cite(1, "hierba es verde")], vec![claim("x", ClaimSupport::Quoted, &[0])]);
    let v = validate(&o, &s);
    assert_eq!(v.status, ValidationStatus::Pass, "{:?}", v.issues);
    assert!(v.citations.iter().all(|c| c.verified && c.r#match == QuoteMatch::Exact));
}

#[test]
fn fail_when_a_source_is_not_cited() {
    let s = [src(0, "El cielo es azul."), src(1, "La hierba es verde.")];
    let o = out(vec![cite(0, "cielo es azul"), cite(0, "El cielo")], vec![]);
    let v = validate(&o, &s);
    assert_eq!(v.status, ValidationStatus::Fail);
    assert!(v.issues.contains(&Issue::SourceUncited(1)));
}

#[test]
fn empty_citations_never_pass() {
    let s = [src(0, "Texto.")];
    assert_eq!(validate(&out(vec![], vec![]), &s).status, ValidationStatus::Fail);
}

#[test]
fn altered_quote_is_not_verified() {
    let s = [src(0, "El cielo es azul.")];
    let v = validate(&out(vec![cite(0, "el cielo es azul")], vec![]), &s);
    assert_eq!(v.citations[0].r#match, QuoteMatch::None);
    assert!(!v.citations[0].verified);
    assert_eq!(v.status, ValidationStatus::Fail);
}

#[test]
fn whitespace_differences_verify_as_whitespace_match() {
    let s = [src(0, "Primera línea\ny  segunda.")];
    let v = validate(&out(vec![cite(0, "línea y segunda")], vec![]), &s);
    assert_eq!(v.citations[0].r#match, QuoteMatch::Whitespace);
    assert!(v.citations[0].verified);
    assert_eq!(v.status, ValidationStatus::Pass);
}

#[test]
fn index_outside_selection_fails() {
    let s = [src(0, "Texto.")];
    let v = validate(&out(vec![cite(0, "Texto"), cite(3, "x")], vec![]), &s);
    assert!(v.issues.contains(&Issue::IndexOutsideSelection(3)));
    assert_eq!(v.status, ValidationStatus::Fail);
}

#[test]
fn quoted_claim_needs_a_verified_citation() {
    let s = [src(0, "Texto real.")];
    let o = out(vec![cite(0, "Texto real"), cite(0, "inventado")], vec![claim("c", ClaimSupport::Quoted, &[1])]);
    let v = validate(&o, &s);
    assert!(v.issues.contains(&Issue::ClaimWithoutVerifiedCitation(0)));
}

#[test]
fn unsupported_claim_fails_and_proposed_does_not() {
    let s = [src(0, "Texto real.")];
    let ok = out(vec![cite(0, "Texto real")], vec![claim("idea", ClaimSupport::Proposed, &[])]);
    assert_eq!(validate(&ok, &s).status, ValidationStatus::Pass);
    let bad = out(vec![cite(0, "Texto real")], vec![claim("dato", ClaimSupport::Unsupported, &[])]);
    assert!(validate(&bad, &s).issues.contains(&Issue::UnsupportedClaim(0)));
}

#[test]
fn quote_hash_is_of_the_model_quote_as_given() {
    let s = [src(0, "a  b")];
    let v = validate(&out(vec![cite(0, "a b")], vec![]), &s);
    assert_eq!(v.citations[0].quote_hash, Sha256Hex::of_bytes(b"a b"));
}
