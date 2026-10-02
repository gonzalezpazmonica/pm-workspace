/** SHA-256 of the UTF-8 bytes, lowercase hex. Uses WebCrypto (127.0.0.1 is a secure context). */
export async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text))
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('')
}

/** The inspector only enables «Enviar» when the bytes shown are the bytes approved. */
export async function bodyMatches(bodyText: string, payloadHash: string): Promise<boolean> {
  return (await sha256Hex(bodyText)) === payloadHash
}
