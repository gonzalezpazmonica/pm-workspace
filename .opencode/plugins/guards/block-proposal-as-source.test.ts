/**
 * block-proposal-as-source.test.ts
 *
 * Tests unitarios para el guard SE-235 block-proposal-as-source.
 * Verifica la lógica de extracción de paths y detección de proposal state.
 */

// Mock de child_process para tests que no dependen de git real
const mockExecSync = jest.fn();
jest.mock("child_process", () => ({
  execSync: mockExecSync,
}));

// Importar funciones a testear
import {
  extractReferencedPaths,
  buildBlockMessage,
  guard,
  IMPORT_PATTERNS,
  PROPOSAL_BRANCH_PREFIXES,
} from "./block-proposal-as-source";

describe("extractReferencedPaths", () => {
  test("extrae path de @import", () => {
    const content = `@import docs/rules/domain/autonomous-safety.md`;
    const paths = extractReferencedPaths(content);
    expect(paths).toContain("docs/rules/domain/autonomous-safety.md");
  });

  test("extrae path de source:", () => {
    const content = `source: agent/overnight-20260628-fix/my-file.md`;
    const paths = extractReferencedPaths(content);
    expect(paths).toContain("agent/overnight-20260628-fix/my-file.md");
  });

  test("extrae path de from:", () => {
    const content = `from: "agent/research-algo/output.md"`;
    const paths = extractReferencedPaths(content);
    expect(paths).toContain("agent/research-algo/output.md");
  });

  test("sin patrones de importación → array vacío", () => {
    const content = `# Documento sin importaciones\nSolo texto plano.`;
    const paths = extractReferencedPaths(content);
    expect(paths).toHaveLength(0);
  });

  test("deduplica paths repetidos", () => {
    const content = `@import docs/file.md\n@import docs/file.md`;
    const paths = extractReferencedPaths(content);
    expect(paths).toHaveLength(1);
  });
});

describe("buildBlockMessage", () => {
  test("incluye el path del fichero destino", () => {
    const msg = buildBlockMessage("output/file.md", "agent/foo/bar.md", "agent/foo");
    expect(msg).toContain("output/file.md");
  });

  test("incluye el path de proposal", () => {
    const msg = buildBlockMessage("output/file.md", "agent/foo/bar.md", "agent/foo");
    expect(msg).toContain("agent/foo/bar.md");
  });

  test("menciona SE-235", () => {
    const msg = buildBlockMessage("x", "y", "z");
    expect(msg).toContain("SE-235");
  });

  test("menciona proposal state", () => {
    const msg = buildBlockMessage("x", "y", "agent/overnight-123");
    expect(msg).toContain("PROPOSAL");
  });
});

describe("guard — herramienta no-Write", () => {
  test("no bloquea la herramienta Read", () => {
    const result = guard({ tool: "Read", params: { filePath: "x", content: "@import agent/foo/bar.md" } });
    expect(result.block).toBe(false);
  });

  test("no bloquea la herramienta Bash", () => {
    const result = guard({ tool: "Bash", params: { filePath: "x", content: "source: agent/foo/bar.md" } });
    expect(result.block).toBe(false);
  });
});

describe("guard — Write sin contenido problemático", () => {
  beforeEach(() => {
    mockExecSync.mockReturnValue("main\n");
  });

  test("no bloquea Write sin importaciones", () => {
    const result = guard({
      tool: "Write",
      params: { filePath: "docs/file.md", content: "# Documento sin importaciones\n" },
    });
    expect(result.block).toBe(false);
  });

  test("no bloquea Write con referencia a fichero en main", () => {
    mockExecSync.mockImplementation((cmd: string) => {
      if (cmd.includes("branch --show-current")) return "main\n";
      if (cmd.includes("git log")) return "abc1234 commit msg\n";
      if (cmd.includes("git branch --all")) return "* main\n  origin/main\n";
      return "";
    });

    const result = guard({
      tool: "Write",
      params: {
        filePath: "docs/file.md",
        content: "@import docs/rules/domain/autonomous-safety.md",
      },
    });
    expect(result.block).toBe(false);
  });
});

describe("guard — Write con referencia a nido (proposal path)", () => {
  test("bloquea cuando el contenido referencia un path en .savia/nidos/", () => {
    const result = guard({
      tool: "Write",
      params: {
        filePath: "docs/output.md",
        content: "@import .savia/nidos/se235-240-proto-architecture/docs/propuestas/SE-235.md",
      },
    });
    expect(result.block).toBe(true);
    expect(result.message).toContain("SE-235");
  });

  test("el mensaje de bloqueo menciona el path proposal", () => {
    const result = guard({
      tool: "Write",
      params: {
        filePath: "docs/output.md",
        content: "source: .savia/nidos/mi-nido/output.md",
      },
    });
    expect(result.block).toBe(true);
    expect(result.message).toContain(".savia/nidos/");
  });
});

describe("constantes del módulo", () => {
  test("IMPORT_PATTERNS tiene al menos 4 patrones", () => {
    expect(IMPORT_PATTERNS.length).toBeGreaterThanOrEqual(4);
  });

  test("PROPOSAL_BRANCH_PREFIXES incluye agent/", () => {
    expect(PROPOSAL_BRANCH_PREFIXES).toContain("agent/");
  });

  test("PROPOSAL_BRANCH_PREFIXES incluye agent/overnight-", () => {
    expect(PROPOSAL_BRANCH_PREFIXES.some((p) => p.includes("overnight"))).toBe(true);
  });
});
