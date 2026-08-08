import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

const HOTKEY_DISPLAY_MAP: Record<string, string> = {
  ctrl: "Ctrl",
  alt: "Alt",
  shift: "Shift",
  win: "Win",
}

export function formatHotkeyForDisplay(hotkey: string | null | undefined): string {
  if (!hotkey) return ""
  return hotkey
    .split("+")
    .map((part) => {
      const key = part.trim().toLowerCase()
      if (HOTKEY_DISPLAY_MAP[key]) return HOTKEY_DISPLAY_MAP[key]
      return key.charAt(0).toUpperCase() + key.slice(1)
    })
    .join("+")
}
