# Meeting Mode is self-contained under services/recording/

Meeting Mode (long-form Recording capture/transcribe/summarize) lives entirely
under `src-pyloid/services/recording/` behind the `MeetingsController` facade,
and must not call into the push-to-talk path (hotkey → record → paste) nor be
called from it. The two features share only the leaf services injected at
construction (`DatabaseService`, `SettingsService`, `TranscriptionService`).
This keeps the newer, faster-evolving Meeting Mode extractable (or removable)
without destabilizing the PTT flow that is the product's core promise.

## Consequences

- Shared needs (e.g. transcription) are met by injecting the shared service,
  never by importing PTT modules from `services/recording/` or vice versa.
- Recording persistence lives in `RecordingsRepository`
  (`services/recording/repository.py`), not spread through the shared
  `DatabaseService` surface.
