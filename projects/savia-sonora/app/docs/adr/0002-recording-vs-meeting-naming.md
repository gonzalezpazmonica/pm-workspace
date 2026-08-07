# "Recording" in code, "Meeting" in the UI

The meeting-notes entity is named **Recording** everywhere machine-facing —
DB table (`recordings`), RPC methods (`recordings_*`), services, the audio
folder, log domains — while the UI labels the same thing "Meeting" (nav item,
page titles, copy), because the dominant use case is multi-party meeting
capture. The split is deliberate: "recording" describes what the thing *is*
(any captured audio, including imports and solo dictation experiments), while
"meeting" describes the dominant *use*; marketing copy can change without a
schema migration. Do not "fix" one side to match the other. See CONTEXT.md
for the full glossary entry.
