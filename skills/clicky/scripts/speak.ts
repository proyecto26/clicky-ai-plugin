import { spawn } from 'node:child_process';
import { writeFileSync, unlinkSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { assertDarwin } from './paths.ts';
import type { SpeakEngine, SpeakRequest } from './types.ts';

export interface SpeakOptions extends SpeakRequest {}

export interface SpeakResult {
  engine: SpeakEngine;
  ok: boolean;
  reason?: string;
}

export async function speak(options: SpeakOptions): Promise<SpeakResult> {
  assertDarwin();
  const text = (options.text ?? '').trim();
  if (text === '') return { engine: 'say', ok: true, reason: 'empty text, no-op' };

  const forced = options.engine;
  const order: SpeakEngine[] = forced
    ? [forced]
    : [pickAutoEngine()].concat(fallbackChain(pickAutoEngine()));

  let lastReason: string | undefined;
  for (const engine of order) {
    try {
      if (engine === 'vibevoice') {
        await speakViaVibeVoice(text);
      } else if (engine === 'elevenlabs') {
        await speakViaElevenLabs(text);
      } else {
        await speakViaSay(text, options.voice, options.rate);
      }
      return { engine, ok: true };
    } catch (err) {
      lastReason = err instanceof Error ? err.message : String(err);
      process.stderr.write(`[clicky:speak] ${engine} failed: ${lastReason}\n`);
      if (forced) return { engine, ok: false, reason: lastReason };
    }
  }
  return { engine: 'say', ok: false, reason: lastReason };
}

function pickAutoEngine(): SpeakEngine {
  if (process.env.CLICKY_VIBEVOICE_URL?.trim()) return 'vibevoice';
  if (process.env.CLICKY_ELEVENLABS_API_KEY?.trim()) return 'elevenlabs';
  return 'say';
}

function fallbackChain(primary: SpeakEngine): SpeakEngine[] {
  if (primary === 'say') return [];
  if (primary === 'vibevoice') return ['say'];
  if (primary === 'elevenlabs') return ['say'];
  return [];
}

function speakViaSay(text: string, voice?: string, rate?: number): Promise<void> {
  return new Promise((resolve, reject) => {
    const args: string[] = [];
    if (voice) args.push('-v', voice);
    if (rate && rate > 0) args.push('-r', String(Math.round(rate)));
    args.push(text);
    const child = spawn('say', args, { stdio: ['ignore', 'ignore', 'pipe'] });
    let stderr = '';
    child.stderr.on('data', (c) => (stderr += String(c)));
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`say exited ${code}: ${stderr}`));
    });
    child.on('error', reject);
  });
}

async function speakViaVibeVoice(text: string): Promise<void> {
  const base = process.env.CLICKY_VIBEVOICE_URL?.trim();
  if (!base) throw new Error('CLICKY_VIBEVOICE_URL not set');
  const url = new URL('/v1/synthesize', base).toString();

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', accept: 'audio/wav' },
    body: JSON.stringify({ text, speaker: process.env.CLICKY_VIBEVOICE_SPEAKER ?? 'Carter' }),
  });
  if (!res.ok) throw new Error(`VibeVoice HTTP ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  await playAudio(buf, 'wav');
}

async function speakViaElevenLabs(text: string): Promise<void> {
  const apiKey = process.env.CLICKY_ELEVENLABS_API_KEY?.trim();
  const voiceId = process.env.CLICKY_ELEVENLABS_VOICE_ID?.trim() ?? 'kPzsL2i3teMYv0FxEYQ6';
  if (!apiKey) throw new Error('CLICKY_ELEVENLABS_API_KEY not set');

  const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'xi-api-key': apiKey,
      'content-type': 'application/json',
      accept: 'audio/mpeg',
    },
    body: JSON.stringify({
      text,
      model_id: 'eleven_flash_v2_5',
      voice_settings: { stability: 0.5, similarity_boost: 0.75 },
    }),
  });
  if (!res.ok) throw new Error(`ElevenLabs HTTP ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  await playAudio(buf, 'mp3');
}

async function playAudio(buf: Buffer, ext: 'wav' | 'mp3'): Promise<void> {
  const dir = mkdtempSync(join(tmpdir(), 'clicky-speak-'));
  const path = join(dir, `audio.${ext}`);
  writeFileSync(path, buf);
  try {
    await runAfplay(path);
  } finally {
    try {
      unlinkSync(path);
    } catch {
      // ignore
    }
  }
}

function runAfplay(path: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn('afplay', [path], { stdio: ['ignore', 'ignore', 'pipe'] });
    let stderr = '';
    child.stderr.on('data', (c) => (stderr += String(c)));
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`afplay exited ${code}: ${stderr}`));
    });
    child.on('error', reject);
  });
}
