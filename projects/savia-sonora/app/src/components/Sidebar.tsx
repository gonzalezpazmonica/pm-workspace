import { useEffect, useState } from "react";
import { NavLink } from "react-router-dom";
import {
  Home,
  History,
  Radio,
  Settings,
  Github,
  MessageSquare,
} from "lucide-react";
import { cn, formatHotkeyForDisplay } from "@/lib/utils";
import { api } from "@/lib/api";
import { t } from "@/lib/i18n";
import { APP_VERSION } from "@/lib/constants";

const REPO_URL = "https://github.com/gonzalezpazmonica/pm-workspace";
const FALLBACK_HOTKEY = "ctrl+win";

const navItems = [
  { to: "/dashboard", icon: Home, label: t("nav.home") },
  { to: "/dashboard/history", icon: History, label: t("nav.history") },
  { to: "/dashboard/meetings", icon: Radio, label: t("nav.meetings") },
  { to: "/dashboard/settings", icon: Settings, label: t("nav.settings") },
];

interface SidebarProps {
  onNavigate?: () => void;
}

export function Sidebar({ onNavigate }: SidebarProps) {
  const [hotkeyDisplay, setHotkeyDisplay] = useState<string>(
    formatHotkeyForDisplay(FALLBACK_HOTKEY),
  );

  useEffect(() => {
    let cancelled = false;
    api
      .getSettings()
      .then((s) => {
        if (cancelled) return;
        const active = s.holdHotkeyEnabled
          ? s.holdHotkey
          : s.toggleHotkeyEnabled
            ? s.toggleHotkey
            : s.holdHotkey;
        setHotkeyDisplay(formatHotkeyForDisplay(active || FALLBACK_HOTKEY));
      })
      .catch(() => {
        // Keep fallback display
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <aside className="sidebar-glass w-64 h-screen flex flex-col relative">
      {/* Logo Area */}
      <div className="p-6 pb-8">
        <div className="flex items-center gap-3">
          <img
            src="/savia-logo.png"
            alt="Savia Sonora"
            className="h-9 w-9 rounded-lg"
          />
          <div className="min-w-0">
            <p className="font-semibold text-cream leading-tight truncate">
              Savia Sonora
            </p>
            <p className="text-xs text-cream-muted font-mono mt-0.5">
              {t("sidebar.subtitle")}
            </p>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-3 space-y-0.5">
        <p className="font-mono text-[10px] text-cream-muted/60 uppercase tracking-[0.2em] px-3 mb-2">
          {t("nav.navigate")}
        </p>
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === "/dashboard"}
            onClick={onNavigate}
            className={({ isActive }) =>
              cn(
                "flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors",
                isActive
                  ? "bg-secondary text-cream"
                  : "text-cream-muted hover:text-cream hover:bg-secondary/60",
              )
            }
          >
            {({ isActive }) => (
              <>
                <item.icon
                  className={cn(
                    "h-4 w-4",
                    isActive ? "text-primary" : "text-cream-muted/70",
                  )}
                  strokeWidth={2}
                />
                <span className="flex-1">{item.label}</span>
              </>
            )}
          </NavLink>
        ))}
      </nav>

      {/* Footer */}
      <div className="p-3 mt-auto space-y-1">
        {/* Hotkey hint - terminal-style line */}
        <div className="px-3 py-2 text-xs text-cream-muted leading-relaxed font-mono border-l-2 border-primary/40 mb-3">
          <span className="text-cream-muted/60">{"→ "}</span>
          {t("sidebar.hotkey", { key: "" })}
          <kbd className="text-primary bg-primary/10 px-1 py-0.5 rounded text-[11px]">
            {hotkeyDisplay}
          </kbd>
        </div>

        {/* Community Links */}
        <button
          type="button"
          onClick={() => api.openExternalUrl(`${REPO_URL}/issues`)}
          className="flex items-center gap-2.5 px-3 py-2 w-full rounded-lg text-xs text-cream-muted hover:text-cream hover:bg-secondary/60 transition-colors"
        >
          <MessageSquare className="h-3.5 w-3.5" strokeWidth={2} />
          {t("sidebar.report")}
        </button>

        <button
          type="button"
          onClick={() => api.openExternalUrl(REPO_URL)}
          className="flex items-center gap-2.5 px-3 py-2 w-full rounded-lg text-xs text-cream-muted hover:text-cream hover:bg-secondary/60 transition-colors"
        >
          <Github className="h-3.5 w-3.5" strokeWidth={2} />
          {t("sidebar.github")}
        </button>

        {/* Version footer */}
        <div className="pt-3 px-3 flex items-center justify-between text-[10px] text-cream-muted/50 font-mono">
          <span className="flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-primary" />
            v{APP_VERSION}
          </span>
          <span className="flex items-center gap-1">
            <span className="w-2 h-2 rounded-full bg-primary/70" />
            {t("sidebar.opensource")}
          </span>
        </div>
      </div>
    </aside>
  );
}
