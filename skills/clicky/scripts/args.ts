export interface ParsedArgs {
  command: string | null;
  positional: string[];
  flags: Record<string, string | boolean>;
}

const SHORT_FLAG_ALIASES: Record<string, string> = {
  h: 'help',
  v: 'verbose',
};

const BOOLEAN_FLAGS = new Set([
  'help',
  'verbose',
  'json',
  'force',
  'dry-run',
]);

export function parseArgs(argv: string[]): ParsedArgs {
  const tokens = argv.slice();
  const positional: string[] = [];
  const flags: Record<string, string | boolean> = {};
  let command: string | null = null;

  while (tokens.length > 0) {
    const raw = tokens.shift()!;

    if (raw === '--') {
      positional.push(...tokens);
      tokens.length = 0;
      break;
    }

    if (raw.startsWith('--')) {
      const [keyRaw, eqValue] = raw.slice(2).split('=', 2);
      const key = keyRaw;
      if (eqValue !== undefined) {
        flags[key] = eqValue;
      } else if (BOOLEAN_FLAGS.has(key)) {
        flags[key] = true;
      } else if (tokens.length > 0 && !tokens[0]!.startsWith('-')) {
        flags[key] = tokens.shift()!;
      } else {
        flags[key] = true;
      }
      continue;
    }

    if (raw.startsWith('-') && raw.length > 1) {
      const shortKey = raw.slice(1);
      const key = SHORT_FLAG_ALIASES[shortKey] ?? shortKey;
      if (BOOLEAN_FLAGS.has(key)) {
        flags[key] = true;
      } else if (tokens.length > 0 && !tokens[0]!.startsWith('-')) {
        flags[key] = tokens.shift()!;
      } else {
        flags[key] = true;
      }
      continue;
    }

    if (command === null) {
      command = raw;
    } else {
      positional.push(raw);
    }
  }

  return { command, positional, flags };
}

export function flagString(flags: ParsedArgs['flags'], key: string): string | undefined {
  const v = flags[key];
  return typeof v === 'string' ? v : undefined;
}

export function flagNumber(flags: ParsedArgs['flags'], key: string): number | undefined {
  const s = flagString(flags, key);
  if (s === undefined) return undefined;
  const n = Number(s);
  return Number.isFinite(n) ? n : undefined;
}

export function flagBool(flags: ParsedArgs['flags'], key: string): boolean {
  return flags[key] === true || flags[key] === 'true';
}
