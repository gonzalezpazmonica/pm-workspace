/* Re-run transcription on an existing recording with explicit model / device /
   language overrides. Audio is unchanged on disk; the new transcript replaces
   the existing one and segment list. Cancellation flows through the normal
   transcribe-cancel path on MeetingDetailPage. */

import { useEffect, useMemo, useState } from "react";
import { toast } from "sonner";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { api } from "@/lib/api";
import type { CachedModel, Recording, Options } from "@/lib/types";

interface RetranscribeDialogProps {
  open: boolean;
  onOpenChange(open: boolean): void;
  recording: Recording;
  onStarted(): void;
}

export function RetranscribeDialog({
  open,
  onOpenChange,
  recording,
  onStarted,
}: RetranscribeDialogProps) {
  const [cachedModels, setCachedModels] = useState<CachedModel[] | null>(null);
  const [options, setOptions] = useState<Options | null>(null);
  const [model, setModel] = useState<string>("");
  const [device, setDevice] = useState<string>("auto");
  const [language, setLanguage] = useState<string>("auto");
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(false);

  // Fetch the model list, global settings, and language options on open. We
  // re-fetch each open so newly-downloaded models appear without remounting.
  useEffect(() => {
    if (!open) return;
    let cancelled = false;
    setLoading(true);
    Promise.all([
      api.recordingsListCachedModels(),
      api.getSettings(),
      api.getOptions(),
    ])
      .then(([models, settings, opts]) => {
        if (cancelled) return;
        setCachedModels(models);
        setOptions(opts);
        // Pre-select: prior transcript model → global default → first cached.
        const initialModel =
          recording.transcriptModel ||
          settings.model ||
          models.find((m) => m.cached)?.name ||
          "tiny";
        setModel(initialModel);
        setDevice(settings.device || "auto");
        setLanguage(recording.language || settings.language || "auto");
      })
      .catch((err) => {
        console.error("retranscribe dialog fetch failed", err);
        toast.error("Could not load model list");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [open, recording.transcriptModel, recording.language]);

  const sortedModels = useMemo(() => {
    if (!cachedModels) return [];
    // Cached first, then uncached (still shown but disabled with hint).
    return [...cachedModels].sort((a, b) => {
      if (a.cached !== b.cached) return a.cached ? -1 : 1;
      return a.name.localeCompare(b.name);
    });
  }, [cachedModels]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!model) return;
    setBusy(true);
    try {
      await api.recordingsRetranscribe(recording.id, {
        model,
        device,
        language,
      });
      toast.success("Re-transcribing — this may take a few minutes");
      onStarted();
      onOpenChange(false);
    } catch (err) {
      console.error("retranscribe failed", err);
      toast.error("Could not start re-transcription");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader className="space-y-2">
          <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
            re-transcribe
          </p>
          <DialogTitle className="font-display text-xl font-medium tracking-tight text-cream">
            Re-run transcription
          </DialogTitle>
          <DialogDescription className="text-sm text-cream-muted leading-relaxed">
            Pick a model, device, and language to re-transcribe this recording.
            The existing transcript and segments will be replaced. Audio on disk
            is not touched.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4 pt-2">
          <div className="space-y-1.5">
            <Label htmlFor="rt-model" className="text-sm font-medium text-cream">
              Model
            </Label>
            <Select value={model} onValueChange={setModel} disabled={loading}>
              <SelectTrigger id="rt-model" className="w-full font-mono text-sm">
                <SelectValue placeholder="Pick a model…" />
              </SelectTrigger>
              <SelectContent>
                {sortedModels.map((m) => (
                  <SelectItem
                    key={m.name}
                    value={m.name}
                    disabled={!m.cached}
                    className="font-mono"
                  >
                    {m.name}
                    {!m.cached && (
                      <span className="text-cream-muted/50 ml-2 text-[11px]">
                        (download via Settings)
                      </span>
                    )}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {recording.transcriptModel && (
              <p className="font-mono text-[11px] text-cream-muted/60">
                currently: {recording.transcriptModel}
              </p>
            )}
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="rt-device" className="text-sm font-medium text-cream">
              Compute device
            </Label>
            <Select
              value={device}
              onValueChange={setDevice}
              disabled={loading || !options}
            >
              <SelectTrigger id="rt-device" className="w-full font-mono text-sm">
                <SelectValue placeholder="Pick a device…" />
              </SelectTrigger>
              <SelectContent>
                {(options?.deviceOptions || ["auto", "cpu", "cuda"]).map(
                  (opt) => (
                    <SelectItem
                      key={opt}
                      value={opt}
                      className="font-mono"
                    >
                      {opt}
                    </SelectItem>
                  ),
                )}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-1.5">
            <Label
              htmlFor="rt-language"
              className="text-sm font-medium text-cream"
            >
              Language
            </Label>
            <Select
              value={language}
              onValueChange={setLanguage}
              disabled={loading || !options}
            >
              <SelectTrigger
                id="rt-language"
                className="w-full font-mono text-sm"
              >
                <SelectValue placeholder="Pick a language…" />
              </SelectTrigger>
              <SelectContent className="max-h-72">
                {(options?.languages || ["auto"]).map((lang) => (
                  <SelectItem key={lang} value={lang} className="font-mono">
                    {lang === "auto" ? "auto-detect" : lang.toUpperCase()}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-cream-muted/50 pt-1">
            replaces existing transcript · audio unchanged
          </p>

          <DialogFooter className="pt-2">
            <Button
              type="button"
              variant="ghost"
              onClick={() => onOpenChange(false)}
              disabled={busy}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={busy || loading || !model}>
              {busy ? "Starting…" : "Re-transcribe"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

