import { useEffect, useState } from "react";
import { Search, Copy, Trash2, FileAudio, X } from "lucide-react";
import { AudioPlayerDialog } from "@/components/AudioPlayerDialog";
import { useHistoryEntries } from "@/hooks/useHistoryEntries";
import type { HistoryEntry } from "@/lib/types";
import { t } from "@/lib/i18n";
import { cn } from "@/lib/utils";

export function HistoryPage() {
  const [search, setSearch] = useState("");
  const {
    history,
    loading,
    searching,
    error,
    loadHistory,
    handleCopy,
    handleDelete,
    handlePlayAudio,
    showPlayer,
    audioUrl,
    audioMeta,
    loadingAudioFor,
    closePlayer,
  } = useHistoryEntries(100, { search });

  useEffect(() => {
    const debounce = setTimeout(() => {
      void loadHistory(search);
    }, 500);
    return () => clearTimeout(debounce);
  }, [search, loadHistory]);

  const durationMs = audioMeta?.durationMs;

  return (
    <div className="min-h-full w-full bg-background">
      <div className="w-full max-w-5xl mx-auto px-6 md:px-10 py-10 md:py-16 space-y-10">
        <header className="space-y-3 min-w-0">
          <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
            {t("nav.history")}
          </p>
          <h1 className="text-4xl md:text-5xl font-semibold tracking-tight text-cream leading-[1.05]">
            {t("history.title")}
          </h1>
          <p className="text-sm text-cream-muted max-w-xl leading-relaxed">
            {t("history.subtitle")}
          </p>
        </header>

        <SearchBar value={search} onChange={setSearch} searching={searching} />

        {loading ? (
          <div aria-live="polite">
            <LogSkeleton />
          </div>
        ) : error ? (
          <LogError
            error={error}
            onRetry={() => void loadHistory(search, true)}
          />
        ) : history.length === 0 ? (
          <LogEmpty searchQuery={search} />
        ) : (
          <LogList
            entries={history}
            onCopy={handleCopy}
            onDelete={handleDelete}
            onPlayAudio={handlePlayAudio}
            loadingAudioFor={loadingAudioFor}
          />
        )}
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
    </div>
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
        {searching && (
          <span className="absolute right-2 top-1/2 -translate-y-1/2">
            <span className="block h-4 w-4 animate-spin rounded-full border-2 border-primary/30 border-t-primary" />
          </span>
        )}
      </div>
    </div>
  );
}

function LogList({
  entries,
  onCopy,
  onDelete,
  onPlayAudio,
  loadingAudioFor,
}: {
  entries: HistoryEntry[];
  onCopy: (text: string) => void;
  onDelete: (id: number) => void;
  onPlayAudio: (id: number) => void;
  loadingAudioFor: number | null;
}) {
  return (
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
      <div className="flex-1 min-w-0">
        <p className="text-sm leading-relaxed text-cream/90 line-clamp-3 group-hover:text-cream transition-colors break-words">
          {entry.text}
        </p>
        <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-cream-muted/50 mt-2">
          {formatDate(entry.created_at)} · {entry.word_count}{" "}
          {entry.word_count === 1 ? t("home.word") : t("home.words")}
        </p>
      </div>
      <div className="flex items-center gap-1 flex-shrink-0 opacity-0 group-hover:opacity-100 group-focus-within:opacity-100 transition-opacity">
        <RowAction
          icon={Copy}
          label="Copiar"
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
        {searchQuery ? `Nada coincide con "${searchQuery}".` : t("home.logEmpty")}
      </p>
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
      {[0, 1, 2, 3, 4].map((i) => (
        <div
          key={i}
          className="flex items-start gap-5 py-4 border-t border-border first:border-t-0"
        >
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
  );
}

function formatDate(isoString: string): string {
  const date = new Date(isoString);
  return date.toLocaleDateString([], {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}
