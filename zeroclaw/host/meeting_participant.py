"""Savia Meeting Participant — context guardian + opportunity window detector.

Runs during live meetings. Maintains internal note buffer, detects
speech windows, and decides when Savia can speak proactively.
"""
import time
import json
import os

# Window detection parameters
SILENCE_THRESHOLD_SEC = 3.0
COOLDOWN_SEC = 300  # 5 minutes between proactive interventions
MAX_PROACTIVE_PER_MEETING = 3


class MeetingParticipant:
    """Manages Savia's active participation in a meeting."""

    def __init__(self, config=None):
        cfg = config or {}
        self.mode = cfg.get("proactive", True)
        self.threshold = cfg.get("proactive_threshold", "critical")
        self.max_interventions = cfg.get("max_interventions",
                                         MAX_PROACTIVE_PER_MEETING)
        self.cooldown = cfg.get("cooldown_minutes", 5) * 60
        self.notes = []          # internal context buffer
        self.interventions = 0
        self.last_intervention = 0
        self.last_speech_end = time.time()
        self.pending_critical = []  # queued critical observations
        self.is_active = True

    def on_speech_detected(self):
        """Called when VAD detects someone is speaking."""
        self.last_speech_end = time.time()

    def on_silence(self):
        """Called on each silence check. Returns intervention or None."""
        if not self.mode or not self.is_active:
            return None
        silence_duration = time.time() - self.last_speech_end
        if silence_duration < SILENCE_THRESHOLD_SEC:
            return None
        if self.interventions >= self.max_interventions:
            return None
        if time.time() - self.last_intervention < self.cooldown:
            return None
        if not self.pending_critical:
            return None
        # All 5 conditions met — speak
        note = self.pending_critical.pop(0)
        self.interventions += 1
        self.last_intervention = time.time()
        return {
            "type": "proactive",
            "text": note["text"],
            "reason": note["type"],
            "intervention_num": self.interventions,
        }

    def add_note(self, note_type, text, ref=None, severity="info"):
        """Add internal observation to context buffer."""
        entry = {
            "type": note_type,
            "text": text,
            "ref": ref,
            "severity": severity,
            "ts": time.strftime("%H:%M:%S"),
        }
        self.notes.append(entry)
        if severity == "critical" and self.mode:
            self.pending_critical.append(entry)

    def on_query(self, question, project_context=None):
        """Handle direct question to Savia. Returns response dict."""
        # Search notes buffer for relevant context
        relevant = [n for n in self.notes
                    if any(w in n["text"].lower()
                           for w in question.lower().split()
                           if len(w) > 3)]
        return {
            "type": "query_response",
            "question": question,
            "relevant_notes": relevant[:3],
            "notes_total": len(self.notes),
        }

    def set_mode(self, mode_name):
        """Change mode: silent, query, active."""
        modes = {
            "silent": (False, "critical"),
            "silencioso": (False, "critical"),
            "query": (False, "critical"),
            "consulta": (False, "critical"),
            "active": (True, "critical"),
            "activo": (True, "critical"),
        }
        if mode_name in modes:
            self.mode, self.threshold = modes[mode_name]
            return {"mode": mode_name, "proactive": self.mode}
        return {"error": f"Unknown mode: {mode_name}"}

    def get_status(self):
        return {
            "mode": "active" if self.mode else "query/silent",
            "notes": len(self.notes),
            "pending_critical": len(self.pending_critical),
            "interventions": f"{self.interventions}/{self.max_interventions}",
            "active": self.is_active,
        }

    def get_buffer_for_digest(self):
        """Return full notes buffer for post-meeting digest."""
        return self.notes

    def stop(self):
        self.is_active = False
        return {
            "total_notes": len(self.notes),
            "interventions_made": self.interventions,
            "pending_unspoken": len(self.pending_critical),
        }
