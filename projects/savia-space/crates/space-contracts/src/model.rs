//! Shared protocol types (protocol version 1). All DTOs reject unknown fields.

use crate::hash::Sha256Hex;
use crate::jcs::JcsError;
use serde::{Deserialize, Serialize};
pub use uuid::Uuid;

pub const PROTOCOL_VERSION: u32 = 1;
pub const MAX_PROMPT_BYTES: usize = 16 * 1024;
pub const MAX_SKILLS: usize = 4;
pub const MAX_HISTORY_MESSAGES: usize = 16;
pub const MAX_OUTPUT_BYTES: usize = 32 * 1024;
pub const MAX_CITATIONS: usize = 8;
pub const MAX_CLAIMS: usize = 20;
pub const MAX_QUOTE_BYTES: usize = 240;
pub const MAX_SOURCES: usize = 8;

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
#[error("{field}: {reason}")]
pub struct ValidationError {
    pub field: &'static str,
    pub reason: &'static str,
}

fn check(ok: bool, field: &'static str, reason: &'static str) -> Result<(), ValidationError> {
    if ok { Ok(()) } else { Err(ValidationError { field, reason }) }
}

/// Idempotency keys and similar tokens: printable ASCII, 1–128 bytes.
pub fn is_valid_key(k: &str) -> bool {
    (1..=128).contains(&k.len()) && k.bytes().all(|b| (0x21..=0x7e).contains(&b))
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ErrorCode {
    InvalidInput,
    Unauthenticated,
    OriginDenied,
    NotFound,
    Conflict,
    StaleRevision,
    ContextChanged,
    Gone,
    ContextLimit,
    EgressDenied,
    UnsupportedCapability,
    OutputLimit,
    ValidationFailed,
    RateLimited,
    ProviderFailed,
    ProviderProtocol,
    CancelUnconfirmed,
    Interrupted,
    Unavailable,
}

impl ErrorCode {
    /// HTTP status for synchronous errors; `None` for codes only reported as run events.
    pub fn http_status(self) -> Option<u16> {
        use ErrorCode::*;
        match self {
            InvalidInput => Some(400),
            Unauthenticated => Some(401),
            OriginDenied => Some(403),
            NotFound => Some(404),
            Conflict | StaleRevision | ContextChanged => Some(409),
            Gone => Some(410),
            ContextLimit | EgressDenied | UnsupportedCapability => Some(422),
            RateLimited => Some(429),
            Unavailable => Some(503),
            OutputLimit | ValidationFailed | ProviderFailed | ProviderProtocol | CancelUnconfirmed | Interrupted => {
                None
            }
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ErrorEnvelope {
    pub code: ErrorCode,
    pub message: String,
    pub request_id: Uuid,
    pub retryable: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum RunState {
    Queued,
    Resolving,
    Running,
    Validating,
    Cancelling,
    Completed,
    Failed,
    Cancelled,
    Interrupted,
}

impl RunState {
    pub fn is_terminal(self) -> bool {
        matches!(self, Self::Completed | Self::Failed | Self::Cancelled | Self::Interrupted)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum RefOwner {
    Workspace,
    Vaults,
    Space,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CanonicalRef {
    pub owner: RefOwner,
    pub id: String,
    pub version: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum PresetId {
    Resume,
    Compare,
    DraftSpec,
}

impl PresetId {
    pub fn minimum_sources(self) -> usize {
        match self {
            Self::Compare => 2,
            Self::Resume | Self::DraftSpec => 1,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct PrepareRequest {
    pub preset_id: PresetId,
    pub preset_version: Sha256Hex,
    pub prompt: String,
    pub selection_id: Uuid,
    pub selection_revision: u64,
    pub agent_ref: CanonicalRef,
    pub skill_refs: Vec<CanonicalRef>,
    pub history_message_ids: Vec<Uuid>,
    pub provider_profile_id: String,
    pub expected_session_revision: u64,
    pub idempotency_key: String,
}

impl PrepareRequest {
    pub fn validate(&self) -> Result<(), ValidationError> {
        check(self.prompt.len() <= MAX_PROMPT_BYTES, "prompt", "exceeds 16 KiB")?;
        check(self.skill_refs.len() <= MAX_SKILLS, "skillRefs", "more than 4")?;
        check(self.history_message_ids.len() <= MAX_HISTORY_MESSAGES, "historyMessageIds", "more than 16")?;
        check((1..=64).contains(&self.provider_profile_id.len()), "providerProfileId", "1–64 bytes")?;
        check(self.selection_revision >= 1, "selectionRevision", "must be ≥ 1")?;
        check(self.expected_session_revision >= 1, "expectedSessionRevision", "must be ≥ 1")?;
        check(is_valid_key(&self.idempotency_key), "idempotencyKey", "printable ASCII 1–128")
    }

    /// `SHA256(JCS(request without idempotencyKey))`.
    pub fn request_hash(&self) -> Result<Sha256Hex, JcsError> {
        let mut v = serde_json::to_value(self).map_err(|_| JcsError::NonInteger)?;
        if let Some(obj) = v.as_object_mut() {
            obj.remove("idempotencyKey");
        }
        Sha256Hex::of_canonical(&v)
    }
}

/// `PrepareRequest` plus the three hashes of the preview the person inspected.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(from = "RunCreationWire", into = "RunCreationWire")]
pub struct RunCreation {
    pub request: PrepareRequest,
    pub approved_preview_id: Uuid,
    pub approved_manifest_hash: Sha256Hex,
    pub approved_payload_hash: Sha256Hex,
}

/// Flat wire shape; `#[serde(flatten)]` cannot be combined with `deny_unknown_fields`.
#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct RunCreationWire {
    preset_id: PresetId,
    preset_version: Sha256Hex,
    prompt: String,
    selection_id: Uuid,
    selection_revision: u64,
    agent_ref: CanonicalRef,
    skill_refs: Vec<CanonicalRef>,
    history_message_ids: Vec<Uuid>,
    provider_profile_id: String,
    expected_session_revision: u64,
    idempotency_key: String,
    approved_preview_id: Uuid,
    approved_manifest_hash: Sha256Hex,
    approved_payload_hash: Sha256Hex,
}

impl From<RunCreationWire> for RunCreation {
    fn from(w: RunCreationWire) -> Self {
        Self {
            request: PrepareRequest {
                preset_id: w.preset_id,
                preset_version: w.preset_version,
                prompt: w.prompt,
                selection_id: w.selection_id,
                selection_revision: w.selection_revision,
                agent_ref: w.agent_ref,
                skill_refs: w.skill_refs,
                history_message_ids: w.history_message_ids,
                provider_profile_id: w.provider_profile_id,
                expected_session_revision: w.expected_session_revision,
                idempotency_key: w.idempotency_key,
            },
            approved_preview_id: w.approved_preview_id,
            approved_manifest_hash: w.approved_manifest_hash,
            approved_payload_hash: w.approved_payload_hash,
        }
    }
}

impl From<RunCreation> for RunCreationWire {
    fn from(c: RunCreation) -> Self {
        let r = c.request;
        Self {
            preset_id: r.preset_id,
            preset_version: r.preset_version,
            prompt: r.prompt,
            selection_id: r.selection_id,
            selection_revision: r.selection_revision,
            agent_ref: r.agent_ref,
            skill_refs: r.skill_refs,
            history_message_ids: r.history_message_ids,
            provider_profile_id: r.provider_profile_id,
            expected_session_revision: r.expected_session_revision,
            idempotency_key: r.idempotency_key,
            approved_preview_id: c.approved_preview_id,
            approved_manifest_hash: c.approved_manifest_hash,
            approved_payload_hash: c.approved_payload_hash,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum StepKind {
    Resolve,
    Generate,
    Validate,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum StepStatus {
    Pending,
    Running,
    Completed,
    Failed,
    Skipped,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Step {
    pub id: Uuid,
    pub run_id: Uuid,
    pub kind: StepKind,
    pub status: StepStatus,
    pub started_at: Option<String>,
    pub ended_at: Option<String>,
    pub error_code: Option<ErrorCode>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Role {
    User,
    Assistant,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MessageStatus {
    Partial,
    Final,
    Interrupted,
    Failed,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Message {
    pub id: Uuid,
    pub session_id: Uuid,
    pub run_id: Option<Uuid>,
    pub role: Role,
    pub status: MessageStatus,
    pub created_sequence: u64,
    pub text: String,
    pub citations: Vec<Citation>,
    pub manifest_id: Option<Uuid>,
    /// Deterministic validation report of an assistant message (status and failed conditions).
    #[serde(default)]
    pub validation: Option<serde_json::Value>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Span {
    pub start: u64,
    pub end: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct NoteSourceRef {
    pub dome_id: String,
    pub resource_id: String,
    pub content_hash: Sha256Hex,
    pub span: Span,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "UPPERCASE")]
pub enum QuoteMatch {
    Exact,
    Whitespace,
    None,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ClaimSupport {
    Quoted,
    Inferred,
    Proposed,
    Unsupported,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Citation {
    pub id: Uuid,
    pub source_index: u8,
    pub r#ref: NoteSourceRef,
    pub quote: String,
    pub quote_hash: Sha256Hex,
    pub verified: bool,
    pub r#match: QuoteMatch,
}

/// What the model is allowed to produce. No IDs, `verified` or principal fields.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ModelOutput {
    pub text: String,
    pub citations: Vec<ModelCitation>,
    pub claims: Vec<ModelClaim>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ModelCitation {
    pub source_index: u8,
    pub quote: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ModelClaim {
    pub text: String,
    pub support: ClaimSupport,
    pub citation_indexes: Vec<u8>,
}

impl ModelOutput {
    pub fn validate(&self) -> Result<(), ValidationError> {
        check(self.text.len() <= MAX_OUTPUT_BYTES, "text", "exceeds 32 KiB")?;
        check(self.citations.len() <= MAX_CITATIONS, "citations", "more than 8")?;
        check(self.claims.len() <= MAX_CLAIMS, "claims", "more than 20")?;
        for c in &self.citations {
            check((c.source_index as usize) < MAX_SOURCES, "citations.sourceIndex", "must be 0–7")?;
            check(!c.quote.is_empty() && c.quote.len() <= MAX_QUOTE_BYTES, "citations.quote", "1–240 bytes")?;
        }
        for claim in &self.claims {
            check(claim.text.len() <= 1000, "claims.text", "exceeds 1000 bytes")?;
            check(
                claim.citation_indexes.iter().all(|i| (*i as usize) < self.citations.len()),
                "claims.citationIndexes",
                "points to a missing citation",
            )?;
        }
        Ok(())
    }
}

/// Event envelope; `body` serializes as `type` + `payload`. Only the server writes events, so
/// the envelope does not need `deny_unknown_fields` (serde cannot combine it with `flatten`);
/// every payload variant is still a closed shape.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Event {
    pub protocol_version: u32,
    pub event_id: Uuid,
    pub sequence: u64,
    pub session_id: Uuid,
    pub run_id: Option<Uuid>,
    pub occurred_at: String,
    #[serde(flatten)]
    pub body: EventBody,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum EventBody {
    #[serde(rename = "run.created", rename_all = "camelCase")]
    RunCreated { run_id: Uuid, state: RunState },
    #[serde(rename = "run.state", rename_all = "camelCase")]
    RunState { state: RunState, revision: u64, reason: Option<ErrorCode> },
    #[serde(rename = "step.state", rename_all = "camelCase")]
    StepState { step: Step },
    #[serde(rename = "message.created", rename_all = "camelCase")]
    MessageCreated { message: Message },
    #[serde(rename = "message.delta", rename_all = "camelCase")]
    MessageDelta { message_id: Uuid, offset: u64, text: String },
    #[serde(rename = "message.final", rename_all = "camelCase")]
    MessageFinal { message: Message },
    #[serde(rename = "context.dispatched", rename_all = "camelCase")]
    ContextDispatched { manifest_id: Uuid, manifest_hash: Sha256Hex, payload_hash: Sha256Hex, attempt_id: Uuid },
}

#[cfg(test)]
#[path = "model.test.rs"]
mod tests;
