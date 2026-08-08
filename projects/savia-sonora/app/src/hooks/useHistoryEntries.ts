import { useCallback, useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { api } from "@/lib/api";
import { t } from "@/lib/i18n";
import type { HistoryEntry } from "@/lib/types";
import { base64ToBlobUrl, revokeUrl, isInvalidAudioPayload } from "@/lib/audio";

export interface AudioMeta {
  fileName?: string;
  mime?: string;
  durationMs?: number;
}

export interface UseHistoryEntriesOptions {
  /** Initial search query sent to the backend (server-side filter). */
  search?: string;
}

export function useHistoryEntries(limit = 100, options?: UseHistoryEntriesOptions) {
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [searching, setSearching] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showPlayer, setShowPlayer] = useState(false);
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [audioMeta, setAudioMeta] = useState<AudioMeta | null>(null);
  const [loadingAudioFor, setLoadingAudioFor] = useState<number | null>(null);

  const lastHistoryIdRef = useRef<number | null>(null);

  const loadHistory = useCallback(
    async (searchQuery?: string, isInitial = false) => {
      if (isInitial) setLoading(true);
      else setSearching(true);
      setError(null);
      try {
        const data = await api.getHistory(limit, 0, searchQuery || undefined, false);
        setHistory(data);
        if (isInitial) lastHistoryIdRef.current = data[0]?.id ?? null;
      } catch (err) {
        console.error("Failed to load history:", err);
        setError(t("home.loadFailed"));
        toast.error(t("home.loadFailed"));
      } finally {
        setLoading(false);
        setSearching(false);
      }
    },
    [limit],
  );

  useEffect(() => {
    loadHistory(options?.search, true);
    // Load once on mount; subsequent search changes are driven by the page.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loadHistory]);

  // Refresh silently when a new recording lands (no full reload UX).
  const refreshIfNew = useCallback(async () => {
    try {
      const data = await api.getHistory(limit, 0, undefined, false);
      const newest = data[0]?.id ?? null;
      if (newest !== null && newest !== lastHistoryIdRef.current) {
        setHistory(data);
        lastHistoryIdRef.current = newest;
      }
    } catch {
      // ignore background refresh errors
    }
  }, [limit]);

  const handleCopy = useCallback(async (text: string) => {
    try {
      await api.copyToClipboard(text);
      toast.success(t("home.copied"));
    } catch {
      try {
        await navigator.clipboard.writeText(text);
        toast.success(t("home.copied"));
      } catch {
        toast.error(t("home.copyFailed"));
      }
    }
  }, []);

  const handleDelete = useCallback(async (id: number) => {
    try {
      await api.deleteHistory(id);
      setHistory((prev) => prev.filter((h) => h.id !== id));
      toast.success(t("home.deleted"));
    } catch (err) {
      console.error("Failed to delete:", err);
      toast.error(t("home.deleteFailed"));
    }
  }, []);

  const handlePlayAudio = useCallback(async (historyId: number) => {
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
        isInvalidAudioPayload(err) ? t("home.audioCorrupted") : t("home.audioNotFound"),
      );
      revokeUrl(audioUrl);
      setAudioUrl(null);
      setShowPlayer(false);
      setAudioMeta(null);
    } finally {
      setLoadingAudioFor(null);
    }
  }, [audioUrl]);

  const closePlayer = useCallback(() => {
    revokeUrl(audioUrl);
    setAudioUrl(null);
    setAudioMeta(null);
    setShowPlayer(false);
  }, [audioUrl]);

  useEffect(() => () => revokeUrl(audioUrl), [audioUrl]);

  return {
    history,
    loading,
    searching,
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
  };
}
