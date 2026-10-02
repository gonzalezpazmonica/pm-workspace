//! `savia-space`: local server for Savia Space.
//!
//! Commands: `serve [--web DIR]`, `pair`, `doctor`. Configuration lives in the private state
//! directory (`$SAVIA_SPACE_HOME` or `$XDG_STATE_HOME/savia-space`); nothing can widen the bind
//! address from the command line.

mod app;
mod config;
mod knowledge;
mod ollama;
mod presets;
mod server;
mod vaults;

use std::path::PathBuf;

#[derive(Debug, PartialEq, Eq)]
enum Cmd {
    Serve { web: Option<PathBuf> },
    Pair,
    Doctor,
}

fn parse(args: &[String]) -> Result<Cmd, String> {
    let usage = "uso: savia-space serve [--web DIR] | pair | doctor";
    match args.first().map(String::as_str) {
        Some("serve") => match &args[1..] {
            [] => Ok(Cmd::Serve { web: None }),
            [flag, dir] if flag == "--web" => Ok(Cmd::Serve { web: Some(PathBuf::from(dir)) }),
            _ => Err(usage.into()),
        },
        Some("pair") if args.len() == 1 => Ok(Cmd::Pair),
        Some("doctor") if args.len() == 1 => Ok(Cmd::Doctor),
        _ => Err(usage.into()),
    }
}

fn doctor(state_dir: &std::path::Path) -> i32 {
    let mut failures = 0;
    let mut check = |name: &str, r: Result<String, String>| match r {
        Ok(msg) => println!("OK    {name}: {msg}"),
        Err(msg) => {
            failures += 1;
            println!("FAIL  {name}: {msg}");
        }
    };
    check("STATE_DIR", server::check_state_dir(state_dir).map(|_| "privado".into()));
    check(
        "CONFIG",
        config::Config::load_or_init(state_dir)
            .map(|c| format!("{} proyecto(s), {} perfil(es)", c.projects.len(), c.profiles.len()))
            .map_err(|e| e.to_string()),
    );
    check(
        "DB",
        space_store::Store::open(&state_dir.join("space.db"))
            .map(|s| format!("esquema {}", s.schema_version()))
            .map_err(|e| e.to_string()),
    );
    if failures == 0 { 0 } else { 1 }
}

#[tokio::main]
async fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let cmd = match parse(&args) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("{e}");
            std::process::exit(2);
        }
    };
    let state_dir = server::default_state_dir();
    let code = match cmd {
        Cmd::Serve { web } => match server::serve(state_dir, web).await {
            Ok(()) => 0,
            Err(e) => {
                eprintln!("error: {e}");
                1
            }
        },
        #[cfg(unix)]
        Cmd::Pair => match server::pair(state_dir).await {
            Ok(code) => {
                println!("Código de emparejamiento (válido 120 s, un solo uso):\n{code}");
                0
            }
            Err(e) => {
                eprintln!("error: {e}");
                1
            }
        },
        #[cfg(not(unix))]
        Cmd::Pair => {
            eprintln!("el emparejamiento en Windows llega con el canal de named pipe (pendiente)");
            1
        }
        Cmd::Doctor => {
            let _ = std::fs::create_dir_all(&state_dir);
            doctor(&state_dir)
        }
    };
    std::process::exit(code);
}

#[cfg(test)]
#[path = "main.test.rs"]
mod tests;
