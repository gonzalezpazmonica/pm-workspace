"""Speaker Roles — maps voice identity to project role and permissions.

Determines what Savia can reveal to each person during meetings.
Role detection: voiceprint → equipo.md lookup → permission level.

Guardrail: this is CODE, not an LLM instruction. Permissions are
enforced by Python functions that filter output before speaking.
"""
import os
import json

# Permission levels (ascending)
LEVELS = {
    "observer": 0,    # can hear summary, no details
    "developer": 1,   # can query sprint items, code, tests
    "tech_lead": 2,   # + architecture, debt, security findings
    "pm": 3,          # + capacity, costs, evaluations, all data
    "external": -1,   # NOTHING — only public info
}

# What each level can access
ALLOWED_TOPICS = {
    "external": {"public_info"},
    "observer": {"public_info", "sprint_summary"},
    "developer": {"public_info", "sprint_summary", "sprint_items",
                  "code_status", "test_results", "blockers"},
    "tech_lead": {"public_info", "sprint_summary", "sprint_items",
                  "code_status", "test_results", "blockers",
                  "architecture", "debt", "security", "performance"},
    "pm": set(),  # PM gets EVERYTHING (empty set = no restrictions)
}

# What NOBODY gets in a meeting (even PM uses console for these)
NEVER_VOICE = {
    "personal_evaluations",  # individual performance reviews
    "salary_data",           # compensation information
    "voiceprints",           # biometric data
    "credentials",           # PATs, passwords, keys
    "pii",                   # personal identifiable info of others
}


class SpeakerRoleManager:
    """Maps speakers to roles and filters responses by permission."""

    def __init__(self, team_file=None):
        self.roles = {}  # {speaker_name: role}
        self._load_team(team_file)

    def _load_team(self, team_file):
        """Load roles from equipo.md or team config."""
        if not team_file or not os.path.isfile(team_file):
            return
        with open(team_file) as f:
            for line in f:
                # Format: | Name | Role | ...
                parts = [p.strip() for p in line.split('|') if p.strip()]
                if len(parts) >= 2:
                    name = parts[0].lower()
                    role = self._detect_role(parts[1].lower())
                    if role:
                        self.roles[name] = role

    def _detect_role(self, role_text):
        """Map role text to permission level."""
        if any(w in role_text for w in ['pm', 'product manager', 'scrum']):
            return "pm"
        if any(w in role_text for w in ['lead', 'architect', 'senior']):
            return "tech_lead"
        if any(w in role_text for w in ['dev', 'developer', 'engineer',
                                         'qa', 'tester']):
            return "developer"
        return "observer"

    def set_role(self, speaker_name, role):
        """Manually set role for a speaker."""
        if role in LEVELS:
            self.roles[speaker_name.lower()] = role
            return {"ok": True, "speaker": speaker_name, "role": role}
        return {"ok": False, "error": f"Unknown role: {role}"}

    def get_role(self, speaker_name):
        """Get role for a speaker. Default: observer."""
        return self.roles.get(speaker_name.lower(), "observer")

    def get_level(self, speaker_name):
        """Get numeric permission level."""
        role = self.get_role(speaker_name)
        return LEVELS.get(role, 0)

    def can_access(self, speaker_name, topic):
        """Check if speaker can access a topic. Returns bool."""
        if topic in NEVER_VOICE:
            return False
        role = self.get_role(speaker_name)
        allowed = ALLOWED_TOPICS.get(role, set())
        if not allowed:  # empty set = PM = access all
            return True
        return topic in allowed

    def filter_response(self, speaker_name, response_data):
        """Filter response to only include permitted topics.

        This is the GATE function. ALL voice responses MUST pass
        through this before being spoken. No exceptions.
        """
        role = self.get_role(speaker_name)
        allowed = ALLOWED_TOPICS.get(role, set())

        # PM gets everything (except NEVER_VOICE)
        if not allowed:
            return {k: v for k, v in response_data.items()
                    if k not in NEVER_VOICE}

        return {k: v for k, v in response_data.items()
                if k in allowed and k not in NEVER_VOICE}

    def list_speakers(self):
        return dict(self.roles)
