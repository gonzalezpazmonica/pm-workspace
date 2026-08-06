/* Recordings-feature behavior settings. Designed to render inside a
   <Section> from SettingsTab, so it mirrors the local `ToggleRow` pattern
   used by every other preference toggle in the panel. */

import { useEffect, useState } from "react";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { api } from "@/lib/api";
import type { Settings } from "@/lib/types";

export function MeetingsSettingsSection() {
  const [settings, setSettings] = useState<Settings | null>(null);

  useEffect(() => {
    api.getSettings().then(setSettings).catch(() => {});
  }, []);

  if (!settings) return null;

  const toggle = async (key: keyof Settings, value: boolean) => {
    setSettings({ ...settings, [key]: value });
    try {
      await api.updateSettings({ [key]: value });
    } catch (err) {
      console.error(err);
    }
  };

  const autoTranscribe =
    (settings as unknown as { recordingsAutoTranscribe?: boolean })
      .recordingsAutoTranscribe ?? true;
  const autoSummarize =
    (settings as unknown as { recordingsAutoSummarize?: boolean })
      .recordingsAutoSummarize ?? false;
  const autoRenameTitle = settings.recordingsAutoRenameTitle ?? true;

  return (
    <>
      <ToggleRow
        id="meetings-auto-transcribe"
        label="Auto-transcribe on stop"
        helper="Run transcription immediately when a recording finishes. Always local — audio never leaves your machine."
        checked={autoTranscribe}
        onChange={(v) =>
          toggle("recordingsAutoTranscribe" as unknown as keyof Settings, v)
        }
      />
      <ToggleRow
        id="meetings-auto-summarize"
        label="Auto-summarize after transcribing"
        helper="Generate an AI summary automatically. Off by default — once enabled, every recording consumes LLM tokens or CPU."
        checked={autoSummarize}
        onChange={(v) =>
          toggle("recordingsAutoSummarize" as unknown as keyof Settings, v)
        }
      />
      <ToggleRow
        id="meetings-auto-rename-title"
        label="Auto-rename from transcript"
        helper="After transcription, replace timestamp titles with a short LLM-generated topic title. Custom titles you typed in are left alone."
        checked={autoRenameTitle}
        onChange={(v) => toggle("recordingsAutoRenameTitle", v)}
      />
    </>
  );
}

/* Local twin of SettingsTab's `ToggleRow`. Kept inline because the helpers
   there aren't exported; same classes, same spacing rhythm. */
function ToggleRow({
  id,
  label,
  helper,
  checked,
  onChange,
}: {
  id: string;
  label: string;
  helper: string;
  checked: boolean;
  onChange(v: boolean): void;
}) {
  return (
    <div className="py-4 border-t border-border first:border-t-0 flex items-start justify-between gap-6">
      <div className="flex-1 min-w-0">
        <Label
          htmlFor={id}
          className="text-sm font-medium text-cream cursor-pointer"
        >
          {label}
        </Label>
        <p className="text-xs text-cream-muted mt-1 leading-relaxed max-w-2xl">
          {helper}
        </p>
      </div>
      <Switch
        id={id}
        checked={checked}
        onCheckedChange={onChange}
        className="mt-0.5 flex-shrink-0"
      />
    </div>
  );
}
