"""Tests for the meeting post-processor (SE-308 S4).

MeetingPostProcessor takes a finished meeting folder (audio.wav + meta.json),
transcribes the audio (via an injected transcription service), and writes
transcript.vtt + transcript.md + updates meta.json.
"""

import sys
import os
import json
import tempfile
import shutil
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


class FakeTranscriber:
    """Deterministic transcription result."""

    def __init__(self, text="Hola equipo, empecemos la reunion.",
                 segments=None, language="es"):
        self.text = text
        self.segments = segments or [
            {"start_ms": 0, "end_ms": 1000, "text": "Hola equipo,"},
            {"start_ms": 1000, "end_ms": 2000, "text": "empecemos la reunion."},
        ]
        self.language = language
        self.calls = []

    def transcribe_file(self, audio_path, **kw):
        self.calls.append(audio_path)
        return {
            "text": self.text,
            "segments": self.segments,
            "language": self.language,
        }


def _load_postprocessor():
    import importlib.util
    path = os.path.join(os.path.dirname(__file__), '..', 'services', 'recording', 'postprocessor.py')
    spec = importlib.util.spec_from_file_location('postproc_mod', path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules['postproc_mod'] = mod
    spec.loader.exec_module(mod)
    return mod


class TestMeetingPostProcessor:
    def setup_method(self):
        self.mod = _load_postprocessor()
        self.tmp = tempfile.mkdtemp()
        self.meeting_dir = Path(self.tmp) / 'reuniones' / '2026-08-04-09-15'
        self.meeting_dir.mkdir(parents=True)
        # audio stub
        (self.meeting_dir / 'audio.wav').write_bytes(b'RIFFFAKE')
        # meta stub
        (self.meeting_dir / 'meta.json').write_text(json.dumps({
            'id': 'm1', 'started_at': '2026-08-04T09:15:00Z',
            'duration_ms': 120000, 'captures': 8, 'model': 'small',
        }))

    def teardown_method(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_transcribes_audio(self):
        transcriber = FakeTranscriber()
        proc = self.mod.MeetingPostProcessor(transcriber)
        proc.process(self.meeting_dir)
        assert transcriber.calls == [str(self.meeting_dir / 'audio.wav')]

    def test_writes_vtt(self):
        transcriber = FakeTranscriber()
        proc = self.mod.MeetingPostProcessor(transcriber)
        proc.process(self.meeting_dir)
        vtt = self.meeting_dir / 'transcript.vtt'
        assert vtt.exists()
        content = vtt.read_text()
        assert 'WEBVTT' in content
        assert 'Hola equipo,' in content

    def test_writes_markdown(self):
        transcriber = FakeTranscriber()
        proc = self.mod.MeetingPostProcessor(transcriber)
        proc.process(self.meeting_dir)
        md = self.meeting_dir / 'transcript.md'
        assert md.exists()
        content = md.read_text()
        assert 'Hola equipo,' in content
        assert 'Transcripcion' in content

    def test_updates_meta_with_transcript_info(self):
        transcriber = FakeTranscriber()
        proc = self.mod.MeetingPostProcessor(transcriber)
        proc.process(self.meeting_dir)
        meta = json.loads((self.meeting_dir / 'meta.json').read_text())
        assert meta['transcribed'] is True
        assert meta['language'] == 'es'
        assert meta['transcript_files'] == ['transcript.vtt', 'transcript.md']

    def test_segment_timestamps_in_vtt(self):
        transcriber = FakeTranscriber()
        proc = self.mod.MeetingPostProcessor(transcriber)
        proc.process(self.meeting_dir)
        vtt = (self.meeting_dir / 'transcript.vtt').read_text()
        # VTT timestamps formato: 00:00:00.000 --> 00:00:01.000
        assert '00:00:00.000 --> 00:00:01.000' in vtt

    def test_missing_audio_is_skipped(self):
        transcriber = FakeTranscriber()
        proc = self.mod.MeetingPostProcessor(transcriber)
        empty = Path(self.tmp) / 'reuniones' / 'empty'
        empty.mkdir()
        result = proc.process(empty)  # no audio.wav
        assert result is None or result == {}
