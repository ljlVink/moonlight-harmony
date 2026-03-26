/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { Want, ExtensionAbility } from "@kit.AbilityKit";
import { hilog } from "@kit.PerformanceAnalysisKit";

const TAG = "StreamingService";
const DOMAIN = 0x0000;

/**
 *
 *
 */
export default class StreamingService extends ExtensionAbility {
  onCreate(): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "StreamingService onCreate");
  }

  onRequest(want: Want, startId: number): void {
    hilog.info(DOMAIN, TAG, "%{public}s", `StreamingService onRequest, startId: ${startId}`);
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "StreamingService onForeground");
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "StreamingService onBackground");
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "StreamingService onDestroy");
  }
}
