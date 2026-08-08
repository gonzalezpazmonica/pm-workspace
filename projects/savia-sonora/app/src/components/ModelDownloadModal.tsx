import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { ModelDownloadProgress } from "./ModelDownloadProgress";

interface ModelDownloadModalProps {
  open: boolean;
  modelName: string;
  onComplete: (success: boolean) => void;
  onCancel: () => void;
}

export function ModelDownloadModal({
  open,
  modelName,
  onComplete,
  onCancel,
}: ModelDownloadModalProps) {
  return (
    <Dialog open={open} onOpenChange={(isOpen) => !isOpen && onCancel()}>
      <DialogContent
        className="sm:max-w-md"
        onPointerDownOutside={(e) => e.preventDefault()}
        onEscapeKeyDown={(e) => e.preventDefault()}
      >
        <DialogHeader className="space-y-2">
          <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
            downloading model
          </p>
          <DialogTitle className="font-display text-xl font-medium tracking-tight text-cream">
            {modelName}
          </DialogTitle>
          <DialogDescription className="text-xs text-cream-muted leading-relaxed">
            Pulling weights from Hugging Face. Cached locally — this is a one-time download.
          </DialogDescription>
        </DialogHeader>
        <ModelDownloadProgress
          modelName={modelName}
          onComplete={onComplete}
          onCancel={onCancel}
          autoStart={true}
        />
      </DialogContent>
    </Dialog>
  );
}
