import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { StepTheme } from "./StepTheme";

vi.mock("@/lib/api", () => ({ api: {} }));

describe("StepTheme", () => {
  it("no muestra branding VoiceFlow", () => {
    render(
      <StepTheme
        theme="dark"
        setTheme={() => {}}
        autoStart
        setAutoStart={() => {}}
      />,
    );
    expect(screen.queryByText(/voiceflow/i)).not.toBeInTheDocument();
  });
});
