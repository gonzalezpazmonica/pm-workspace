import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { HistoryPage } from "./HistoryPage";

vi.mock("@/lib/api", () => ({
  api: {
    getHistory: vi.fn(),
    getRecordingState: vi.fn(),
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
  text: `entrada ${id}`,
  char_count: 8,
  word_count: 1,
  created_at: new Date().toISOString(),
  has_audio: false,
});

describe("HistoryPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (api.getHistory as ReturnType<typeof vi.fn>).mockResolvedValue([
      mkEntry(1),
    ]);
  });

  it("muestra el título y las entradas en español", async () => {
    render(<HistoryPage />);
    expect(screen.getByRole("heading", { name: "Historial" })).toBeInTheDocument();
    await waitFor(() =>
      expect(screen.getByText("entrada 1")).toBeInTheDocument(),
    );
  });
});
