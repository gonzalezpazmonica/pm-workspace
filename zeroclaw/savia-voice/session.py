"""SessionManager v2.2 — Streaming sentences from Claude Code."""

import json
import subprocess
import time
from pathlib import Path

from text_utils import split_sentences, split_into_voice_chunks, clean_for_voice


class SessionManager:
    """Persistent Claude Code session with streaming sentence output."""

    def __init__(self, model="sonnet", permission_mode="default",
                 append_system_prompt=None, tts=None):
        self.model = model
        self.permission_mode = permission_mode
        self.session_id = None
        self.tts = tts
        self.voice_prompt = self._load_voice_prompt(append_system_prompt)

    def _load_voice_prompt(self, prompt_path):
        if not prompt_path:
            return None
        p = Path(prompt_path)
        if not p.is_absolute():
            p = Path(__file__).parent / p
        return p.read_text().strip() if p.exists() else None

    def _build_cmd(self):
        cmd = [
            "claude", "-p",
            "--output-format", "stream-json",
            "--input-format", "stream-json",
            "--verbose", "--include-partial-messages",
            "--model", self.model,
        ]
        if self.session_id:
            cmd += ["--resume", self.session_id]
        if self.voice_prompt:
            cmd += ["--append-system-prompt", self.voice_prompt]
        return cmd

    def _build_message(self, text):
        return json.dumps({
            "type": "user",
            "message": {"role": "user", "content": text},
            "parent_tool_use_id": None,
            "session_id": self.session_id or ""
        }) + "\n"

    def ask(self, text, timeout=60):
        """Non-streaming — returns full response."""
        return " ".join(self.ask_streaming(text, timeout=timeout))

    def ask_streaming(self, text, timeout=60):
        """Yield sentences as they stream from Claude Code."""
        cmd = self._build_cmd()
        msg = self._build_message(text)
        proc = subprocess.Popen(
            cmd, stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        proc.stdin.write(msg.encode("utf-8"))
        proc.stdin.close()

        token_buf = ""
        full_resp = ""
        first_token = None
        t0 = time.time()
        feedback_given = False
        stall_given = False
        last_text = ""

        try:
            for raw_line in proc.stdout:
                elapsed = time.time() - t0
                if elapsed > timeout:
                    proc.kill()
                    yield "Se me ha agotado el tiempo."
                    return
                cache = getattr(self.tts, '_cache', None)
                if elapsed > 3 and not first_token and cache:
                    if not feedback_given:
                        # First: short filler ("Pues mira...", ~1s)
                        filler = cache.get_filler(text)
                        if filler:
                            name, audio = filler
                            print(f"[filler] \"{name}\"")
                            self.tts._queue.put(audio)
                        feedback_given = True
                    elif elapsed > 8 and not stall_given:
                        # Second: longer stall ("Déjame que lo mire", ~2s)
                        stall = cache.get_stall(text)
                        if stall:
                            name, audio = stall
                            print(f"[stall] \"{name}\"")
                            self.tts._queue.put(audio)
                        stall_given = True

                line = raw_line.decode("utf-8", errors="replace").strip()
                if not line:
                    continue
                try:
                    ev = json.loads(line)
                except json.JSONDecodeError:
                    continue

                etype = ev.get("type", "")
                if etype == "system" and ev.get("subtype") == "init":
                    self.session_id = ev.get("session_id", self.session_id)
                elif etype == "assistant":
                    cur = "".join(
                        b.get("text", "") for b in
                        ev.get("message", {}).get("content", [])
                        if b.get("type") == "text"
                    )
                    if cur and len(cur) > len(last_text):
                        token_buf += cur[len(last_text):]
                        last_text = cur
                        if first_token is None:
                            first_token = time.time()
                        parts = split_sentences(token_buf)
                        if len(parts) > 1:
                            for s in parts[:-1]:
                                c = clean_for_voice(s)
                                if c:
                                    full_resp += c + " "
                                    yield c
                            token_buf = parts[-1]
                elif etype == "result":
                    if token_buf.strip():
                        c = clean_for_voice(token_buf.strip())
                        if c:
                            full_resp += c
                            yield c
                    if not full_resp.strip():
                        rt = ev.get("result", "")
                        if rt:
                            for s in split_into_voice_chunks(
                                clean_for_voice(rt)):
                                yield s
                    break
        except Exception as e:
            print(f"[session] Error: {e}")
            yield "Ha ocurrido un error."
        finally:
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
