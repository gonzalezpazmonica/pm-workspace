import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { Sidebar } from "./Sidebar";
import { api } from "@/lib/api";

vi.mock("@/lib/api", () => ({
  api: { getSettings: vi.fn(), openExternalUrl: vi.fn() },
}));

const renderSidebar = () =>
  render(
    <MemoryRouter initialEntries={["/dashboard"]}>
      <Sidebar />
    </MemoryRouter>,
  );

describe("Sidebar", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (api.getSettings as ReturnType<typeof vi.fn>).mockResolvedValue({
      holdHotkey: "ctrl+win",
      holdHotkeyEnabled: true,
      toggleHotkey: "",
      toggleHotkeyEnabled: false,
    });
  });

  it("muestra la marca Savia Sonora (no VoiceFlow)", () => {
    renderSidebar();
    expect(screen.getByAltText("Savia Sonora")).toBeInTheDocument();
    expect(screen.queryByText("VoiceFlow")).not.toBeInTheDocument();
  });

  it("muestra la navegación en español", () => {
    renderSidebar();
    expect(screen.getByText("Inicio")).toBeInTheDocument();
    expect(screen.getByText("Historial")).toBeInTheDocument();
    expect(screen.getByText("Reuniones")).toBeInTheDocument();
    expect(screen.getByText("Ajustes")).toBeInTheDocument();
  });
});
