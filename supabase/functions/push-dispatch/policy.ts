export function allowedEndpoint(endpoint: string): boolean {
  try {
    const url = new URL(endpoint);
    return url.protocol === 'https:' && !url.username && !url.password && !url.port &&
      (url.hostname === 'fcm.googleapis.com' || url.hostname === 'updates.push.services.mozilla.com' ||
       url.hostname === 'web.push.apple.com' || url.hostname.endsWith('.push.apple.com') ||
       url.hostname === 'wns2-pn1p.notify.windows.com' || url.hostname.endsWith('.notify.windows.com'));
  } catch { return false; }
}
export function shouldSend(prefs: Record<string, any>, type: string, category: string,
  offset: number, now = new Date()): boolean {
  const group = type === 'message' ? 'message' :
    ['like', 'comment', 'follow', 'repost', 'mention', 'reply', 'reaction'].includes(type) ? 'community' :
    type === 'trade_execution' ? 'trade' : category;
  if (prefs.push_by_category?.[group] === false) return false;
  if (!prefs.quiet_hours_enabled) return true;
  const parse = (v: string) => /^\d{2}:\d{2}$/.test(v) ? Number(v.slice(0, 2)) * 60 + Number(v.slice(3)) : NaN;
  const start = parse(prefs.quiet_hours_start ?? '22:00');
  const end = parse(prefs.quiet_hours_end ?? '07:00');
  const minute = (now.getUTCHours() * 60 + now.getUTCMinutes() + offset + 1440) % 1440;
  if (!Number.isFinite(start) || !Number.isFinite(end) || start === end) return true;
  return !(start < end ? minute >= start && minute < end : minute >= start || minute < end);
}
