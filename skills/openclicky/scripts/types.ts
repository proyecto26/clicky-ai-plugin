export interface ScreenInfo {
  index: number;
  label: string;
  path: string;
  widthPx: number;
  heightPx: number;
  displayWidthPoints?: number;
  displayHeightPoints?: number;
  isCursorScreen: boolean;
}

export interface CaptureManifest {
  schemaVersion: 1;
  capturedAt: string;
  cursorScreenIndex: number | null;
  screens: ScreenInfo[];
}

export interface PointTarget {
  x: number;
  y: number;
  label: string;
  screen: number;
}

export interface LaunchResult {
  ok: boolean;
  path?: string;
  launchedVia?: 'open' | 'direct';
  reason?: string;
}

export interface InstallResult {
  ok: boolean;
  path?: string;
  method?: 'already-installed' | 'brew-tap' | 'dmg-download' | 'manual';
  reason?: string;
}

export type SpeakEngine = 'say' | 'vibevoice' | 'elevenlabs';

export interface SpeakRequest {
  text: string;
  engine?: SpeakEngine;
  voice?: string;
  rate?: number;
}

export type PermissionState = 'granted' | 'denied' | 'unknown';

export interface StatusReport {
  platform: string;
  arch: string;
  permissions: {
    screenRecording: PermissionState;
    accessibility: PermissionState;
  };
  nativeApp: {
    installed: boolean;
    path?: string;
    version?: string;
  };
  claudeCLI: {
    installed: boolean;
    path?: string;
    version?: string;
  };
  voice: {
    say: boolean;
    vibevoice: { configured: boolean; url: string | null; reachable: boolean };
    elevenlabs: { configured: boolean };
  };
  dataDir: string;
}
