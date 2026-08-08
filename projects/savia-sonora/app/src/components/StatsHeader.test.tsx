import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { StatsHeader } from "./StatsHeader";
import { api } from "@/lib/api";

vi.mock("@/lib/api", () => ({
  api: {
    getStats: vi.fn(),
    getSettings: vi.fn(),
    getOptions: vi.fn(),
    getGpuInfo: vi.fn(),
  },
}));

describe("StatsHeader", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (api.getStats as ReturnType<typeof vi.fn>).mockResolvedValue({
      totalTranscriptions: 42,
      totalWords: 1234,
      totalCharacters: 5678,
      streakDays: 3,
    });
    (api.getSettings as ReturnType<typeof vi.fn>).mockResolvedValue({
      model: "small",
      language: "es",
      microphone: 1,
      device: "cpu",
    });
    (api.getOptions as ReturnType<typeof vi.fn>).mockResolvedValue({
      microphones: [{ id: 1, name: "Micrófono", channels: 1 }],
    });
    (api.getGpuInfo as ReturnType<typeof vi.fn>).mockResolvedValue({
      cudaAvailable: false,
      gpuName: null,
    });
  });

  it("muestra las estadísticas en español", async () => {
    render(<StatsHeader />);
    await waitFor(() => expect(screen.getByText("palabras")).toBeInTheDocument());
    expect(screen.getByText("entradas")).toBeInTheDocument();
    expect(screen.getByText("caracteres")).toBeInTheDocument();
    expect(screen.getByText("racha")).toBeInTheDocument();
    expect(screen.getByText("3 días")).toBeInTheDocument();
  });
});
