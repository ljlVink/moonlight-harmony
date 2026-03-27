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
import { UsbDriverService, AbstractController } from "./usbdriver/index";
import { RUMBLE_MAX } from "./GamepadTypes";

export class GamepadVibrationService {
  private usbDriverService: UsbDriverService;

  private deviceVibrateEnabled = false;
  private deviceVibrateStrength = 100;
  private vibrationMode = "自动";

  private deviceKeyToSlotLookup: Map<string, number>;

  private hdHapticSupported: boolean | null = null;
  private lastLowFreq: number = 0;
  private lastHighFreq: number = 0;
  private isVibrating: boolean = false;
  private rumbleWatchdogTimer: number = -1;
  private lastRumbleControllerNumber: number = 0;
  private static readonly RUMBLE_WATCHDOG_MS = 3000;
  private stopConfirmTimer: number = -1;

  constructor(usbDriverService: UsbDriverService, deviceKeyToSlot: Map<string, number>) {
    this.usbDriverService = usbDriverService;
    this.deviceKeyToSlotLookup = deviceKeyToSlot;
  }

  setSettings(enabled: boolean, strength: number, mode: string): void {
    this.deviceVibrateEnabled = enabled;
    this.deviceVibrateStrength = strength;
    this.vibrationMode = mode;
  }

  handleRumble(controllerNumber: number, lowFreqMotor: number, highFreqMotor: number): void {
    if (this.rumbleWatchdogTimer !== -1) {
      clearTimeout(this.rumbleWatchdogTimer);
      this.rumbleWatchdogTimer = -1;
    }
    if (this.stopConfirmTimer !== -1) {
      clearTimeout(this.stopConfirmTimer);
      this.stopConfirmTimer = -1;
    }
    if (lowFreqMotor !== 0 || highFreqMotor !== 0) {
      this.lastRumbleControllerNumber = controllerNumber;
      this.rumbleWatchdogTimer = setTimeout(() => {
        this.rumbleWatchdogTimer = -1;
        console.warn("[Vibration] watchdog: 3s 无回调, 强制停止振动");
        this.handleRumble(this.lastRumbleControllerNumber, 0, 0);
      }, GamepadVibrationService.RUMBLE_WATCHDOG_MS);
    }

    const controllers = this.usbDriverService.getControllers();
    const hasUsbController = controllers.length > 0;

    switch (this.vibrationMode) {
      case "仅手柄":
        if (hasUsbController) {
          this.rumbleUsbControllers(controllers, controllerNumber, lowFreqMotor, highFreqMotor);
        }
        break;

      case "仅设备":
        this.triggerDeviceVibrate(lowFreqMotor, highFreqMotor);
        break;

      case "同时":
        if (hasUsbController) {
          this.rumbleUsbControllers(controllers, controllerNumber, lowFreqMotor, highFreqMotor);
        }
        this.triggerDeviceVibrate(lowFreqMotor, highFreqMotor);
        break;

      case "自动":
      default:
        if (hasUsbController) {
          this.rumbleUsbControllers(controllers, controllerNumber, lowFreqMotor, highFreqMotor);
        } else {
          this.triggerDeviceVibrate(lowFreqMotor, highFreqMotor);
        }
        break;
    }

    if (lowFreqMotor === 0 && highFreqMotor === 0 && hasUsbController) {
      this.stopConfirmTimer = setTimeout(() => {
        this.stopConfirmTimer = -1;
        const ctrls = this.usbDriverService.getControllers();
        this.rumbleUsbControllers(ctrls, controllerNumber, 0, 0);
      }, 100);
    }
  }

  handleRumbleTriggers(controllerNumber: number, leftTrigger: number, rightTrigger: number): void {
    const controllers = this.usbDriverService.getControllers();
    const controller = this.findControllerBySlot(controllers, controllerNumber);
    controller?.rumbleTriggers(leftTrigger, rightTrigger);
  }

  rumbleUsbControllersOnly(
    controllerNumber: number,
    lowFreqMotor: number,
    highFreqMotor: number,
  ): void {
    const controllers = this.usbDriverService.getControllers();
    if (controllers.length > 0) {
      this.rumbleUsbControllers(controllers, controllerNumber, lowFreqMotor, highFreqMotor);
    }
  }

  hasUsbControllers(): boolean {
    return this.usbDriverService.getControllers().length > 0;
  }

  stopAll(): void {
    if (this.rumbleWatchdogTimer !== -1) {
      clearTimeout(this.rumbleWatchdogTimer);
      this.rumbleWatchdogTimer = -1;
    }
    if (this.stopConfirmTimer !== -1) {
      clearTimeout(this.stopConfirmTimer);
      this.stopConfirmTimer = -1;
    }

    if (this.isVibrating) {
      this.stopVibrationImmediate();
    }
    this.lastLowFreq = 0;
    this.lastHighFreq = 0;

    try {
      const controllers = this.usbDriverService.getControllers();
      for (const controller of controllers) {
        controller.rumble(0, 0);
      }
    } catch (_) {
      /* ignore */
    }
  }

  private findControllerBySlot(
    controllers: AbstractController[],
    slotNumber: number,
  ): AbstractController | null {
    if (controllers.length === 0) return null;

    for (const controller of controllers) {
      if (this.deviceKeyToSlotLookup.get(controller.getDeviceKey()) === slotNumber) {
        return controller;
      }
    }

    if (controllers.length === 1) return controllers[0];
    if (slotNumber < controllers.length) return controllers[slotNumber];
    return controllers[0];
  }

  private rumbleUsbControllers(
    controllers: AbstractController[],
    controllerNumber: number,
    lowFreqMotor: number,
    highFreqMotor: number,
  ): void {
    const controller = this.findControllerBySlot(controllers, controllerNumber);
    controller?.rumble(lowFreqMotor, highFreqMotor);
  }

  /**
   *
   */
  private triggerDeviceVibrate(lowFreqMotor: number, highFreqMotor: number): void {
    if (!this.deviceVibrateEnabled) return;

    if (lowFreqMotor === 0 && highFreqMotor === 0) {
      if (this.isVibrating) {
        this.stopVibrationImmediate();
        this.lastLowFreq = 0;
        this.lastHighFreq = 0;
      }
      return;
    }

    const lowDelta = Math.abs(lowFreqMotor - this.lastLowFreq);
    const highDelta = Math.abs(highFreqMotor - this.lastHighFreq);
    const threshold = 3000;

    if (this.isVibrating && lowDelta < threshold && highDelta < threshold) {
      return;
    }

    this.lastLowFreq = lowFreqMotor;
    this.lastHighFreq = highFreqMotor;

    const userStrength = this.deviceVibrateStrength / 100;

    const lowIntensity = Math.floor((lowFreqMotor / RUMBLE_MAX) * userStrength * 100);
    const highIntensity = Math.floor((highFreqMotor / RUMBLE_MAX) * userStrength * 100);

    if (this.hdHapticSupported === null) {
      try {
        this.hdHapticSupported = vibrator.isHdHapticSupported();
        console.info(`[VIBRATION] 高清振动支持: ${this.hdHapticSupported}`);
      } catch (_) {
        this.hdHapticSupported = false;
      }
    }

    if (this.isVibrating) {
      this.stopVibrationImmediate();
    }

    try {
      if (this.hdHapticSupported) {
        this.triggerContinuousVibration(lowIntensity, highIntensity);
      } else {
        this.triggerTimeVibration(lowIntensity, highIntensity);
      }
      this.isVibrating = true;
    } catch (err) {
      console.warn(`[VIBRATION] 设备震动异常: ${err}`);
      this.fallbackTimeVibration(Math.max(lowIntensity, highIntensity));
    }
  }

  private stopVibrationImmediate(): void {
    try {
      vibrator.stopVibrationSync();
    } catch (_) {
      try {
        vibrator.stopVibration();
      } catch (_) {
        /* ignore */
      }
    }
    this.isVibrating = false;
  }

  private triggerContinuousVibration(lowIntensity: number, highIntensity: number): void {
    try {
      const builder = new vibrator.VibratorPatternBuilder();

      const combinedIntensity = Math.min(100, Math.max(lowIntensity, highIntensity));
      if (combinedIntensity < 5) return;

      let frequency: number;
      if (lowIntensity > 0 && highIntensity > 0) {
        const ratio = highIntensity / (lowIntensity + highIntensity);
        frequency = Math.floor(30 + ratio * 50); // 30-80
      } else if (lowIntensity > 0) {
        frequency = 35;
      } else {
        frequency = 70;
      }

      builder.addContinuousEvent(0, 500, {
        intensity: combinedIntensity,
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
        .catch((err: Error) => {
          this.triggerTimeVibration(lowIntensity, highIntensity);
        });
    } catch (err) {
      this.triggerTimeVibration(lowIntensity, highIntensity);
    }
  }

  private triggerTimeVibration(lowIntensity: number, highIntensity: number): void {
    const combinedIntensity = Math.max(lowIntensity, highIntensity);
    if (combinedIntensity < 5) return;

    vibrator
      .startVibration(
        {
          type: "time",
          duration: 500,
        },
        {
          id: 0,
          usage: "physicalFeedback",
        },
      )
      .catch((err: Error) => {
        console.warn(`[VIBRATION] 时长震动失败: ${err.message}`);
      });
  }

  private fallbackTimeVibration(intensity: number): void {
    if (intensity < 5) return;
    const duration = Math.floor(50 + intensity * 4.5); // 50-500ms

    vibrator
      .startVibration({ type: "time", duration }, { id: 0, usage: "physicalFeedback" })
      .catch((err: Error) => console.warn(`[VIBRATION] 设备震动失败: ${err.message}`));
    this.isVibrating = true;
  }
}
