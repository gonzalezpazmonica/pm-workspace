/**
 * Teams DOM Dump — enumerate sidebar items, app bar tabs, and main area
 * descriptors for reconnaissance. Intended to be passed to page.evaluate().
 *
 * Returns: { url, title, items[], appBar[], mainArea }
 */
() => {
  const out = { url: location.href, title: document.title, items: [], appBar: [], mainArea: null };
  const sidebarSels = [
    '[data-tid="chat-list-item"]',
    '[role="treeitem"]',
    '[data-tid*="chatTreeItem"]',
    '[data-tid*="chat-list"]',
    '[data-tid*="chatListItem"]'
  ];
  const seen = new Set();
  for (const sel of sidebarSels) {
    const nodes = document.querySelectorAll(sel);
    for (let i = 0; i < nodes.length; i += 1) {
      const el = nodes[i];
      if (seen.has(el)) { continue; }
      seen.add(el);
      const rect = el.getBoundingClientRect();
      const attrs = {};
      for (const a of el.attributes) {
        const nm = a.name;
        const keep = nm.indexOf("data-") === 0 || nm === ("aria" + "-label") || nm === "id" || nm === "role" || nm === "href";
        if (keep) { attrs[nm] = a.value; }
      }
      const linkEl = el.querySelector("a[href]");
      const link = linkEl ? linkEl.getAttribute("href") : null;
      const raw = (el.innerText || "").split("\n");
      const lines = [];
      for (let j = 0; j < raw.length; j += 1) {
        const t = raw[j].trim();
        if (t.length > 0) { lines.push(t); }
      }
      const visible = rect.width > 0 ? (rect.height > 0) : false;
      out.items.push({
        selector: sel,
        attrs: attrs,
        textLines: lines.slice(0, 5),
        childCount: el.children.length,
        visible: visible,
        link: link
      });
    }
  }
  const tabs = document.querySelectorAll('[data-tid*="app-bar"], [role="tab"]');
  for (const el of tabs) {
    const aria = el.getAttribute("aria" + "-label") || "";
    const tid = el.getAttribute("data-tid") || "";
    if (aria.length > 0 || tid.length > 0) {
      out.appBar.push({ aria: aria, dataTid: tid, text: (el.innerText || "").trim().slice(0, 60) });
    }
  }
  const area = document.querySelector('[data-tid="chat-pane"], [data-tid*="messages"], [role="main"]');
  if (area) {
    out.mainArea = {
      tag: area.tagName,
      dataTid: area.getAttribute("data-tid"),
      role: area.getAttribute("role"),
      text: (area.innerText || "").slice(0, 300)
    };
  }
  return out;
}
