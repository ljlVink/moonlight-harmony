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
import { GamepadManager } from "./GamepadManager";
import { RUMBLE_MAX } from "./GamepadTypes";

export class AudioVibrationService {
  private enabled: boolean = false;
  private strength: number = 100;
  private vibrationMode: string = "自动";
  private sceneMode: string = "游戏/电影";

  private lastIntensity: number = 0;
  private lastLowFreqRatio: number = 50;

  private hdHapticSupported: boolean | null = null;
  private isDeviceVibrating: boolean = false;

  private isUsbRumbling: boolean = false;

  private lastVibrationTime: number = 0;
  private static readonly MIN_VIBRATION_INTERVAL_MS = 20;
  private static readonly MIN_VIBRATION_INTERVAL_MUSIC_MS = 15;

  setSettings(
    enabled: boolean,
    strength: number,
    vibrationMode: string,
    sceneMode: string = "游戏/电影",
  ): void {
    this.enabled = enabled;
    this.strength = strength;
    this.vibrationMode = vibrationMode;
    this.sceneMode = sceneMode;

    if (!enabled) {
      this.stopAll();
    }
  }

  getSceneModeInt(): number {
    switch (this.sceneMode) {
      case "音乐/节奏":
        return 1;
      case "自动":
        return 2;
      case "游戏/电影":
      default:
        return 0;
    }
  }

  handleBassEnergy(intensity: number, lowFreqRatio: number = 50): void {
    if (!this.enabled) return;

    if (intensity === 0) {
      if (this.isDeviceVibrating || this.isUsbRumbling) {
        this.stopAll();
      }
      return;
    }

    const effectiveIntensity = Math.floor((intensity * this.strength) / 100);
    if (effectiveIntensity < 5) {
      if (this.isDeviceVibrating || this.isUsbRumbling) {
        this.stopAll();
      }
      return;
    }

    const now = Date.now();
    const minInterval = this.isMusicScene()
      ? AudioVibrationService.MIN_VIBRATION_INTERVAL_MUSIC_MS
      : AudioVibrationService.MIN_VIBRATION_INTERVAL_MS;
    if (now - this.lastVibrationTime < minInterval) {
      return;
    }

    const changeTolerance = this.isMusicScene() ? 2 : 4;
    if (
      (this.isDeviceVibrating || this.isUsbRumbling) &&
      Math.abs(effectiveIntensity - this.lastIntensity) < changeTolerance
    ) {
      return;
    }

    this.lastIntensity = effectiveIntensity;
    this.lastLowFreqRatio = lowFreqRatio;
    this.lastVibrationTime = now;

    const shouldDevice = this.shouldVibrateDevice();
    const shouldUsb = this.shouldVibrateGamepad();

    if (shouldDevice) {
      this.triggerDeviceVibration(effectiveIntensity);
    } else if (this.isDeviceVibrating) {
      this.stopDeviceVibration();
    }

    if (shouldUsb) {
      this.triggerUsbRumble(effectiveIntensity, lowFreqRatio);
    } else if (this.isUsbRumbling) {
      this.stopUsbRumble();
    }
  }

  stop(): void {
    this.stopAll();
  }

  private isMusicScene(): boolean {
    return this.sceneMode === "音乐/节奏" || this.sceneMode === "自动";
  }

  private shouldVibrateDevice(): boolean {
    switch (this.vibrationMode) {
      case "仅手柄":
        return false;
      case "仅设备":
        return true;
      case "同时":
        return true;
      case "自动":
      default:
        return !GamepadManager.getInstance().hasUsbControllers();
    }
  }

  private shouldVibrateGamepad(): boolean {
    switch (this.vibrationMode) {
      case "仅手柄":
        return true;
      case "仅设备":
        return false;
      case "同时":
        return true;
      case "自动":
      default:
        return GamepadManager.getInstance().hasUsbControllers();
    }
  }

  private triggerDeviceVibration(intensity: number): void {
    if (this.hdHapticSupported === null) {
      try {
        this.hdHapticSupported = vibrator.isHdHapticSupported();
      } catch (_) {
        this.hdHapticSupported = false;
      }
    }

    if (this.isDeviceVibrating) {
      this.stopVibrationSync();
    }

    try {
      if (this.hdHapticSupported) {
        if (this.sceneMode === "音乐/节奏") {
          this.triggerMusicHdHaptic(intensity);
        } else {
          this.triggerGameHdHaptic(intensity);
        }
      } else {
        if (this.sceneMode === "音乐/节奏") {
          this.triggerMusicTimeVibration(intensity);
        } else {
          this.triggerGameTimeVibration(intensity);
        }
      }
      this.isDeviceVibrating = true;
    } catch (_) {
      if (this.sceneMode === "音乐/节奏") {
        this.triggerMusicTimeVibration(intensity);
      } else {
        this.triggerGameTimeVibration(intensity);
      }
    }
  }

  private triggerGameHdHaptic(intensity: number): void {
    try {
      const builder = new vibrator.VibratorPatternBuilder();
      const frequency = Math.floor(30 + (intensity / 100) * 20);

      builder.addContinuousEvent(0, 300, {
        intensity: Math.min(100, intensity),
        frequency: frequency,
        index: 0,
      });

      vibrator
        .startVibration(
          {
            type: "pattern",
            pattern: builder.build(),
          },
          {
            id: 0,
            usage: "physicalFeedback",
          },
        )
        .catch((_: Error) => {
          this.triggerGameTimeVibration(intensity);
        });
    } catch (_) {
      this.triggerGameTimeVibration(intensity);
    }
  }

  private triggerGameTimeVibration(intensity: number): void {
    if (intensity < 5) return;
    const duration = Math.floor(50 + intensity * 2.5);

    vibrator
      .startVibration(
        {
          type: "time",
          duration: duration,
        },
        {
          id: 0,
          usage: "physicalFeedback",
        },
      )
      .catch((_: Error) => {
        /* ignore */
      });
    this.isDeviceVibrating = true;
  }

  private triggerMusicHdHaptic(intensity: number): void {
    try {
      const builder = new vibrator.VibratorPatternBuilder();

      const frequency = Math.floor(40 + (intensity / 100) * 20);

      builder.addContinuousEvent(0, 60, {
        intensity: Math.min(100, intensity),
        frequency: frequency,
        index: 0,
      });

      vibrator
        .startVibration(
          {
            type: "pattern",
            pattern: builder.build(),
          },
          {
            id: 0,
            usage: "physicalFeedback",
          },
        )
        .catch((_: Error) => {
          this.triggerMusicTimeVibration(intensity);
        });
    } catch (_) {
      this.triggerMusicTimeVibration(intensity);
    }
  }

  private triggerMusicTimeVibration(intensity: number): void {
    if (intensity < 5) return;

    const duration = Math.floor(30 + intensity * 0.5);

    vibrator
      .startVibration(
        {
          type: "time",
          duration: duration,
        },
        {
          id: 0,
          usage: "physicalFeedback",
        },
      )
      .catch((_: Error) => {
        /* ignore */
      });
    this.isDeviceVibrating = true;
  }

  private triggerUsbRumble(intensity: number, lowFreqRatio: number = 50): void {
    const base = Math.floor((intensity * RUMBLE_MAX) / 100);

    const lowWeight = Math.max(0.15, Math.min(0.85, lowFreqRatio / 100));
    const highWeight = 1.0 - lowWeight;

    const lowFreq = Math.floor(base * lowWeight);
    const highFreq = Math.floor(base * highWeight);

    GamepadManager.getInstance().rumbleUsbControllers(0, lowFreq, highFreq);
    this.isUsbRumbling = true;
  }

  private stopUsbRumble(): void {
    GamepadManager.getInstance().rumbleUsbControllers(0, 0, 0);
    this.isUsbRumbling = false;
  }

  private stopAll(): void {
    if (this.isDeviceVibrating) {
      this.stopDeviceVibration();
    }
    if (this.isUsbRumbling) {
      this.stopUsbRumble();
    }
    this.lastIntensity = 0;
  }

  private stopDeviceVibration(): void {
    this.stopVibrationSync();
    this.isDeviceVibrating = false;
  }

  private stopVibrationSync(): void {
    try {
      vibrator.stopVibrationSync();
    } catch (_) {
      try {
        vibrator.stopVibration();
      } catch (_) {
        /* ignore */
      }
    }
  }
}
