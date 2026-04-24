import { spawnSync } from 'node:child_process';
import { existsSync, unlinkSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { arch, platform } from 'node:os';
import { isDarwin, resolveDataDir } from './paths.ts';
import { findAppPath } from './launch-app.ts';
import type { StatusReport, PermissionState } from './types.ts';

export function status(): StatusReport {
  const claudeInfo = probeClaudeCLI();
  const appPath = isDarwin() ? findAppPath() : undefined;
  const appVersion = appPath ? probeAppVersion(appPath) : undefined;

  return {
    platform: platform(),
    arch: arch(),
    permissions: {
      screenRecording: probeScreenRecording(),
      accessibility: probeAccessibility(),
    },
    nativeApp: {
      installed: Boolean(appPath),
      path: appPath,
      version: appVersion,
    },
    claudeCLI: claudeInfo,
    voice: {
      say: isDarwin(),
      vibevoice: {
        configured: Boolean(process.env.OPENCLICKY_VIBEVOICE_URL?.trim()),
        url: process.env.OPENCLICKY_VIBEVOICE_URL?.trim() || null,
        reachable: false,
      },
      elevenlabs: { configured: Boolean(process.env.OPENCLICKY_ELEVENLABS_API_KEY?.trim()) },
    },
    dataDir: isDarwin() ? resolveDataDir() : '',
  };
}

function probeScreenRecording(): PermissionState {
  if (!isDarwin()) return 'unknown';
  const dir = mkdtempSync(join(tmpdir(), 'clicky-tcc-'));
  const probePath = join(dir, 'probe.png');
  const r = spawnSync('screencapture', ['-x', '-t', 'png', '-R', '0,0,4,4', probePath], {
    encoding: 'utf8',
    stdio: ['ignore', 'ignore', 'pipe'],
  });
  const ok = r.status === 0 && existsSync(probePath);
  try {
    if (existsSync(probePath)) unlinkSync(probePath);
  } catch {
    // ignore
  }
  if (ok) return 'granted';
  if (r.stderr?.includes('could not create image')) return 'denied';
  return 'unknown';
}

function probeAccessibility(): PermissionState {
  if (!isDarwin()) return 'unknown';
  const r = spawnSync(
    'osascript',
    ['-e', 'tell application "System Events" to return (UI elements enabled)'],
    { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] },
  );
  if (r.status !== 0) {
    if (r.stderr?.includes('1002') || r.stderr?.toLowerCase().includes('not allowed')) return 'denied';
    return 'unknown';
  }
  return r.stdout.trim() === 'true' ? 'granted' : 'denied';
}

function probeClaudeCLI(): StatusReport['claudeCLI'] {
  const candidates = [
    process.env.OPENCLICKY_CLAUDE_BIN,
    '/opt/homebrew/bin/claude',
    '/usr/local/bin/claude',
    join(process.env.HOME ?? '', '.claude', 'local', 'claude'),
  ].filter((p): p is string => Boolean(p));

  for (const path of candidates) {
    if (!existsSync(path)) continue;
    const version = probeVersionAt(path);
    if (version) return { installed: true, path, version };
  }

  const which = spawnSync('which', ['claude'], { encoding: 'utf8' });
  if (which.status === 0 && which.stdout.trim()) {
    const path = which.stdout.trim();
    const version = probeVersionAt(path);
    return { installed: true, path, version };
  }

  return { installed: false };
}

function probeVersionAt(path: string): string | undefined {
  const r = spawnSync(path, ['--version'], { encoding: 'utf8' });
  if (r.status !== 0) return undefined;
  return r.stdout.trim() || undefined;
}

function probeAppVersion(appPath: string): string | undefined {
  const plist = join(appPath, 'Contents', 'Info.plist');
  if (!existsSync(plist)) return undefined;
  const r = spawnSync(
    'defaults',
    ['read', plist.replace(/\.plist$/, ''), 'CFBundleShortVersionString'],
    { encoding: 'utf8' },
  );
  if (r.status !== 0) return undefined;
  return r.stdout.trim() || undefined;
}
