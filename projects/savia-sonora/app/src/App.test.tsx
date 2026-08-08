import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, waitFor } from "@testing-library/react";
import App from "./App";

vi.mock("@/lib/api", () => ({
  api: {
    getSettings: vi.fn(),
    getModelInfo: vi.fn(),
  },
}));

import { api } from "@/lib/api";

describe("App", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // jsdom does not load index.html; create the meta tag the app syncs.
    const meta = document.createElement("meta");
    meta.setAttribute("name", "theme-color");
    document.head.appendChild(meta);
    (api.getSettings as ReturnType<typeof vi.fn>).mockResolvedValue({
      onboardingComplete: true,
      theme: "dark",
      model: "small",
    });
    (api.getModelInfo as ReturnType<typeof vi.fn>).mockResolvedValue({
      cached: true,
    });
  });

  it("sincroniza el meta theme-color con el tema oscuro", async () => {
    render(<App />);
    await waitFor(() => {
      const meta = document.querySelector('meta[name="theme-color"]');
      expect(meta?.getAttribute("content")).toBe("#13111a");
    });
  });
});
