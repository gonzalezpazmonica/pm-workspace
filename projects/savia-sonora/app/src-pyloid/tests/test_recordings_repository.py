"""Focused tests for RecordingsRepository (services/recording/repository.py).

test_recordings_repo.py already exercises most moved methods through the
DatabaseService delegating methods; this file covers what that one doesn't:

  * the `db.recordings` attribute is the repository and is what the
    delegates forward to (same rows visible from both surfaces),
  * `set_recording_transcript` (not covered by test_recordings_repo.py),
    including the COALESCE semantics for language / transcript_model.
"""

import tempfile
from pathlib import Path

import pytest

from services.database import DatabaseService
from services.recording.repository import RecordingsRepository


@pytest.fixture
def db():
    with tempfile.TemporaryDirectory() as tmpdir:
        yield DatabaseService(Path(tmpdir) / "test.db")


@pytest.fixture
def repo(db):
    return db.recordings


class TestRepositoryWiring:
    def test_db_exposes_recordings_repository(self, db):
        assert isinstance(db.recordings, RecordingsRepository)

    def test_delegates_and_repo_share_the_same_table(self, db, repo):
        rid = repo.create_recording(title="via repo", sources=["mic"])
        # Visible through the backward-compat delegate...
        assert db.get_recording(rid)["title"] == "via repo"
        # ...and writes through the delegate are visible through the repo.
        db.update_recording(rid, title="via delegate")
        assert repo.get_recording(rid)["title"] == "via delegate"


class TestSetRecordingTranscript:
    def test_round_trip(self, repo):
        rid = repo.create_recording(title="x", sources=["mic"])
        repo.set_recording_transcript(rid, "hello world", language="en", model="tiny")
        rec = repo.get_recording(rid)
        assert rec["transcript"] == "hello world"
        assert rec["language"] == "en"
        assert rec["transcript_model"] == "tiny"

    def test_none_language_and_model_preserve_existing(self, repo):
        rid = repo.create_recording(title="x", sources=["mic"])
        repo.set_recording_transcript(rid, "first", language="en", model="tiny")
        # Re-transcribe without language/model must not clear the columns.
        repo.set_recording_transcript(rid, "second")
        rec = repo.get_recording(rid)
        assert rec["transcript"] == "second"
        assert rec["language"] == "en"
        assert rec["transcript_model"] == "tiny"

    def test_bumps_updated_at(self, repo):
        rid = repo.create_recording(title="x", sources=["mic"])
        before = repo.get_recording(rid)["updated_at"]
        repo.set_recording_transcript(rid, "t")
        assert repo.get_recording(rid)["updated_at"] >= before
