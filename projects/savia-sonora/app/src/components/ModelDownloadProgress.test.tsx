import { describe, it, expect, vi } from "vitest";
import { render } from "@testing-library/react";
import { ModelDownloadProgress } from "./ModelDownloadProgress";

vi.mock("@/lib/api", () => ({
  api: {
    getDownloadStatus: vi.fn().mockResolvedValue({ active: false }),
    cancelDownload: vi.fn(),
    getModelInfo: vi.fn().mockResolvedValue({ cached: true }),
    startModelDownload: vi.fn().mockResolvedValue({}),
    cancelModelDownload: vi.fn(),
  },
}));

describe("ModelDownloadProgress", () => {
  it("renderiza sin romperse", () => {
    const { container } = render(
      <ModelDownloadProgress modelName="small" onComplete={() => {}} />,
    );
    expect(container).toBeTruthy();
  });
});
