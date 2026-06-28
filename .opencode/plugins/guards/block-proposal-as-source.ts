/**
 * block-proposal-as-source.ts
 *
 * Guard SE-235: Dual Pool — bloquea que una herramienta Write use como source
 * un archivo cuya ruta está en una rama agent/* (estado proposal).
 *
 * Lógica:
 * 1. Intercepta la herramienta Write
 * 2. Escanea el contenido a escribir en busca de patrones de importación/referencia
 * 3. Para cada path referenciado, verifica si pertenece a una rama agent/*
 * 4. Si detecta referencia a proposal state, bloquea con mensaje explicativo
 *
 * Referencia: docs/propuestas/SE-235-dual-pool-proposal-result.md
 */

import { execSync } from "child_process";

/** Patrones que indican una referencia/importación de otro fichero */
const IMPORT_PATTERNS: RegExp[] = [
  /@import\s+["']?([^\s"']+)["']?/g,
  /source:\s*["']?([^\s"']+)["']?/g,
  /from:\s*["']?([^\s"']+)["']?/g,
  /read:\s*["']?([^\s"']+)["']?/g,
  /include:\s*["']?([^\s"']+)["']?/g,
];

/** Prefijos de ramas en estado proposal */
const PROPOSAL_BRANCH_PREFIXES = [
  "agent/overnight-",
  "agent/improve-",
  "agent/research-",
  "agent/nido-",
  "agent/",
];

/** Prefijos de paths en estado proposal (nidos) */
const PROPOSAL_PATH_PREFIXES = [
  ".savia/nidos/",
  "~/.savia/nidos/",
];

/**
 * Extrae todos los paths referenciados en el contenido a escribir.
 */
function extractReferencedPaths(content: string): string[] {
  const paths: string[] = [];
  for (const pattern of IMPORT_PATTERNS) {
    const regex = new RegExp(pattern.source, pattern.flags);
    let match: RegExpExecArray | null;
    while ((match = regex.exec(content)) !== null) {
      if (match[1]) {
        paths.push(match[1]);
      }
    }
  }
  return [...new Set(paths)];
}

/**
 * Verifica si un path pertenece a una rama agent/* verificando git.
 * Devuelve el nombre de la rama proposal si se detecta, null si está en result state.
 */
function getProposalBranch(filePath: string): string | null {
  // Verificar prefijos de nido directamente
  for (const prefix of PROPOSAL_PATH_PREFIXES) {
    if (filePath.includes(prefix)) {
      return `nido-path (${filePath})`;
    }
  }

  try {
    // Obtener la rama actual
    const currentBranch = execSync("git branch --show-current 2>/dev/null", {
      encoding: "utf8",
      stdio: ["pipe", "pipe", "pipe"],
    }).trim();

    // Si estamos en una rama agent/*, todos los ficheros son proposal
    for (const prefix of PROPOSAL_BRANCH_PREFIXES) {
      if (currentBranch.startsWith(prefix)) {
        return currentBranch;
      }
    }

    // Verificar si el fichero referenciado solo existe en ramas agent/*
    const gitLog = execSync(
      `git log --oneline --all --follow -- "${filePath}" 2>/dev/null | head -5`,
      { encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] }
    ).trim();

    if (gitLog) {
      // Verificar en qué ramas existe este fichero
      const branches = execSync(
        `git branch --all --contains $(git log --oneline -1 -- "${filePath}" 2>/dev/null | cut -d' ' -f1) 2>/dev/null`,
        { encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] }
      ).trim();

      const branchLines = branches.split("\n").map((b) => b.trim());
      const onlyInProposal = branchLines.every((branch) =>
        PROPOSAL_BRANCH_PREFIXES.some((prefix) => branch.includes(prefix))
      );

      if (onlyInProposal && branchLines.length > 0 && branchLines[0] !== "") {
        return branchLines[0];
      }
    }
  } catch {
    // Si git no está disponible o falla, no bloqueamos (fail-open)
    return null;
  }

  return null;
}

/**
 * Genera el mensaje de error cuando se detecta una referencia a proposal state.
 */
function buildBlockMessage(
  targetFile: string,
  proposalPath: string,
  proposalBranch: string
): string {
  return [
    "SE-235 Dual Pool Guard — Referencia a Proposal State bloqueada",
    "",
    `El fichero que intentas escribir (${targetFile}) referencia un artefacto`,
    `en estado PROPOSAL que no puede usarse como fuente de verdad:`,
    "",
    `  Path referenciado: ${proposalPath}`,
    `  Rama/Estado proposal: ${proposalBranch}`,
    "",
    "Un artefacto en estado proposal es efímero y mutable.",
    "Solo los artefactos en estado RESULT (mergeados a main via Code Review Court)",
    "pueden ser referenciados como fuente de verdad.",
    "",
    "Para continuar:",
    "  1. Espera a que el PR de este artefacto sea aprobado y mergeado a main",
    "  2. O usa una referencia con anotación explícita: [PROPOSAL - no usar como fuente de verdad]",
    "  3. O añade --allow-proposal-ref si es una inspección/comparación temporal",
    "",
    "Ref: docs/propuestas/SE-235-dual-pool-proposal-result.md",
  ].join("\n");
}

/**
 * Hook principal — intercepta Write y verifica referencias a proposal state.
 *
 * En OpenCode, los guards exportan una función `guard` que recibe el contexto
 * de la herramienta y devuelve { block: boolean, message?: string }.
 */
export function guard(context: {
  tool: string;
  params: { filePath?: string; content?: string };
}): { block: boolean; message?: string } {
  // Solo actúa sobre la herramienta Write
  if (context.tool !== "Write") {
    return { block: false };
  }

  const { filePath, content } = context.params;

  if (!filePath || !content) {
    return { block: false };
  }

  // Extraer paths referenciados en el contenido
  const referencedPaths = extractReferencedPaths(content);

  if (referencedPaths.length === 0) {
    return { block: false };
  }

  // Verificar cada path referenciado
  for (const refPath of referencedPaths) {
    const proposalBranch = getProposalBranch(refPath);
    if (proposalBranch) {
      return {
        block: true,
        message: buildBlockMessage(filePath, refPath, proposalBranch),
      };
    }
  }

  return { block: false };
}

// Para tests unitarios
export {
  extractReferencedPaths,
  getProposalBranch,
  buildBlockMessage,
  IMPORT_PATTERNS,
  PROPOSAL_BRANCH_PREFIXES,
};
