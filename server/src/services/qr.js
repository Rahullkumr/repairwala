// The UPI payment link and its QR code, so the customer can scan and pay the exact amount.
import QRCode from 'qrcode';
import { UPI_ID, UPI_NAME } from '../config.js';

export const upiReady = Boolean(UPI_ID);

export function upiLink(jobId, amount) {
  const params = [
    ['pa', UPI_ID],
    ['pn', UPI_NAME],
    ['am', `${amount}.00`],
    ['cu', 'INR'],
    ['tn', `Job ${jobId}`],
  ];
  return `upi://pay?${params.map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&')}`;
}

// PNG bytes for the link.
export function qrPng(link) {
  return QRCode.toBuffer(link, { type: 'png', width: 600, margin: 2 });
}
