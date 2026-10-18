// Dates in the shop's own time zone (Asia/Kolkata), as YYYY-MM-DD strings.
import { TIMEZONE } from '../config.js';

const WEEKDAYS = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

// Today in India as { y, m, d }, whatever time zone this computer is set to.
export function todayParts(now = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: TIMEZONE, year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(now);
  const get = (type) => Number(parts.find((p) => p.type === type).value);
  return { y: get('year'), m: get('month'), d: get('day') };
}

const pad = (n) => String(n).padStart(2, '0');
const fmt = (y, m, d) => `${y}-${pad(m)}-${pad(d)}`;

// Calendar arithmetic is done in UTC so the computer's time zone never matters.
function addDays({ y, m, d }, n) {
  const t = new Date(Date.UTC(y, m - 1, d + n));
  return { y: t.getUTCFullYear(), m: t.getUTCMonth() + 1, d: t.getUTCDate() };
}

export function todayString(now = new Date()) {
  const { y, m, d } = todayParts(now);
  return fmt(y, m, d);
}

const daysInMonth = (y, m) => new Date(Date.UTC(y, m, 0)).getUTCDate();

// Turns what the model heard ("परसों", "बुधवार को", "15 तारीख") into a date.
// Pickup is always in the future. Returns null when nothing usable was said.
export function resolvePickupDate(pickup, now = new Date()) {
  if (!pickup) return null;
  const today = todayParts(now);

  const n = pickup.days_from_today;
  if (Number.isInteger(n) && n >= 0 && n <= 365) {
    const t = addDays(today, n);
    return fmt(t.y, t.m, t.d);
  }

  const wd = WEEKDAYS.indexOf(String(pickup.weekday || '').toLowerCase());
  if (wd >= 0) {
    const todayWd = new Date(Date.UTC(today.y, today.m - 1, today.d)).getUTCDay();
    // Next occurrence strictly after today: the same weekday means a week from now.
    const ahead = ((wd - todayWd + 7) % 7) || 7;
    const t = addDays(today, ahead);
    return fmt(t.y, t.m, t.d);
  }

  const dom = pickup.day_of_month;
  if (Number.isInteger(dom) && dom >= 1 && dom <= 31) {
    let { y, m } = today;
    // This month if the day has not passed, else the next month that has such a day.
    if (dom < today.d || dom > daysInMonth(y, m)) {
      for (let i = 0; i < 3; i++) {
        m += 1;
        if (m > 12) { m = 1; y += 1; }
        if (dom <= daysInMonth(y, m)) break;
      }
    }
    if (dom > daysInMonth(y, m)) return null;
    return fmt(y, m, dom);
  }
  return null;
}
