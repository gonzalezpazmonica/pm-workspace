import { describe, it, expect, vi, beforeEach } from "vitest";
import { render } from "@testing-library/react";
import { Popup } from "./Popup";

vi.mock("@/lib/api", () => ({
  api: { getSettings: vi.fn() },
}));

import { api } from "@/lib/api";

describe("Popup", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (api.getSettings as ReturnType<typeof vi.fn>).mockResolvedValue({
      model: "small",
    });
  });

  it("renderiza sin romperse en estado idle", () => {
    const { container } = render(<Popup />);
    expect(container).toBeTruthy();
  });
});
