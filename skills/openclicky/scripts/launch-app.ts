import { spawn, spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { assertDarwin } from './paths.ts';
import type { LaunchResult } from './types.ts';

const APP_CANDIDATES = [
  '/Applications/OpenClicky.app',
  '/Applications/leanring-buddy.app',
];

export function findAppPath(): string | undefined {
  const override = process.env.OPENCLICKY_APP_PATH?.trim();
  if (override && existsSync(override)) return override;

  for (const candidate of APP_CANDIDATES) {
    if (existsSync(candidate)) return candidate;
  }

  const derived = findInDerivedData();
  if (derived) return derived;

  return undefined;
}

function findInDerivedData(): string | undefined {
  const root = join(homedir(), 'Library', 'Developer', 'Xcode', 'DerivedData');
  if (!existsSync(root)) return undefined;

  let best: { path: string; mtime: number } | undefined;
  let entries: string[];
  try {
    entries = readdirSync(root);
  } catch {
    return undefined;
  }

  for (const entry of entries) {
    if (!entry.startsWith('leanring-buddy-')) continue;
    const candidate = join(root, entry, 'Build', 'Products', 'Debug', 'leanring-buddy.app');
    if (!existsSync(candidate)) continue;
    try {
      const mtime = statSync(candidate).mtimeMs;
      if (!best || mtime > best.mtime) best = { path: candidate, mtime };
    } catch {
      continue;
    }
  }
  return best?.path;
}

export async function launch(): Promise<LaunchResult> {
  assertDarwin();
  const appPath = findAppPath();
  if (!appPath) {
    return {
      ok: false,
      reason:
        'OpenClicky.app not found. Run: npx -y bun scripts/main.ts install',
    };
  }

  const { status, stderr } = spawnSync('open', ['-a', appPath], { encoding: 'utf8' });
  if (status === 0) {
    return { ok: true, path: appPath, launchedVia: 'open' };
  }

  return {
    ok: false,
    path: appPath,
    reason: `open -a failed (exit ${status}): ${stderr?.trim() ?? ''}`,
  };
}
