import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { SettingsTab } from "./SettingsTab";

vi.mock("@/lib/api", () => ({
  api: {
    getSettings: vi.fn(),
    getOptions: vi.fn(),
    getGpuInfo: vi.fn(),
    getModelInfo: vi.fn(),
    updateSettings: vi.fn(),
    openDataFolder: vi.fn(),
    openModelCacheDir: vi.fn(),
    getModelCacheDir: vi.fn().mockResolvedValue({}),
    validateDevice: vi.fn().mockResolvedValue({ ok: true }),
    validateHotkey: vi.fn().mockResolvedValue({ valid: true }),
    deleteModel: vi.fn().mockResolvedValue({}),
    clearModelCache: vi.fn().mockResolvedValue({}),
    clearCudaLibs: vi.fn().mockResolvedValue({}),
  },
}));
vi.mock("@/components/meetings/LLMSettingsSection", () => ({
  LLMSettingsSection: () => <div data-testid="llm" />,
}));
vi.mock("@/components/meetings/MeetingsSettingsSection", () => ({
  MeetingsSettingsSection: () => <div data-testid="meetings-settings" />,
}));

import { api } from "@/lib/api";

describe("SettingsTab", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (api.getSettings as ReturnType<typeof vi.fn>).mockResolvedValue({
      theme: "system",
      model: "small",
      language: "es",
      microphone: 1,
      device: "cpu",
      onboardingComplete: true,
      holdHotkey: "ctrl+win",
      holdHotkeyEnabled: true,
      toggleHotkey: "",
      toggleHotkeyEnabled: false,
      floatingIndicator: true,
      saveAudio: false,
      prependSpace: true,
      launchAtLogin: false,
      retentionDays: 30,
      llmEnabled: false,
    });
    (api.getOptions as ReturnType<typeof vi.fn>).mockResolvedValue({
      microphones: [{ id: 1, name: "Micrófono", channels: 1 }],
      models: ["small", "base"],
      languages: ["es", "auto"],
      retentionOptions: { "30 días": 30 },
      themeOptions: ["light", "dark", "system"],
      deviceOptions: ["cpu"],
    });
    (api.getGpuInfo as ReturnType<typeof vi.fn>).mockResolvedValue({
      cudaAvailable: false,
      gpuName: null,
    });
    (api.getModelInfo as ReturnType<typeof vi.fn>).mockResolvedValue({
      cached: true,
    });
  });

  it("renderiza los ajustes con el título en español", async () => {
    render(<SettingsTab />);
    await waitFor(() => expect(screen.getByText("Ajustes")).toBeInTheDocument());
  });
});
