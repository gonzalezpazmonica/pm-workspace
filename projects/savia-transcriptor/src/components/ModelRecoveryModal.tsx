import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { ModelDownloadProgress } from "./ModelDownloadProgress";
import { AlertTriangle } from "lucide-react";

interface ModelRecoveryModalProps {
  open: boolean;
  modelName: string;
  onComplete: () => void;
}

export function ModelRecoveryModal({
  open,
  modelName,
  onComplete,
}: ModelRecoveryModalProps) {
  const handleComplete = (success: boolean) => {
    if (success) {
      onComplete();
    }
    // If not successful, the ModelDownloadProgress will show retry UI
  };

  return (
    <Dialog open={open}>
      <DialogContent
        className="sm:max-w-md glass-strong rounded-2xl border-border/50"
        onPointerDownOutside={(e) => e.preventDefault()}
        onEscapeKeyDown={(e) => e.preventDefault()}
        showCloseButton={false}
      >
        <DialogHeader className="space-y-3">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center">
              <AlertTriangle className="w-5 h-5 text-amber-500" />
            </div>
            <div>
              <DialogTitle className="text-lg">Model Not Found</DialogTitle>
              <DialogDescription className="text-sm">
                The AI model needs to be downloaded
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>
        <div className="flex items-center justify-center py-4">
          <ModelDownloadProgress
            modelName={modelName}
            onComplete={handleComplete}
            autoStart={true}
          />
        </div>
      </DialogContent>
    </Dialog>
  );
}
