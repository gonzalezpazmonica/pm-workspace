"""Voice-guided assembly — TTS offline via pyttsx3.

Reads assembly steps aloud so the human can work hands-free.
Falls back to text-only if pyttsx3 not installed.
"""
import sys

TTS_AVAILABLE = False
try:
    import pyttsx3
    TTS_AVAILABLE = True
except ImportError:
    pass


class VoiceGuide:
    """Step-by-step voice narrator for assembly guides."""

    def __init__(self, steps, lang="es", rate=130):
        """
        Args:
            steps: List of (step_title, step_text) tuples
            lang: Language code ("es" or "en")
            rate: Speech rate (words per minute, 130 = slow/clear)
        """
        self.steps = steps
        self.current = 0
        self.lang = lang
        self.engine = None
        if TTS_AVAILABLE:
            self.engine = pyttsx3.init()
            self.engine.setProperty('rate', rate)
            self.engine.setProperty('volume', 0.9)
            self._set_voice(lang)

    def _set_voice(self, lang):
        if not self.engine:
            return
        voices = self.engine.getProperty('voices')
        target = 'spanish' if lang == 'es' else 'english'
        for v in voices:
            if target in v.name.lower() or target in str(v.languages).lower():
                self.engine.setProperty('voice', v.id)
                return

    def say(self, text):
        """Speak text or print if TTS unavailable."""
        if self.engine:
            self.engine.say(text)
            self.engine.runAndWait()
        else:
            print(f"  🔊 {text}")

    def current_step(self):
        if 0 <= self.current < len(self.steps):
            return self.steps[self.current]
        return None, None

    def speak_current(self):
        title, text = self.current_step()
        if title:
            step_num = self.current + 1
            total = len(self.steps)
            self.say(f"Paso {step_num} de {total}. {title}")
            self.say(text)
            return True
        return False

    def next(self):
        if self.current < len(self.steps) - 1:
            self.current += 1
            return self.speak_current()
        self.say("Has completado todos los pasos. Verificación final.")
        return False

    def prev(self):
        if self.current > 0:
            self.current -= 1
            return self.speak_current()
        self.say("Ya estás en el primer paso.")
        return True

    def repeat(self):
        return self.speak_current()

    def status(self):
        msg = f"Paso {self.current + 1} de {len(self.steps)}"
        self.say(msg)
        return msg

    def run_interactive(self):
        """Run full interactive voice session."""
        if not self.steps:
            print("No assembly steps loaded.")
            return
        print("🔊 Guía de voz — Comandos: [Enter]=siguiente, "
              "[r]=repetir, [b]=atrás, [s]=estado, [q]=salir")
        print()
        self.speak_current()

        while True:
            cmd = input("  > ").strip().lower()
            if cmd in ('', 'n', 'next'):
                if not self.next():
                    break
            elif cmd in ('r', 'repeat'):
                self.repeat()
            elif cmd in ('b', 'back', 'prev'):
                self.prev()
            elif cmd in ('s', 'status'):
                self.status()
            elif cmd in ('q', 'quit', 'exit'):
                self.say("Guía detenida.")
                break
            else:
                print("  Comandos: Enter, r(epeat), b(ack), s(tatus), q(uit)")


def is_available():
    """Check if TTS is available."""
    return TTS_AVAILABLE
