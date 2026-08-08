import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { StepFinal } from "./StepFinal";

vi.mock("@/lib/api", () => ({ api: {} }));

describe("StepFinal", () => {
  it("no muestra branding VoiceFlow", () => {
    render(<StepFinal />);
    expect(screen.queryByText(/voiceflow/i)).not.toBeInTheDocument();
  });
});
