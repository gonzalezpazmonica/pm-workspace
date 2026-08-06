/* Markdown summary panel with in-place edit. Renders via react-markdown +
   remark-gfm. Edit mode swaps the rendered view for a plain textarea. */

import { useEffect, useState } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { Pencil, Check, X, RotateCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";

interface SummaryViewProps {
  markdown: string | null;
  /** True while the LLM is currently producing tokens (locks UI, shows live caret). */
  streaming?: boolean;
  /** True when no LLM config exists — the regenerate button routes to settings. */
  llmConfigured?: boolean;
  onSave(next: string): Promise<void> | void;
  onRegenerate?(): void;
  onConfigureLLM?(): void;
  className?: string;
}

export function SummaryView({
  markdown,
  streaming = false,
  llmConfigured = true,
  onSave,
  onRegenerate,
  onConfigureLLM,
  className,
}: SummaryViewProps) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(markdown ?? "");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!editing) setDraft(markdown ?? "");
  }, [markdown, editing]);

  const empty = !markdown || markdown.trim().length === 0;

  const handleSave = async () => {
    setSaving(true);
    try {
      await onSave(draft);
      setEditing(false);
    } finally {
      setSaving(false);
    }
  };

  if (editing) {
    return (
      <section className={cn("space-y-3", className)}>
        <Textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          className="min-h-[24rem] font-mono text-[13px] leading-relaxed"
          autoFocus
        />
        <div className="flex items-center gap-2">
          <Button
            size="sm"
            onClick={handleSave}
            disabled={saving}
            className="gap-1.5"
          >
            <Check className="w-3.5 h-3.5" />
            Save
          </Button>
          <Button
            size="sm"
            variant="ghost"
            onClick={() => {
              setDraft(markdown ?? "");
              setEditing(false);
            }}
            className="gap-1.5 text-cream-muted"
          >
            <X className="w-3.5 h-3.5" />
            Cancel
          </Button>
        </div>
      </section>
    );
  }

  return (
    <section className={cn("space-y-4", className)}>
      <header className="flex items-baseline justify-between gap-4">
        <h2 className="font-display text-2xl md:text-3xl font-medium tracking-tight text-cream leading-tight">
          Summary
        </h2>
        <div className="flex items-center gap-1">
          {!empty && !streaming && (
            <Button
              size="sm"
              variant="ghost"
              className="h-8 gap-1.5 text-cream-muted hover:text-cream"
              onClick={() => setEditing(true)}
            >
              <Pencil className="w-3.5 h-3.5" />
              Edit
            </Button>
          )}
          {!streaming && (
            <Button
              size="sm"
              variant="ghost"
              className="h-8 gap-1.5 text-cream-muted hover:text-cream"
              disabled={!llmConfigured && !onConfigureLLM}
              onClick={() => {
                if (!llmConfigured && onConfigureLLM) {
                  onConfigureLLM();
                } else {
                  onRegenerate?.();
                }
              }}
              title={
                llmConfigured ? "Regenerate summary" : "Set up an LLM to summarize"
              }
            >
              <RotateCw className="w-3.5 h-3.5" />
              {empty ? "Generate" : "Regenerate"}
            </Button>
          )}
        </div>
      </header>

      {empty ? (
        <EmptyState llmConfigured={llmConfigured} onConfigure={onConfigureLLM} />
      ) : (
        <article className="prose prose-invert max-w-none prose-headings:font-display prose-headings:font-medium prose-headings:tracking-tight prose-headings:text-cream prose-h2:text-xl prose-h3:text-base prose-p:text-cream/90 prose-strong:text-cream prose-li:text-cream/90 prose-li:marker:text-cream-muted text-[15px] leading-relaxed">
          <ReactMarkdown remarkPlugins={[remarkGfm]}>{markdown!}</ReactMarkdown>
          {streaming && (
            <span
              aria-hidden
              className="inline-block w-1.5 h-4 ml-0.5 bg-accent-500 align-text-bottom animate-pulse"
            />
          )}
        </article>
      )}
    </section>
  );
}

function EmptyState({
  llmConfigured,
  onConfigure,
}: {
  llmConfigured: boolean;
  onConfigure?: () => void;
}) {
  if (!llmConfigured) {
    return (
      <div className="border border-dashed border-border rounded-md py-12 px-6 text-center space-y-3">
        <p className="font-mono text-[11px] uppercase tracking-[0.25em] text-cream-muted/60">
          llm not configured
        </p>
        <p className="text-sm text-cream-muted max-w-md mx-auto leading-relaxed">
          Connect a local Ollama instance or any OpenAI-compatible endpoint to
          generate structured meeting summaries — TL;DR, decisions, action items.
        </p>
        {onConfigure && (
          <div className="pt-2">
            <Button size="sm" variant="outline" onClick={onConfigure}>
              Open settings
            </Button>
          </div>
        )}
      </div>
    );
  }
  return (
    <div className="border border-dashed border-border rounded-md py-12 px-6 text-center space-y-3">
      <p className="font-mono text-[11px] uppercase tracking-[0.25em] text-cream-muted/60">
        no summary yet
      </p>
      <p className="text-sm text-cream-muted max-w-md mx-auto leading-relaxed">
        Generate one from the transcript — TL;DR, decisions, action items.
      </p>
      <p className="font-mono text-xs text-cream-muted/60 pt-1">
        <span className="text-cream-muted/40">→ </span>
        click Generate above
      </p>
    </div>
  );
}
