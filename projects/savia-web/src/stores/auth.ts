import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { TeamMember } from '../types/bridge'

const COOKIE_NAME = 'savia_session'
const CONN_COOKIE = 'savia_connection'

function readCookie(): { serverUrl: string; username: string; token: string } | null {
  const match = document.cookie.split('; ').find(c => c.startsWith(`${COOKIE_NAME}=`))
  if (!match) return null
  try { return JSON.parse(decodeURIComponent(match.split('=').slice(1).join('='))) }
  catch { return null }
}

function writeCookie(serverUrl: string, username: string, token: string) {
  const val = JSON.stringify({ serverUrl, username, token })
  document.cookie = `${COOKIE_NAME}=${encodeURIComponent(val)}; path=/; SameSite=Lax`
}

function readConnCookie(): { serverUrl: string; token: string } | null {
  const match = document.cookie.split('; ').find(c => c.startsWith(`${CONN_COOKIE}=`))
  if (!match) return null
  try { return JSON.parse(decodeURIComponent(match.split('=').slice(1).join('='))) }
  catch { return null }
}

function writeConnCookie(serverUrl: string, token: string) {
  const val = JSON.stringify({ serverUrl, token })
  document.cookie = `${CONN_COOKIE}=${encodeURIComponent(val)}; path=/; max-age=31536000; SameSite=Lax`
}

function clearCookie() {
  document.cookie = `${COOKIE_NAME}=; path=/; max-age=0`
}

export const useAuthStore = defineStore('auth', () => {
  const saved = readCookie()
  const conn = readConnCookie()
  const serverUrl = ref(saved?.serverUrl || conn?.serverUrl || 'https://localhost:8922')
  const username = ref(saved?.username || '')
  const token = ref(saved?.token || conn?.token || '')
  const connected = ref(false)
  const profile = ref<TeamMember | null>(null)

  const profileName = computed(() => profile.value?.name || username.value || '')
  const isLoggedIn = computed(() => connected.value && !!token.value && !!username.value)
  const hasCookie = computed(() => !!readCookie())

  function login(url: string, user: string, tok: string, member: TeamMember | null) {
    serverUrl.value = url
    username.value = user
    token.value = tok
    profile.value = member
    connected.value = true
    writeCookie(url, user, tok)
  }

  function setProfile(member: TeamMember) { profile.value = member }
  function setConnected(ok: boolean) { connected.value = ok }

  function logout() {
    connected.value = false
    token.value = ''
    username.value = ''
    profile.value = null
    clearCookie()
  }

  // Legacy compat — useBridge reads these
  const host = computed(() => { try { return new URL(serverUrl.value).hostname } catch { return 'localhost' } })
  const port = computed(() => { try { return new URL(serverUrl.value).port || '8922' } catch { return '8922' } })
  const useTls = computed(() => serverUrl.value.startsWith('https'))

  function save(h: string, p: string, t: string, tls: boolean) {
    const proto = tls ? 'https' : 'http'
    serverUrl.value = `${proto}://${h}:${p}`
    token.value = t
    writeConnCookie(serverUrl.value, t)
  }

  return {
    serverUrl, username, token, connected, profile, profileName,
    isLoggedIn, hasCookie, host, port, useTls,
    login, logout, setProfile, setConnected, save,
  }
})
