# Stereo channel layout for two-source Recordings

When a Recording captures both a mic and a system-loopback source, the WAV is
written as stereo 16 kHz PCM16 with the **mic on the left channel (ch 0)** and
the **loopback on the right channel (ch 1)** — deliberately *not* mixed down to
mono. Keeping the sides separate means "who said what" (you vs. them) is
recoverable later by channel, enabling speaker attribution with zero ML
diarization. A single-source Recording is mono.

## Consequences

- Sources are fixed at `start()`; a source cannot be added or removed
  mid-recording, because the channel count of the WAV is decided up front.
- In stereo mode the recorder pads a starved side with silence (starvation
  detection in `recorder.py`) so the channels stay time-aligned — alignment is
  the property that makes per-channel attribution trustworthy.
- Playback of a stereo Recording sounds hard-panned (you fully left, them
  fully right). That is accepted, not a bug.
