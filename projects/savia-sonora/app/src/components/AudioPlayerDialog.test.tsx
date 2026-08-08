import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { AudioPlayerDialog } from "./AudioPlayerDialog";
import type { AudioMeta } from "@/hooks/useHistoryEntries";

describe("AudioPlayerDialog", () => {
  it("renders filename and duration when open", () => {
    const meta: AudioMeta = { fileName: "nota.wav", mime: "audio/wav", durationMs: 3200 };
    render(
      <AudioPlayerDialog
        open
        audioUrl="blob:test"
        audioMeta={meta}
        durationMs={meta.durationMs}
        onOpenChange={() => {}}
      />,
    );
    expect(screen.getByText("nota.wav")).toBeInTheDocument();
    expect(screen.getByText(/3s/)).toBeInTheDocument();
  });

  it("shows no-audio message when url is missing", () => {
    render(
      <AudioPlayerDialog
        open
        audioUrl={null}
        audioMeta={null}
        durationMs={undefined}
        onOpenChange={() => {}}
      />,
    );
    expect(screen.getByText("No hay audio cargado.")).toBeInTheDocument();
  });
});
