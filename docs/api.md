# Theek Ho Gaya: API contract

The Flutter app (`app/`) on the shop owner's phone talks to the server (`server/`) on the shop laptop over the shop Wi-Fi.
The server listens on `0.0.0.0:3000` by default. Every `/api/*` request must send the header `X-Shop-Token: <SHOP_TOKEN from server .env>`; a wrong or missing token gets `401 {"error":"bad token"}`.
Errors are always `{"error": "<message>"}` with a 4xx/5xx status. All JSON field names are snake_case. Dates are `YYYY-MM-DD` (shop's local date, Asia/Kolkata); timestamps are ISO 8601 strings. Money is whole rupees (integer).

## Enums

`status`: `received` (machine left at shop), `repaired` (fixed, waiting for pickup), `delivered` (customer took it), `returned` (not repairable, given back).

`appliance` (key → Hindi label the app shows):
`water_pump` पानी पंप · `submersible` सबमर्सिबल · `fan` पंखा · `ac` एसी · `cooler` कूलर · `cutter` कटर मशीन · `mixer` मिक्सी · `induction` इंडक्शन चूल्हा · `heater` हीटर · `kettle` केतली · `iron` प्रेस (आयरन) · `other` अन्य

`pay_method`: `cash`, `upi`, or null.

## Objects

Customer:
```json
{ "id": 7, "phone": "9876543210", "name": "रामेश्वर महतो", "village": "पिठोरिया", "photo_url": "/files/customers/7.jpg", "created_at": "..." }
```
`phone` is 10 digits, no +91. `photo_url` may be null. File URLs are relative to the server base URL and also need the token header.

Job:
```json
{
  "id": 42, "customer": { ...Customer },
  "kind": "intake",                      // "intake" (left at shop) or "quick" (fixed while the customer waited)
  "appliance": "submersible", "brand": "Crompton", "model": "MINI MASTER", "rating": "1 HP", "serial": "AB123",
  "complaint": "चलता नहीं है",              // what the customer said is wrong
  "diagnosis": "वाइंडिंग जल गई है",          // what the electrician found / expects
  "work_done": null,                     // filled when repaired
  "estimate": 1500, "final_amount": null,
  "pickup_date": "2026-10-21",
  "status": "received", "paid": false, "pay_method": null,
  "transcript": "...raw Whisper text...",
  "machine_photo_url": "/files/jobs/42-machine.jpg", "plate_photo_url": "/files/jobs/42-plate.jpg",
  "created_at": "...", "repaired_at": null, "delivered_at": null, "notified_at": null
}
```

## Endpoints

`GET /api/health` → `{ "ok": true, "whisper": true, "ollama": true, "tts": true, "shop_name": "...", "upi_ready": true }` (each flag says whether that service answered or is configured).

`POST /api/transcribe` (multipart, field `audio`: WAV 16 kHz mono, as recorded by the app) → `{ "text": "...", "seconds": 4.2 }`. Runs local whisper.cpp in Hindi.

`POST /api/parse-intake` JSON `{ "text": "...", "kind": "intake" | "quick" }` → the fields Gemma could find, every one nullable, nothing invented:
```json
{ "name": null, "village": null, "appliance": "fan", "complaint": "...", "diagnosis": "...", "work_done": null,
  "estimate": 350, "final_amount": null, "pickup_date": "2026-10-20", "pickup_said": "परसों", "seconds": 6.1 }
```
`pickup_date` is computed by server code from what Gemma heard (`pickup_said`), never by the model.

`POST /api/read-plate` (multipart, field `photo`: JPEG of the rating plate) → `{ "brand": null, "model": null, "rating": null, "serial": null, "seconds": 9.0 }`.

`GET /api/customers/by-phone/:phone` → `{ "customer": Customer | null, "jobs": [Job, ...newest first] }`.

`POST /api/jobs` multipart:
- field `data`: JSON string `{ "phone", "name", "village", "kind", "appliance", "brand", "model", "rating", "serial", "complaint", "diagnosis", "work_done", "estimate", "final_amount", "pickup_date", "transcript", "paid", "pay_method" }` (phone is required for `intake` and optional for `quick`; the rest are optional. The customer is found by phone or created; name/village update the customer if given. A `quick` job with no phone has `"customer": null`.)
- optional files: `machine_photo`, `plate_photo`, `customer_photo` (JPEG).
- A `quick` job is saved straight away as `delivered` (with `repaired_at` and `delivered_at` set to now).
→ `201` Job.

`GET /api/jobs?status=open|done|all&q=<text>` → `{ "jobs": [Job, ...] }`. `open` = received + repaired, sorted by pickup_date (oldest/overdue first, nulls last); `done` and `all` newest first. `q` matches phone, name, village, appliance, brand (substring). Default `status=open`.

`GET /api/jobs/:id` → Job plus `"history": [Job, ...]` (this customer's other jobs, newest first).

`PATCH /api/jobs/:id` JSON with any of `status, work_done, diagnosis, estimate, final_amount, pickup_date, paid, pay_method, appliance, brand, model, rating, serial, complaint` → Job. Setting `status` to `repaired` sets `repaired_at`; to `delivered` or `returned` sets `delivered_at`.

`POST /api/jobs/:id/notify` JSON `{ "final_amount": 1500, "work_done": "..." }` (both optional; they are saved first). Marks the job `repaired` if it was `received`, builds the customer message, and returns:
```json
{
  "text": "WhatsApp message in Hindi (with amount and UPI ID)",
  "speech": "the shorter text that was spoken in the voice note",
  "voice_url": "/files/jobs/42-ready.mp3",       // null if ElevenLabs is not configured or failed
  "qr_url": "/files/jobs/42-qr.png",             // null if UPI_ID is not set or amount is missing
  "upi_link": "upi://pay?pa=...&pn=...&am=1500.00&cu=INR&tn=...",
  "wa_phone": "919876543210"
}
```
and sets `notified_at`.

`GET /files/...` → the stored photo, MP3 or PNG (same token header).
