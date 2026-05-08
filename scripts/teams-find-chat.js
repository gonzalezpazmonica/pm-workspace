/**
 * Teams chat finder — returns the candidate index in the filtered list
 * (same filtering as teams-click-chat) so Python can click it natively.
 *
 * args = [target, labelAttr, kind, opts]
 * returns: integer index in candidates list, or -1 if not found
 */
(args) => {
  const target = args[0];
  const labelAttr = args[1];
  const kind = args[2] || "name";
  const opts = args[3] || {};
  const GROUP = new Set([
    "custom-folder", "chats", "teams-and-channels",
    "quick-views", "slice", "drafts"
  ]);
  const all = Array.from(document.querySelectorAll('[role="treeitem"]'));
  function itemType(el) { return (el.getAttribute("data-item-type") || "").toLowerCase(); }
  function testId(el) { return (el.getAttribute("data-testid") || ""); }
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
  const filterType = (opts.filter || "").toLowerCase();
  const candidates = [];
  for (let i = 0; i < all.length; i += 1) {
    const el = all[i];
    if (GROUP.has(itemType(el))) { continue; }
    if (filterType && itemType(el) !== filterType) { continue; }
    candidates.push(el);
  }
  if (kind === "index") {
    const idx = parseInt(target, 10);
    if (!isNaN(idx)) {
      if (idx >= 0) {
        if (idx < candidates.length) { return idx; }
      }
    }
    return -1;
  }
  if (kind === "threadId") {
    for (let i = 0; i < candidates.length; i += 1) {
      if (testId(candidates[i]).indexOf(target) >= 0) { return i; }
    }
    return -1;
  }
  if (kind === "testid") {
    for (let i = 0; i < candidates.length; i += 1) {
      if (testId(candidates[i]) === target) { return i; }
    }
    return -1;
  }
  const needle = String(target).toLowerCase().trim();
  if (!needle) { return -1; }
  function tryFind(extract, method) {
    for (let i = 0; i < candidates.length; i += 1) {
      const s = extract(candidates[i]);
      if (!s) { continue; }
      const low = s.toLowerCase();
      if (method === "exact") { if (low === needle) { return i; } }
      if (method === "start") { if (low.indexOf(needle) === 0) { return i; } }
      if (method === "contains") { if (low.indexOf(needle) >= 0) { return i; } }
    }
    return -1;
  }
  let found = tryFind(resolveLabel, "exact"); if (found >= 0) { return found; }
  found = tryFind(resolveLabel, "start"); if (found >= 0) { return found; }
  found = tryFind(resolveLabel, "contains"); if (found >= 0) { return found; }
  found = tryFind(firstLine, "exact"); if (found >= 0) { return found; }
  found = tryFind(firstLine, "start"); if (found >= 0) { return found; }
  found = tryFind(firstLine, "contains"); if (found >= 0) { return found; }
  return -1;
}
