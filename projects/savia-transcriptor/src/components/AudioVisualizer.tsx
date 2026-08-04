import { cn } from "@/lib/utils";
import { useMemo } from "react";

interface AudioVisualizerProps {
  amplitude: number; // 0-1 range
  className?: string;
  bars?: number;
}

export function AudioVisualizer({ amplitude, className, bars = 7 }: AudioVisualizerProps) {
  // Generate bar heights based on amplitude
  const barHeights = useMemo(() => {
    return Array.from({ length: bars }).map((_, i) => {
      // Calculate distance from center (0 to 1)
      const center = (bars - 1) / 2;
      const distance = Math.abs(i - center) / center;

      // Create wave pattern - center bars are taller
      const waveScale = 1 - distance * 0.6;

      // Add organic variation based on position
      const phase = (i / bars) * Math.PI * 2;
      const variation = Math.sin(phase + amplitude * 15) * 0.15;

      // Height: base (15%) + amplitude-driven height + variation
      // When amplitude is 0, bars are at minimum
      // When amplitude is 1, bars reach maximum
      const baseHeight = 15;
      const amplitudeHeight = amplitude * 70 * waveScale;
      const variationHeight = variation * amplitude * 20;

      const height = baseHeight + amplitudeHeight + variationHeight;

      return Math.min(100, Math.max(10, height));
    });
  }, [amplitude, bars]);

  return (
    <div className={cn("flex items-center justify-center gap-[3px] h-6", className)}>
      {barHeights.map((height, i) => (
        <div
          key={i}
          className="w-[3px] rounded-full transition-all duration-[50ms] ease-out"
          style={{
            height: `${height}%`,
            backgroundColor: 'currentColor',
            opacity: 0.4 + (amplitude * 0.6), // Bars get brighter with amplitude
          }}
        />
      ))}
    </div>
  );
}
