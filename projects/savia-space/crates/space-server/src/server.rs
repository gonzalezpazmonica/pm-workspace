//! Process wiring: state dir, lock, recovery, provider routing, pairing channel, HTTP serve.

use crate::app::{AppState, router};
use crate::config::{Config, ProfileKind};
use crate::knowledge::{FIXTURE_DOME, Knowledge};
use crate::ollama::OllamaProvider;
use crate::vaults::{Vaults, VaultsConfig};
use space_contracts::model::NoteSourceRef;
use space_core::provider::{MockProvider, Provider, ProviderEvent};
use space_core::runtime::{BoxFuture, Revalidator, Runtime, RuntimeOptions};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use tokio::sync::{mpsc, watch};

/// Re-reads every source with the person's access and compares content hashes.
pub struct KnowledgeRevalidator {
    fixtures: Knowledge,
    vaults: Option<Arc<Knowledge>>,
}

impl KnowledgeRevalidator {
    #[cfg(test)]
    pub fn fixtures_only() -> Self {
        Self { fixtures: Knowledge::fixtures(), vaults: None }
    }

    pub fn new(vaults: Option<Arc<Knowledge>>) -> Self {
        Self { fixtures: Knowledge::fixtures(), vaults }
    }
}

impl Revalidator for KnowledgeRevalidator {
    fn still_valid<'a>(&'a self, refs: &'a [NoteSourceRef]) -> BoxFuture<'a, bool> {
        Box::pin(async move {
            for r in refs {
                let k = if r.dome_id == FIXTURE_DOME { Some(&self.fixtures) } else { self.vaults.as_deref() };
                let Some(k) = k else { return false };
                match k.read(&r.dome_id, &r.resource_id).await {
                    Ok(Some(n)) if n.content_hash == r.content_hash => {}
                    _ => return false,
                }
            }
            true
        })
    }
}

/// Routes the approved body to the adapter of its `model` (one profile per model name).
pub struct ProviderRouter {
    by_model: HashMap<String, Arc<dyn Provider>>,
}

impl ProviderRouter {
    pub fn from_config(cfg: &Config) -> Self {
        let mut by_model: HashMap<String, Arc<dyn Provider>> = HashMap::new();
        for p in &cfg.profiles {
            let provider: Arc<dyn Provider> = match p.kind {
                ProfileKind::Mock => Arc::new(MockProvider { chunk_delay: std::time::Duration::from_millis(40) }),
                ProfileKind::Ollama => Arc::new(OllamaProvider::new(p.port.unwrap_or(11434))),
            };
            by_model.insert(p.model.clone(), provider);
        }
        Self { by_model }
    }

    pub fn route(&self, body: &[u8]) -> Option<Arc<dyn Provider>> {
        let v: serde_json::Value = serde_json::from_slice(body).ok()?;
        self.by_model.get(v["model"].as_str()?).cloned()
    }
}

impl Provider for ProviderRouter {
    fn dispatch(&self, body: Vec<u8>, cancel: watch::Receiver<bool>) -> mpsc::Receiver<ProviderEvent> {
        match self.route(&body) {
            Some(p) => p.dispatch(body, cancel),
            None => {
                let (tx, rx) = mpsc::channel(1);
                let _ = tx.try_send(ProviderEvent::Failed);
                rx
            }
        }
    }
}

pub fn default_state_dir() -> PathBuf {
    if let Ok(dir) = std::env::var("SAVIA_SPACE_HOME") {
        return PathBuf::from(dir);
    }
    let base = std::env::var("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(std::env::var("HOME").unwrap_or_default()).join(".local/state"));
    base.join("savia-space")
}

/// The state directory must be private to its owner. Never fixes permissions on its own.
pub fn check_state_dir(dir: &Path) -> Result<(), String> {
    let meta = std::fs::metadata(dir).map_err(|e| format!("state dir: {e}"))?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        if meta.permissions().mode() & 0o077 != 0 {
            return Err(format!("{} is readable by other users; run: chmod 700 {}", dir.display(), dir.display()));
        }
    }
    let _ = meta;
    Ok(())
}

#[cfg(unix)]
pub fn spawn_pairing_listener<F>(
    sock: &Path,
    state_dir: &Path,
    issue: F,
) -> std::io::Result<tokio::task::JoinHandle<()>>
where
    F: Fn() -> String + Send + 'static,
{
    use std::os::unix::fs::{MetadataExt, PermissionsExt};
    use tokio::io::AsyncWriteExt;
    let _ = std::fs::remove_file(sock);
    let listener = tokio::net::UnixListener::bind(sock)?;
    std::fs::set_permissions(sock, std::fs::Permissions::from_mode(0o600))?;
    let owner = std::fs::metadata(state_dir)?.uid();
    Ok(tokio::spawn(async move {
        loop {
            let Ok((mut stream, _)) = listener.accept().await else { continue };
            let same_user = stream.peer_cred().map(|c| c.uid() == owner).unwrap_or(false);
            if same_user {
                let code = issue();
                let _ = stream.write_all(format!("{code}\n").as_bytes()).await;
            }
            let _ = stream.shutdown().await;
        }
    }))
}

pub async fn serve(state_dir: PathBuf, web_dir: Option<PathBuf>) -> Result<(), String> {
    std::fs::create_dir_all(&state_dir).map_err(|e| e.to_string())?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        // Only on first creation: an existing directory is checked, never changed.
        if std::fs::read_dir(&state_dir).map(|mut d| d.next().is_none()).unwrap_or(false) {
            let _ = std::fs::set_permissions(&state_dir, std::fs::Permissions::from_mode(0o700));
        }
    }
    check_state_dir(&state_dir)?;
    let _lock = space_store::InstanceLock::acquire(&state_dir).map_err(|e| e.to_string())?;
    let config = Config::load_or_init(&state_dir).map_err(|e| e.to_string())?;
    let store = space_store::Store::open(&state_dir.join("space.db")).map_err(|e| e.to_string())?;
    let vaults = match &config.vaults {
        Some(v) => {
            let token = match &v.token_file {
                Some(path) => {
                    check_state_dir(path.parent().unwrap_or(Path::new("/")))?;
                    Some(std::fs::read_to_string(path).map_err(|e| format!("token file: {e}"))?.trim().to_owned())
                }
                None => None,
            };
            Some(Arc::new(Knowledge::Vaults(Box::new(Vaults::new(VaultsConfig {
                command: v.command.clone(),
                cwd: v.cwd.clone(),
                token,
            })))))
        }
        None => None,
    };
    let runtime = Runtime::new(
        store,
        Arc::new(ProviderRouter::from_config(&config)),
        Arc::new(KnowledgeRevalidator::new(vaults.clone())),
        RuntimeOptions {
            principal: "local".into(),
            epoch: space_contracts::clock::now_millis() as u64,
            slots: 2,
            queue_timeout: std::time::Duration::from_secs(300),
            cancel_timeout: std::time::Duration::from_secs(5),
        },
    );
    runtime.recover().await.map_err(|e| e.message)?;
    let state = Arc::new(AppState {
        runtime,
        config: config.clone(),
        fixtures: Knowledge::fixtures(),
        vaults,
        pairing: Mutex::new(HashMap::new()),
        candidates: Mutex::new(HashMap::new()),
    });
    let _retention = {
        let st = state.clone();
        tokio::spawn(async move {
            loop {
                let days = st.config.retention_days;
                let purged = st
                    .runtime
                    .db(move |s| {
                        let tx = s.begin()?;
                        let r = space_store::retention::purge(
                            &tx,
                            space_contracts::clock::now_millis(),
                            days,
                            crate::app::WEB_MAX_MS,
                        )
                        .map_err(space_core::runtime::ApiError::from)?;
                        tx.commit()
                            .map_err(|e| space_core::runtime::ApiError::from(space_store::StoreError::from(e)))?;
                        Ok(r)
                    })
                    .await;
                if let Ok(r) = purged
                    && r.sessions + r.orphan_captures > 0
                {
                    eprintln!("retención: {} sesiones y {} capturas sueltas eliminadas", r.sessions, r.orphan_captures);
                }
                tokio::time::sleep(std::time::Duration::from_secs(3600)).await;
            }
        })
    };
    #[cfg(unix)]
    let _pairing = {
        let st = state.clone();
        spawn_pairing_listener(&state_dir.join("pair.sock"), &state_dir, move || st.issue_pairing_code())
            .map_err(|e| format!("pairing socket: {e}"))?
    };
    let addr: std::net::SocketAddr =
        format!("{}:{}", config.bind, config.port).parse().map_err(|e| format!("bind: {e}"))?;
    let listener = tokio::net::TcpListener::bind(addr).await.map_err(|e| format!("bind {addr}: {e}"))?;
    eprintln!("Savia Space escuchando en http://{addr} (solo esta máquina). Empareja con: savia-space pair");
    let app = router(state, web_dir);
    axum::serve(listener, app)
        .with_graceful_shutdown(async {
            let _ = tokio::signal::ctrl_c().await;
        })
        .await
        .map_err(|e| e.to_string())
}

#[cfg(unix)]
pub async fn pair(state_dir: PathBuf) -> Result<String, String> {
    use tokio::io::AsyncReadExt;
    let mut s = tokio::net::UnixStream::connect(state_dir.join("pair.sock"))
        .await
        .map_err(|e| format!("no hay servidor en marcha ({e})"))?;
    let mut out = String::new();
    s.read_to_string(&mut out).await.map_err(|e| e.to_string())?;
    let code = out.trim().to_owned();
    if code.is_empty() { Err("el servidor rechazó la petición".into()) } else { Ok(code) }
}

#[cfg(test)]
#[path = "server.test.rs"]
mod tests;
