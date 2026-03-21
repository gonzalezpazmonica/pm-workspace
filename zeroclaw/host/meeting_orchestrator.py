"""Meeting Orchestrator — unified controller for physical + Teams meetings.

Same brain, two channels. Uses meeting_participant, context_guardian,
and speaker_roles regardless of whether audio comes from ZeroClaw
or transcript from Teams.
"""
from .meeting_participant import MeetingParticipant
from .context_guardian import ContextGuardian
from .speaker_roles import SpeakerRoleManager


class MeetingOrchestrator:
    """Orchestrates Savia's participation in any meeting format."""

    def __init__(self, project_dir=None, team_file=None, config=None):
        self.participant = MeetingParticipant(config)
        self.guardian = ContextGuardian(project_dir)
        self.roles = SpeakerRoleManager(team_file)
        self.channel = None  # "zeroclaw" or "teams"
        self.session_id = None
        self.transcript = []

    def start(self, channel, session_id=None):
        """Start meeting session on a channel."""
        self.channel = channel
        self.session_id = session_id
        self.transcript = []
        return {"status": "started", "channel": channel}

    def process_utterance(self, speaker, text, timestamp=None):
        """Process a single utterance. Works for both channels.

        For ZeroClaw: called after STT + speaker ID.
        For Teams: called after parsing transcript chunk.

        Returns: {notes, intervention, filtered_response}
        """
        self.participant.on_speech_detected()

        # 1. Guardian checks against project context
        observations = self.guardian.check_transcript_line(speaker, text)
        for obs in observations:
            self.participant.add_note(
                obs["type"], obs["text"], severity=obs["severity"])

        # 2. Add to transcript
        entry = {"ts": timestamp, "speaker": speaker, "text": text}
        self.transcript.append(entry)

        # 3. Check for intervention opportunity
        intervention = self.participant.on_silence()

        # 4. If intervention, filter by requester role
        if intervention:
            role = self.roles.get_role(speaker)
            intervention["speaker_role"] = role

        return {
            "observations": observations,
            "intervention": intervention,
        }

    def handle_query(self, speaker, question):
        """Handle direct query from a meeting participant.

        Applies role-based filtering to the response.
        """
        role = self.roles.get_role(speaker)
        raw = self.participant.on_query(question)

        # Filter response by speaker's permissions
        filtered = self.roles.filter_response(speaker, {
            "query_response": raw,
            "sprint_items": True,
            "blockers": True,
        })

        return {
            "speaker": speaker,
            "role": role,
            "response": filtered,
            "channel": self.channel,
        }

    def set_mode(self, mode):
        return self.participant.set_mode(mode)

    def stop(self):
        """Stop meeting. Returns summary + buffer for digest."""
        summary = self.participant.stop()
        summary["transcript_lines"] = len(self.transcript)
        summary["channel"] = self.channel
        summary["notes_for_digest"] = self.participant.get_buffer_for_digest()
        return summary

    def get_status(self):
        return {
            "channel": self.channel,
            "participant": self.participant.get_status(),
            "speakers": self.roles.list_speakers(),
            "transcript_lines": len(self.transcript),
        }
