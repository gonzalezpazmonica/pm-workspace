// Ligero i18n para Savia Sonora — diccionario es/en, sin librería externa.
// El idioma por defecto es español (idioma del perfil activo de Savia).

type Dict = Record<string, string>;
type Vars = Record<string, string | number>;

const ES: Dict = {
  // Sidebar / navegación
  "nav.home": "Inicio",
  "nav.history": "Historial",
  "nav.meetings": "Reuniones",
  "nav.settings": "Ajustes",
  "nav.navigate": "navegar",
  "sidebar.subtitle": "Interfaz hablada de Savia",
  "sidebar.hotkey": "pulsa {key} en cualquier sitio",
  "sidebar.report": "Reportar un problema",
  "sidebar.github": "Ver en GitHub",
  "sidebar.opensource": "Código abierto",

  // Dashboard / Home
  "home.dashboard": "Panel",
  "home.subtitle":
    "Tu registro local de dictado. Pulsa tu hotkey en cualquier sitio para capturar, o usa el botón.",
  "home.record": "Grabar",
  "home.stop": "Detener",
  "home.search": "Buscar transcripciones",
  "home.noMatches": "Sin coincidencias",
  "home.match": "coincidencia",
  "home.matches": "coincidencias",
  "home.logEmptyLabel": "registro vacío",
  "home.logEmpty":
    "Tus transcripciones aparecerán aquí cuando dictes.",
  "home.logEmptyHint": "pulsa tu hotkey o usa el botón",
  "home.loadFailed": "No se pudo cargar el historial.",
  "home.retry": "Reintentar",
  "home.entry": "entrada",
  "home.entries": "entradas",
  "home.word": "palabra",
  "home.words": "palabras",
  "home.day": "día",
  "home.days": "días",
  "home.today": "hoy",
  "home.yesterday": "ayer",
  "home.audio": "audio",
  "home.copied": "Copiado al portapapeles",
  "home.copyFailed": "No se pudo copiar al portapapeles",
  "home.deleted": "Transcripción eliminada",
  "home.deleteFailed": "No se pudo eliminar la transcripción",
  "home.playAudio": "Reproducir audio",
  "home.loading": "Cargando…",
  "home.recordingOnboarding":
    "Termina la configuración antes de grabar",
  "home.recordFailed": "No se pudo iniciar/detener la grabación",
  "home.audioCorrupted": "El archivo de audio está dañado",
  "home.audioNotFound": "No se encontró el archivo de audio",

  // Stats
  "stats.words": "palabras",
  "stats.entries": "entradas",
  "stats.chars": "caracteres",
  "stats.streak": "racha",
  "stats.active": "activo",
  "stats.noStreak": "sin racha todavía",
  "stats.today": "hoy",
  "stats.model": "modelo",
  "stats.mic": "micrófono",
  "stats.language": "idioma",
  "stats.compute": "cómputo",


  // History
  "history.title": "Historial",
  "history.subtitle":
    "Todas tus transcripciones, buscables y ordenadas por fecha.",

  // Meetings
  "meetings.title": "Reuniones",
  "meetings.subtitle":
    "Grabaciones largas, transcritas y resumidas — tuyas para archivar, buscar y revisitar.",
  "meetings.new": "Nueva reunión",
  "meetings.import": "Importar audio",
  "meetings.live": "en directo",
  "meetings.empty":
    "Tu biblioteca de reuniones aparecerá aquí.",
  "meetings.record": "Grabar",

  // Settings
  "settings.title": "Ajustes",
  "settings.voice": "Voz y dictado",
  "settings.behavior": "Comportamiento",
  "settings.meetings": "Reuniones",
  "settings.appearance": "Apariencia",
  "settings.data": "Datos",
  "settings.reset": "Restablecer",

  // Onboarding
  "onboarding.welcome": "Bienvenida a Savia Sonora",
  "onboarding.welcomeSub":
    "Convierte tu voz en texto con IA local. Nada sale de tu máquina.",
  "onboarding.audio": "Configura el audio",
  "onboarding.audioSub":
    "Selecciona tu micrófono y comprueba los niveles de entrada.",
  "onboarding.hardware": "Hardware",
  "onboarding.hardwareSub":
    "Configura la aceleración por GPU para transcribir más rápido.",
  "onboarding.model": "Elige el modelo",
  "onboarding.modelSub":
    "Selecciona el modelo de IA y el idioma de transcripción.",
  "onboarding.download": "Descarga el modelo",
  "onboarding.downloadSub":
    "Descargando pesos — solo la primera vez, se guarda en local.",
  "onboarding.theme": "Tema",
  "onboarding.themeSub": "Elige cómo se ve Savia Sonora.",
  "onboarding.final": "Lista",
  "onboarding.finalSub": "Tu configuración está completa. ¡A dictar!",
};

const EN: Dict = {
  "nav.home": "Home",
  "nav.history": "History",
  "nav.meetings": "Meetings",
  "nav.settings": "Settings",
  "nav.navigate": "navigate",
  "sidebar.subtitle": "Savia's voice interface",
  "sidebar.hotkey": "press {key} anywhere",
  "sidebar.report": "Report an issue",
  "sidebar.github": "View on GitHub",
  "sidebar.opensource": "Open source",
  "home.dashboard": "Dashboard",
  "home.subtitle":
    "Your local dictation log. Press your hotkey anywhere to capture, or use the button.",
  "home.record": "Record",
  "home.stop": "Stop",
  "home.search": "Search transcriptions",
  "home.noMatches": "no matches",
  "home.match": "match",
  "home.matches": "matches",
  "home.logEmptyLabel": "log empty",
  "home.logEmpty": "Your transcriptions will appear here as you dictate.",
  "home.logEmptyHint": "press your hotkey or use the Record button",
  "home.loadFailed": "Failed to load history.",
  "home.retry": "retry",
  "home.entry": "entry",
  "home.entries": "entries",
  "home.word": "word",
  "home.words": "words",
  "home.day": "day",
  "home.days": "days",
  "home.today": "today",
  "home.yesterday": "yesterday",
  "home.audio": "audio",
  "home.copied": "Copied to clipboard",
  "home.copyFailed": "Failed to copy to clipboard",
  "home.deleted": "Transcription deleted",
  "home.deleteFailed": "Failed to delete transcription",
  "home.playAudio": "Play audio",
  "home.loading": "Loading…",
  "home.recordingOnboarding": "Finish onboarding before recording",
  "home.recordFailed": "Failed to toggle recording",
  "home.audioCorrupted": "Audio file is corrupted",
  "home.audioNotFound": "Audio file not found",

  // Stats
  "stats.words": "words",
  "stats.entries": "entries",
  "stats.chars": "chars",
  "stats.streak": "streak",
  "stats.active": "active",
  "stats.noStreak": "no streak yet",
  "stats.today": "today",
  "stats.model": "model",
  "stats.mic": "microphone",
  "stats.language": "language",
  "stats.compute": "compute",

  "history.title": "History",
  "history.subtitle": "All your transcriptions, searchable and grouped by date.",
  "meetings.title": "Meetings",
  "meetings.subtitle":
    "Long-form recordings, transcribed and summarized — yours to archive, search, and revisit.",
  "meetings.new": "New meeting",
  "meetings.import": "Import audio",
  "meetings.live": "live",
  "meetings.empty": "Your meeting library will appear here.",
  "meetings.record": "Record",
  "settings.title": "Settings",
  "settings.voice": "Voice & dictation",
  "settings.behavior": "Behavior",
  "settings.meetings": "Meetings",
  "settings.appearance": "Appearance",
  "settings.data": "Data",
  "settings.reset": "Reset",
  "onboarding.welcome": "Welcome to Savia Sonora",
  "onboarding.welcomeSub":
    "Turn your voice into text with local AI. Nothing leaves your machine.",
  "onboarding.audio": "Configure audio",
  "onboarding.audioSub": "Select your microphone and test the input levels.",
  "onboarding.hardware": "Hardware setup",
  "onboarding.hardwareSub":
    "Configure GPU acceleration for faster transcription.",
  "onboarding.model": "Choose model",
  "onboarding.modelSub":
    "Select the AI model and language for transcription.",
  "onboarding.download": "Download model",
  "onboarding.downloadSub":
    "Pulling weights — first run only, cached locally.",
  "onboarding.theme": "Theme",
  "onboarding.themeSub": "Choose how Savia Sonora looks.",
  "onboarding.final": "You're set",
  "onboarding.finalSub": "Your setup is complete. Start dictating!",
};

let locale: "es" | "en" = "es";

export function getLocale(): "es" | "en" {
  return locale;
}

export function setLocale(next: "es" | "en"): void {
  locale = next;
}

const dict: Record<"es" | "en", Dict> = { es: ES, en: EN };

export function t(key: string, vars?: Vars): string {
  const value = dict[locale][key] ?? dict.es[key] ?? key;
  if (!vars) return value;
  return value.replace(/\{(\w+)\}/g, (_, name: string) =>
    vars[name] !== undefined ? String(vars[name]) : `{${name}}`,
  );
}
