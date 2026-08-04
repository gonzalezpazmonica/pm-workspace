export const INVALID_AUDIO_PAYLOAD = "Invalid audio payload";

export function isInvalidAudioPayload(err: unknown): boolean {
  return err instanceof Error && err.message === INVALID_AUDIO_PAYLOAD;
}

export function base64ToBlobUrl(base64: string, mime: string): string {
  try {
    const byteCharacters = atob(base64);
    const byteArray = Uint8Array.from(byteCharacters, (c) => c.charCodeAt(0));
    const blob = new Blob([byteArray], { type: mime });
    return URL.createObjectURL(blob);
  } catch (err) {
    console.error("Failed to create audio blob URL (invalid payload):", err);
    throw new Error(INVALID_AUDIO_PAYLOAD);
  }
}

export function revokeUrl(url?: string | null) {
  if (url) {
    URL.revokeObjectURL(url);
  }
}
