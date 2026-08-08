/* Local helpers for the Meetings UI. Kept out of `src/lib/utils.ts` so the rest
   of the app doesn't pick them up as a global convention. */

export function formatDuration(ms: number | null | undefined): string {
  if (ms == null || !isFinite(ms) || ms < 0) return "0:00";
  const totalSec = Math.floor(ms / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  if (h > 0) return `${h}:${pad2(m)}:${pad2(s)}`;
  return `${m}:${pad2(s)}`;
}

export function formatTimestamp(ms: number): string {
  return formatDuration(ms);
}

export function formatBytes(n: number | null | undefined): string {
  if (n == null) return "—";
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(0)} KB`;
  if (n < 1024 * 1024 * 1024) return `${(n / 1024 / 1024).toFixed(1)} MB`;
  return `${(n / 1024 / 1024 / 1024).toFixed(2)} GB`;
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : String(n);
}

/** Group meetings by their `createdAt` date (`yyyy-mm-dd` key, formatted label). */
export function groupByDate<T extends { createdAt: string }>(
  items: T[],
): Array<{ key: string; label: string; entries: T[] }> {
  const map = new Map<string, T[]>();
  for (const item of items) {
    const d = new Date(item.createdAt);
    if (isNaN(d.getTime())) continue;
    const key = d.toISOString().slice(0, 10);
    const bucket = map.get(key) ?? [];
    bucket.push(item);
    map.set(key, bucket);
  }
  const today = new Date();
  const todayKey = today.toISOString().slice(0, 10);
  const yesterday = new Date(today.getTime() - 86400 * 1000);
  const yesterdayKey = yesterday.toISOString().slice(0, 10);

  return Array.from(map.entries())
    .sort(([a], [b]) => (a < b ? 1 : -1))
    .map(([key, entries]) => {
      let label: string;
      if (key === todayKey) label = "Today";
      else if (key === yesterdayKey) label = "Yesterday";
      else {
        const d = new Date(key);
        label = d.toLocaleDateString("en-US", {
          month: "long",
          day: "numeric",
          year: today.getFullYear() === d.getFullYear() ? undefined : "numeric",
        });
      }
      return { key, label, entries };
    });
}

/**
 * Pick the active segment for the current playback position. Returns the index
 * of the latest segment whose `startMs <= positionMs`. Returns -1 if no
 * segment matches yet.
 */
export function findActiveSegment(
  segments: Array<{ startMs: number; endMs: number }>,
  positionMs: number,
): number {
  let lo = 0;
  let hi = segments.length - 1;
  let result = -1;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (segments[mid].startMs <= positionMs) {
      result = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return result;
}
