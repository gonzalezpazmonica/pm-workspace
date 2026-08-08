import { useEffect, useState } from "react";
import { Mic } from "lucide-react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { AudioVisualizer } from "@/components/AudioVisualizer";
import { api } from "@/lib/api";
import { useBackendEvent } from "@/hooks/useBackendEvent";
import { cn } from "@/lib/utils";
import type { Options } from "@/lib/types";

// ============================================================================
// STEP: AUDIO
// ============================================================================

export const StepAudio = ({
  microphone,
  setMicrophone,
  options,
}: {
  microphone: number;
  setMicrophone: (id: number) => void;
  options: Options;
}) => {
  const [amplitude, setAmplitude] = useState(0);
  const [isListening, setIsListening] = useState(false);

  useBackendEvent<number>("amplitude", setAmplitude);

  useEffect(() => {
    let mounted = true;
    const startRecording = async () => {
      try {
        await api.updateSettings({ microphone });
        await api.startTestRecording();
        if (mounted) setIsListening(true);
      } catch (error) {
        console.error("[Audio] Failed to start test recording:", error);
      }
    };
    const timer = setTimeout(startRecording, 100);
    return () => {
      mounted = false;
      clearTimeout(timer);
      api.stopTestRecording().catch(() => {});
      setIsListening(false);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleDeviceChange = async (backendDeviceId: string) => {
    const backendId = Number(backendDeviceId);
    setIsListening(false);
    try {
      await api.stopTestRecording();
    } catch {
      // ignore
    }
    try {
      await api.updateSettings({ microphone: backendId });
      await api.startTestRecording();
      setMicrophone(backendId);
      setIsListening(true);
    } catch (error) {
      setIsListening(false);
      console.error("[Audio] Failed to restart recording:", error);
    }
  };

  return (
    <div className="space-y-5 max-w-xl w-full">
      <div>
        <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60 mb-2">
          input device
        </p>
        <Select value={String(microphone)} onValueChange={handleDeviceChange}>
          <SelectTrigger className="h-12 text-sm bg-secondary/40 border-border hover:bg-secondary/60 transition-colors rounded-md">
            <div className="flex items-center gap-2">
              <Mic className="w-4 h-4 text-cream-muted/70" strokeWidth={2} />
              <SelectValue placeholder="Select a microphone" />
            </div>
          </SelectTrigger>
          <SelectContent>
            {options.microphones.map((mic) => (
              <SelectItem key={mic.id} value={String(mic.id)}>
                {mic.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div>
        <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60 mb-2 flex items-center justify-between">
          <span>level meter</span>
          <span
            className={cn(
              "flex items-center gap-1.5 normal-case tracking-normal text-[11px]",
              isListening ? "text-accent-500" : "text-cream-muted/40"
            )}
          >
            <span
              className={cn(
                "w-1.5 h-1.5 rounded-full",
                isListening ? "bg-accent-500" : "bg-cream-muted/30"
              )}
            />
            {isListening ? "listening" : "idle"}
          </span>
        </p>
        <div className="h-24 w-full border border-border rounded-md bg-surface flex items-center justify-center px-4">
          {isListening ? (
            <AudioVisualizer
              amplitude={amplitude}
              bars={40}
              className="gap-1 h-14 text-accent-500"
            />
          ) : (
            <span className="font-mono text-xs text-cream-muted/60">
              waiting for microphone…
            </span>
          )}
        </div>
      </div>

      <p className="text-sm text-cream-muted leading-relaxed">
        Speak now to test your input levels — the meter should respond to your
        voice.
      </p>
    </div>
  );
};
