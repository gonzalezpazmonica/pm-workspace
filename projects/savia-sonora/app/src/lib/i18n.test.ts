import { describe, it, expect } from "vitest";
import { t, setLocale, getLocale } from "./i18n";

describe("i18n", () => {
  it("defaults to Spanish (perfil activo de Savia)", () => {
    expect(getLocale()).toBe("es");
  });

  it("returns the key itself when translation is missing", () => {
    expect(t("clave.que.no.existe")).toBe("clave.que.no.existe");
  });

  it("interpolates {vars} in translations", () => {
    expect(t("sidebar.hotkey", { key: "Ctrl+Win" })).toContain("Ctrl+Win");
  });

  it("can switch locale to en", () => {
    setLocale("en");
    expect(t("nav.home")).toBe("Home");
    setLocale("es");
    expect(t("nav.home")).toBe("Inicio");
  });
});
