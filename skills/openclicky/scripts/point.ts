import type { PointTarget } from './types.ts';

export interface PointOptions {
  x?: number;
  y?: number;
  label?: string;
  screen?: number;
  json?: boolean;
}

export function point(options: PointOptions): { target: PointTarget; rendered: string } {
  const { x, y, label } = options;
  if (x === undefined || y === undefined || !label || label.trim() === '') {
    throw new Error(
      'point requires --x, --y, and --label. Example: ' +
        '--x 1100 --y 42 --label "color inspector" [--screen 2]',
    );
  }

  const target: PointTarget = {
    x: Math.round(x),
    y: Math.round(y),
    label: label.trim(),
    screen: options.screen ?? 1,
  };

  const rendered = options.json
    ? JSON.stringify(target)
    : `→ "${target.label}" at (${target.x}, ${target.y}) on screen ${target.screen}`;

  return { target, rendered };
}
