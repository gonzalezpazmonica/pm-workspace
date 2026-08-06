"""Tests for the meeting store (SE-308 S4).

MeetingStore manages meeting folders under reuniones/YYYY-MM-DD-HH-MM/:
creating a new session, listing sessions, and scanning for new/undigested
meetings (the hook Savia uses to detect new content).
"""

import sys
import os
import json
import tempfile
import shutil
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


def _load_store():
    import importlib.util
    path = os.path.join(os.path.dirname(__file__), '..', 'services', 'recording', 'meeting_store.py')
    spec = importlib.util.spec_from_file_location('store_mod', path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules['store_mod'] = mod
    spec.loader.exec_module(mod)
    return mod


class TestMeetingStore:
    def setup_method(self):
        self.mod = _load_store()
        self.tmp = tempfile.mkdtemp()
        self.root = Path(self.tmp) / 'reuniones'

    def teardown_method(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_new_session_creates_folder(self):
        store = self.mod.MeetingStore(self.root)
        folder = store.new_session()
        assert folder.exists()
        assert folder.is_dir()
        assert (folder / 'meta.json').exists()

    def test_new_session_name_is_timestamped(self):
        store = self.mod.MeetingStore(self.root)
        folder = store.new_session()
        # pattern: YYYY-MM-DD-HH-MM
        parts = folder.name.split('-')
        assert len(parts) == 5
        assert len(parts[0]) == 4 and len(parts[1]) == 2

    def test_list_returns_sessions(self):
        store = self.mod.MeetingStore(self.root)
        store.new_session()
        store.new_session()
        sessions = store.list_sessions()
        assert len(sessions) == 2

    def test_undigested_meetings(self):
        store = self.mod.MeetingStore(self.root)
        m1 = store.new_session()
        m2 = store.new_session()
        # marcar m1 como digerido
        meta = json.loads((m1 / 'meta.json').read_text())
        meta['digested'] = True
        (m1 / 'meta.json').write_text(json.dumps(meta))
        undigested = store.list_undigested()
        assert len(undigested) == 1
        assert undigested[0] == m2

    def test_mark_digested(self):
        store = self.mod.MeetingStore(self.root)
        m = store.new_session()
        store.mark_digested(m)
        meta = json.loads((m / 'meta.json').read_text())
        assert meta['digested'] is True

    def test_sessions_dir_created_lazily(self):
        store = self.mod.MeetingStore(self.root)
        assert self.root.exists() is False  # no creado hasta new_session
        store.new_session()
        assert self.root.exists() is True
