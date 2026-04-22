import { spawn } from 'node:child_process';
import { join } from 'node:path';
import { unlinkSync, existsSync } from 'node:fs';
import { assertDarwin, resolveScreenshotsDir, ensureDir } from './paths.ts';
import type { CaptureManifest, ScreenInfo } from './types.ts';

const DEFAULT_MAX_WIDTH = 1280;

export interface CaptureOptions {
  maxWidth?: number;
  outputDir?: string;
}

export async function capture(options: CaptureOptions = {}): Promise<CaptureManifest> {
  assertDarwin();
  const dir = options.outputDir ?? resolveScreenshotsDir();
  ensureDir(dir);
  const maxWidth = options.maxWidth ?? DEFAULT_MAX_WIDTH;
  const stamp = timestamp();

  const screens: ScreenInfo[] = [];
  for (let index = 1; index <= 16; index++) {
    const path = join(dir, `${stamp}-screen${index}.jpg`);
    const captured = await runScreencapture(index, path);
    if (!captured) break;

    if (maxWidth > 0) {
      await runSips(['-Z', String(maxWidth), path]);
    }
    const dims = await readJpegDimensions(path);

    screens.push({
      index,
      label: `screen${index} (${dims.width}x${dims.height})`,
      path,
      widthPx: dims.width,
      heightPx: dims.height,
      isCursorScreen: index === 1,
    });
  }

  if (screens.length === 0) {
    throw new Error(
      'No displays captured. Screen Recording permission may be missing. ' +
        'Grant it in System Settings → Privacy & Security → Screen Recording.',
    );
  }

  decorateCursorScreenLabel(screens);

  return {
    schemaVersion: 1,
    capturedAt: new Date().toISOString(),
    cursorScreenIndex: screens.find((s) => s.isCursorScreen)?.index ?? null,
    screens,
  };
}

function timestamp(): string {
  return new Date().toISOString().replace(/[:.]/g, '-');
}

function runScreencapture(displayIndex: number, outputPath: string): Promise<boolean> {
  return new Promise((resolve) => {
    const child = spawn('screencapture', ['-x', '-D', String(displayIndex), '-t', 'jpg', outputPath], {
      stdio: ['ignore', 'ignore', 'pipe'],
    });
    let stderr = '';
    child.stderr.on('data', (chunk) => {
      stderr += String(chunk);
    });
    child.on('close', (code) => {
      if (code === 0 && existsSync(outputPath)) {
        resolve(true);
        return;
      }
      if (existsSync(outputPath)) {
        try {
          unlinkSync(outputPath);
        } catch {
          // ignore
        }
      }
      if (stderr.includes('not enough displays') || stderr.includes('Invalid display')) {
        resolve(false);
        return;
      }
      resolve(false);
    });
    child.on('error', () => resolve(false));
  });
}

function runSips(args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn('sips', args, { stdio: ['ignore', 'ignore', 'pipe'] });
    let stderr = '';
    child.stderr.on('data', (chunk) => {
      stderr += String(chunk);
    });
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`sips failed (exit ${code}): ${stderr}`));
    });
    child.on('error', reject);
  });
}

function readJpegDimensions(path: string): Promise<{ width: number; height: number }> {
  return new Promise((resolve, reject) => {
    const child = spawn('sips', ['-g', 'pixelWidth', '-g', 'pixelHeight', path], {
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    child.stdout.on('data', (chunk) => {
      stdout += String(chunk);
    });
    child.on('close', (code) => {
      if (code !== 0) return reject(new Error(`sips dim read failed (exit ${code})`));
      const widthMatch = stdout.match(/pixelWidth:\s*(\d+)/);
      const heightMatch = stdout.match(/pixelHeight:\s*(\d+)/);
      if (!widthMatch || !heightMatch) {
        return reject(new Error(`could not parse sips output: ${stdout}`));
      }
      resolve({ width: Number(widthMatch[1]), height: Number(heightMatch[1]) });
    });
    child.on('error', reject);
  });
}

function decorateCursorScreenLabel(screens: ScreenInfo[]): void {
  for (const s of screens) {
    const tag = s.isCursorScreen ? 'primary focus' : 'secondary';
    s.label = `screen${s.index} (${tag}, ${s.widthPx}x${s.heightPx})`;
  }
}
