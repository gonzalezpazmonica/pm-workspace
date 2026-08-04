"""Hyprland compositor integration for the popup overlay.

On Wayland, Qt clients cannot position their own toplevels — `set_position()`
is a silent no-op. The compositor is the only authority on window placement,
so when running under Hyprland we (a) install windowrulev2 rules that float /
pin / place the popup, and (b) move/resize it at runtime via `hyprctl
dispatch`.

All hyprctl subprocesses run with a scrubbed env (services.process_env.
system_env) — the AppImage's bundled libstdc++ otherwise shadows the system
one and hyprctl fails with `GLIBCXX_3.4.32 not found`.

TODO(wayland-other-compositors): KDE and GNOME need wlr-layer-shell or
equivalent to dock a window — there's no portable Wayland positioning API.
Only Hyprland is handled here for now (the rest of the userbase is
X11/win/mac).

This module is import-light on purpose: `setup_popup_window_rules()` runs in
main.py's early-boot block before Qt/env configuration, so heavyweight
imports (logger, subprocess) stay inside the functions.
"""

import os


def is_hyprland() -> bool:
    return bool(os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'))


def setup_popup_window_rules() -> None:
    """Install Hyprland window rules for the popup overlay. Safe no-op when
    not under Hyprland or when hyprctl is unavailable.

    Rules use `windowrulev2` with the matcher syntax `title:^(Recording)$`.
    The previous `windowrule "...,match:title Recording"` form was silently
    rejected by hyprctl (no `match:` keyword exists), which is why the popup
    spawned in the middle of the screen on production builds even though the
    Python coordinate math was correct.

    Runs pre-logging — warnings go to stdout via print().
    """
    if not is_hyprland():
        return
    import subprocess
    from services.process_env import system_env
    # `move 50%-w/2 100%-h-100` puts the popup horizontally centered and
    # 100 px above the bottom of the active monitor (matches the original
    # Python intent: popup_y = _screen_y + _screen_height - 100).
    rules = [
        "float,title:^(Recording)$",
        "pin,title:^(Recording)$",
        "noinitialfocus,title:^(Recording)$",
        "nofocus,title:^(Recording)$",
        "noborder,title:^(Recording)$",
        "noshadow,title:^(Recording)$",
        "noblur,title:^(Recording)$",
        "rounding 0,title:^(Recording)$",
        "opacity 1.0 override 1.0 override,title:^(Recording)$",
        "move onscreen 50%-w/2 100%-h-100,title:^(Recording)$",
    ]
    env = system_env()
    for rule in rules:
        try:
            result = subprocess.run(
                ['hyprctl', 'keyword', 'windowrulev2', rule],
                capture_output=True, timeout=2, text=True, env=env,
            )
            if result.returncode != 0:
                print(f"[WARN] hyprctl rejected rule {rule!r}: {result.stderr.strip() or result.stdout.strip()}",
                      flush=True)
        except (FileNotFoundError, subprocess.TimeoutExpired):
            break


def dispatch(*args: str) -> None:
    """Run `hyprctl dispatch ...`; no-op if not on Hyprland or hyprctl missing.

    Used at runtime to move/resize the floating popup whenever it changes
    state (idle ↔ active).
    """
    if not is_hyprland():
        return
    import subprocess
    from services.logger import get_logger
    from services.process_env import system_env
    log = get_logger("window")
    try:
        result = subprocess.run(
            ['hyprctl', 'dispatch', *args],
            capture_output=True, timeout=2, text=True, env=system_env(),
        )
        if result.returncode != 0:
            log.warning("hyprctl dispatch failed",
                        args=list(args),
                        stderr=(result.stderr or '').strip())
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        log.warning("hyprctl dispatch error", error=str(e))
