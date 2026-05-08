/**
 * Teams sidebar enumerator — expand folders, dump items with identifiers.
 *
 * Output item schema:
 *   { idx, level, itemType, testid, treeValue, resolvedLabel, textLines, hasNotificationHint }
 *
 * itemType values seen in Teams v2:
 *   "quick-views" | "custom-folder" | "chats" | "teams-and-channels"
 *   "team" | "channel" | "chat" | "muted-chat" | "slice"
 *
 * Pass args = [ {doExpand: true|false} ] to control side effects.
 */
(args) => {
  const cfg = (args && args[0]) ? args[0] : {};
  const doExpand = cfg.doExpand !== false;

  if (doExpand) {
    // Only expand folders that are currently collapsed so we do not toggle
    // open folders closed on repeat calls.
    const folders = document.querySelectorAll('[data-conversation-folder="true"]');
    for (let i = 0; i < folders.length; i += 1) {
      const f = folders[i];
      const expanded = f.getAttribute("aria-expanded");
      if (expanded === "false" || expanded === null) {
        try { f.click(); } catch (e) { /* ignore */ }
      }
    }
  }

  const items = [];
  const nodes = document.querySelectorAll('[role="treeitem"]');
  for (let i = 0; i < nodes.length; i += 1) {
    const el = nodes[i];
    const attrs = {};
    for (const a of el.attributes) { attrs[a.name] = a.value; }

    const raw = (el.innerText || "").split("\n");
    const lines = [];
    for (let j = 0; j < raw.length; j += 1) {
      const t = raw[j].trim();
      if (t.length > 0) { lines.push(t); }
    }

    const lblAttr = "aria" + "-labelledby";
    let resolved = "";
    const ref = el.getAttribute(lblAttr);
    if (ref) {
      const ids = ref.split(" ");
      const parts = [];
      for (let k = 0; k < ids.length; k += 1) {
        const id = ids[k];
        if (!id) { continue; }
        const node = document.getElementById(id);
        if (node) {
          const txt = (node.textContent || "").trim();
          if (txt.length > 0) { parts.push(txt); }
        }
      }
      resolved = parts.join(" | ");
    }

    const testid = attrs["data-testid"] || "";
    let threadId = null;
    const m = testid.match(/sc-channel-list-item-(19:[^@]+(@thread\.[a-z0-9]+)?)/i);
    if (m) { threadId = m[1]; }

    items.push({
      idx: i,
      level: attrs["aria-level"] || "",
      itemType: attrs["data-item-type"] || "",
      testid: testid,
      treeValue: attrs["data-fui-tree-item-value"] || "",
      resolvedLabel: resolved,
      textLines: lines.slice(0, 5),
      threadId: threadId
    });
  }

  return {
    url: location.href,
    title: document.title,
    expandedFolders: doExpand,
    items: items
  };
}
