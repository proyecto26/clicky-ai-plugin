#!/usr/bin/env -S npx -y bun
import { parseArgs, flagString, flagNumber, flagBool, type ParsedArgs } from './args.ts';
import { capture } from './screenshot.ts';
import { point } from './point.ts';
import { speak } from './speak.ts';
import { launch } from './launch-app.ts';
import { install } from './installer.ts';
import { status } from './status.ts';
import type { SpeakEngine } from './types.ts';

const USAGE = `openclicky — screen-aware Claude Code companion for macOS

usage:
  npx -y bun scripts/main.ts <subcommand> [flags]

subcommands:
  install [--force] [--dry-run]
      install /Applications/OpenClicky.app via Homebrew tap (preferred) or
      GitHub Releases DMG (fallback).

  launch
      launch the installed OpenClicky.app. Errors cleanly if not installed.

  capture [--max-width 1280] [--output-dir PATH]
      capture every connected display to JPEG, emit a JSON manifest Claude
      can Read.

  point --x N --y N --label TEXT [--screen N] [--json]
      render a POINT target line for a coordinate Claude emitted via
      [POINT:x,y:label:screenN].

  speak "text" [--engine say|vibevoice|elevenlabs] [--voice NAME] [--rate N]
      speak text aloud. default engine: say. opt-in: VibeVoice via
      OPENCLICKY_VIBEVOICE_URL, ElevenLabs via OPENCLICKY_ELEVENLABS_API_KEY.

  status [--json]
      report environment health (permissions, installed app, claude CLI).

  help, -h, --help
      this message.

global flags:
  --json     emit machine-readable JSON where applicable
  -h, --help
`;

async function main(): Promise<number> {
  const parsed = parseArgs(process.argv.slice(2));
  const command = parsed.command;

  if (!command || command === 'help' || flagBool(parsed.flags, 'help')) {
    process.stdout.write(USAGE);
    return 0;
  }

  try {
    switch (command) {
      case 'install':
        return await runInstall(parsed);
      case 'launch':
        return await runLaunch(parsed);
      case 'capture':
        return await runCapture(parsed);
      case 'point':
        return runPoint(parsed);
      case 'speak':
        return await runSpeak(parsed);
      case 'status':
        return runStatus(parsed);
      default:
        process.stderr.write(`unknown subcommand: ${command}\n\n${USAGE}`);
        return 1;
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    process.stderr.write(`Error: ${message}\n`);
    return 1;
  }
}

async function runInstall(parsed: ParsedArgs): Promise<number> {
  const result = await install({
    force: flagBool(parsed.flags, 'force'),
    dryRun: flagBool(parsed.flags, 'dry-run'),
  });
  emitResult(parsed, result, () => {
    if (result.ok) {
      process.stdout.write(`installed: ${result.path ?? ''} (method: ${result.method})\n`);
    } else {
      process.stderr.write(`install failed: ${result.reason ?? 'unknown'}\n`);
    }
  });
  return result.ok ? 0 : 1;
}

async function runLaunch(parsed: ParsedArgs): Promise<number> {
  const result = await launch();
  emitResult(parsed, result, () => {
    if (result.ok) {
      process.stdout.write(`launched: ${result.path}\n`);
    } else {
      process.stderr.write(`launch failed: ${result.reason}\n`);
    }
  });
  return result.ok ? 0 : 1;
}

async function runCapture(parsed: ParsedArgs): Promise<number> {
  const manifest = await capture({
    maxWidth: flagNumber(parsed.flags, 'max-width'),
    outputDir: flagString(parsed.flags, 'output-dir'),
  });
  process.stdout.write(JSON.stringify(manifest, null, 2) + '\n');
  return 0;
}

function runPoint(parsed: ParsedArgs): number {
  const { rendered } = point({
    x: flagNumber(parsed.flags, 'x'),
    y: flagNumber(parsed.flags, 'y'),
    label: flagString(parsed.flags, 'label'),
    screen: flagNumber(parsed.flags, 'screen'),
    json: flagBool(parsed.flags, 'json'),
  });
  process.stdout.write(rendered + '\n');
  return 0;
}

async function runSpeak(parsed: ParsedArgs): Promise<number> {
  const text = parsed.positional.join(' ').trim();
  if (text === '') {
    process.stderr.write('speak requires a text argument: `speak "hello world"`\n');
    return 1;
  }
  const engineFlag = flagString(parsed.flags, 'engine');
  const engine = engineFlag as SpeakEngine | undefined;
  const result = await speak({
    text,
    engine,
    voice: flagString(parsed.flags, 'voice'),
    rate: flagNumber(parsed.flags, 'rate'),
  });
  emitResult(parsed, result, () => {
    process.stdout.write(`spoke via ${result.engine} (ok=${result.ok})\n`);
  });
  return result.ok ? 0 : 1;
}

function runStatus(parsed: ParsedArgs): number {
  const report = status();
  process.stdout.write(JSON.stringify(report, null, 2) + '\n');
  return 0;
}

function emitResult(
  parsed: ParsedArgs,
  result: unknown,
  textFallback: () => void,
): void {
  if (flagBool(parsed.flags, 'json')) {
    process.stdout.write(JSON.stringify(result, null, 2) + '\n');
  } else {
    textFallback();
  }
}

main().then(
  (code) => process.exit(code),
  (err) => {
    process.stderr.write(`fatal: ${err instanceof Error ? err.message : String(err)}\n`);
    process.exit(1);
  },
);
