import { test, expect } from "bun:test";
import { isWatchedConfig } from "../guards/config-snapshot.ts";

// SE-405 Slice 2: only the watched configuration files trigger a snapshot.

test("settings.json under .claude is watched", () => {
  expect(isWatchedConfig("/repo/.claude/settings.json", "/home/u")).toBe(true);
});

test("settings.local.json is watched", () => {
  expect(isWatchedConfig("/repo/.claude/settings.local.json", "/home/u")).toBe(true);
});

test("opencode.json is watched", () => {
  expect(isWatchedConfig("/repo/opencode.json", "/home/u")).toBe(true);
});

test("preferences.yaml under ~/.savia is watched", () => {
  expect(isWatchedConfig("/home/u/.savia/preferences.yaml", "/home/u")).toBe(true);
});

test("other files are ignored", () => {
  expect(isWatchedConfig("/repo/README.md", "/home/u")).toBe(false);
  expect(isWatchedConfig("", "/home/u")).toBe(false);
});
