import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { HomePage } from "./HomePage";

vi.mock("@/lib/api", () => ({
  api: {
    getHistory: vi.fn(),
    getRecordingState: vi.fn(),
    manualToggleRecording: vi.fn(),
    getStats: vi.fn(),
    getSettings: vi.fn(),
    getOptions: vi.fn(),
    getGpuInfo: vi.fn(),
    copyToClipboard: vi.fn(),
    deleteHistory: vi.fn(),
    getHistoryAudio: vi.fn(),
  },
}));

import { api } from "@/lib/api";

const mkEntry = (id: number) => ({
  id,
  text: `transcripción ${id}`,
  char_count: 12,
  word_count: 2,
  created_at: new Date().toISOString(),
  has_audio: false,
});

describe("HomePage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (api.getHistory as ReturnType<typeof vi.fn>).mockResolvedValue([
      mkEntry(1),
      mkEntry(2),
    ]);
    (api.getRecordingState as ReturnType<typeof vi.fn>).mockResolvedValue({
      recording: false,
    });
    (api.manualToggleRecording as ReturnType<typeof vi.fn>).mockResolvedValue({
      recording: false,
    });
    (api.getStats as ReturnType<typeof vi.fn>).mockResolvedValue({
      totalTranscriptions: 2,
      totalWords: 4,
      totalCharacters: 24,
      streakDays: 1,
    });
    (api.getSettings as ReturnType<typeof vi.fn>).mockResolvedValue({
      model: "small",
      language: "es",
      microphone: 1,
      device: "cpu",
    });
    (api.getOptions as ReturnType<typeof vi.fn>).mockResolvedValue({
      microphones: [{ id: 1, name: "Mic", channels: 1 }],
    });
    (api.getGpuInfo as ReturnType<typeof vi.fn>).mockResolvedValue({
      cudaAvailable: false,
      gpuName: null,
    });
  });

  it("muestra el título en español y el botón Grabar", async () => {
    render(<HomePage />);
    expect(screen.getByRole("heading", { name: "Panel" })).toBeInTheDocument();
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Grabar" })).toBeInTheDocument(),
    );
  });

  it("lista las transcripciones cargadas", async () => {
    render(<HomePage />);
    await waitFor(() =>
      expect(screen.getByText("transcripción 1")).toBeInTheDocument(),
    );
    expect(screen.getByText("transcripción 2")).toBeInTheDocument();
  });
});
