import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import type { AudioMeta } from "@/hooks/useHistoryEntries";

export interface AudioPlayerDialogProps {
  open: boolean;
  audioUrl: string | null;
  audioMeta: AudioMeta | null;
  durationMs?: number;
  onOpenChange: (open: boolean) => void;
}

export function AudioPlayerDialog({
  open,
  audioUrl,
  audioMeta,
  durationMs,
  onOpenChange,
}: AudioPlayerDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader className="space-y-2">
          <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
            audio
          </p>
          <DialogTitle className="text-xl font-semibold tracking-tight text-cream truncate">
            {audioMeta?.fileName || "Grabación"}
          </DialogTitle>
          <DialogDescription className="text-xs text-cream-muted">
            {durationMs
              ? `${Math.round(durationMs / 1000)}s · ${audioMeta?.mime || "audio/wav"}`
              : "Reproducción del audio grabado"}
          </DialogDescription>
        </DialogHeader>
        {audioUrl ? (
          // biome-ignore lint/a11y/useMediaCaption: transcript text is shown in the log
          <audio controls autoPlay className="w-full">
            <source src={audioUrl} type={audioMeta?.mime || "audio/wav"} />
            Tu navegador no soporta reproducción de audio.
          </audio>
        ) : (
          <p className="text-sm text-cream-muted">No hay audio cargado.</p>
        )}
      </DialogContent>
    </Dialog>
  );
}
