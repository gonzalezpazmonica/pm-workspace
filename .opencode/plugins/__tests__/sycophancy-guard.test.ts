// sycophancy-guard.test.ts — SPEC-150 Slice 2
//
// Unit tests for the sycophancyGuard after-guard (TS port of sycophancy-strip.sh).
// Tests run via `bun test` (same runner as all other plugin tests).

import { test, expect, beforeEach, afterEach } from "bun:test";
import { detectSycophancy, sycophancyGuard } from "../guards/sycophancy-guard.ts";

// ── Helper ────────────────────────────────────────────────────────────────────
function makeOutput(text: string) {
  return { output: text };
}

// ── detectSycophancy unit tests ───────────────────────────────────────────────

test("detectSycophancy: returns null for clean response", () => {
  const result = detectSycophancy("Velocity dropped 12%. Fix: re-estimate 5 PBIs.");
  expect(result).toBeNull();
});

test("detectSycophancy: detects 'buena pregunta' (Spanish obvious)", () => {
  const result = detectSycophancy("Buena pregunta. La respuesta es X.");
  expect(result).not.toBeNull();
  expect(result!.category).toBe("obvious");
  expect(result!.position).toBeLessThan(50);
});

test("detectSycophancy: detects 'tienes razón' Spanish", () => {
  const result = detectSycophancy("Tienes razón, el enfoque es correcto.");
  expect(result).not.toBeNull();
  expect(result!.category).toBe("obvious");
});

test("detectSycophancy: detects 'absolutely,' English", () => {
  const result = detectSycophancy("Absolutely, I'll help you with that.");
  expect(result).not.toBeNull();
  expect(result!.category).toBe("obvious");
});

test("detectSycophancy: detects 'great question' English", () => {
  const result = detectSycophancy("Great question! Here's the answer.");
  expect(result).not.toBeNull();
  expect(result!.category).toBe("obvious");
});

test("detectSycophancy: detects 'you're right' English", () => {
  const result = detectSycophancy("You're right about that assumption.");
  expect(result).not.toBeNull();
  expect(result!.category).toBe("obvious");
});

test("detectSycophancy: not triggered by mid-sentence occurrence", () => {
  // "buena pregunta" not at start — should not match ^ anchored patterns
  const result = detectSycophancy("El diseño tiene detalles. Es una buena pregunta en general.");
  expect(result).toBeNull();
});

test("detectSycophancy: only scans first 200 chars (positional bound)", () => {
  const padding = "x".repeat(250);
  const result = detectSycophancy(padding + "Buena pregunta. La respuesta es X.");
  expect(result).toBeNull();
});

// ── sycophancyGuard integration tests ────────────────────────────────────────

test("sycophancyGuard: master off — no warn even on adulation", async () => {
  const original = process.env["SAVIA_ANTIADULATION"];
  process.env["SAVIA_ANTIADULATION"] = "off";
  const warnings: string[] = [];
  const origWarn = console.warn;
  console.warn = (...args: unknown[]) => { warnings.push(String(args[0])); };
  try {
    await sycophancyGuard({} as any, makeOutput("Absolutely, great question!") as any);
    expect(warnings).toHaveLength(0);
  } finally {
    console.warn = origWarn;
    if (original === undefined) delete process.env["SAVIA_ANTIADULATION"];
    else process.env["SAVIA_ANTIADULATION"] = original;
  }
});

test("sycophancyGuard: shadow mode — no visible output on match", async () => {
  const origWarn = console.warn;
  const warnings: string[] = [];
  console.warn = (...args: unknown[]) => { warnings.push(String(args[0])); };
  const origMode = process.env["SAVIA_ANTIADULATION_LAYER1"];
  process.env["SAVIA_ANTIADULATION_LAYER1"] = "shadow";
  const origMaster = process.env["SAVIA_ANTIADULATION"];
  process.env["SAVIA_ANTIADULATION"] = "on";
  try {
    await sycophancyGuard({} as any, makeOutput("Buena pregunta. La respuesta es X.") as any);
    expect(warnings).toHaveLength(0);
  } finally {
    console.warn = origWarn;
    if (origMode === undefined) delete process.env["SAVIA_ANTIADULATION_LAYER1"];
    else process.env["SAVIA_ANTIADULATION_LAYER1"] = origMode;
    if (origMaster === undefined) delete process.env["SAVIA_ANTIADULATION"];
    else process.env["SAVIA_ANTIADULATION"] = origMaster;
  }
});

test("sycophancyGuard: warn mode — emits console.warn on match", async () => {
  const origWarn = console.warn;
  const warnings: string[] = [];
  console.warn = (...args: unknown[]) => { warnings.push(String(args[0])); };
  const origMode = process.env["SAVIA_ANTIADULATION_LAYER1"];
  process.env["SAVIA_ANTIADULATION_LAYER1"] = "warn";
  const origMaster = process.env["SAVIA_ANTIADULATION"];
  process.env["SAVIA_ANTIADULATION"] = "on";
  try {
    await sycophancyGuard({} as any, makeOutput("Absolutely, that's correct.") as any);
    expect(warnings.length).toBeGreaterThan(0);
    expect(warnings[0]).toMatch(/anti-adulation/i);
  } finally {
    console.warn = origWarn;
    if (origMode === undefined) delete process.env["SAVIA_ANTIADULATION_LAYER1"];
    else process.env["SAVIA_ANTIADULATION_LAYER1"] = origMode;
    if (origMaster === undefined) delete process.env["SAVIA_ANTIADULATION"];
    else process.env["SAVIA_ANTIADULATION"] = origMaster;
  }
});

test("sycophancyGuard: clean output — no action in any mode", async () => {
  const origWarn = console.warn;
  const warnings: string[] = [];
  console.warn = (...args: unknown[]) => { warnings.push(String(args[0])); };
  const origMode = process.env["SAVIA_ANTIADULATION_LAYER1"];
  process.env["SAVIA_ANTIADULATION_LAYER1"] = "warn";
  const origMaster = process.env["SAVIA_ANTIADULATION"];
  process.env["SAVIA_ANTIADULATION"] = "on";
  try {
    await sycophancyGuard({} as any, makeOutput("Velocity: 38 SP (-12%). Fix: escalate AB#1023.") as any);
    expect(warnings).toHaveLength(0);
  } finally {
    console.warn = origWarn;
    if (origMode === undefined) delete process.env["SAVIA_ANTIADULATION_LAYER1"];
    else process.env["SAVIA_ANTIADULATION_LAYER1"] = origMode;
    if (origMaster === undefined) delete process.env["SAVIA_ANTIADULATION"];
    else process.env["SAVIA_ANTIADULATION"] = origMaster;
  }
});

test("sycophancyGuard: block mode — throws on score>=85 and position<50", async () => {
  const origMode = process.env["SAVIA_ANTIADULATION_LAYER1"];
  process.env["SAVIA_ANTIADULATION_LAYER1"] = "block";
  const origMaster = process.env["SAVIA_ANTIADULATION"];
  process.env["SAVIA_ANTIADULATION"] = "on";
  try {
    await expect(
      sycophancyGuard({} as any, makeOutput("Buena pregunta. La respuesta es X.") as any)
    ).rejects.toThrow(/anti-adulation/i);
  } finally {
    if (origMode === undefined) delete process.env["SAVIA_ANTIADULATION_LAYER1"];
    else process.env["SAVIA_ANTIADULATION_LAYER1"] = origMode;
    if (origMaster === undefined) delete process.env["SAVIA_ANTIADULATION"];
    else process.env["SAVIA_ANTIADULATION"] = origMaster;
  }
});

test("sycophancyGuard: no output field — no-op (safe for pre-output hooks)", async () => {
  // output without .output string should not throw
  await expect(
    sycophancyGuard({} as any, {} as any)
  ).resolves.toBeUndefined();
});
