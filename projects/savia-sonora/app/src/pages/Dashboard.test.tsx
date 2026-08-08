import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";

vi.mock("@/components/Sidebar", () => ({
  Sidebar: () => <aside data-testid="sidebar" />,
}));
vi.mock("@/components/HomePage", () => ({
  HomePage: () => <div>home</div>,
}));
vi.mock("@/components/HistoryPage", () => ({
  HistoryPage: () => <div>history</div>,
}));
vi.mock("@/components/SettingsTab", () => ({
  SettingsTab: () => <div>settings</div>,
}));
vi.mock("@/components/meetings/MeetingsListPage", () => ({
  MeetingsListPage: () => <div>meetings</div>,
}));
vi.mock("@/components/meetings/MeetingRecorderPage", () => ({
  MeetingRecorderPage: () => <div>recorder</div>,
}));
vi.mock("@/components/meetings/MeetingDetailPage", () => ({
  MeetingDetailPage: () => <div>detail</div>,
}));
vi.mock("@/components/HotkeyStatusBanner", () => ({
  HotkeyStatusBanner: () => <div />,
}));

import { Dashboard } from "./Dashboard";

describe("Dashboard", () => {
  it("renderiza el sidebar y el header móvil con la marca Savia", () => {
    render(
      <MemoryRouter initialEntries={["/dashboard"]}>
        <Dashboard />
      </MemoryRouter>,
    );
    expect(screen.getByTestId("sidebar")).toBeInTheDocument();
    expect(screen.getByAltText("Savia Sonora")).toBeInTheDocument();
  });
});
