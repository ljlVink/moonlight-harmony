/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

export interface AppInfo {
  id: number;
  name: string;
  isRunning: boolean;
  isHdrSupported?: boolean;
  isHidden?: boolean;
}

export interface AppAsset {
  appId: number;
  computerId: string;
  boxArt?: string;
}
