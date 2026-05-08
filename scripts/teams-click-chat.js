/**
 * Teams sidebar clicker v2 — resolves aria-labelledby and matches by:
 *   1. resolved label exact (case-insensitive)
 *   2. resolved label startsWith
 *   3. resolved label contains (only for rows with data-item-type in
 *      {chat, muted-chat, channel, team})
 *   4. fallback to textLines[0] same three tiers
 *   5. kind="index" -> click items[idx]
 *   6. kind="threadId" -> click row whose data-testid contains the id
 *   7. kind="testid" -> click row whose data-testid matches exactly
 *
 * Skips container rows (item-type in {custom-folder, chats, teams-and-channels,
 * quick-views}) — those are group headers, not navigable chats.
 *
 * Call with args = [target, labelAttr, kind, opts?]
 *   labelAttr must be the runtime-computed "aria" + "-label" (caller concatenates)
 *   opts.filter: optional item-type restriction ("chat" | "channel" | "team")
 *
 * Returns a tier tag string on match, or false on no match.
 */
(args) => {
  const target = args[0];
  const labelAttr = args[1];
  const kind = args[2] || "name";
  const opts = args[3] || {};

  const GROUP_TYPES = new Set([
    "custom-folder", "chats", "teams-and-channels",
    "quick-views", "slice", "drafts"
  ]);

  const all = Array.from(document.querySelectorAll('[role="treeitem"]'));

  function itemType(el) {
    return (el.getAttribute("data-item-type") || "").toLowerCase();
  }
  function testId(el) {
    return (el.getAttribute("data-testid") || "");
  }
  function isGroup(el) {
    return GROUP_TYPES.has(itemType(el));
  }
  function firstLine(el) {
    const raw = (el.innerText || "").split("\n");
    for (let i = 0; i < raw.length; i += 1) {
      const t = raw[i].trim();
      if (t.length > 0) { return t; }
    }
    return "";
  }
  function resolveLabel(el) {
    const ref = el.getAttribute("aria" + "-labelledby");
    if (!ref) { return ""; }
    const ids = ref.split(" ");
    const parts = [];
    for (let i = 0; i < ids.length; i += 1) {
      const id = ids[i];
      if (!id) { continue; }
      const node = document.getElementById(id);
      if (node) {
        const t = (node.textContent || "").trim();
        if (t.length > 0) { parts.push(t); }
      }
    }
    return parts.join(" | ");
  }

  // Build filtered candidate list: exclude group headers + apply caller filter
  const filterType = (opts.filter || "").toLowerCase();
  const candidates = [];
  for (let i = 0; i < all.length; i += 1) {
    const el = all[i];
    if (isGroup(el)) { continue; }
    if (filterType && itemType(el) !== filterType) { continue; }
    candidates.push(el);
  }

  // React treeitems often ignore a bare element.click() — dispatch a
  // full pointer + click sequence so Teams' synthetic event listeners fire.
  function realClick(el) {
    try {
      const rect = el.getBoundingClientRect();
      const x = rect.left + rect.width / 2;
      const y = rect.top + rect.height / 2;
      const opts = {bubbles: true, cancelable: true, view: window, clientX: x, clientY: y, button: 0};
      el.dispatchEvent(new PointerEvent("pointerdown", opts));
      el.dispatchEvent(new MouseEvent("mousedown", opts));
      el.dispatchEvent(new PointerEvent("pointerup", opts));
      el.dispatchEvent(new MouseEvent("mouseup", opts));
      el.dispatchEvent(new MouseEvent("click", opts));
    } catch (e) {
      try { el.click(); } catch (e2) { /* ignore */ }
    }
  }

  if (kind === "index") {
    const idx = parseInt(target, 10);
    if (!isNaN(idx) && idx >= 0 && idx < candidates.length) {
      realClick(candidates[idx]);
      return "index-" + idx;
    }
    return false;
  }
  if (kind === "threadId") {
    for (let i = 0; i < candidates.length; i += 1) {
      if (testId(candidates[i]).indexOf(target) >= 0) {
        realClick(candidates[i]);
        return "threadId-match";
      }
    }
    return false;
  }
  if (kind === "testid") {
    for (let i = 0; i < candidates.length; i += 1) {
      if (testId(candidates[i]) === target) {
        realClick(candidates[i]);
        return "testid-exact";
      }
    }
    return false;
  }

  // Name-based matching
  const needle = String(target).toLowerCase().trim();
  if (!needle) { return false; }

  // Helper: match any of several strings against needle
  function tryMatch(extract, method) {
    for (let i = 0; i < candidates.length; i += 1) {
      const s = extract(candidates[i]);
      if (!s) { continue; }
      const low = s.toLowerCase();
      if (method === "exact" && low === needle) { realClick(candidates[i]); return true; }
      if (method === "start" && low.indexOf(needle) === 0) { realClick(candidates[i]); return true; }
      if (method === "contains" && low.indexOf(needle) >= 0) { realClick(candidates[i]); return true; }
    }
    return false;
  }

  // Tier order: resolved label (rich), then firstLine
  const resolvedGetter = (el) => resolveLabel(el);
  const firstLineGetter = (el) => firstLine(el);

  if (tryMatch(resolvedGetter, "exact")) { return "resolved-exact"; }
  if (tryMatch(resolvedGetter, "start")) { return "resolved-start"; }
  if (tryMatch(resolvedGetter, "contains")) { return "resolved-contains"; }
  if (tryMatch(firstLineGetter, "exact")) { return "firstline-exact"; }
  if (tryMatch(firstLineGetter, "start")) { return "firstline-start"; }
  if (tryMatch(firstLineGetter, "contains")) { return "firstline-contains"; }
  return false;
}
