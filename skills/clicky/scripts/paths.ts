import { homedir, platform } from 'node:os';
import { join, resolve } from 'node:path';
import { mkdirSync } from 'node:fs';

const DATA_DIR_NAME = 'clicky-ai';

export function isDarwin(): boolean {
  return platform() === 'darwin';
}

export function assertDarwin(): void {
  if (!isDarwin()) {
    throw new Error('clicky-ai requires macOS. Non-darwin platforms are not supported in v1.');
  }
}

export function resolveUserDataRoot(): string {
  assertDarwin();
  return join(homedir(), 'Library', 'Application Support');
}

export function resolveDataDir(): string {
  const override = process.env.CLICKY_DATA_DIR?.trim();
  if (override) return resolve(override);
  return join(resolveUserDataRoot(), DATA_DIR_NAME);
}

export function resolveScreenshotsDir(): string {
  return join(resolveDataDir(), 'screenshots');
}

export function resolveDownloadsDir(): string {
  return join(resolveDataDir(), 'downloads');
}

export function resolveConfigPath(): string {
  return join(resolveDataDir(), 'config.json');
}

export function ensureDir(path: string): string {
  mkdirSync(path, { recursive: true });
  return path;
}
