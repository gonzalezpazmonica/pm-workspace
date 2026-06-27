use reqwest::Client;
use serde::{Deserialize, Serialize};

// HTTP QUERY client examples — Rust / reqwest (RFC 10008)
// http crate >= 2026-06-16 has Method::QUERY (hyperium/http PR #798)
// reqwest will expose it once it bumps the http dependency

/// Send an HTTP QUERY request and deserialize the JSON response.
///
/// QUERY is safe, idempotent and cacheable (RFC 10008) — use for complex
/// read queries whose criteria don't fit in a URL query string.
pub async fn query_resource<T, R>(url: &str, criteria: &T) -> Result<R, reqwest::Error>
where
    T: Serialize,
    R: for<'de> Deserialize<'de>,
{
    // Method::from_bytes works in all reqwest versions.
    // Use Method::QUERY once reqwest bumps to http crate with the constant.
    let method = reqwest::Method::from_bytes(b"QUERY").unwrap();

    Client::new()
        .request(method, url)
        .json(criteria)
        .send()
        .await?
        .json()
        .await
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::{json, Value};

    // Integration test — requires running server on :3000
    #[ignore]
    #[tokio::test]
    async fn test_query_resource() {
        let criteria = json!({ "status": "active", "limit": 5 });
        let result: Value = query_resource("http://localhost:3000/search", &criteria)
            .await
            .expect("QUERY failed");
        assert!(result.get("results").is_some());
    }
}

#[tokio::main]
async fn main() {
    use serde_json::{json, Value};

    let criteria = json!({
        "status": "active",
        "tags": ["production"],
        "limit": 10,
    });

    match query_resource::<_, Value>("http://localhost:3000/search", &criteria).await {
        Ok(results) => println!("QUERY results: {}", results),
        Err(e) => eprintln!("Error: {}", e),
    }
}
