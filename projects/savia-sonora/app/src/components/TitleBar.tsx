import { Minus, Square, X } from "lucide-react";
import { api } from "@/lib/api";

export function TitleBar() {
  return (
    <div className="h-10 w-full flex items-center justify-between px-4 bg-transparent absolute top-0 left-0 z-50 select-none">
      {/* Draggable Region */}
      <div 
        className="flex-1 h-full drag-region" 
        style={{ WebkitAppRegion: "drag" } as React.CSSProperties}
      />

      {/* Window Controls */}
      <div className="flex items-center gap-2 no-drag relative z-50" style={{ WebkitAppRegion: "no-drag" } as React.CSSProperties}>
        <button 
          onClick={() => api.windowMinimize()}
          className="p-1.5 rounded-full hover:bg-white/10 text-white/50 hover:text-white transition-colors"
          title="Minimize"
        >
          <Minus className="w-4 h-4" />
        </button>
        <button 
          onClick={() => api.windowToggleMaximize()}
          className="p-1.5 rounded-full hover:bg-white/10 text-white/50 hover:text-white transition-colors"
          title="Maximize"
        >
          <Square className="w-3.5 h-3.5" />
        </button>
        <button 
          onClick={() => api.windowClose()}
          className="p-1.5 rounded-full hover:bg-red-500/20 text-white/50 hover:text-red-500 transition-colors"
          title="Close (Minimize to Tray)"
        >
          <X className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
}
