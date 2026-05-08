/**
 * Teams Chat Extractor — Playwright evaluate function
 * Extracts structured messages from Teams web client.
 * Usage: paste into browser_evaluate or load via browser_run_code
 *
 * Returns: { chatTitle, participants, messages[], totalMessages }
 * Each message: { time, author, content }
 */
() => {
  const timeEls = document.querySelectorAll('time');
  const structured = [];

  for (const timeEl of timeEls) {
    const timeText = timeEl.textContent.trim();
    if (!timeText) continue;

    // Navigate up to message container
    let container = timeEl.closest('[class*="message"]') || timeEl.parentElement?.parentElement;
    if (!container) continue;

    // Extract author from sibling of time element
    const parentGroup = timeEl.parentElement;
    let author = '';
    if (parentGroup) {
      for (const child of parentGroup.children) {
        if (child !== timeEl && child.textContent.trim().length > 2 &&
            child.textContent.trim().length < 60 && !child.querySelector('time')) {
          author = child.textContent.trim();
          break;
        }
      }
    }

    // Extract message content from paragraphs
    let content = '';
    const grandparent = container.parentElement;
    if (grandparent) {
      const ps = grandparent.querySelectorAll('p');
      if (ps.length > 0) {
        content = Array.from(ps).map(p => p.textContent.trim()).filter(t => t).join('\n');
      }
    }

    if (timeText && (author || content)) {
      structured.push({ time: timeText, author, content: content.substring(0, 1000) });
    }
  }

  // Deduplicate by time+author (Teams renders some messages twice in quotes)
  const seen = new Set();
  const deduped = structured.filter(m => {
    const key = `${m.time}|${m.author}|${m.content.substring(0, 50)}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return m.content.length > 0;
  });

  // Get chat title and participant count
  const title = document.title.replace(/^\(\d+\)\s*/, '').replace(' | Microsoft Teams', '').trim();
  const partButton = document.querySelector('[class*="participant"], button[aria-label*="participantes"]');
  const participants = partButton ? partButton.textContent.trim() : '';

  return {
    chatTitle: title,
    participants,
    messages: deduped,
    totalMessages: deduped.length
  };
}
