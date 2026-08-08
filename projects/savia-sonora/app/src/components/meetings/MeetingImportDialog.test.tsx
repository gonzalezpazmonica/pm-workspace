import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { MeetingImportDialog } from "./MeetingImportDialog";

vi.mock("@/lib/api", () => ({
  api: {
    recordingsImport: vi.fn().mockResolvedValue({}),
  },
}));

describe("MeetingImportDialog", () => {
  it("no muestra branding VoiceFlow", () => {
    render(
      <MeetingImportDialog
        open
        onOpenChange={() => {}}
        onImported={() => {}}
      />,
    );
    expect(screen.queryByText(/voiceflow/i)).not.toBeInTheDocument();
  });
});
