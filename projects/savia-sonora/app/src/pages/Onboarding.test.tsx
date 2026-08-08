import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { Onboarding } from "./Onboarding";

vi.mock("@/lib/api", () => ({
  api: {
    getOptions: vi.fn(),
    getGpuInfo: vi.fn(),
    updateSettings: vi.fn(),
  },
}));

import { api } from "@/lib/api";

const options = {
  microphones: [{ id: 1, name: "Micrófono", channels: 1 }],
  models: ["tiny", "small"],
  languages: ["es", "auto"],
  retentionOptions: {},
  themeOptions: ["light", "dark", "system"],
  deviceOptions: ["cpu", "cuda"],
};

describe("Onboarding", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (api.getOptions as ReturnType<typeof vi.fn>).mockResolvedValue(options);
    (api.getGpuInfo as ReturnType<typeof vi.fn>).mockResolvedValue({
      cudaAvailable: false,
      gpuName: null,
    });
  });

  it("muestra la bienvenida en español", async () => {
    render(
      <MemoryRouter>
        <Onboarding />
      </MemoryRouter>,
    );
    expect(
      await screen.findByText(/convierte tu voz en texto/i),
    ).toBeInTheDocument();
  });
});
