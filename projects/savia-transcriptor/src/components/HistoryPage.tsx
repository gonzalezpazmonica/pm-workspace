import { useEffect, useMemo, useState } from "react";
import { Search, Copy, Trash2, FileAudio, X } from "lucide-react";
import { toast } from "sonner";
import {
  base64ToBlobUrl,
  revokeUrl,
  isInvalidAudioPayload,
} from "@/lib/audio";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { api } from "@/lib/api";
import type { HistoryEntry } from "@/lib/types";
import { cn } from "@/lib/utils";

export function HistoryPage() {
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [searching, setSearching] = useState(false);
  const [showPlayer, setShowPlayer] = useState(false);
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [audioMeta, setAudioMeta] = useState<{
    fileName?: string;
    mime?: string;
    durationMs?: number;
  } | null>(null);
  const [loadingAudioFor, setLoadingAudioFor] = useState<number | null>(null);

  const loadHistory = async (searchQuery?: string, isInitial = false) => {
    if (isInitial) setLoading(true);
    else setSearching(true);
    try {
      const data = await api.getHistory(
        100,
        0,
        searchQuery || undefined,
        false
      );
      setHistory(data);
    } catch (error) {
      console.error("Failed to load history:", error);
      toast.error("Failed to load history");
    } finally {
      setLoading(false);
      setSearching(false);
    }
  };

  useEffect(() => {
    loadHistory(undefined, true);
  }, []);

  useEffect(() => {
    const debounce = setTimeout(() => {
      loadHistory(search);
    }, 500);
    return () => clearTimeout(debounce);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search]);

  useEffect(() => () => revokeUrl(audioUrl), [audioUrl]);

  const handleCopy = async (text: string) => {
    try {
      await api.copyToClipboard(text);
      toast.success("Copied to clipboard");
    } catch {
      try {
        await navigator.clipboard.writeText(text);
        toast.success("Copied to clipboard");
      } catch {
        toast.error("Failed to copy to clipboard");
      }
    }
  };

  const handleDelete = async (id: number) => {
    try {
      await api.deleteHistory(id);
      setHistory((prev) => prev.filter((h) => h.id !== id));
      toast.success("Transcription deleted");
    } catch (err) {
      console.error("Failed to delete:", err);
      toast.error("Failed to delete transcription");
    }
  };

  const handlePlayAudio = async (historyId: number) => {
    setLoadingAudioFor(historyId);
    try {
      const response = await api.getHistoryAudio(historyId);
      revokeUrl(audioUrl);
      const url = base64ToBlobUrl(response.base64, response.mime);
      setAudioUrl(url);
      setAudioMeta({
        fileName: response.fileName,
        mime: response.mime,
        durationMs: response.durationMs,
      });
      setShowPlayer(true);
    } catch (err) {
      console.error("Failed to load audio recording:", err);
      toast.error(
        isInvalidAudioPayload(err)
          ? "Audio file is corrupted"
          : "Audio file not found"
      );
      revokeUrl(audioUrl);
      setAudioUrl(null);
      setShowPlayer(false);
      setAudioMeta(null);
    } finally {
      setLoadingAudioFor(null);
    }
  };

  const groupedHistory = useMemo(() => groupByDate(history), [history]);
  const groupedKeys = Object.keys(groupedHistory);
  const hasResults = groupedKeys.length > 0;
  const totalEntries = history.length;
  const durationMs = audioMeta?.durationMs;

  return (
    <>
      <div className="min-h-full w-full bg-background">
        <div className="w-full max-w-5xl mx-auto px-6 md:px-10 py-10 md:py-16 space-y-10">
          <header className="space-y-3 min-w-0">
            <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
              archive
              <span className="text-cream-muted/30 mx-2">·</span>
              <span className="text-cream-muted/40">
                {totalEntries.toLocaleString()}{" "}
                {totalEntries === 1 ? "entry" : "entries"}
              </span>
            </p>
            <h1 className="font-display text-4xl md:text-5xl font-medium tracking-tight text-cream leading-[1.05]">
              History
            </h1>
            <p className="text-sm text-cream-muted max-w-xl leading-relaxed">
              A complete log of everything you've dictated. Search runs against
              the database — results update as you type.
            </p>
          </header>

          <SearchBar
            value={search}
            onChange={setSearch}
            searching={searching}
          />

          {loading ? (
            <LogSkeleton />
          ) : !hasResults ? (
            <LogEmpty searchQuery={search} />
          ) : (
            <div className="space-y-10">
              {Object.entries(groupedHistory).map(([dateLabel, entries]) => (
                <LogSection
                  key={dateLabel}
                  label={dateLabel}
                  entries={entries}
                  onCopy={handleCopy}
                  onDelete={handleDelete}
                  onPlayAudio={handlePlayAudio}
                  loadingAudioFor={loadingAudioFor}
                />
              ))}
            </div>
          )}
        </div>
      </div>

      <AudioPlayerDialog
        open={showPlayer}
        audioUrl={audioUrl}
        audioMeta={audioMeta}
        durationMs={durationMs}
        onOpenChange={(open) => {
          setShowPlayer(open);
          if (!open) {
            revokeUrl(audioUrl);
            setAudioUrl(null);
            setAudioMeta(null);
          }
        }}
      />
    </>
  );
}

function SearchBar({
  value,
  onChange,
  searching,
}: {
  value: string;
  onChange: (v: string) => void;
  searching: boolean;
}) {
  const hasQuery = value.length > 0;
  return (
    <div className="flex items-center gap-3 flex-wrap">
      <div className="relative flex-1 max-w-md min-w-[240px]">
        <Search
          className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-cream-muted/60 pointer-events-none"
          strokeWidth={2}
        />
        <input
          type="search"
          placeholder="Search the archive"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className="w-full h-10 pl-9 pr-9 bg-secondary/30 border border-border rounded-md text-sm text-cream placeholder:text-cream-muted/50 focus:bg-secondary/50 focus:border-accent-500/40 focus:outline-none transition-colors"
        />
        {hasQuery && (
          <button
            type="button"
            onClick={() => onChange("")}
            className="absolute right-2 top-1/2 -translate-y-1/2 text-cream-muted/60 hover:text-cream p-1 rounded transition-colors"
            aria-label="Clear search"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        )}
      </div>
      {searching && (
        <span className="font-mono text-[11px] uppercase tracking-widest text-cream-muted/60">
          searching…
        </span>
      )}
    </div>
  );
}

function LogSection({
  label,
  entries,
  onCopy,
  onDelete,
  onPlayAudio,
  loadingAudioFor,
}: {
  label: string;
  entries: HistoryEntry[];
  onCopy: (text: string) => void;
  onDelete: (id: number) => void;
  onPlayAudio: (id: number) => void;
  loadingAudioFor: number | null;
}) {
  return (
    <section>
      <div className="flex items-center gap-3 mb-2 sticky top-0 z-10 bg-background/95 backdrop-blur-sm py-2 -mx-2 px-2">
        <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60 whitespace-nowrap">
          {label}
          <span className="text-cream-muted/30 mx-2">·</span>
          <span className="text-cream-muted/40">
            {entries.length} {entries.length === 1 ? "entry" : "entries"}
          </span>
        </p>
        <div className="flex-1 h-px bg-border" />
      </div>
      <div>
        {entries.map((entry) => (
          <LogRow
            key={entry.id}
            entry={entry}
            onCopy={onCopy}
            onDelete={onDelete}
            onPlayAudio={onPlayAudio}
            isLoadingAudio={loadingAudioFor === entry.id}
          />
        ))}
      </div>
    </section>
  );
}

function LogRow({
  entry,
  onCopy,
  onDelete,
  onPlayAudio,
  isLoadingAudio,
}: {
  entry: HistoryEntry;
  onCopy: (text: string) => void;
  onDelete: (id: number) => void;
  onPlayAudio: (id: number) => void;
  isLoadingAudio: boolean;
}) {
  const hasAudio = !!entry.has_audio;
  return (
    <article className="group relative flex items-start gap-5 py-4 border-t border-border first:border-t-0 transition-colors hover:bg-secondary/[0.25] -mx-2 px-2 rounded-sm">
      <div className="flex flex-col items-end gap-1.5 w-14 flex-shrink-0 pt-0.5">
        <span className="font-mono text-[11px] text-cream-muted/70 leading-none">
          {formatTime(entry.created_at)}
        </span>
        {hasAudio && (
          <span
            className="font-mono text-[9px] uppercase tracking-[0.15em] text-accent-500/80 flex items-center gap-1 leading-none"
            title="Audio recording attached"
          >
            <FileAudio className="w-2.5 h-2.5" strokeWidth={2.5} />
            audio
          </span>
        )}
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm leading-relaxed text-cream/90 line-clamp-4 group-hover:text-cream transition-colors break-words">
          {entry.text}
        </p>
        <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-cream-muted/50 mt-2">
          {entry.word_count} {entry.word_count === 1 ? "word" : "words"}
        </p>
      </div>
      <div className="flex items-center gap-1 flex-shrink-0 opacity-0 group-hover:opacity-100 group-focus-within:opacity-100 transition-opacity">
        <RowAction
          icon={Copy}
          label="Copy"
          onClick={() => onCopy(entry.text)}
        />
        {hasAudio && (
          <RowAction
            icon={FileAudio}
            label={isLoadingAudio ? "Loading…" : "Play audio"}
            onClick={() => onPlayAudio(entry.id)}
            disabled={isLoadingAudio}
          />
        )}
        <RowAction
          icon={Trash2}
          label="Delete"
          tone="danger"
          onClick={() => onDelete(entry.id)}
        />
      </div>
    </article>
  );
}

function RowAction({
  icon: Icon,
  label,
  onClick,
  disabled,
  tone = "default",
}: {
  icon: React.ElementType;
  label: string;
  onClick: () => void;
  disabled?: boolean;
  tone?: "default" | "danger";
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-label={label}
      title={label}
      className={cn(
        "h-8 w-8 rounded-md flex items-center justify-center transition-colors",
        "text-cream-muted/70 hover:bg-secondary/60",
        tone === "danger"
          ? "hover:text-destructive hover:bg-destructive/10"
          : "hover:text-cream",
        "disabled:opacity-40 disabled:cursor-not-allowed"
      )}
    >
      <Icon className="w-3.5 h-3.5" strokeWidth={2} />
    </button>
  );
}

function LogEmpty({ searchQuery }: { searchQuery: string }) {
  return (
    <div className="border border-dashed border-border rounded-md py-20 px-6 text-center space-y-3">
      <p className="font-mono text-[11px] uppercase tracking-[0.25em] text-cream-muted/60">
        {searchQuery ? "no matches" : "archive empty"}
      </p>
      <p className="text-sm text-cream-muted">
        {searchQuery
          ? `Nothing in the archive matches "${searchQuery}".`
          : "Everything you transcribe will be saved here."}
      </p>
      {searchQuery && (
        <p className="font-mono text-xs text-cream-muted/60 pt-2">
          <span className="text-cream-muted/40">→ </span>
          try simpler keywords or clear the search
        </p>
      )}
    </div>
  );
}

function LogSkeleton() {
  return (
    <div>
      <div className="flex items-center gap-3 mb-2">
        <div className="h-2 w-32 bg-secondary/50 rounded animate-pulse" />
        <div className="flex-1 h-px bg-border" />
      </div>
      <div>
        {[0, 1, 2, 3, 4, 5, 6].map((i) => (
          <div
            key={i}
            className="flex items-start gap-5 py-4 border-t border-border first:border-t-0"
          >
            <div className="w-14 flex-shrink-0 flex justify-end">
              <div className="h-2.5 w-9 bg-secondary/50 rounded animate-pulse" />
            </div>
            <div className="flex-1 space-y-2">
              <div className="h-3 bg-secondary/40 rounded animate-pulse" />
              <div
                className="h-3 bg-secondary/40 rounded animate-pulse"
                style={{ width: `${50 + ((i * 13) % 40)}%` }}
              />
              <div className="h-2 w-16 bg-secondary/30 rounded animate-pulse mt-1" />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function AudioPlayerDialog({
  open,
  audioUrl,
  audioMeta,
  durationMs,
  onOpenChange,
}: {
  open: boolean;
  audioUrl: string | null;
  audioMeta: { fileName?: string; mime?: string; durationMs?: number } | null;
  durationMs?: number;
  onOpenChange: (open: boolean) => void;
}) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader className="space-y-2">
          <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
            audio playback
          </p>
          <DialogTitle className="font-display text-xl font-medium tracking-tight text-cream truncate">
            {audioMeta?.fileName || "Recording"}
          </DialogTitle>
          <DialogDescription className="font-mono text-xs text-cream-muted">
            {durationMs
              ? `${Math.round(durationMs / 1000)}s · ${audioMeta?.mime || "audio/wav"}`
              : "Playback of the recorded audio"}
          </DialogDescription>
        </DialogHeader>
        {audioUrl ? (
          // biome-ignore lint/a11y/useMediaCaption: transcript text is shown in the log
          <audio controls autoPlay className="w-full">
            <source src={audioUrl} type={audioMeta?.mime || "audio/wav"} />
            Your browser does not support audio playback.
          </audio>
        ) : (
          <p className="text-sm text-cream-muted">No audio loaded.</p>
        )}
      </DialogContent>
    </Dialog>
  );
}

function formatTime(isoString: string): string {
  const date = new Date(isoString);
  return date.toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

function groupByDate(entries: HistoryEntry[]): Record<string, HistoryEntry[]> {
  const groups: Record<string, HistoryEntry[]> = {};
  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);

  for (const entry of entries) {
    const entryDate = new Date(entry.created_at);
    let label: string;

    if (isSameDay(entryDate, today)) {
      label = "today";
    } else if (isSameDay(entryDate, yesterday)) {
      label = "yesterday";
    } else {
      label = entryDate.toLocaleDateString([], {
        weekday: "long",
        month: "long",
        day: "numeric",
      });
    }

    if (!groups[label]) groups[label] = [];
    groups[label].push(entry);
  }

  return groups;
}

function isSameDay(d1: Date, d2: Date): boolean {
  return (
    d1.getFullYear() === d2.getFullYear() &&
    d1.getMonth() === d2.getMonth() &&
    d1.getDate() === d2.getDate()
  );
}
