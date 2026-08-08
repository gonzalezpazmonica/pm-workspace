import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, waitFor, act } from "@testing-library/react";
import { useHistoryEntries } from "./useHistoryEntries";
import { api } from "@/lib/api";
import type { HistoryEntry } from "@/lib/types";

vi.mock("@/lib/api", () => ({
  api: {
    getHistory: vi.fn(),
    getHistoryAudio: vi.fn(),
    deleteHistory: vi.fn(),
    copyToClipboard: vi.fn(),
  },
}));

const entry = (id: number, text = "hola savia"): HistoryEntry => ({
  id,
  text,
  char_count: text.length,
  word_count: 2,
  created_at: new Date().toISOString(),
  has_audio: false,
});

describe("useHistoryEntries", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (api.getHistory as ReturnType<typeof vi.fn>).mockResolvedValue([entry(1)]);
    (api.getHistoryAudio as ReturnType<typeof vi.fn>).mockResolvedValue({
      base64: "AA==",
      mime: "audio/wav",
      fileName: "a.wav",
      durationMs: 1000,
    });
    (api.deleteHistory as ReturnType<typeof vi.fn>).mockResolvedValue({});
    (api.copyToClipboard as ReturnType<typeof vi.fn>).mockResolvedValue({});
  });

  it("loads history on mount", async () => {
    const { result } = renderHook(() => useHistoryEntries(50));
    expect(result.current.loading).toBe(true);
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.history).toHaveLength(1);
  });

  it("reloads when search changes", async () => {
    const { result } = renderHook(() => useHistoryEntries(50));
    await waitFor(() => expect(result.current.loading).toBe(false));
    await act(async () => {
      await result.current.loadHistory("savia");
    });
    expect(api.getHistory).toHaveBeenCalledWith(50, 0, "savia", false);
  });

  it("deletes an entry and updates state", async () => {
    const { result } = renderHook(() => useHistoryEntries(50));
    await waitFor(() => expect(result.current.history).toHaveLength(1));
    await act(async () => {
      await result.current.handleDelete(1);
    });
    expect(result.current.history).toHaveLength(0);
  });

  it("loads audio and opens the player", async () => {
    const { result } = renderHook(() => useHistoryEntries(50));
    await waitFor(() => expect(result.current.loading).toBe(false));
    await act(async () => {
      await result.current.handlePlayAudio(1);
    });
    expect(result.current.audioUrl).toBeTruthy();
    expect(result.current.showPlayer).toBe(true);
  });
});
