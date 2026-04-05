use serde::Serialize;

#[derive(Serialize, Clone, Debug)]
pub struct ShieldHealth {
    pub daemon_up: bool,
    pub ner_available: bool,
    pub ollama_up: bool,
    pub ollama_models: Vec<String>,
    pub proxy_up: bool,
    pub timestamp: String,
}

pub fn poll_shield_health() -> ShieldHealth {
    let client = reqwest::blocking::Client::builder()
        .timeout(std::time::Duration::from_secs(2))
        .build()
        .unwrap_or_else(|_| {
            reqwest::blocking::Client::builder()
                .timeout(std::time::Duration::from_secs(2))
                .build()
                .expect("http client")
        });

    let port = std::env::var("SAVIA_SHIELD_PORT").unwrap_or_else(|_| "8444".to_string());
    let proxy_port =
        std::env::var("SAVIA_SHIELD_PROXY_PORT").unwrap_or_else(|_| "8443".to_string());

    // Check daemon health
    let (daemon_up, ner_available) = match client
        .get(format!("http://127.0.0.1:{}/health", port))
        .send()
    {
        Ok(resp) => {
            if let Ok(json) = resp.json::<serde_json::Value>() {
                (
                    json["status"] == "ok",
                    json["ner"].as_bool().unwrap_or(false),
                )
            } else {
                (false, false)
            }
        }
        Err(_) => (false, false),
    };

    // Check Ollama
    let (ollama_up, ollama_models) = match client
        .get("http://127.0.0.1:11434/api/tags")
        .send()
    {
        Ok(resp) => {
            if let Ok(json) = resp.json::<serde_json::Value>() {
                let models: Vec<String> = json["models"]
                    .as_array()
                    .map(|arr| {
                        arr.iter()
                            .filter_map(|m| m["name"].as_str().map(String::from))
                            .collect()
                    })
                    .unwrap_or_default();
                (true, models)
            } else {
                (true, vec![])
            }
        }
        Err(_) => (false, vec![]),
    };

    // Check proxy — any HTTP response (even 502) means it's running
    let proxy_up = match client
        .get(format!("http://127.0.0.1:{}/", proxy_port))
        .send()
    {
        Ok(_) => true,
        Err(e) => !e.is_connect() && !e.is_timeout(),
    };

    ShieldHealth {
        daemon_up,
        ner_available,
        ollama_up,
        ollama_models,
        proxy_up,
        timestamp: chrono::Utc::now().to_rfc3339(),
    }
}

#[tauri::command]
pub fn get_shield_health() -> ShieldHealth {
    poll_shield_health()
}
