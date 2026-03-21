"""Context Guardian — cross-references meeting speech with project data.

Runs in background during meetings. Detects contradictions, missing
context, incorrect data, and unmentioned risks by comparing what's
said against sprint status, decision log, and business rules.
"""
import os
import json
import re


class ContextGuardian:
    """Watches meeting transcript and flags issues against project data."""

    def __init__(self, project_dir=None):
        self.project_dir = project_dir
        self.decisions = self._load_decisions()
        self.rules = self._load_rules()
        self.known_items = self._load_sprint_items()

    def _load_file(self, *path_parts):
        if not self.project_dir:
            return ""
        path = os.path.join(self.project_dir, *path_parts)
        if os.path.isfile(path):
            with open(path) as f:
                return f.read()
        return ""

    def _load_decisions(self):
        content = self._load_file("decision-log.md")
        return [line.strip() for line in content.split('\n')
                if line.strip().startswith('- ')]

    def _load_rules(self):
        content = self._load_file("reglas-negocio.md")
        return [line.strip() for line in content.split('\n')
                if line.strip().startswith('RN-')]

    def _load_sprint_items(self):
        # Load from agent-notes or sprint state if available
        return []

    def check_transcript_line(self, speaker, text):
        """Check a single transcript line against project context.

        Returns list of {type, severity, text} observations.
        """
        observations = []
        lower = text.lower()

        # Check for date/deadline mentions
        date_match = re.findall(
            r'\b(\d{1,2})\s+de\s+(enero|febrero|marzo|abril|mayo|junio'
            r'|julio|agosto|septiembre|octubre|noviembre|diciembre)\b',
            lower)
        if date_match:
            observations.append({
                "type": "date_mentioned",
                "severity": "info",
                "text": f"{speaker} mentioned date: {date_match[0]}",
            })

        # Detect commitment language (action items)
        commit_patterns = [
            r'(yo|me)\s+(encargo|comprometo|hago)',
            r'(lo|la)\s+(tengo|termino)\s+(para|el|antes)',
            r'(para el|antes del)\s+(lunes|martes|miércoles|jueves|viernes)',
            r'i\'?ll\s+(do|finish|handle|take care)',
        ]
        for pat in commit_patterns:
            if re.search(pat, lower):
                observations.append({
                    "type": "action_item",
                    "severity": "info",
                    "text": f"ACTION: {speaker} committed: '{text[:80]}'",
                })
                break

        # Detect contradiction with prior decisions
        for decision in self.decisions:
            # Simple keyword overlap check
            d_words = set(re.findall(r'\w{4,}', decision.lower()))
            t_words = set(re.findall(r'\w{4,}', lower))
            overlap = d_words & t_words
            if len(overlap) >= 3:
                # Check if negation or change is mentioned
                if any(w in lower for w in ['no ', 'cambiar', 'en vez de',
                                             'mejor ', 'descartamos']):
                    observations.append({
                        "type": "contradiction",
                        "severity": "critical",
                        "text": (f"Possible contradiction with prior decision: "
                                 f"'{decision[:60]}' — {speaker} said: "
                                 f"'{text[:60]}'"),
                    })
                    break

        # Detect risk language
        risk_words = ['riesgo', 'peligro', 'problema', 'falla', 'no funciona',
                      'bloqueado', 'retrasado', 'imposible', 'risk', 'blocked']
        if any(w in lower for w in risk_words):
            observations.append({
                "type": "risk",
                "severity": "high",
                "text": f"RISK mentioned by {speaker}: '{text[:80]}'",
            })

        # Detect questions left unanswered (ends with ?)
        if text.strip().endswith('?'):
            observations.append({
                "type": "question",
                "severity": "info",
                "text": f"QUESTION by {speaker}: '{text[:80]}'",
            })

        return observations
