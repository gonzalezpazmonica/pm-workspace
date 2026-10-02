//! Built-in presets (trusted configuration) and the built-in agent for the synthetic project.

use space_contracts::Sha256Hex;
use space_contracts::model::{CanonicalRef, PresetId, RefOwner};
use space_core::context::{AssetText, PresetText};

const RESUME: &str = "Tarea: resumir las fuentes. Da una síntesis breve, los puntos clave, lo que falta y las \
siguientes preguntas. Usa solo lo que dicen las fuentes; marca como propuesta lo que sea tuyo.";
const COMPARE: &str = "Tarea: comparar las fuentes. Separa coincidencias, diferencias por tema y lagunas. Cita todas \
las fuentes. No elijas una fuente ganadora.";
const DRAFT_SPEC: &str = "Tarea: borrador de especificación. Escribe objetivo, alcance, propuesta, criterios de \
aceptación, riesgos, dependencias y preguntas abiertas. Todo lo que no esté citado es propuesta.";

pub fn preset(id: PresetId) -> PresetText {
    let instructions = match id {
        PresetId::Resume => RESUME,
        PresetId::Compare => COMPARE,
        PresetId::DraftSpec => DRAFT_SPEC,
    };
    PresetText { id, version: Sha256Hex::of_bytes(instructions.as_bytes()), instructions: instructions.into() }
}

pub fn builtin_agent() -> AssetText {
    let body = include_str!("../../../fixtures/n1/agents/resumen.md").to_owned();
    AssetText {
        r#ref: CanonicalRef { owner: RefOwner::Space, id: "builtin/resumen".into(), version: "1".into() },
        body_hash: Sha256Hex::of_bytes(body.as_bytes()),
        control_hash: Sha256Hex::of_bytes(b""),
        body,
    }
}

#[cfg(test)]
#[path = "presets.test.rs"]
mod tests;
