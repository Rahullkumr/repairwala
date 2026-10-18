// Quick self-checks for the Hindi number words and the pickup date rules. Run: npm run check-numbers
import assert from 'node:assert/strict';
import { hindiNumber } from '../src/lib/hindi-numbers.js';
import { resolvePickupDate } from '../src/lib/dates.js';

const cases = {
  0: 'शून्य',
  35: 'पैंतीस',
  49: 'उनचास',
  99: 'निन्यानवे',
  100: 'एक सौ',
  150: 'एक सौ पचास',
  350: 'तीन सौ पचास',
  1200: 'एक हज़ार दो सौ',
  1500: 'एक हज़ार पाँच सौ',
  2000: 'दो हज़ार',
  12345: 'बारह हज़ार तीन सौ पैंतालीस',
  100000: 'एक लाख',
  250000: 'दो लाख पचास हज़ार',
  10000000: 'एक करोड़',
  99999999: 'नौ करोड़ निन्यानवे लाख निन्यानवे हज़ार नौ सौ निन्यानवे',
};
for (const [n, words] of Object.entries(cases)) assert.equal(hindiNumber(Number(n)), words, `n=${n}`);
for (let i = 0; i <= 99; i++) assert.ok(hindiNumber(i), `missing ${i}`);
assert.throws(() => hindiNumber(-1));
assert.throws(() => hindiNumber(1.5));

// 2026-10-18 is a Sunday. 20:00 UTC is already 01:30 on the 19th in India.
const sunday = new Date('2026-10-18T06:00:00Z');
assert.equal(resolvePickupDate({ days_from_today: 2 }, sunday), '2026-10-20');
assert.equal(resolvePickupDate({ days_from_today: 1 }, new Date('2026-10-18T20:00:00Z')), '2026-10-20');
assert.equal(resolvePickupDate({ weekday: 'wednesday' }, sunday), '2026-10-21');
assert.equal(resolvePickupDate({ weekday: 'sunday' }, sunday), '2026-10-25');
assert.equal(resolvePickupDate({ day_of_month: 25 }, sunday), '2026-10-25');
assert.equal(resolvePickupDate({ day_of_month: 5 }, sunday), '2026-11-05');
assert.equal(resolvePickupDate({ day_of_month: 18 }, sunday), '2026-10-18');
assert.equal(resolvePickupDate({}, sunday), null);
assert.equal(resolvePickupDate(null, sunday), null);

console.log('hindi-numbers and dates: all checks passed');
