// The customer message when a machine is ready: a WhatsApp text and a shorter spoken version.
// Built from templates in code, not by the model, so the amount and UPI ID are always exact.
import { SHOP_NAME, SHOP_PHONE, UPI_ID } from '../config.js';
import { APPLIANCES } from './appliances.js';
import { hindiNumber } from './hindi-numbers.js';

const applianceLabel = (key) => APPLIANCES[key] || APPLIANCES.other;

// "9876543210" -> "919876543210", or null if there is no 10-digit phone.
export function waPhone(phone) {
  return phone && /^\d{10}$/.test(phone) ? `91${phone}` : null;
}

// `hasQr` says whether the QR photo will go with the message.
export function buildText(job, amount, hasQr) {
  const name = job.customer?.name;
  const brand = job.brand ? ` (${job.brand})` : '';
  const lines = [
    name ? `नमस्ते ${name} जी 🙏` : 'नमस्ते जी 🙏',
    `आपका ${applianceLabel(job.appliance)}${brand} ठीक हो गया है।`,
  ];
  if (job.work_done) lines.push(`काम: ${job.work_done}`);
  if (amount) lines.push(`कुल: ₹${amount}`);
  lines.push('जब चाहें दुकान से ले जाएं।');
  if (UPI_ID) lines.push(`UPI से भुगतान: ${UPI_ID}${hasQr ? ' (QR फ़ोटो साथ में है)' : ''}`);
  lines.push(`— ${SHOP_NAME}${SHOP_PHONE ? `, ${SHOP_PHONE}` : ''}`);
  lines.push(`जॉब नंबर #${job.id}`);
  return lines.join('\n');
}

// Short and gender-neutral: the voice is a woman's, the shopkeeper a man, so no "I" verbs.
export function buildSpeech(job, amount) {
  const name = job.customer?.name;
  const parts = [
    name ? `नमस्ते ${name} जी।` : 'नमस्ते जी।',
    `यह संदेश ${SHOP_NAME} की तरफ़ से है।`,
    `आपका ${applianceLabel(job.appliance)} ठीक हो गया है।`,
  ];
  if (amount) {
    const words = amount <= 99999999 ? hindiNumber(amount) : String(amount);
    parts.push(`कुल ${words} रुपये हुए हैं।`);
  }
  parts.push('आप जब चाहें दुकान से ले जा सकते हैं।', 'धन्यवाद।');
  return parts.join(' ');
}
