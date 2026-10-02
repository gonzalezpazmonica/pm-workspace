use super::*;
use axum::body::Body;
use http_body_util::BodyExt;
use space_core::provider::MockProvider;
use space_core::runtime::RuntimeOptions;
use tower::ServiceExt;

const HOST: &str = "127.0.0.1:8737";
const ORIGIN: &str = "http://127.0.0.1:8737";

struct T {
    _dir: tempfile::TempDir,
    st: Shared,
    app: Router,
}

fn harness() -> T {
    let dir = tempfile::tempdir().expect("tmp");
    let store = space_store::Store::open(&dir.path().join("space.db")).expect("store");
    let runtime = Runtime::new(
        store,
        Arc::new(MockProvider { chunk_delay: std::time::Duration::ZERO }),
        Arc::new(crate::server::KnowledgeRevalidator::fixtures_only()),
        RuntimeOptions {
            principal: "local".into(),
            epoch: 1,
            slots: 2,
            queue_timeout: std::time::Duration::from_secs(5),
            cancel_timeout: std::time::Duration::from_millis(500),
        },
    );
    let st = Arc::new(AppState {
        runtime,
        config: Config::default_local(),
        fixtures: Knowledge::fixtures(),
        vaults: None,
        pairing: Mutex::new(HashMap::new()),
        candidates: Mutex::new(HashMap::new()),
    });
    let app = router(st.clone(), None);
    T { _dir: dir, st, app }
}

async fn call(
    t: &T,
    method: Method,
    path: &str,
    body: Option<Value>,
    cookie: Option<&str>,
) -> (StatusCode, Value, HeaderMap) {
    let mut req = Request::builder().method(method.clone()).uri(path).header(header::HOST, HOST);
    if method != Method::GET {
        req = req.header(header::ORIGIN, ORIGIN).header("x-space-request", "1");
    }
    if let Some(c) = cookie {
        req = req.header(header::COOKIE, format!("{COOKIE}={c}"));
    }
    let req = match body {
        Some(b) => req.header(header::CONTENT_TYPE, "application/json").body(Body::from(b.to_string())),
        None => req.body(Body::empty()),
    }
    .expect("request");
    let resp = t.app.clone().oneshot(req).await.expect("response");
    let status = resp.status();
    let headers = resp.headers().clone();
    let bytes = resp.into_body().collect().await.expect("body").to_bytes();
    let json = serde_json::from_slice(&bytes).unwrap_or(Value::Null);
    (status, json, headers)
}

async fn login(t: &T) -> String {
    let code = t.st.issue_pairing_code();
    let (status, _, headers) =
        call(t, Method::POST, "/api/v1/auth/session", Some(json!({"pairingCode": code})), None).await;
    assert_eq!(status, StatusCode::CREATED);
    let set = headers.get(header::SET_COOKIE).and_then(|v| v.to_str().ok()).expect("cookie").to_owned();
    assert!(set.contains("HttpOnly") && set.contains("SameSite=Strict"));
    set.split(';').next().and_then(|kv| kv.split_once('=')).map(|(_, v)| v.to_owned()).expect("token")
}

fn project() -> String {
    Config::default_local().projects[0].id.to_string()
}

#[tokio::test]
async fn health_is_public_and_minimal() {
    let t = harness();
    let (s, v, _) = call(&t, Method::GET, "/api/v1/health", None, None).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(v, json!({"protocolVersion": 1, "status": "READY"}));
}

#[tokio::test]
async fn foreign_host_or_origin_is_rejected_before_anything_else() {
    let t = harness();
    let req =
        Request::builder().uri("/api/v1/health").header(header::HOST, "evil.example").body(Body::empty()).expect("req");
    assert_eq!(t.app.clone().oneshot(req).await.expect("resp").status(), StatusCode::FORBIDDEN);
    let req = Request::builder()
        .method(Method::POST)
        .uri("/api/v1/auth/session")
        .header(header::HOST, HOST)
        .header(header::ORIGIN, "http://evil.example")
        .header("x-space-request", "1")
        .body(Body::from("{}"))
        .expect("req");
    assert_eq!(t.app.clone().oneshot(req).await.expect("resp").status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn mutation_without_marker_header_is_rejected() {
    let t = harness();
    let req = Request::builder()
        .method(Method::POST)
        .uri("/api/v1/auth/session")
        .header(header::HOST, HOST)
        .header(header::ORIGIN, ORIGIN)
        .header(header::CONTENT_TYPE, "application/json")
        .body(Body::from(json!({"pairingCode": "x"}).to_string()))
        .expect("req");
    assert_eq!(t.app.clone().oneshot(req).await.expect("resp").status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn api_requires_a_paired_session_and_codes_are_single_use() {
    let t = harness();
    let (s, v, _) = call(&t, Method::GET, "/api/v1/projects", None, None).await;
    assert_eq!(s, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "UNAUTHENTICATED");
    let code = t.st.issue_pairing_code();
    let body = json!({"pairingCode": code});
    assert_eq!(call(&t, Method::POST, "/api/v1/auth/session", Some(body.clone()), None).await.0, StatusCode::CREATED);
    assert_eq!(call(&t, Method::POST, "/api/v1/auth/session", Some(body), None).await.0, StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn logout_revokes_the_cookie() {
    let t = harness();
    let c = login(&t).await;
    assert_eq!(call(&t, Method::GET, "/api/v1/projects", None, Some(&c)).await.0, StatusCode::OK);
    assert_eq!(call(&t, Method::DELETE, "/api/v1/auth/session", None, Some(&c)).await.0, StatusCode::NO_CONTENT);
    assert_eq!(call(&t, Method::GET, "/api/v1/projects", None, Some(&c)).await.0, StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn unknown_project_and_session_are_404() {
    let t = harness();
    let c = login(&t).await;
    let path = format!("/api/v1/projects/{}/sessions", Uuid::now_v7());
    assert_eq!(call(&t, Method::GET, &path, None, Some(&c)).await.0, StatusCode::NOT_FOUND);
    let path = format!("/api/v1/sessions/{}/snapshot", Uuid::now_v7());
    assert_eq!(call(&t, Method::GET, &path, None, Some(&c)).await.0, StatusCode::NOT_FOUND);
}

/// J1 end to end with the mock provider: search → capture → select → prepare → run → export.
#[tokio::test]
async fn full_turn_with_mock_completes_and_exports() {
    let t = harness();
    let c = login(&t).await;
    let p = project();
    let (s, v, _) = call(
        &t,
        Method::POST,
        &format!("/api/v1/projects/{p}/sessions"),
        Some(json!({"title": "Riego", "idempotencyKey": "s1"})),
        Some(&c),
    )
    .await;
    assert_eq!(s, StatusCode::CREATED);
    let sid = v["session"]["id"].as_str().expect("sid").to_owned();

    let (s, v, _) = call(
        &t,
        Method::POST,
        &format!("/api/v1/projects/{p}/sources/search"),
        Some(json!({"queries": ["riego depósito"]})),
        Some(&c),
    )
    .await;
    assert_eq!(s, StatusCode::OK);
    let cand = v["candidates"][0]["id"].as_str().expect("candidate").to_owned();

    let (s, cap, _) = call(
        &t,
        Method::POST,
        &format!("/api/v1/projects/{p}/sources/capture"),
        Some(json!({"candidateId": cand})),
        Some(&c),
    )
    .await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(cap["coverage"], "FULL");

    let (s, sel, _) = call(
        &t,
        Method::PUT,
        &format!("/api/v1/sessions/{sid}/selection"),
        Some(json!({"captureIds": [cap["captureId"]], "expectedRevision": 0, "idempotencyKey": "sel1"})),
        Some(&c),
    )
    .await;
    assert_eq!(s, StatusCode::OK, "{sel}");

    let (_, cat, _) = call(&t, Method::GET, &format!("/api/v1/projects/{p}/catalog"), None, Some(&c)).await;
    let req = json!({
        "presetId": "resume", "presetVersion": cat["presets"][0]["version"], "prompt": "Resume el riego",
        "selectionId": sel["id"], "selectionRevision": sel["revision"], "agentRef": cat["agents"][0]["ref"],
        "skillRefs": [], "historyMessageIds": [], "providerProfileId": "mock",
        "expectedSessionRevision": 1, "idempotencyKey": "turn1"
    });
    let (s, preview, _) =
        call(&t, Method::POST, &format!("/api/v1/sessions/{sid}/prepare"), Some(req.clone()), Some(&c)).await;
    assert_eq!(s, StatusCode::CREATED, "{preview}");
    let body_text = preview["bodyText"].as_str().expect("body");
    assert_eq!(Sha256Hex::of_bytes(body_text.as_bytes()).as_str(), preview["payloadHash"], "client can verify");

    let req_template = req.clone();
    let mut creation = req.clone();
    creation["approvedPreviewId"] = preview["id"].clone();
    creation["approvedManifestHash"] = preview["manifestHash"].clone();
    creation["approvedPayloadHash"] = preview["payloadHash"].clone();
    let (s, run, _) = call(&t, Method::POST, &format!("/api/v1/sessions/{sid}/runs"), Some(creation), Some(&c)).await;
    assert_eq!(s, StatusCode::ACCEPTED, "{run}");
    let run_id = run["runId"].as_str().expect("run").to_owned();

    let mut done = false;
    for _ in 0..200 {
        let (_, snap, _) = call(&t, Method::GET, &format!("/api/v1/sessions/{sid}/snapshot"), None, Some(&c)).await;
        if snap["runs"][0]["state"] == "COMPLETED" {
            let assistant =
                snap["messages"].as_array().expect("m").iter().find(|m| m["role"] == "assistant").expect("a").clone();
            assert_eq!(assistant["status"], "final");
            assert!(assistant["citations"][0]["verified"].as_bool().expect("verified"));
            done = true;
            break;
        }
        tokio::time::sleep(std::time::Duration::from_millis(10)).await;
    }
    assert!(done, "run completed");

    let req = Request::builder()
        .uri(format!("/api/v1/runs/{run_id}/export"))
        .header(header::HOST, HOST)
        .header(header::COOKIE, format!("{COOKIE}={c}"))
        .body(Body::empty())
        .expect("req");
    let resp = t.app.clone().oneshot(req).await.expect("resp");
    assert_eq!(resp.status(), StatusCode::OK);
    assert_eq!(resp.headers()[header::CACHE_CONTROL], "no-store");
    let md = String::from_utf8(resp.into_body().collect().await.expect("b").to_bytes().to_vec()).expect("utf8");
    assert!(md.starts_with("# DRAFT — NEEDS_HUMAN_REVIEW"));
    assert!(!md.contains(&c), "no secrets in export");

    // History from another session is never accepted, even if the ids are real complete turns.
    let (_, snap, _) = call(&t, Method::GET, &format!("/api/v1/sessions/{sid}/snapshot"), None, Some(&c)).await;
    let foreign: Vec<Value> = snap["messages"].as_array().expect("m").iter().map(|m| m["id"].clone()).collect();
    assert_eq!(foreign.len(), 2);
    let (_, v, _) = call(
        &t,
        Method::POST,
        &format!("/api/v1/projects/{p}/sessions"),
        Some(json!({"title": "Otra", "idempotencyKey": "s2"})),
        Some(&c),
    )
    .await;
    let sid2 = v["session"]["id"].as_str().expect("sid").to_owned();
    let (_, found, _) = call(
        &t,
        Method::POST,
        &format!("/api/v1/projects/{p}/sources/search"),
        Some(json!({"queries": ["riego"]})),
        Some(&c),
    )
    .await;
    let (_, cap2, _) = call(
        &t,
        Method::POST,
        &format!("/api/v1/projects/{p}/sources/capture"),
        Some(json!({"candidateId": found["candidates"][0]["id"]})),
        Some(&c),
    )
    .await;
    let (s2, sel2, _) = call(
        &t,
        Method::PUT,
        &format!("/api/v1/sessions/{sid2}/selection"),
        Some(json!({"captureIds": [cap2["captureId"]], "expectedRevision": 0, "idempotencyKey": "sel2"})),
        Some(&c),
    )
    .await;
    assert_eq!(s2, StatusCode::OK, "{sel2}");
    let mut req2 = req_template;
    req2["selectionId"] = sel2["id"].clone();
    req2["selectionRevision"] = sel2["revision"].clone();
    req2["historyMessageIds"] = json!(foreign);
    req2["idempotencyKey"] = json!("turn2");
    let (s, err, _) = call(&t, Method::POST, &format!("/api/v1/sessions/{sid2}/prepare"), Some(req2), Some(&c)).await;
    assert_ne!(s, StatusCode::CREATED, "foreign history must be refused: {err}");
    assert_eq!(err["code"], "CONTEXT_LIMIT", "{s} {err}");
}

#[tokio::test]
async fn prepare_without_selection_and_with_wrong_profile_fail() {
    let t = harness();
    let c = login(&t).await;
    let p = project();
    let (_, v, _) = call(
        &t,
        Method::POST,
        &format!("/api/v1/projects/{p}/sessions"),
        Some(json!({"title": "X", "idempotencyKey": "s1"})),
        Some(&c),
    )
    .await;
    let sid = v["session"]["id"].as_str().expect("sid").to_owned();
    let (_, cat, _) = call(&t, Method::GET, &format!("/api/v1/projects/{p}/catalog"), None, Some(&c)).await;
    let mut req = json!({
        "presetId": "resume", "presetVersion": cat["presets"][0]["version"], "prompt": "x",
        "selectionId": Uuid::now_v7(), "selectionRevision": 1, "agentRef": cat["agents"][0]["ref"],
        "skillRefs": [], "historyMessageIds": [], "providerProfileId": "mock",
        "expectedSessionRevision": 1, "idempotencyKey": "t1"
    });
    let (s, v, _) =
        call(&t, Method::POST, &format!("/api/v1/sessions/{sid}/prepare"), Some(req.clone()), Some(&c)).await;
    assert_eq!(s, StatusCode::BAD_REQUEST, "{v}");
    req["providerProfileId"] = json!("cloud");
    let (s, _, _) = call(&t, Method::POST, &format!("/api/v1/sessions/{sid}/prepare"), Some(req), Some(&c)).await;
    assert_eq!(s, StatusCode::UNPROCESSABLE_ENTITY);
}

#[tokio::test]
async fn event_stream_ends_when_the_cookie_session_is_revoked() {
    let t = harness();
    let c = login(&t).await;
    let p = project();
    let (_, v, _) = call(
        &t,
        Method::POST,
        &format!("/api/v1/projects/{p}/sessions"),
        Some(json!({"title": "SSE", "idempotencyKey": "s1"})),
        Some(&c),
    )
    .await;
    let sid = v["session"]["id"].as_str().expect("sid").to_owned();
    let req = Request::builder()
        .uri(format!("/api/v1/sessions/{sid}/events"))
        .header(header::HOST, HOST)
        .header(header::COOKIE, format!("{COOKIE}={c}"))
        .body(Body::empty())
        .expect("req");
    let resp = t.app.clone().oneshot(req).await.expect("resp");
    assert_eq!(resp.status(), StatusCode::OK);
    let (s, _, _) = call(&t, Method::DELETE, "/api/v1/auth/session", None, Some(&c)).await;
    assert_eq!(s, StatusCode::NO_CONTENT);
    let ended = tokio::time::timeout(std::time::Duration::from_secs(3), resp.into_body().collect()).await;
    assert!(ended.is_ok(), "the open stream must close after revocation");
}
