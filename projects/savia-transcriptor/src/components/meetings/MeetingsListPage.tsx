/* The Meetings library. Mirrors HistoryPage's shell, header, search, and
   sticky date-group rhythm so the two list views feel like one app. */

import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Plus, Search, Upload, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { api } from "@/lib/api";
import type { Recording } from "@/lib/types";
import { cn } from "@/lib/utils";
import { useMeetingRecorder } from "./MeetingRecorderContext";
import { StatusLine } from "./StatusLine";
import { MeetingImportDialog } from "./MeetingImportDialog";
import { formatDuration, groupByDate } from "./utils";

export function MeetingsListPage() {
  const navigate = useNavigate();
  const recorder = useMeetingRecorder();

  const [recordings, setRecordings] = useState<Recording[]>([]);
  const [loading, setLoading] = useState(true);
  const [searching, setSearching] = useState(false);
  const [search, setSearch] = useState("");
  const [importOpen, setImportOpen] = useState(false);

  const load = async (q?: string, initial = false) => {
    if (initial) setLoading(true);
    else setSearching(true);
    try {
      const rows = await api.recordingsList(200, 0, q || undefined);
      setRecordings(rows);
    } catch (err) {
      // Tolerate the backend RPC not being wired yet — render empty.
      if (initial) {
        console.warn("recordings_list not available yet", err);
        setRecordings([]);
      }
    } finally {
      setLoading(false);
      setSearching(false);
    }
  };

  useEffect(() => {
    load(undefined, true);
  }, []);

  useEffect(() => {
    const t = window.setTimeout(() => {
      load(search);
    }, 400);
    return () => window.clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search]);

  const groups = useMemo(() => groupByDate(recordings), [recordings]);
  const totalEntries = recordings.length;
  const hasResults = groups.length > 0;

  return (
    <div className="min-h-full w-full bg-background">
      <div className="w-full max-w-5xl mx-auto px-6 md:px-10 py-10 md:py-16 space-y-10">
        <header className="space-y-3 min-w-0">
          <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
            library
            <span className="text-cream-muted/30 mx-2">·</span>
            <span className="text-cream-muted/40">
              {totalEntries.toLocaleString()}{" "}
              {totalEntries === 1 ? "entry" : "entries"}
            </span>
          </p>
          <div className="flex items-end justify-between gap-6 flex-wrap">
            <div className="space-y-3 min-w-0">
              <h1 className="font-display text-4xl md:text-5xl font-medium tracking-tight text-cream leading-[1.05]">
                Meetings
              </h1>
              <p className="text-sm text-cream-muted max-w-xl leading-relaxed">
                Long-form recordings, transcribed and summarized — yours to
                archive, search, and revisit.
              </p>
            </div>
            <div className="flex items-center gap-2 flex-shrink-0">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setImportOpen(true)}
                className="gap-1.5 text-cream-muted hover:text-cream"
              >
                <Upload className="w-3.5 h-3.5" strokeWidth={2} />
                Import audio
              </Button>
              {recorder.isLive ? (
                <Link
                  to="/dashboard/meetings/record"
                  className="inline-flex items-center gap-2 h-9 px-4 rounded-md border border-destructive/40 bg-destructive/[0.06] text-destructive hover:bg-destructive/10 transition-colors font-mono text-xs uppercase tracking-widest"
                >
                  <span className="rec-pulse" aria-hidden />
                  <span>live</span>
                  <span className="text-cream-muted/40">·</span>
                  <span className="tabular-figs normal-case tracking-normal text-cream">
                    {formatDuration(recorder.state.durationMs)}
                  </span>
                </Link>
              ) : (
                <Link to="/dashboard/meetings/record">
                  <Button size="sm" className="gap-1.5">
                    <Plus className="w-4 h-4" strokeWidth={2.5} />
                    New meeting
                  </Button>
                </Link>
              )}
            </div>
          </div>
        </header>

        <SearchBar
          value={search}
          onChange={setSearch}
          searching={searching}
        />

        {loading ? (
          <LogSkeleton />
        ) : !hasResults ? (
          <LogEmpty
            searchQuery={search}
            onStartNew={() => navigate("/dashboard/meetings/record")}
            onImport={() => setImportOpen(true)}
          />
        ) : (
          <div className="space-y-10">
            {groups.map((group) => (
              <GroupSection
                key={group.key}
                label={group.label}
                entries={group.entries}
              />
            ))}
          </div>
        )}
      </div>

      <MeetingImportDialog
        open={importOpen}
        onOpenChange={setImportOpen}
        onImported={(id) => navigate(`/dashboard/meetings/${id}`)}
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
      <div className="relative flex-1 max-w-md min-w-[240px]">
        <Search
          className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-cream-muted/60 pointer-events-none"
          strokeWidth={2}
        />
        <input
          type="search"
          placeholder="Search the library"
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

function GroupSection({
  label,
  entries,
}: {
  label: string;
  entries: Recording[];
}) {
  return (
    <section>
      <div className="flex items-center gap-3 mb-2 sticky top-0 z-10 bg-background/95 backdrop-blur-sm py-2 -mx-2 px-2">
        <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60 whitespace-nowrap">
          {label.toLowerCase()}
          <span className="text-cream-muted/30 mx-2">·</span>
          <span className="text-cream-muted/40">
            {entries.length} {entries.length === 1 ? "entry" : "entries"}
          </span>
        </p>
        <div className="flex-1 h-px bg-border" />
      </div>
      <ul>
        {entries.map((rec) => (
          <RecordingRow key={rec.id} recording={rec} />
        ))}
      </ul>
    </section>
  );
}

function RecordingRow({ recording }: { recording: Recording }) {
  const summaryPreview = (recording.summary ?? "")
    .replace(/^#{1,6}\s+.+$/gm, "")
    .replace(/[*_`>]/g, "")
    .trim()
    .split("\n")
    .filter(Boolean)
    .slice(0, 2)
    .join(" ");

  const sourceLabel =
    recording.sources.length === 0
      ? "—"
      : recording.sources
          .map((s) => (s === "mic" ? "mic" : "system"))
          .join(" + ");

  return (
    <li className="border-t border-border first:border-t-0 -mx-2">
      <Link
        to={`/dashboard/meetings/${recording.id}`}
        className="group block px-2 py-4 transition-colors hover:bg-secondary/[0.25] rounded-sm"
      >
        <div className="flex items-start gap-5">
          <div className="flex flex-col items-end gap-1.5 w-14 flex-shrink-0 pt-0.5">
            <span className="font-mono text-[11px] tabular-figs text-cream-muted/70 leading-none">
              {new Date(recording.createdAt).toLocaleTimeString([], {
                hour: "2-digit",
                minute: "2-digit",
                hour12: false,
              })}
            </span>
            {recording.audioDurationMs != null && (
              <span className="font-mono text-[9px] uppercase tracking-[0.15em] text-cream-muted/50 leading-none">
                {formatDuration(recording.audioDurationMs)}
              </span>
            )}
          </div>

          <div className="flex-1 min-w-0">
            <div className="flex items-baseline gap-3 flex-wrap">
              <span
                className={cn(
                  "font-display text-base font-medium tracking-tight",
                  recording.title ? "text-cream" : "text-cream-muted",
                )}
              >
                {recording.title || "Untitled recording"}
              </span>
              <StatusLine recording={recording} />
            </div>

            {summaryPreview && (
              <p className="text-sm leading-relaxed text-cream-muted line-clamp-2 group-hover:text-cream/80 transition-colors mt-1.5">
                {summaryPreview}
              </p>
            )}

            <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-cream-muted/50 mt-2">
              {sourceLabel}
              {recording.language && (
                <>
                  <span className="text-cream-muted/30 mx-2">·</span>
                  {recording.language}
                </>
              )}
            </p>
          </div>
        </div>
      </Link>
    </li>
  );
}

function LogEmpty({
  searchQuery,
  onStartNew,
  onImport,
}: {
  searchQuery: string;
  onStartNew: () => void;
  onImport: () => void;
}) {
  if (searchQuery) {
    return (
      <div className="border border-dashed border-border rounded-md py-20 px-6 text-center space-y-3">
        <p className="font-mono text-[11px] uppercase tracking-[0.25em] text-cream-muted/60">
          no matches
        </p>
        <p className="text-sm text-cream-muted">
          Nothing in the library matches{" "}
          <span className="font-mono text-cream">"{searchQuery}"</span>.
        </p>
        <p className="font-mono text-xs text-cream-muted/60 pt-2">
          <span className="text-cream-muted/40">→ </span>
          try simpler keywords or clear the search
        </p>
      </div>
    );
  }
  return (
    <div className="border border-dashed border-border rounded-md py-20 px-6 text-center space-y-4">
      <p className="font-mono text-[11px] uppercase tracking-[0.25em] text-cream-muted/60">
        library empty
      </p>
      <p className="text-sm text-cream-muted max-w-md mx-auto leading-relaxed">
        Nothing recorded yet. Start a new meeting to capture your microphone
        and system audio — or import an existing file you already have.
      </p>
      <div className="pt-2 flex items-center justify-center gap-3">
        <Button onClick={onStartNew} size="sm" className="gap-1.5">
          <Plus className="w-4 h-4" />
          New meeting
        </Button>
        <Button variant="ghost" size="sm" onClick={onImport} className="gap-1.5">
          <Upload className="w-3.5 h-3.5" />
          Import audio
        </Button>
      </div>
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
            <div className="w-14 flex-shrink-0 flex flex-col items-end gap-1.5">
              <div className="h-2.5 w-9 bg-secondary/50 rounded animate-pulse" />
              <div className="h-2 w-7 bg-secondary/30 rounded animate-pulse" />
            </div>
            <div className="flex-1 space-y-2">
              <div className="h-4 w-1/3 bg-secondary/40 rounded animate-pulse" />
              <div
                className="h-3 bg-secondary/30 rounded animate-pulse"
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
