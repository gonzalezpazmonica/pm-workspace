// require-criterion-cite.ts — SE-255 Slice 5
//
// Guard pre-output: valida que todo artefacto delegado declare
// los criterios de CRITERIO.md que aplico (ART-06 deber de cita).
//
// Artefacto sin CRIT aplicable → NO va a drafts/; va a questions/
// con etiqueta SIN-CRITERIO-DECLARADO.
//
// Regla dura (ART-15/V-08): inferir criterio en silencio es sustitucion.

import { extractToolName, type ToolInput, type ToolOutput } from "../lib/hook-input.ts";

const CRIT_CITE_RX = /CRIT-\d{3}/;
const DELEGATED_PATHS = ["drafts/", "propuestas/", "borrador", "follow-up", "respuesta"];
const CRIT_REQUIRED_PATHS = ["drafts/", "propuestas/"];

function isDelegated(filePath: string): boolean {
  if (!filePath) return false;
  return DELEGATED_PATHS.some(p => filePath.toLowerCase().includes(p.toLowerCase()));
}

function isCritRequired(filePath: string): boolean {
  if (!filePath) return false;
  if (filePath.includes("questions/")) return false;
  return CRIT_REQUIRED_PATHS.some(p => filePath.toLowerCase().includes(p.toLowerCase()));
}

export async function requireCriterionCite(input: ToolInput, _output: ToolOutput): Promise<void> {
  if (extractToolName(input) !== "write" && extractToolName(input) !== "edit") return;

  const raw = input as Record<string, unknown>;
  const filePath = (raw.filePath || raw.path || "") as string;
  const content = (raw.content || raw.text || raw.newString || "") as string;

  if (!filePath || !isDelegated(filePath)) return;
  if (!content) return;

  const hasCitation = CRIT_CITE_RX.test(content);

  if (!hasCitation && isCritRequired(filePath)) {
    console.warn(
      `  ⚠️  SIN-CRITERIO-DECLARADO: ${filePath}\n` +
      `  ART-06 (CONSTITUCION.md): toda accion delegada declara que criterios aplico.\n` +
      `  Si no aplica ningun CRIT de CRITERIO.md, mueve el artefacto a questions/.\n` +
      `  ART-15/V-08: inferir criterio en silencio es sustitucion.\n`
    );
  }
}
