/* LLM provider settings — preset cards, endpoint/key/model, test button.
   Drops into SettingsTab's `<Section title="AI summary">` so it follows the
   same `SectionBlock`/`SettingRow` rhythm as every other preference panel. */

import { useEffect, useState } from "react";
import { Check, Eye, EyeOff, RotateCw } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { api } from "@/lib/api";
import type { LLMConfig, LLMPreset } from "@/lib/types";
import { cn } from "@/lib/utils";

const PRESET_DEFAULTS: Record<
  LLMPreset,
  {
    endpoint: string;
    needsKey: boolean;
    defaultModel: string;
    label: string;
    description: string;
  }
> = {
  openai: {
    endpoint: "https://api.openai.com/v1",
    needsKey: true,
    defaultModel: "gpt-4o-mini",
    label: "OpenAI",
    description: "Cloud · paid API",
  },
  groq: {
    endpoint: "https://api.groq.com/openai/v1",
    needsKey: true,
    defaultModel: "llama-3.3-70b-versatile",
    label: "Groq",
    description: "Cloud · free tier · fast",
  },
  openrouter: {
    endpoint: "https://openrouter.ai/api/v1",
    needsKey: true,
    defaultModel: "openai/gpt-4o-mini",
    label: "OpenRouter",
    description: "Cloud · one key, many models",
  },
  ollama: {
    endpoint: "http://localhost:11434/v1",
    needsKey: false,
    defaultModel: "llama3.2",
    label: "Local (Ollama)",
    description: "Runs entirely on your machine",
  },
  custom: {
    endpoint: "",
    needsKey: false,
    defaultModel: "",
    label: "Custom endpoint",
    description: "Any OpenAI-compatible server",
  },
};

export function LLMSettingsSection() {
  const [config, setConfig] = useState<LLMConfig | null>(null);
  const [draft, setDraft] = useState<LLMConfig | null>(null);
  const [apiKeyDraft, setApiKeyDraft] = useState("");
  const [showKey, setShowKey] = useState(false);
  const [models, setModels] = useState<string[]>([]);
  const [loadingModels, setLoadingModels] = useState(false);
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<{ ok: boolean; msg: string } | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api
      .llmGetConfig()
      .then((c) => {
        setConfig(c);
        setDraft(c);
      })
      .catch(() => {
        const fallback: LLMConfig = {
          preset: "ollama",
          endpoint: "http://localhost:11434/v1",
          model: "llama3.2",
          hasApiKey: false,
          promptTemplate: "",
        };
        setConfig(fallback);
        setDraft(fallback);
      });
  }, []);

  const refreshModels = async () => {
    if (!draft) return;
    setLoadingModels(true);
    try {
      const list = await api.llmListModels(
        draft.preset,
        draft.endpoint,
        apiKeyDraft || undefined,
      );
      setModels(list);
    } catch (err) {
      console.error("list models failed", err);
      toast.error("Could not list models — check endpoint / key");
    } finally {
      setLoadingModels(false);
    }
  };

  const handlePreset = (preset: LLMPreset) => {
    if (!draft) return;
    const defaults = PRESET_DEFAULTS[preset];
    setDraft({
      ...draft,
      preset,
      endpoint: defaults.endpoint || draft.endpoint,
      model: defaults.defaultModel || draft.model,
    });
    setTestResult(null);
  };

  const handleTest = async () => {
    if (!draft) return;
    setTesting(true);
    setTestResult(null);
    try {
      const result = await api.llmTestConnection(
        draft.preset,
        draft.endpoint,
        apiKeyDraft || undefined,
      );
      if (result.ok) {
        setTestResult({ ok: true, msg: "Connection OK" });
        if (result.models) setModels(result.models);
      } else {
        setTestResult({ ok: false, msg: result.error ?? "Failed" });
      }
    } catch (err) {
      setTestResult({ ok: false, msg: String(err) });
    } finally {
      setTesting(false);
    }
  };

  const handleSave = async () => {
    if (!draft) return;
    setSaving(true);
    try {
      await api.llmSetConfig({
        ...draft,
        apiKey: apiKeyDraft || undefined,
      });
      toast.success("LLM settings saved");
      const fresh = await api.llmGetConfig();
      setConfig(fresh);
      setDraft(fresh);
      setApiKeyDraft("");
    } catch (err) {
      console.error(err);
      toast.error("Could not save");
    } finally {
      setSaving(false);
    }
  };

  if (!draft || !config) return null;

  const presetMeta = PRESET_DEFAULTS[draft.preset];
  const isDirty =
    draft.preset !== config.preset ||
    draft.endpoint !== config.endpoint ||
    draft.model !== config.model ||
    draft.promptTemplate !== config.promptTemplate ||
    apiKeyDraft.length > 0;

  return (
    <>
      <SectionBlock
        label="Provider"
        helper="Pick a preset for the common cases, or wire up any OpenAI-compatible endpoint."
      >
        <RadioGroup
          value={draft.preset}
          onValueChange={(v) => handlePreset(v as LLMPreset)}
          className="grid grid-cols-1 sm:grid-cols-2 gap-2"
        >
          {(Object.keys(PRESET_DEFAULTS) as LLMPreset[]).map((preset) => {
            const meta = PRESET_DEFAULTS[preset];
            const selected = draft.preset === preset;
            return (
              <label
                key={preset}
                className={cn(
                  "flex items-start gap-3 p-3 rounded-md border transition-colors cursor-pointer",
                  selected
                    ? "border-accent-500/40 bg-accent-500/[0.04]"
                    : "border-border bg-secondary/30 hover:bg-secondary/50",
                )}
              >
                <RadioGroupItem
                  value={preset}
                  id={`preset-${preset}`}
                  className="mt-1"
                />
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-cream">{meta.label}</p>
                  <p className="text-xs text-cream-muted mt-0.5">
                    {meta.description}
                  </p>
                </div>
              </label>
            );
          })}
        </RadioGroup>
      </SectionBlock>

      <SectionBlock
        label="Endpoint & model"
        helper={
          draft.preset === "custom"
            ? "Provide the base URL of any OpenAI-compatible server."
            : "Endpoint is fixed by the preset. Pick a model below or refresh the list."
        }
      >
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <Label className="text-xs text-cream-muted">Endpoint</Label>
            <Input
              value={draft.endpoint}
              onChange={(e) => setDraft({ ...draft, endpoint: e.target.value })}
              disabled={draft.preset !== "custom"}
              className="font-mono text-xs"
              placeholder="https://example.com/v1"
            />
          </div>

          <div className="space-y-1.5">
            <Label className="text-xs text-cream-muted">Model</Label>
            <div className="flex items-center gap-1">
              {models.length > 0 ? (
                <Select
                  value={draft.model}
                  onValueChange={(v) => setDraft({ ...draft, model: v })}
                >
                  <SelectTrigger className="font-mono text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {models.map((m) => (
                      <SelectItem key={m} value={m}>
                        <span className="font-mono text-xs">{m}</span>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              ) : (
                <Input
                  value={draft.model}
                  onChange={(e) => setDraft({ ...draft, model: e.target.value })}
                  className="font-mono text-xs"
                />
              )}
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className="shrink-0"
                onClick={refreshModels}
                disabled={loadingModels}
                title="Refresh model list"
              >
                <RotateCw
                  className={cn("w-3.5 h-3.5", loadingModels && "animate-spin")}
                />
              </Button>
            </div>
          </div>
        </div>
      </SectionBlock>

      {presetMeta.needsKey && (
        <SectionBlock
          label="API key"
          helper="Stored in your OS keychain — never written to the database or logs."
        >
          <div className="space-y-1.5">
            {config.hasApiKey && (
              <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-accent-500">
                · stored
              </p>
            )}
            <div className="relative">
              <Input
                type={showKey ? "text" : "password"}
                value={apiKeyDraft}
                onChange={(e) => setApiKeyDraft(e.target.value)}
                placeholder={
                  config.hasApiKey ? "•••••••••• (already saved)" : "sk-…"
                }
                className="font-mono text-xs pr-10"
              />
              <button
                type="button"
                onClick={() => setShowKey((s) => !s)}
                className="absolute right-2 top-1/2 -translate-y-1/2 text-cream-muted/70 hover:text-cream transition-colors"
                aria-label={showKey ? "Hide" : "Show"}
              >
                {showKey ? (
                  <EyeOff className="w-4 h-4" />
                ) : (
                  <Eye className="w-4 h-4" />
                )}
              </button>
            </div>
          </div>
        </SectionBlock>
      )}

      <SectionBlock
        label="Connection"
        helper="Verify the endpoint accepts your credentials before saving."
      >
        <div className="flex items-center gap-3">
          <Button
            variant="outline"
            size="sm"
            onClick={handleTest}
            disabled={testing}
          >
            {testing ? "Testing…" : "Test connection"}
          </Button>
          {testResult && (
            <span
              className={cn(
                "font-mono text-[11px] inline-flex items-center gap-1.5",
                testResult.ok ? "text-accent-500" : "text-destructive",
              )}
            >
              {testResult.ok && <Check className="w-3 h-3" />}
              {testResult.msg}
            </span>
          )}
        </div>
      </SectionBlock>

      <SectionBlock>
        <details className="group">
          <summary className="cursor-pointer font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60 hover:text-accent-500 inline-flex items-center gap-2 select-none transition-colors">
            advanced · prompt template
            <span className="text-cream-muted/40 group-open:rotate-90 transition-transform">
              ›
            </span>
          </summary>
          <div className="mt-3 space-y-1.5">
            <Textarea
              value={draft.promptTemplate}
              onChange={(e) =>
                setDraft({ ...draft, promptTemplate: e.target.value })
              }
              className="min-h-[10rem] font-mono text-xs leading-relaxed"
              placeholder="Use {transcript} to interpolate the transcript text."
            />
            <p className="text-xs text-cream-muted">
              Use <code className="font-mono text-cream">{"{transcript}"}</code>{" "}
              as the placeholder. Long transcripts are auto-chunked and reduced.
            </p>
          </div>
        </details>
      </SectionBlock>

      {isDirty && (
        <div className="pt-4 border-t border-border flex items-center justify-end gap-2">
          <Button
            size="sm"
            variant="ghost"
            onClick={() => {
              setDraft(config);
              setApiKeyDraft("");
              setTestResult(null);
            }}
            disabled={saving}
          >
            Discard
          </Button>
          <Button size="sm" onClick={handleSave} disabled={saving}>
            {saving ? "Saving…" : "Save changes"}
          </Button>
        </div>
      )}
    </>
  );
}

/* Local twin of SettingsTab's `SectionBlock`. Inline-replicated because the
   helpers there aren't exported; same classes, same dividers. */
function SectionBlock({
  label,
  helper,
  children,
}: {
  label?: string;
  helper?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="py-5 border-t border-border first:border-t-0 space-y-3">
      {(label || helper) && (
        <div className="space-y-1">
          {label && <p className="text-sm font-medium text-cream">{label}</p>}
          {helper && (
            <p className="text-xs text-cream-muted leading-relaxed max-w-2xl">
              {helper}
            </p>
          )}
        </div>
      )}
      <div>{children}</div>
    </div>
  );
}
