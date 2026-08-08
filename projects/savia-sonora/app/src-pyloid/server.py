from typing import Optional
from pyloid.rpc import PyloidRPC, RPCContext
from app_controller import get_controller
from services.logger import get_logger
from services.model_manager import get_model_manager
import threading

log = get_logger("window")
model_log = get_logger("model")

server = PyloidRPC()

# Callbacks that main.py will register
_on_onboarding_complete = None
_on_data_reset = None
_on_popup_visibility_changed = None  # Callback when showPopup setting changes
_send_download_progress = None  # Callback to send progress to frontend


def _emit_download_event(event_name: str, payload: dict) -> None:
    """Forward a download event to the frontend if the bridge is registered."""
    if _send_download_progress:
        _send_download_progress(event_name, payload)


def register_download_progress_callback(callback):
    """Register callback to send download progress to frontend."""
    global _send_download_progress
    _send_download_progress = callback


def register_popup_visibility_callback(callback):
    """Register callback for when showPopup setting changes."""
    global _on_popup_visibility_changed
    _on_popup_visibility_changed = callback


def register_onboarding_complete_callback(callback):
    """Register callback to be called when onboarding completes."""
    global _on_onboarding_complete
    _on_onboarding_complete = callback


def register_data_reset_callback(callback):
    """Register callback to be called when data is reset."""
    global _on_data_reset
    _on_data_reset = callback


@server.method()
async def get_settings():
    controller = get_controller()
    return controller.get_settings()


@server.method()
async def update_settings(
    *,
    language: Optional[str] = None,
    model: Optional[str] = None,
    device: Optional[str] = None,
    autoStart: Optional[bool] = None,
    retention: Optional[int] = None,
    theme: Optional[str] = None,
    onboardingComplete: Optional[bool] = None,
    microphone: Optional[int] = None,
    saveAudioToHistory: Optional[bool] = None,
    showPopup: Optional[bool] = None,
    holdHotkey: Optional[str] = None,
    holdHotkeyEnabled: Optional[bool] = None,
    toggleHotkey: Optional[str] = None,
    toggleHotkeyEnabled: Optional[bool] = None,
    prependSpace: Optional[bool] = None,
    recordingsAutoRenameTitle: Optional[bool] = None,
):
    controller = get_controller()
    provided = {
        "language": language,
        "model": model,
        "device": device,
        "autoStart": autoStart,
        "retention": retention,
        "theme": theme,
        "onboardingComplete": onboardingComplete,
        "microphone": microphone,
        "saveAudioToHistory": saveAudioToHistory,
        "showPopup": showPopup,
        "holdHotkey": holdHotkey,
        "holdHotkeyEnabled": holdHotkeyEnabled,
        "toggleHotkey": toggleHotkey,
        "toggleHotkeyEnabled": toggleHotkeyEnabled,
        "prependSpace": prependSpace,
        "recordingsAutoRenameTitle": recordingsAutoRenameTitle,
    }
    kwargs = {key: value for key, value in provided.items() if value is not None}

    # Check if onboarding was already complete before this update
    old_settings = controller.get_settings()
    was_onboarding_complete = old_settings.get("onboardingComplete", False)

    result = controller.update_settings(**kwargs)

    # If onboarding JUST NOW completed (was false, now true), trigger the callback
    if onboardingComplete is True and not was_onboarding_complete and _on_onboarding_complete:
        log.info("Onboarding completed, initializing popup")
        _on_onboarding_complete()

    # If showPopup changed, trigger visibility callback
    if showPopup is not None and _on_popup_visibility_changed:
        _on_popup_visibility_changed(showPopup)

    return result


@server.method()
async def validate_hotkey(hotkey: str, excludeCurrent: Optional[str] = None):
    """Validate a hotkey string and check for conflicts with existing hotkeys.

    Args:
        hotkey: The hotkey string to validate (e.g., "ctrl+shift+r")
        excludeCurrent: Field to exclude from conflict check ("holdHotkey" or "toggleHotkey")

    Returns:
        {"valid": bool, "error": str or None, "conflicts": bool, "normalized": str}
    """
    from services.hotkey import validate_hotkey as do_validate, are_hotkeys_conflicting, normalize_hotkey

    # Validate format
    is_valid, error = do_validate(hotkey)
    if not is_valid:
        return {"valid": False, "error": error, "conflicts": False, "normalized": hotkey}

    # Normalize the hotkey to canonical format
    normalized = normalize_hotkey(hotkey)

    # Check for conflicts with existing hotkeys
    controller = get_controller()
    settings = controller.get_settings()

    conflicts = False
    conflict_with = None

    if excludeCurrent != "holdHotkey" and are_hotkeys_conflicting(normalized, settings.get("holdHotkey", "")):
        conflicts = True
        conflict_with = "Hold Mode"
    elif excludeCurrent != "toggleHotkey" and are_hotkeys_conflicting(normalized, settings.get("toggleHotkey", "")):
        conflicts = True
        conflict_with = "Toggle Mode"

    return {
        "valid": not conflicts,
        "error": f"Conflicts with {conflict_with} hotkey" if conflicts else None,
        "conflicts": conflicts,
        "normalized": normalized
    }


@server.method()
async def get_options():
    controller = get_controller()
    return controller.get_options()


@server.method()
async def get_gpu_info():
    """Get GPU/CUDA information."""
    controller = get_controller()
    return controller.get_gpu_info()


@server.method()
async def validate_device(device: str):
    """Validate a device setting before saving."""
    controller = get_controller()
    return controller.validate_device(device)


@server.method()
async def get_cudnn_download_info():
    """Get info about cuDNN download status."""
    controller = get_controller()
    return controller.get_cudnn_download_info()


# cuDNN download thread
_cudnn_download_thread: threading.Thread = None


@server.method()
async def download_cudnn():
    """Download and install cuDNN libraries in background thread."""
    global _cudnn_download_thread

    # Check if already downloading
    if _cudnn_download_thread and _cudnn_download_thread.is_alive():
        return {"success": True, "started": True, "alreadyRunning": True}

    controller = get_controller()

    def do_download():
        try:
            controller.download_cudnn()
        except Exception as e:
            log.error("cuDNN download thread error", error=str(e))

    # Start download in background thread
    _cudnn_download_thread = threading.Thread(target=do_download, daemon=True)
    _cudnn_download_thread.start()

    return {"success": True, "started": True}


@server.method()
async def get_cudnn_download_progress():
    """Get current cuDNN download progress."""
    controller = get_controller()
    return controller.get_cudnn_download_progress()


@server.method()
async def clear_cuda_libs():
    """Clear downloaded CUDA libraries (cuDNN + cuBLAS)."""
    controller = get_controller()
    return controller.clear_cuda_libs()


@server.method()
async def get_history(limit: int = 100, offset: int = 0, search: str = None, include_audio_meta: bool = False):
    controller = get_controller()
    return controller.get_history(limit, offset, search, include_audio_meta)


@server.method()
async def get_history_audio(history_id: int):
    controller = get_controller()
    return controller.get_history_audio(history_id)


@server.method()
async def get_stats():
    controller = get_controller()
    stats = controller.get_stats()
    return stats


@server.method()
async def delete_history(history_id: int):
    controller = get_controller()
    controller.delete_history(history_id)
    return {"success": True}


@server.method()
async def copy_to_clipboard(text: str):
    controller = get_controller()
    controller.clipboard_service.copy_to_clipboard(text)
    return {"success": True}


@server.method()
async def stop_recording():
    """Manually stop recording from the popup stop button."""
    controller = get_controller()
    controller.stop_recording()
    return {"success": True}


@server.method()
async def start_test_recording():
    """Start recording for onboarding test (no hotkey needed)."""
    controller = get_controller()
    controller.start_test_recording()
    return {"success": True}


@server.method()
async def stop_test_recording():
    """Stop test recording, transcribe, and return result (no paste/history)."""
    controller = get_controller()
    result = controller.stop_test_recording()
    return result


@server.method()
async def manual_toggle_recording():
    """Toggle recording from a dashboard button - same flow as the hotkey."""
    controller = get_controller()
    return controller.manual_toggle_recording()


@server.method()
async def get_recording_state():
    """Return the current recording state for UI sync."""
    controller = get_controller()
    return controller.get_recording_state()


@server.method()
async def get_hotkey_status():
    """Return hotkey availability status (e.g. evdev permission errors)."""
    controller = get_controller()
    return controller.hotkey_service.get_status()


@server.method()
async def open_data_folder():
    """Open the application data folder."""
    controller = get_controller()
    controller.open_data_folder()
    return {"success": True}


@server.method()
async def open_external_url(url: str):
    """Open a URL in the system's default browser.

    On Linux when frozen we go straight to xdg-open with a sanitized env so
    the spawned browser doesn't inherit the bundle's LD_LIBRARY_PATH (which
    causes chromium "undefined symbol: hb_calloc" from the bundled
    libharfbuzz). QDesktopServices can't be told to use a custom env, so
    we skip it in that case.
    """
    import sys
    import subprocess
    import webbrowser
    from services.process_env import is_frozen, system_env

    log.info("Opening external URL", url=url)

    use_qt_first = not (is_frozen() and sys.platform.startswith("linux"))
    if use_qt_first:
        try:
            from PySide6.QtCore import QUrl
            from PySide6.QtGui import QDesktopServices
            if QDesktopServices.openUrl(QUrl(url)):
                return {"success": True}
        except Exception as e:
            log.warning("QDesktopServices failed, falling back", error=str(e))

    try:
        if sys.platform == 'win32':
            import os
            os.startfile(url)
        elif sys.platform == 'darwin':
            subprocess.Popen(['open', url])
        else:
            subprocess.Popen(['xdg-open', url], env=system_env(),
                             stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
        return {"success": True}
    except Exception as e:
        log.error("Failed to open external URL", url=url, error=str(e))
        try:
            webbrowser.open(url)
            return {"success": True}
        except Exception as fallback_error:
            log.error("Fallback browser open also failed", error=str(fallback_error))
            return {"success": False, "error": str(e)}


@server.method()
async def set_popup_enabled(enabled: bool):
    """Enable or disable the popup (used during onboarding)."""
    controller = get_controller()
    controller.set_popup_enabled(enabled)
    return {"success": True}


@server.method()
async def reset_all_data():
    """Reset all user data and return to onboarding state."""
    controller = get_controller()
    controller.reset_all_data()
    # Trigger callback to hide popup and show main window
    if _on_data_reset:
        _on_data_reset()
    return {"success": True}

# Window Management Callbacks
_window_actions = {
    "minimize": None,
    "maximize": None,
    "close": None
}

def register_window_actions(minimize_cb, maximize_cb, close_cb):
    _window_actions["minimize"] = minimize_cb
    _window_actions["maximize"] = maximize_cb
    _window_actions["close"] = close_cb

@server.method()
async def window_minimize():
    if _window_actions["minimize"]:
        _window_actions["minimize"]()
    return {"success": True}

@server.method()
async def window_toggle_maximize():
    if _window_actions["maximize"]:
        _window_actions["maximize"]()
    return {"success": True}

@server.method()
async def window_close():
    if _window_actions["close"]:
        _window_actions["close"]()
    return {"success": True}


# Model Management RPC Methods

@server.method()
async def get_model_info(model_name: str):
    """Get information about a model including cache status."""
    manager = get_model_manager()
    info = manager.get_model_info(model_name)
    return {
        "name": info.name,
        "sizeBytes": info.size_bytes,
        "cached": info.cached,
        "repoId": info.repo_id
    }


@server.method()
async def get_model_cache_dir():
    """Return the resolved model cache directory path."""
    manager = get_model_manager()
    return {"path": manager.get_cache_dir()}


@server.method()
async def open_model_cache_dir():
    """Open the model cache directory in the system file manager."""
    import sys
    import subprocess
    from pathlib import Path

    manager = get_model_manager()
    path = manager.get_cache_dir()
    Path(path).mkdir(parents=True, exist_ok=True)
    log.info("Opening model cache folder", path=path)
    try:
        if sys.platform == 'win32':
            import os
            os.startfile(path)
        elif sys.platform == 'darwin':
            subprocess.Popen(['open', path])
        else:
            subprocess.Popen(['xdg-open', path])
        return {"success": True, "path": path}
    except Exception as e:
        log.error("Failed to open model cache folder", error=str(e))
        return {"success": False, "error": str(e), "path": path}


@server.method()
async def start_model_download(model_name: str):
    """Start downloading a model in the background.

    Progress updates are sent via 'download-progress' event.
    Completion is signaled via 'download-complete' event.
    """
    return get_model_manager().start_download(model_name, _emit_download_event)


@server.method()
async def cancel_model_download():
    """Cancel the current model download if any."""
    return get_model_manager().cancel_download()


@server.method()
async def get_download_status():
    """Snapshot of the active model download, if any.

    Lets a remounted UI re-attach to an in-flight download instead of
    losing it when the settings page unmounts.
    """
    return get_model_manager().get_download_status()


@server.method()
async def clear_model_cache():
    """Clear all cached Whisper models from the HuggingFace cache directory."""
    manager = get_model_manager()
    result = manager.clear_cache()
    return result


@server.method()
async def delete_model(model_name: str):
    """Delete a single cached Whisper model from the cache directory."""
    manager = get_model_manager()
    return manager.delete_model(model_name)


# ═══════════════════════════════════════════════════════════════════════════════
# Meetings feature — recordings + LLM config
# Thin wrappers over AppController.meetings (MeetingsController).
# ═══════════════════════════════════════════════════════════════════════════════


@server.method()
async def recordings_list_audio_sources():
    return get_controller().meetings.list_audio_sources()


@server.method()
async def recordings_start(
    *,
    title: str = "",
    mic_device_id: Optional[int] = None,
    loopback_device_id: Optional[int] = None,
):
    return get_controller().meetings.start(
        title=title or "",
        mic_device_id=mic_device_id,
        loopback_device_id=loopback_device_id,
    )


@server.method()
async def recordings_pause():
    return get_controller().meetings.pause()


@server.method()
async def recordings_resume():
    return get_controller().meetings.resume()


@server.method()
async def recordings_stop():
    return get_controller().meetings.stop()


@server.method()
async def recordings_get_recorder_state():
    return get_controller().meetings.get_recorder_state()


@server.method()
async def recordings_preview_start(
    *,
    mic_device_id: Optional[int] = None,
    loopback_device_id: Optional[int] = None,
):
    return get_controller().meetings.preview_start(mic_device_id, loopback_device_id)


@server.method()
async def recordings_preview_stop():
    return get_controller().meetings.preview_stop()


@server.method()
async def recordings_preview_state():
    return get_controller().meetings.preview_state()


@server.method()
async def recordings_list(*, limit: int = 100, offset: int = 0, search: Optional[str] = None):
    return get_controller().meetings.list_recordings(limit=limit, offset=offset, search=search)


@server.method()
async def recordings_get(*, id: int):
    rec = get_controller().meetings.get_recording(id)
    if rec is None:
        raise ValueError(f"recording {id} not found")
    return rec


@server.method()
async def recordings_update(*, id: int, fields: dict):
    return get_controller().meetings.update_recording(id, fields or {})


@server.method()
async def recordings_delete(*, id: int):
    return get_controller().meetings.delete_recording(id)


@server.method()
async def recordings_import_file(*, file_path: str, title: Optional[str] = None):
    return get_controller().meetings.import_file(file_path, title)


@server.method()
async def recordings_export(*, id: int, format: str):
    return get_controller().meetings.export(id, format)


@server.method()
async def recordings_transcribe(*, id: int):
    return get_controller().meetings.transcribe(id)


@server.method()
async def recordings_retranscribe(
    *,
    id: int,
    model: Optional[str] = None,
    device: Optional[str] = None,
    language: Optional[str] = None,
):
    """Re-run transcription on an existing recording with optional overrides.

    Reuses the same transcribe queue as `recordings_transcribe` — the only
    difference is the model/device/language overrides applied for this single
    job. Audio file is unchanged. Existing transcript + segments are replaced
    on success. Cancellation goes through `recordings_cancel_transcribe`.
    """
    return get_controller().meetings.transcribe(
        id, model=model, device=device, language=language,
    )


@server.method()
async def recordings_cancel_transcribe(*, id: int):
    return get_controller().meetings.cancel_transcribe(id)


@server.method()
async def recordings_list_cached_models():
    """Return all supported whisper models with their cache status, so the
    Re-transcribe modal can offer only models that won't trigger a download.
    """
    manager = get_model_manager()
    names = manager.get_available_models()
    return [
        {"name": name, "cached": manager.is_model_cached(name)}
        for name in names
    ]


@server.method()
async def recordings_summarize(*, id: int, prompt: Optional[str] = None):
    return get_controller().meetings.summarize(id, prompt)


@server.method()
async def recordings_cancel_summarize(*, id: int):
    return get_controller().meetings.cancel_summarize(id)


@server.method()
async def llm_get_config():
    return get_controller().meetings.get_llm_config()


@server.method()
async def llm_set_config(
    *,
    preset: Optional[str] = None,
    endpoint: Optional[str] = None,
    model: Optional[str] = None,
    apiKey: Optional[str] = None,
    promptTemplate: Optional[str] = None,
    hasApiKey: Optional[bool] = None,  # accepted but ignored - boolean view only
):
    return get_controller().meetings.set_llm_config(
        preset=preset,
        endpoint=endpoint,
        model=model,
        apiKey=apiKey,
        promptTemplate=promptTemplate,
    )


@server.method()
async def llm_test_connection(*, preset: str, endpoint: str, apiKey: Optional[str] = None):
    return get_controller().meetings.test_llm_connection(preset, endpoint, apiKey)


@server.method()
async def llm_list_models(*, preset: str, endpoint: str, apiKey: Optional[str] = None):
    return get_controller().meetings.list_llm_models(preset, endpoint, apiKey)
