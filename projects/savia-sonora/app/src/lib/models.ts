import { MODEL_OPTIONS } from "./constants";

/**
 * Frontend model-catalog helpers.
 *
 * `MODEL_OPTIONS` (constants.ts) is the single source of truth for model
 * display metadata. Components read through these helpers instead of keeping
 * their own (drift-prone) copies — SettingsTab used to maintain a 6-entry
 * `MODEL_META` subset that left 10 models showing fallback specs.
 *
 * Repo ids / download URLs come from the backend (getModelInfo -> repoId),
 * not from a hardcoded map here.
 */

export type ModelOption = (typeof MODEL_OPTIONS)[number];

const BY_ID = new Map<string, ModelOption>(
  MODEL_OPTIONS.map((m) => [m.id, m])
);

/** Look up a model's display metadata by id, or undefined if unknown. */
export function getModelOption(id: string): ModelOption | undefined {
  return BY_ID.get(id);
}

/** Parse the human-readable size string (e.g. "~466 MB", "~1.5 GB") to MB. */
export function modelSizeMb(id: string): number {
  const size = BY_ID.get(id)?.size;
  if (!size) return 0;
  const match = size.match(/([\d.]+)\s*(MB|GB)/i);
  if (!match) return 0;
  const value = parseFloat(match[1]);
  return match[2].toUpperCase() === "GB" ? value * 1024 : value;
}

/** Approximate VRAM needed to run a model on GPU, derived from its size.
 *  VRAM is inherently approximate, so deriving it from the size band avoids
 *  maintaining yet another per-model table. */
export function modelVram(id: string): string {
  const mb = modelSizeMb(id);
  if (mb === 0) return "—";
  if (mb < 200) return "~1 GB";
  if (mb < 600) return "~2 GB";
  if (mb < 1100) return "~4 GB";
  if (mb < 2200) return "~6 GB";
  return "~10 GB";
}

/** Build the HuggingFace repo URL from a repo id. */
export function huggingFaceUrl(repoId: string | undefined | null): string | null {
  return repoId ? `https://huggingface.co/${repoId}` : null;
}
