import { describe, expect, it } from 'vitest'
import { sha256Hex, bodyMatches } from './hash'

describe('sha256Hex', () => {
  it('hashes UTF-8 bytes', async () => {
    expect(await sha256Hex('abc')).toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
    expect(await sha256Hex('ñ')).toBe('024bb90888ca89a15a19e9bdd8c712bfb070465fce1ef25e43c170ea44fc5e5f')
  })
  it('bodyMatches only for the exact bytes', async () => {
    const h = await sha256Hex('{"a":1}')
    expect(await bodyMatches('{"a":1}', h)).toBe(true)
    expect(await bodyMatches('{"a": 1}', h)).toBe(false)
    expect(await bodyMatches('{"a":1}', h.toUpperCase())).toBe(false)
  })
})
