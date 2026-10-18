// Every setting the server reads from the environment, with defaults. See .env.example.
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { randomBytes } from 'node:crypto';

// 0.0.0.0 so the phone on the shop Wi-Fi can reach this laptop.
export const HOST = process.env.HOST || '0.0.0.0';
export const PORT = Number(process.env.PORT) || 3000;

const ROOT = fileURLToPath(new URL('../', import.meta.url));
export const DATA_DIR = resolve(ROOT, process.env.DATA_DIR || 'data');
export const FILES_DIR = resolve(DATA_DIR, 'files');

// The app sends this in the X-Shop-Token header. If it is not set, make one for this run
// (server.js prints it at start).
export const TOKEN_FROM_ENV = Boolean(process.env.SHOP_TOKEN);
export const SHOP_TOKEN = process.env.SHOP_TOKEN || randomBytes(12).toString('hex');

export const SHOP_NAME = process.env.SHOP_NAME || 'बिजली मरम्मत दुकान';
export const SHOP_PHONE = process.env.SHOP_PHONE || '';
export const UPI_ID = process.env.UPI_ID || '';
// Payee name shown in the customer's UPI app.
export const UPI_NAME = process.env.UPI_NAME || SHOP_NAME;

// 127.0.0.1, not localhost: Node 22 tries IPv6 ::1 first, and Ollama listens on IPv4 only.
export const OLLAMA_URL = process.env.OLLAMA_URL || 'http://127.0.0.1:11434';
export const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'gemma4:e4b';
// Reads the rating plate photo. Needs a model that accepts images.
export const VISION_MODEL = process.env.VISION_MODEL || OLLAMA_MODEL;
export const OLLAMA_KEEP_ALIVE = process.env.OLLAMA_KEEP_ALIVE || '30m';

// whisper.cpp whisper-server (POST /inference).
export const WHISPER_URL = (process.env.WHISPER_URL || 'http://127.0.0.1:8178').replace(/\/+$/, '');
export const WHISPER_LANGUAGE = process.env.WHISPER_LANGUAGE || 'hi';

export const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY || '';
// Default: George, a premade multilingual voice. The shop should use an Indian-accent female
// Hindi voice from the ElevenLabs library; the voice note text avoids first-person verbs.
export const ELEVENLABS_VOICE_ID = process.env.ELEVENLABS_VOICE_ID || 'JBFqnCBsd6RMkjVDRZzb';
export const ELEVENLABS_MODEL = process.env.ELEVENLABS_MODEL || 'eleven_multilingual_v2';

// The shop runs on India time whatever the laptop clock says.
export const TIMEZONE = 'Asia/Kolkata';
