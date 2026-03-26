/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { vibrator } from "@kit.SensorServiceKit";

export interface DigitalDirState {
  up: boolean;
  down: boolean;
  left: boolean;
  right: boolean;
}

export interface SnapResult {
  dx: number;
  dy: number;
}

export const EDIT_BORDER_COLOR = "#80FF6B6B";
export const SELECT_BORDER_COLOR = "#FFFFD700";
export const EDIT_TOOLBAR_HEIGHT = 48;
export const DRAG_THRESHOLD = 5;

export const BG_COLOR_PRESETS: string[] = [
  "#401A1A2E",
  "#40A8D8EA",
  "#40FF6B6B",
  "#4050C080",
  "#40FFD700",
  "#40D06060",
  "#406098C0",
  "#40FF8C00",
];

export const TEXT_COLOR_PRESETS: string[] = [
  "#E0FFFFFF",
  "#FFFFD700",
  "#FFA8D8EA",
  "#FFFF6B6B",
  "#FF50C080",
  "#FFFF8C00",
  "#FFD06060",
  "#FF6098C0",
];

export const PRESSED_COLOR_PRESETS: string[] = [
  "#80A8D8EA",
  "#80FF6B6B",
  "#8050C080",
  "#80FFD700",
  "#80D06060",
  "#806098C0",
  "#80FF8C00",
  "#80E070E0",
];

export const HAPTIC_OPTIONS: Array<[string, string]> = [
  ["none", "None"],
  ["light", "Light"],
  ["medium", "Medium"],
  ["heavy", "Heavy"],
];

export function doKeyHaptic(level: string): void {
  let duration = 0;
  switch (level) {
    case "light":
      duration = 15;
      break;
    case "medium":
      duration = 40;
      break;
    case "heavy":
      duration = 80;
      break;
    default:
      return;
  }
  try {
    vibrator.startVibration({ type: "time", duration }, { id: 0, usage: "touch" });
  } catch (_e) {
    /* ignore */
  }
}
