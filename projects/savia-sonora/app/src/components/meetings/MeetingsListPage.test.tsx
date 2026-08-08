import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { MeetingsListPage } from "./MeetingsListPage";

vi.mock("@/lib/api", () => ({
  api: {
    recordingsList: vi.fn(),
    recordingsDelete: vi.fn(),
  },
}));
vi.mock("./MeetingRecorderContext", () => ({
  useMeetingRecorder: () => ({
    isLive: false,
    state: { durationMs: 0 },
  }),
}));
vi.mock("./MeetingImportDialog", () => ({
  MeetingImportDialog: () => <div />,
}));

import { api } from "@/lib/api";

describe("MeetingsListPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (api.recordingsList as ReturnType<typeof vi.fn>).mockResolvedValue([]);
  });

  it("muestra el título en español", async () => {
    render(
      <MemoryRouter>
        <MeetingsListPage />
      </MemoryRouter>,
    );
    expect(screen.getByRole("heading", { name: "Reuniones" })).toBeInTheDocument();
    await waitFor(() =>
      expect(screen.getByText("Nueva reunión")).toBeInTheDocument(),
    );
  });
});
