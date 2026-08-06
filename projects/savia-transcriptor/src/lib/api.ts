import { rpc } from "pyloid-js";
import type {
  Settings,
  HistoryEntry,
  Options,
  Stats,
  ModelInfo,
  HotkeyValidation,
  GpuInfo,
  DeviceValidation,
  CudnnDownloadInfo,
  CudnnDownloadResult,
  CudnnDownloadProgress,
  DownloadStatus,
  AudioSourceList,
  RecorderState,
  Recording,
  RecordingWithSegments,
  CachedModel,
  LLMConfig,
  LLMPreset,
  LLMTestResult,
} from "./types";

export const api = {
  async getSettings(): Promise<Settings> {
    return rpc.call("get_settings");
  },

  async getStats(): Promise<Stats> {
    return rpc.call("get_stats");
  },

  async updateSettings(settings: Partial<Settings>): Promise<Settings> {
    return rpc.call("update_settings", settings);
  },

  async getOptions(): Promise<Options> {
    return rpc.call("get_options");
  },

  async getHistory(
    limit = 100,
    offset = 0,
    search?: string,
    include_audio_meta?: boolean
  ): Promise<HistoryEntry[]> {
    return rpc.call("get_history", { limit, offset, search, include_audio_meta });
  },

  async getHistoryAudio(historyId: number): Promise<{ base64: string; mime: string; fileName?: string; sizeBytes?: number; durationMs?: number }> {
    return rpc.call("get_history_audio", { history_id: historyId });
  },

  async deleteHistory(historyId: number): Promise<void> {
    await rpc.call("delete_history", { history_id: historyId });
  },

  async copyToClipboard(text: string): Promise<void> {
    await rpc.call("copy_to_clipboard", { text });
  },

  async stopRecording(): Promise<void> {
    await rpc.call("stop_recording");
  },

  async manualToggleRecording(): Promise<{ recording: boolean; changed: boolean; error?: string }> {
    return rpc.call("manual_toggle_recording");
  },

  async getRecordingState(): Promise<{ recording: boolean; mode: string | null }> {
    return rpc.call("get_recording_state");
  },

  async getHotkeyStatus(): Promise<{ available: boolean; code: string; message: string; device_count: number }> {
    return rpc.call("get_hotkey_status");
  },

  async startTestRecording(): Promise<void> {
    await rpc.call("start_test_recording");
  },

  async stopTestRecording(): Promise<{ success: boolean; transcript: string; error?: string }> {
    return rpc.call("stop_test_recording");
  },

  async openDataFolder(): Promise<void> {
    await rpc.call("open_data_folder");
  },

  async openExternalUrl(url: string): Promise<void> {
    await rpc.call("open_external_url", { url });
  },

  async setPopupEnabled(enabled: boolean): Promise<void> {
    await rpc.call("set_popup_enabled", { enabled });
  },

  async resetAllData(): Promise<void> {
    await rpc.call("reset_all_data");
  },

  async windowMinimize(): Promise<void> {
    await rpc.call("window_minimize");
  },

  async windowToggleMaximize(): Promise<void> {
    await rpc.call("window_toggle_maximize");
  },

  async windowClose(): Promise<void> {
    await rpc.call("window_close");
  },

  // Model Management
  async getModelInfo(modelName: string): Promise<ModelInfo> {
    return rpc.call("get_model_info", { model_name: modelName });
  },

  async startModelDownload(modelName: string): Promise<{ success: boolean; alreadyCached?: boolean; started?: boolean }> {
    return rpc.call("start_model_download", { model_name: modelName });
  },

  async cancelModelDownload(): Promise<{ success: boolean; cancelled: boolean }> {
    return rpc.call("cancel_model_download");
  },

  async getDownloadStatus(): Promise<DownloadStatus> {
    return rpc.call("get_download_status");
  },

  async clearModelCache(): Promise<{ success: boolean; deleted_bytes: number; deleted_models: string[]; error: string | null }> {
    return rpc.call("clear_model_cache");
  },

  async deleteModel(modelName: string): Promise<{ success: boolean; deleted_bytes: number; deleted_model: string | null; error: string | null }> {
    return rpc.call("delete_model", { model_name: modelName });
  },

  async getModelCacheDir(): Promise<{ path: string }> {
    return rpc.call("get_model_cache_dir");
  },

  async openModelCacheDir(): Promise<{ success: boolean; error?: string; path: string }> {
    return rpc.call("open_model_cache_dir");
  },

  // Hotkey validation
  async validateHotkey(
    hotkey: string,
    excludeCurrent?: "holdHotkey" | "toggleHotkey"
  ): Promise<HotkeyValidation> {
    return rpc.call("validate_hotkey", { hotkey, excludeCurrent });
  },

  // GPU/Device info
  async getGpuInfo(): Promise<GpuInfo> {
    return rpc.call("get_gpu_info");
  },

  async validateDevice(device: string): Promise<DeviceValidation> {
    return rpc.call("validate_device", { device });
  },

  // cuDNN download
  async getCudnnDownloadInfo(): Promise<CudnnDownloadInfo> {
    return rpc.call("get_cudnn_download_info");
  },

  async downloadCudnn(): Promise<CudnnDownloadResult> {
    return rpc.call("download_cudnn");
  },

  async getCudnnDownloadProgress(): Promise<CudnnDownloadProgress> {
    return rpc.call("get_cudnn_download_progress");
  },

  async clearCudaLibs(): Promise<{ success: boolean }> {
    return rpc.call("clear_cuda_libs");
  },

  // ───── Recordings (Meetings feature) ─────────────────────────────────────

  async recordingsListAudioSources(): Promise<AudioSourceList> {
    return rpc.call("recordings_list_audio_sources");
  },

  async recordingsStart(
    title: string,
    micDeviceId: number | null,
    loopbackDeviceId: number | null,
  ): Promise<{ recording_id: number }> {
    return rpc.call("recordings_start", {
      title,
      mic_device_id: micDeviceId,
      loopback_device_id: loopbackDeviceId,
    });
  },

  async recordingsPause(): Promise<{ ok: boolean }> {
    return rpc.call("recordings_pause");
  },

  async recordingsResume(): Promise<{ ok: boolean }> {
    return rpc.call("recordings_resume");
  },

  async recordingsStop(): Promise<Recording> {
    return rpc.call("recordings_stop");
  },

  async recordingsGetRecorderState(): Promise<RecorderState> {
    return rpc.call("recordings_get_recorder_state");
  },

  async recordingsPreviewStart(
    micDeviceId: number | null,
    loopbackDeviceId: number | null,
  ): Promise<{ ok: boolean; reason?: string }> {
    return rpc.call("recordings_preview_start", {
      mic_device_id: micDeviceId,
      loopback_device_id: loopbackDeviceId,
    });
  },

  async recordingsPreviewStop(): Promise<{ ok: boolean }> {
    return rpc.call("recordings_preview_stop");
  },

  async recordingsPreviewState(): Promise<{
    active: boolean;
    hasMic: boolean;
    hasLoopback: boolean;
    micPeakDb: number | null;
    loopbackPeakDb: number | null;
  }> {
    return rpc.call("recordings_preview_state");
  },

  async recordingsList(
    limit = 100,
    offset = 0,
    search?: string,
  ): Promise<Recording[]> {
    return rpc.call("recordings_list", { limit, offset, search });
  },

  async recordingsGet(id: number): Promise<RecordingWithSegments> {
    return rpc.call("recordings_get", { id });
  },

  async recordingsUpdate(
    id: number,
    fields: Partial<
      Pick<Recording, "title" | "summary" | "notes" | "tags" | "language">
    >,
  ): Promise<Recording> {
    return rpc.call("recordings_update", { id, fields });
  },

  async recordingsDelete(id: number): Promise<{ ok: boolean }> {
    return rpc.call("recordings_delete", { id });
  },

  async recordingsImportFile(
    filePath: string,
    title?: string,
  ): Promise<{ recording_id: number }> {
    return rpc.call("recordings_import_file", { file_path: filePath, title });
  },

  async recordingsExport(
    id: number,
    format: "txt" | "md" | "json" | "srt",
  ): Promise<{ path: string }> {
    return rpc.call("recordings_export", { id, format });
  },

  async recordingsTranscribe(id: number): Promise<{ ok: boolean }> {
    return rpc.call("recordings_transcribe", { id });
  },

  async recordingsRetranscribe(
    id: number,
    opts: { model?: string; device?: string; language?: string } = {},
  ): Promise<{ ok: boolean }> {
    return rpc.call("recordings_retranscribe", {
      id,
      model: opts.model,
      device: opts.device,
      language: opts.language,
    });
  },

  async recordingsCancelTranscribe(id: number): Promise<{ ok: boolean }> {
    return rpc.call("recordings_cancel_transcribe", { id });
  },

  async recordingsListCachedModels(): Promise<CachedModel[]> {
    return rpc.call("recordings_list_cached_models");
  },

  async recordingsSummarize(
    id: number,
    prompt?: string,
  ): Promise<{ ok: boolean }> {
    return rpc.call("recordings_summarize", { id, prompt });
  },

  async recordingsCancelSummarize(id: number): Promise<{ ok: boolean }> {
    return rpc.call("recordings_cancel_summarize", { id });
  },

  async llmGetConfig(): Promise<LLMConfig> {
    return rpc.call("llm_get_config");
  },

  async llmSetConfig(
    config: Partial<LLMConfig> & { apiKey?: string },
  ): Promise<{ ok: boolean }> {
    return rpc.call("llm_set_config", config);
  },

  async llmTestConnection(
    preset: LLMPreset,
    endpoint: string,
    apiKey?: string,
  ): Promise<LLMTestResult> {
    return rpc.call("llm_test_connection", { preset, endpoint, apiKey });
  },

  async llmListModels(
    preset: LLMPreset,
    endpoint: string,
    apiKey?: string,
  ): Promise<string[]> {
    return rpc.call("llm_list_models", { preset, endpoint, apiKey });
  },
};
