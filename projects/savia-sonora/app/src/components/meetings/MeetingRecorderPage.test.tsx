import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { MeetingRecorderPage } from "./MeetingRecorderPage";

vi.mock("./MeetingRecorderContext", () => ({
  useMeetingRecorder: () => ({
    start: vi.fn(),
    stop: vi.fn(),
    pause: vi.fn(),
    resume: vi.fn(),
    isLive: false,
    isPaused: false,
    state: { durationMs: 0, segments: [] },
    sources: [],
    setSources: vi.fn(),
    error: null,
  }),
}));
vi.mock("@/lib/api", () => ({
  api: {
    recordingsListAudioSources: vi.fn().mockResolvedValue([]),
    recordingsStart: vi.fn(),
    recordingsStop: vi.fn(),
    recordingsPause: vi.fn(),
    recordingsResume: vi.fn(),
    recordingsPreviewStart: vi.fn().mockResolvedValue({}),
    recordingsPreviewStop: vi.fn().mockResolvedValue({}),
  },
}));

describe("MeetingRecorderPage", () => {
  it("no muestra branding VoiceFlow", () => {
    render(
      <MemoryRouter>
        <MeetingRecorderPage />
      </MemoryRouter>,
    );
    expect(screen.queryByText(/voiceflow/i)).not.toBeInTheDocument();
  });
});
