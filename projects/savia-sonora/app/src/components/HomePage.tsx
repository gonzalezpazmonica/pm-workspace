import { useEffect, useMemo, useRef, useState } from "react";
import { Copy, Trash2, Search, Mic, FileAudio, X } from "lucide-react";
import { toast } from "sonner";
import { StatsHeader } from "@/components/StatsHeader";
import { AudioPlayerDialog } from "@/components/AudioPlayerDialog";
import { useHistoryEntries } from "@/hooks/useHistoryEntries";
import { api } from "@/lib/api";
import type { HistoryEntry } from "@/lib/types";
import { t } from "@/lib/i18n";
import { cn } from "@/lib/utils";

// Poll the recording state so hotkey-driven starts stay in sync. The
// interval pauses when the window is hidden to avoid useless requests.
function useRecordingState() {
  const [isRecording, setIsRecording] = useState(false);
  const [recordToggling, setRecordToggling] = useState(false);

  useEffect(() => {
    let cancelled = false;
    let inFlight = false;
    const tick = async () => {
      if (inFlight || document.visibilityState !== "visible") return;
      inFlight = true;
      try {
        const state = await api.getRecordingState();
        if (!cancelled) setIsRecording(state.recording);
      } catch {
        // backend may not be ready yet
      } finally {
        inFlight = false;
      }
    };
    tick();
    const id = window.setInterval(tick, 1000);
    return () => {
      cancelled = true;
      window.clearInterval(id);
    };
  }, []);

  const toggleRecording = async () => {
    if (recordToggling) return;
    setRecordToggling(true);
    try {
      const result = await api.manualToggleRecording();
      setIsRecording(result.recording);
      if (result.error === "onboarding_active") {
        toast.error(t("home.recordingOnboarding"));
      }
    } catch (e) {
      console.error("Failed to toggle recording:", e);
      toast.error(t("home.recordFailed"));
    } finally {
      setRecordToggling(false);
    }
  };

  return { isRecording, recordToggling, toggleRecording };
}

export function HomePage() {
  const {
    history,
    loading,
    error,
    loadHistory,
    refreshIfNew,
    handleCopy,
    handleDelete,
    handlePlayAudio,
    showPlayer,
    audioUrl,
    audioMeta,
    loadingAudioFor,
    closePlayer,
  } = useHistoryEntries(50);

  const { isRecording, recordToggling, toggleRecording } = useRecordingState();

  // Refresh history after a recording stops so new entries appear without reload.
  const lastRecording = useRef(isRecording);
  useEffect(() => {
    if (lastRecording.current === isRecording) return;
    lastRecording.current = isRecording;
    if (isRecording) return;
    const refresh = setTimeout(() => {
      void refreshIfNew();
    }, 600);
    return () => clearTimeout(refresh);
  }, [isRecording, refreshIfNew]);

  const [searchQuery, setSearchQuery] = useState("");

  const filteredHistory = useMemo(
    () =>
      history.filter((entry) =>
        entry.text.toLowerCase().includes(searchQuery.toLowerCase()),
      ),
    [history, searchQuery],
  );

  const groupedHistory = useMemo(
    () => groupByDate(filteredHistory),
    [filteredHistory],
  );

  const todayStats = useMemo(() => {
    const today = new Date();
    const todayEntries = history.filter((h) =>
      isSameDay(new Date(h.created_at), today),
    );
    return {
      words: todayEntries.reduce((sum, h) => sum + h.word_count, 0),
      entries: todayEntries.length,
    };
  }, [history]);

  const durationMs = audioMeta?.durationMs;
  const groupedKeys = Object.keys(groupedHistory);
  const hasResults = groupedKeys.length > 0;

  return (
    <>
      <div className="min-h-full w-full bg-background">
        <div className="w-full max-w-5xl mx-auto px-6 md:px-10 py-10 md:py-16 space-y-12">
          <header className="flex flex-col gap-6 md:flex-row md:items-end md:justify-between">
            <div className="space-y-3 min-w-0">
              <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
                {formatDateLine(new Date())}
              </p>
              <h1 className="text-4xl md:text-5xl font-semibold tracking-tight text-cream leading-[1.05]">
                {t("home.dashboard")}
              </h1>
              <p className="text-sm text-cream-muted max-w-xl leading-relaxed">
                {t("home.subtitle")}
              </p>
            </div>
            <RecordButton
              isRecording={isRecording}
              disabled={recordToggling}
              onClick={toggleRecording}
            />
          </header>

          <StatsHeader todayStats={todayStats} />

          <div className="border-t border-border" />

          <SearchBar
            value={searchQuery}
            onChange={setSearchQuery}
            count={filteredHistory.length}
          />

          {loading ? (
            <div aria-live="polite">
              <LogSkeleton />
            </div>
          ) : error ? (
            <LogError
              error={error}
              onRetry={() => void loadHistory(undefined, true)}
            />
          ) : !hasResults ? (
            <LogEmpty searchQuery={searchQuery} />
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
          if (!open) closePlayer();
        }}
      />
    </>
  );
}

function RecordButton({
  isRecording,
  disabled,
  onClick,
}: {
  isRecording: boolean;
  disabled: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-pressed={isRecording}
      aria-label={isRecording ? t("home.stop") : t("home.record")}
      className={cn(
        "h-11 px-6 rounded-lg font-medium text-sm transition-colors flex items-center gap-2.5 flex-shrink-0 self-start md:self-auto disabled:opacity-60 disabled:cursor-not-allowed shadow-sm",
        isRecording
          ? "bg-destructive text-destructive-foreground hover:bg-destructive/90"
          : "bg-primary text-primary-foreground hover:bg-primary-700",
      )}
    >
      {isRecording ? (
        <>
          <span className="relative inline-flex w-2.5 h-2.5">
            <span className="absolute inset-0 rounded-full bg-current animate-ping opacity-50" />
            <span className="relative w-2.5 h-2.5 rounded-full bg-current" />
          </span>
          {t("home.stop")}
        </>
      ) : (
        <>
          <Mic className="w-4 h-4" strokeWidth={2.5} />
          {t("home.record")}
        </>
      )}
    </button>
  );
}

function SearchBar({
  value,
  onChange,
  count,
}: {
  value: string;
  onChange: (v: string) => void;
  count: number;
}) {
  const hasQuery = value.length > 0;
  return (
    <div className="flex items-center gap-3 flex-wrap">
      <div className="relative flex-1 max-w-sm min-w-[200px]">
        <Search
          className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-cream-muted/60 pointer-events-none"
          strokeWidth={2}
        />
        <input
          type="text"
          placeholder={t("home.search")}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          aria-label={t("home.search")}
          className="w-full h-9 pl-9 pr-9 bg-secondary/30 border border-border rounded-lg text-sm text-cream placeholder:text-cream-muted/50 focus:bg-secondary/50 focus:border-primary/40 focus:outline-none transition-colors"
        />
        {hasQuery && (
          <button
            type="button"
            onClick={() => onChange("")}
            className="absolute right-2 top-1/2 -translate-y-1/2 text-cream-muted/60 hover:text-cream p-1 rounded transition-colors"
            aria-label="Limpiar búsqueda"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        )}
      </div>
      {hasQuery && (
        <span className="font-mono text-[11px] uppercase tracking-widest text-cream-muted/60">
          {count} {count === 1 ? t("home.match") : t("home.matches")}
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
      <div className="flex items-center gap-3 mb-2">
        <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60 whitespace-nowrap">
          {label}
          <span className="text-cream-muted/30 mx-2">·</span>
          <span className="text-cream-muted/40">
            {entries.length} {entries.length === 1 ? t("home.entry") : t("home.entries")}
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
    <article className="group relative flex items-start gap-5 py-4 border-t border-border first:border-t-0 transition-colors hover:bg-secondary/[0.25] -mx-2 px-2 rounded-lg">
      <div className="flex flex-col items-end gap-1.5 w-14 flex-shrink-0 pt-0.5">
        <span className="font-mono text-[11px] text-cream-muted/70 leading-none">
          {formatTime(entry.created_at)}
        </span>
        {hasAudio && (
          <span
            className="font-mono text-[9px] uppercase tracking-[0.15em] text-primary/80 flex items-center gap-1 leading-none"
            title={t("home.audio")}
          >
            <FileAudio className="w-2.5 h-2.5" strokeWidth={2.5} />
            {t("home.audio")}
          </span>
        )}
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm leading-relaxed text-cream/90 line-clamp-3 group-hover:text-cream transition-colors break-words">
          {entry.text}
        </p>
        <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-cream-muted/50 mt-2">
          {entry.word_count} {entry.word_count === 1 ? t("home.word") : t("home.words")}
        </p>
      </div>
      <div className="flex items-center gap-1 flex-shrink-0 opacity-0 group-hover:opacity-100 group-focus-within:opacity-100 transition-opacity">
        <RowAction
          icon={Copy}
          label={t("home.copied").slice(0, 0) || "Copiar"}
          title="Copiar"
          onClick={() => onCopy(entry.text)}
        />
        {hasAudio && (
          <RowAction
            icon={FileAudio}
            label={isLoadingAudio ? t("home.loading") : t("home.playAudio")}
            title={t("home.playAudio")}
            onClick={() => onPlayAudio(entry.id)}
            disabled={isLoadingAudio}
          />
        )}
        <RowAction
          icon={Trash2}
          label="Eliminar"
          title="Eliminar"
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
  title,
  onClick,
  disabled,
  tone = "default",
}: {
  icon: React.ElementType;
  label: string;
  title: string;
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
      title={title}
      className={cn(
        "h-8 w-8 rounded-lg flex items-center justify-center transition-colors",
        "text-cream-muted/70 hover:bg-secondary/60",
        tone === "danger"
          ? "hover:text-destructive hover:bg-destructive/10"
          : "hover:text-cream",
        "disabled:opacity-40 disabled:cursor-not-allowed",
      )}
    >
      <Icon className="w-3.5 h-3.5" strokeWidth={2} />
    </button>
  );
}

function LogEmpty({ searchQuery }: { searchQuery: string }) {
  return (
    <div className="border border-dashed border-border rounded-lg py-16 px-6 text-center space-y-3">
      <p className="font-mono text-[11px] uppercase tracking-[0.25em] text-cream-muted/60">
        {searchQuery ? t("home.noMatches") : t("home.logEmptyLabel")}
      </p>
      <p className="text-sm text-cream-muted">
        {searchQuery
          ? `Nada coincide con "${searchQuery}".`
          : t("home.logEmpty")}
      </p>
      {!searchQuery && (
        <p className="font-mono text-xs text-cream-muted/60 pt-2">
          <span className="text-cream-muted/40">→ </span>
          {t("home.logEmptyHint")}
        </p>
      )}
    </div>
  );
}

function LogError({
  error,
  onRetry,
}: {
  error: string;
  onRetry: () => void;
}) {
  return (
    <div
      role="alert"
      className="border border-destructive/30 bg-destructive/[0.03] rounded-lg p-6 space-y-4"
    >
      <div className="space-y-1">
        <p className="font-mono text-[11px] uppercase tracking-[0.25em] text-destructive">
          error
        </p>
        <p className="text-sm text-cream">{error}</p>
      </div>
      <button
        type="button"
        onClick={onRetry}
        className="h-9 px-4 rounded-lg border border-border bg-secondary/40 hover:bg-secondary/60 hover:text-cream transition-colors font-mono text-[11px] uppercase tracking-widest text-cream-muted"
      >
        {t("home.retry")}
      </button>
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
        {[0, 1, 2, 3, 4].map((i) => (
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

function formatDateLine(date: Date): string {
  const weekday = date.toLocaleDateString([], { weekday: "long" });
  const month = date.toLocaleDateString([], { month: "long" });
  const day = date.getDate();
  const year = date.getFullYear();
  return `${weekday} · ${month} ${day} · ${year}`;
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
      label = t("home.today");
    } else if (isSameDay(entryDate, yesterday)) {
      label = t("home.yesterday");
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
