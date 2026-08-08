import "@testing-library/jest-dom";
import { vi } from "vitest";

// Savia Sonora talks to the desktop backend through the Pyloid bridge
// (`pyloid-js`), which is unavailable in jsdom. Mock the RPC layer globally
// so component tests can run without the Qt/desktop host.
vi.mock("pyloid-js", () => ({
  rpc: {
    call: vi.fn(),
  },
}));

// jsdom does not implement matchMedia (used by theme/system detection).
Object.defineProperty(window, "matchMedia", {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
});
