// Speech to text with the local whisper.cpp whisper-server.
import { WHISPER_URL, WHISPER_LANGUAGE } from '../config.js';

// True if the whisper-server answers at all.
export async function whisperUp() {
  try {
    const res = await fetch(`${WHISPER_URL}/`, { signal: AbortSignal.timeout(2000) });
    return res.status < 500;
  } catch {
    return false;
  }
}

// `wav` is a Buffer with 16 kHz mono WAV audio. Returns the trimmed text.
export async function transcribe(wav, signal) {
  const form = new FormData();
  form.append('file', new Blob([wav], { type: 'audio/wav' }), 'audio.wav');
  form.append('language', WHISPER_LANGUAGE);
  form.append('response_format', 'json');
  form.append('temperature', '0.0');
  const res = await fetch(`${WHISPER_URL}/inference`, { method: 'POST', body: form, signal });
  if (!res.ok) throw new Error(`Whisper error ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const data = await res.json();
  if (data.error) throw new Error(`Whisper error: ${data.error}`);
  return String(data.text || '').replace(/\s+/g, ' ').trim();
}
