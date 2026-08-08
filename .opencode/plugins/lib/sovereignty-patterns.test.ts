import { test, expect } from "bun:test";
import { isN1Destination } from "./sovereignty-patterns.ts";

test("isN1Destination: changelog fragment CHANGELOG.d/ is N1 (public docs)", () => {
  expect(isN1Destination("CHANGELOG.d/se310-savia-conversacional.md")).toBe(true);
  expect(isN1Destination("/repo/CHANGELOG.d/se301-303-specs.md")).toBe(true);
});

test("isN1Destination: CHANGELOG.md is N1", () => {
  expect(isN1Destination("CHANGELOG.md")).toBe(true);
});

test("isN1Destination: docs and rules are N1", () => {
  expect(isN1Destination("docs/ROADMAP.md")).toBe(true);
  expect(isN1Destination(".claude/rules/domain/x.md")).toBe(true);
});

test("isN1Destination: private/local files are NOT N1", () => {
  expect(isN1Destination("projects/savia-vaults/config.yaml")).toBe(false);
  expect(isN1Destination("~/.savia/transcriptor/meeting.md")).toBe(false);
  expect(isN1Destination("output/out.json")).toBe(false);
});
