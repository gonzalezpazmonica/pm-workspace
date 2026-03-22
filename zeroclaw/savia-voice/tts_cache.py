"""TTS Pre-cache — Muletillas, stalls y respuestas para conversación natural.

Basado en:
- Sacks-Schegloff-Jefferson turn-taking model (1974)
- Briz Gómez: El español coloquial en la conversación (Val.Es.Co)
- CVC Cervantes: marcadores discursivos
- Estudio muletillas en español hablado (Universidad de Tartu)

3 tipos de audio pre-generado:
1. RESPONSES: Respuestas frecuentes exactas (0ms)
2. FILLERS: Muletillas cortas 0.5-1.5s (inicio de turno)
3. STALLS: Frases de ganar tiempo 1.5-3s (mientras el LLM trabaja)

Personalidad Savia: profesional-cercana, española peninsular, directa,
cálida sin empalagar. No usa jerga juvenil ni masculinismos.
"""

import random
import numpy as np

KOKORO_RATE = 24000

# ── Respuestas comunes (exact match, 0ms) ───────────────────────────────
CACHE_PHRASES = [
    "Aquí estoy.", "Te escucho.", "Dime.",
    "Entendido.", "De acuerdo.", "Vale.", "Perfecto.",
    "Hecho.", "Listo.",
    "Dame un momento.", "Déjame pensar.", "Un segundo.",
    "Sí.", "No.", "Claro.", "Exacto.",
    "No lo sé.", "No estoy segura.",
    "No he entendido eso.", "Repítemelo, por favor.",
]

# ── Muletillas cortas (0.5-1.5s) — inicio de turno ─────────────────────
FILLERS = {
    "inicio": [
        "Pues mira...", "A ver...", "Vamos a ver...",
        "Mira...", "Bueno...",
    ],
    "reflexion": [
        "Déjame ver...", "Veamos...", "Hmm, vale...",
        "Déjame pensar...",
    ],
    "acuerdo": [
        "Sí, verás...", "Claro, te cuento...",
        "Vale, pues...", "Sí, mira...",
    ],
    "transicion": [
        "Entonces...", "Pues bien...",
        "Vale, pues...", "En ese caso...",
    ],
    "empatia": [
        "Entiendo...", "Ya veo...",
        "Claro, claro...", "Comprendo...",
    ],
}

# ── Stalls (1.5-3s) — ganar tiempo mientras el LLM procesa ─────────────
# Estas frases suenan naturales y compran 2-4 segundos reales.
# Se usan cuando la muletilla corta ya sonó y aún no hay respuesta.
STALLS = {
    "buscando": [
        "Déjame que lo mire.",
        "Voy a comprobarlo.",
        "Estoy buscándolo.",
        "Un momento, que lo localizo.",
        "Déjame que consulte eso.",
        "Voy a echarle un vistazo.",
    ],
    "pensando": [
        "Déjame que le dé una vuelta.",
        "Es buena pregunta, déjame pensar.",
        "Voy a pensarlo un momento.",
        "A ver cómo te lo explico.",
        "Dame un segundo que organizo las ideas.",
        "Necesito un momento para eso.",
    ],
    "investigando": [
        "Voy a investigar sobre el tema.",
        "Déjame que revise la información.",
        "Estoy mirando los datos.",
        "Un segundo, que estoy recopilando.",
        "Voy a revisar eso ahora mismo.",
        "Estoy consultando, un momentito.",
    ],
    "procesando": [
        "Estoy en ello.",
        "Ya casi lo tengo.",
        "Un poquito más de paciencia.",
        "Casi estoy, un segundo.",
        "Estoy trabajando en ello.",
        "Dame unos segundos más.",
    ],
}

# ── Mapeo: primera palabra → categoría de filler ────────────────────────
QUESTION_MAP = {
    "que": "inicio", "qué": "inicio",
    "como": "reflexion", "cómo": "reflexion",
    "por": "reflexion",
    "puedes": "acuerdo", "podrías": "acuerdo",
    "hazme": "acuerdo", "necesito": "acuerdo",
    "si": "acuerdo", "sí": "acuerdo",
    "pero": "empatia", "es": "empatia",
    "y": "transicion", "entonces": "transicion",
    "dime": "inicio", "lista": "inicio", "busca": "inicio",
}

# ── Mapeo: tipo de tarea → categoría de stall ───────────────────────────
STALL_MAP = {
    "que": "buscando",
    "qué": "buscando",
    "busca": "buscando", "lista": "buscando", "dime": "buscando",
    "como": "pensando", "cómo": "pensando",
    "por": "pensando", "explica": "pensando",
    "investiga": "investigando", "analiza": "investigando",
    "revisa": "investigando",
    "hazme": "procesando", "genera": "procesando",
    "crea": "procesando", "prepara": "procesando",
}


class TTSCache:
    """Audio pre-generado: respuestas + muletillas + stalls."""

    def __init__(self):
        self._cache = {}
        self._fillers = {}
        self._stalls = {}
        self._last_filler_cat = None
        self._last_stall_cat = None

    def warm(self, kokoro_pipe, voice):
        all_phrases = list(CACHE_PHRASES)
        for phrases in FILLERS.values():
            all_phrases.extend(phrases)
        for phrases in STALLS.values():
            all_phrases.extend(phrases)

        print(f"[cache] Pre-generando {len(all_phrases)} frases...")
        for phrase in all_phrases:
            self._generate(kokoro_pipe, voice, phrase)

        for cat, phrases in FILLERS.items():
            self._fillers[cat] = self._index(phrases)
        for cat, phrases in STALLS.items():
            self._stalls[cat] = self._index(phrases)

        nf = sum(len(v) for v in self._fillers.values())
        ns = sum(len(v) for v in self._stalls.values())
        print(f"[cache] {len(self._cache)} total: "
              f"{len(CACHE_PHRASES)} respuestas + "
              f"{nf} muletillas + {ns} stalls.")

    def warm_from_files(self, audio_dir):
        """Load pre-generated audio from disk (skip Kokoro generation)."""
        from pathlib import Path
        import wave
        d = Path(audio_dir)
        if not d.exists():
            return False
        count = 0
        for wav in d.glob("*.wav"):
            key = wav.stem.replace("_", " ")
            with wave.open(str(wav), "rb") as wf:
                data = np.frombuffer(
                    wf.readframes(wf.getnframes()), dtype=np.int16
                )
                rate = wf.getframerate()
            self._cache[key] = (data, rate)
            count += 1
        if count == 0:
            return False
        for cat, phrases in FILLERS.items():
            self._fillers[cat] = self._index(phrases)
        for cat, phrases in STALLS.items():
            self._stalls[cat] = self._index(phrases)
        nf = sum(len(v) for v in self._fillers.values())
        ns = sum(len(v) for v in self._stalls.values())
        print(f"[cache] Cargado de disco: {count} audios, "
              f"{nf} muletillas + {ns} stalls.")
        return True

    def _generate(self, pipe, voice, phrase):
        try:
            segs = list(pipe(phrase, voice=voice))
            if not segs:
                return
            audio = np.concatenate([s[2] for s in segs])
            data = (audio * 32767).astype(np.int16)
            self._cache[self._key(phrase)] = (data, KOKORO_RATE)
        except Exception:
            pass

    def _index(self, phrases):
        result = []
        for phrase in phrases:
            key = self._key(phrase)
            if key in self._cache:
                result.append((phrase, self._cache[key]))
        return result

    def _key(self, text):
        return text.lower().strip().rstrip(".").rstrip("…").strip()

    def get(self, text):
        return self._cache.get(self._key(text))

    def get_filler(self, user_text=""):
        return self._pick(
            QUESTION_MAP, self._fillers, user_text,
            "_last_filler_cat", "inicio"
        )

    def get_stall(self, user_text=""):
        return self._pick(
            STALL_MAP, self._stalls, user_text,
            "_last_stall_cat", "pensando"
        )

    def _pick(self, mapping, pool, text, last_attr, default):
        cat = self._categorize(mapping, text, default)
        last = getattr(self, last_attr)
        if cat == last and len(pool) > 1:
            alts = [c for c in pool if c != cat and pool[c]]
            if alts:
                cat = random.choice(alts)
        setattr(self, last_attr, cat)
        options = pool.get(cat, pool.get(default, []))
        if not options:
            return None
        return random.choice(options)

    def _categorize(self, mapping, text, default):
        first = text.lower().strip().split()[0] if text.strip() else ""
        for trigger, cat in mapping.items():
            if first.startswith(trigger):
                return cat
        return default
