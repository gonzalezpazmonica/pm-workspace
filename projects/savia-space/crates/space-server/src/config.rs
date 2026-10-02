//! Private configuration in the state directory (`config.json`, mode 0600).

use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use uuid::Uuid;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Config {
    pub schema_version: u32,
    pub bind: String,
    pub port: u16,
    pub retention_days: u32,
    pub projects: Vec<ProjectConfig>,
    pub profiles: Vec<ProfileConfig>,
    pub vaults: Option<VaultsSettings>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ProjectConfig {
    pub id: Uuid,
    pub title: String,
    pub knowledge: KnowledgeKind,
    pub dome_ids: Vec<String>,
    /// Canonical agents tree (`.opencode/agents`) of the workspace; `None` = built-in agent.
    pub agents_dir: Option<PathBuf>,
    pub default_agent: String,
    pub profile_ids: Vec<String>,
    pub default_profile: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum KnowledgeKind {
    Fixtures,
    Vaults,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct VaultsSettings {
    pub command: Vec<String>,
    pub cwd: Option<PathBuf>,
    /// File (mode 0600) holding the person's reader token.
    pub token_file: Option<PathBuf>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ProfileKind {
    Mock,
    Ollama,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ProfileConfig {
    pub id: String,
    pub kind: ProfileKind,
    pub model: String,
    pub port: Option<u16>,
    pub context_window: u64,
    pub output_reserve: u64,
    pub margin_tokens: u64,
}

#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("invalid config: {0}")]
    Invalid(String),
    #[error("config io: {0}")]
    Io(#[from] std::io::Error),
    #[error("config json: {0}")]
    Json(#[from] serde_json::Error),
}

impl Config {
    pub fn default_local() -> Self {
        Self {
            schema_version: 1,
            bind: "127.0.0.1".into(),
            port: 8737,
            retention_days: 30,
            projects: vec![ProjectConfig {
                id: Uuid::from_u128(0x0199_a000_0000_7000_8000_0000_0000_0001),
                title: "Huerto comunitario (datos sintéticos)".into(),
                knowledge: KnowledgeKind::Fixtures,
                dome_ids: vec![crate::knowledge::FIXTURE_DOME.into()],
                agents_dir: None,
                default_agent: "resumen".into(),
                profile_ids: vec!["mock".into(), "gemma3-4b".into()],
                default_profile: "mock".into(),
            }],
            profiles: vec![
                ProfileConfig {
                    id: "mock".into(),
                    kind: ProfileKind::Mock,
                    model: "fixture-v1".into(),
                    port: None,
                    context_window: 16_384,
                    output_reserve: 1024,
                    margin_tokens: 256,
                },
                ProfileConfig {
                    id: "gemma3-4b".into(),
                    kind: ProfileKind::Ollama,
                    model: "gemma3:4b".into(),
                    port: Some(11434),
                    context_window: 16_384,
                    output_reserve: 1024,
                    margin_tokens: 256,
                },
            ],
            vaults: None,
        }
    }

    pub fn validate(&self) -> Result<(), ConfigError> {
        let bad = |m: &str| Err(ConfigError::Invalid(m.into()));
        if !matches!(self.bind.as_str(), "127.0.0.1" | "::1") {
            return bad("bind must be 127.0.0.1 or ::1");
        }
        if !(7..=365).contains(&self.retention_days) {
            return bad("retentionDays must be 7–365");
        }
        if self.projects.is_empty() || self.projects.len() > 20 {
            return bad("1–20 projects");
        }
        for p in &self.projects {
            if !(1..=120).contains(&p.title.len()) || p.dome_ids.is_empty() || p.dome_ids.len() > 8 {
                return bad("project title 1–120 bytes and 1–8 domes");
            }
            if !p.profile_ids.contains(&p.default_profile)
                || p.profile_ids.iter().any(|id| !self.profiles.iter().any(|pr| &pr.id == id))
            {
                return bad("project profiles must exist and include the default");
            }
            if p.knowledge == KnowledgeKind::Vaults && self.vaults.is_none() {
                return bad("vaults knowledge needs a vaults section");
            }
        }
        for pr in &self.profiles {
            if pr.output_reserve + pr.margin_tokens >= pr.context_window {
                return bad("profile reserve must fit the context window");
            }
        }
        Ok(())
    }

    pub fn load_or_init(state_dir: &Path) -> Result<Self, ConfigError> {
        let path = state_dir.join("config.json");
        if !path.exists() {
            let c = Self::default_local();
            write_private(&path, serde_json::to_string_pretty(&c)?.as_bytes())?;
            return Ok(c);
        }
        let raw = std::fs::read(&path)?;
        let value = space_contracts::json::parse_strict(&raw).map_err(|e| ConfigError::Invalid(e.to_string()))?;
        let c: Self = serde_json::from_value(value)?;
        c.validate()?;
        Ok(c)
    }

    pub fn project(&self, id: Uuid) -> Option<&ProjectConfig> {
        self.projects.iter().find(|p| p.id == id)
    }

    pub fn profile(&self, id: &str) -> Option<&ProfileConfig> {
        self.profiles.iter().find(|p| p.id == id)
    }
}

/// Creates a file readable only by its owner (0600 on Unix).
pub fn write_private(path: &Path, bytes: &[u8]) -> std::io::Result<()> {
    use std::io::Write;
    let mut opts = std::fs::OpenOptions::new();
    opts.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        opts.mode(0o600);
    }
    let mut f = opts.open(path)?;
    f.write_all(bytes)
}

#[cfg(test)]
#[path = "config.test.rs"]
mod tests;
