/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { usbManager } from "@kit.BasicServicesKit";
import { AbstractDualSenseController } from "./AbstractDualSenseController";
import { UsbDriverListener } from "./UsbDriverListener";
import {
  ButtonFlags,
  ControllerCapabilities,
  DPadDirection,
  DualSense,
} from "./ControllerConstants";
import { readShortLE, TRIGGER_MAX } from "../GamepadTypes";

const TAG = "[USB-DS5]";

export class DualSenseController extends AbstractDualSenseController {
  private lastRumbleLow: number = -1;
  private lastRumbleHigh: number = -1;

  constructor(
    device: usbManager.USBDevice,
    pipe: usbManager.USBDevicePipe,
    deviceId: number,
    listener: UsbDriverListener,
  ) {
    super(device, pipe, deviceId, listener);
    this.capabilities |= ControllerCapabilities.TRIGGER_RUMBLE;
    this.deviceName = "DualSense Controller";
  }

  static canClaimDevice(device: usbManager.USBDevice): boolean {
    if (device.vendorId !== DualSense.VID) {
      return false;
    }

    if (!DualSense.PIDS.includes(device.productId)) {
      return false;
    }

    if (!device.configs || device.configs.length === 0) {
      return false;
    }

    const config = device.configs[0];
    if (!config.interfaces || config.interfaces.length === 0) {
      return false;
    }

    console.info(
      `${TAG} 检测到 DualSense 控制器: VID=0x${device.vendorId.toString(16)}, PID=0x${device.productId.toString(16)}`,
    );
    return true;
  }

  private normalizeThumbStickAxis(value: number): number {
    return (2.0 * value) / TRIGGER_MAX - 1.0;
  }

  private normalizeTriggerAxis(value: number): number {
    return value / TRIGGER_MAX;
  }

  protected handleRead(buffer: Uint8Array): boolean {
    if (buffer.length < 10) {
      console.warn(`${TAG} 数据太短: ${buffer.length}`);
      return false;
    }

    // https://controllers.fandom.com/wiki/Sony_DualSense

    const reportId = buffer[0];
    let offset = 1;

    if (reportId !== 0x01) {
      return false;
    }

    this.leftStickX = this.normalizeThumbStickAxis(buffer[offset++]);
    this.leftStickY = this.normalizeThumbStickAxis(buffer[offset++]);
    this.rightStickX = this.normalizeThumbStickAxis(buffer[offset++]);
    this.rightStickY = this.normalizeThumbStickAxis(buffer[offset++]);

    this.leftTrigger = this.normalizeTriggerAxis(buffer[offset++]);
    this.rightTrigger = this.normalizeTriggerAxis(buffer[offset++]);

    offset++;

    const b8 = buffer[offset++]; // byte 8
    const b9 = buffer[offset++]; // byte 9
    const b10 = buffer[offset++]; // byte 10

    const dpad = b8 & 0x0f;
    this.setButtonFlag(
      ButtonFlags.UP_FLAG,
      dpad === DPadDirection.UP || dpad === DPadDirection.UP_RIGHT || dpad === DPadDirection.UP_LEFT
        ? 1
        : 0,
    );
    this.setButtonFlag(
      ButtonFlags.DOWN_FLAG,
      dpad === DPadDirection.DOWN ||
        dpad === DPadDirection.DOWN_RIGHT ||
        dpad === DPadDirection.DOWN_LEFT
        ? 1
        : 0,
    );
    this.setButtonFlag(
      ButtonFlags.LEFT_FLAG,
      dpad === DPadDirection.LEFT ||
        dpad === DPadDirection.UP_LEFT ||
        dpad === DPadDirection.DOWN_LEFT
        ? 1
        : 0,
    );
    this.setButtonFlag(
      ButtonFlags.RIGHT_FLAG,
      dpad === DPadDirection.RIGHT ||
        dpad === DPadDirection.UP_RIGHT ||
        dpad === DPadDirection.DOWN_RIGHT
        ? 1
        : 0,
    );

    this.setButtonFlag(ButtonFlags.X_FLAG, b8 & 0x10); // Square
    this.setButtonFlag(ButtonFlags.A_FLAG, b8 & 0x20); // Cross
    this.setButtonFlag(ButtonFlags.B_FLAG, b8 & 0x40); // Circle
    this.setButtonFlag(ButtonFlags.Y_FLAG, b8 & 0x80); // Triangle

    this.setButtonFlag(ButtonFlags.LB_FLAG, b9 & 0x01); // L1
    this.setButtonFlag(ButtonFlags.RB_FLAG, b9 & 0x02); // R1
    this.setButtonFlag(ButtonFlags.BACK_FLAG, b9 & 0x10); // Create (Share)
    this.setButtonFlag(ButtonFlags.PLAY_FLAG, b9 & 0x20); // Options
    this.setButtonFlag(ButtonFlags.LS_CLK_FLAG, b9 & 0x40); // L3
    this.setButtonFlag(ButtonFlags.RS_CLK_FLAG, b9 & 0x80); // R3

    this.setButtonFlag(ButtonFlags.SPECIAL_BUTTON_FLAG, b10 & 0x01); // PS
    this.setButtonFlag(ButtonFlags.TOUCHPAD_FLAG, b10 & 0x02); // Touchpad click
    this.setButtonFlag(ButtonFlags.MISC_FLAG, b10 & 0x04); // Mute

    // DualSense touchpad resolution: 1920 x 1080
    if (buffer.length >= 37) {
      const contactByte = buffer[33];
      const isActive = (contactByte & 0x80) === 0;
      this.touchpadActive = isActive;
      if (isActive) {
        this.touchpadX = buffer[34] | ((buffer[35] & 0x0f) << 8);
        this.touchpadY = ((buffer[35] & 0xf0) >> 4) | (buffer[36] << 4);
      }
    }

    if (buffer.length >= offset + 12) {
      const GYRO_SCALE = 2000.0 / 32768.0;
      const ACCEL_SCALE = 4.0 / 32768.0;
      const G_TO_MS2 = 9.81;

      const imuOffset = 16;

      if (buffer.length >= imuOffset + 12) {
        const gyrox = readShortLE(buffer, imuOffset);
        const gyroy = readShortLE(buffer, imuOffset + 2);
        const gyroz = readShortLE(buffer, imuOffset + 4);

        const accelx = readShortLE(buffer, imuOffset + 6);
        const accely = readShortLE(buffer, imuOffset + 8);
        const accelz = readShortLE(buffer, imuOffset + 10);

        this.gyroX = gyrox * GYRO_SCALE;
        this.gyroY = gyroy * GYRO_SCALE;
        this.gyroZ = gyroz * GYRO_SCALE;

        this.accelX = accelx * ACCEL_SCALE * G_TO_MS2;
        this.accelY = accely * ACCEL_SCALE * G_TO_MS2;
        this.accelZ = accelz * ACCEL_SCALE * G_TO_MS2;
      }
    }

    return true;
  }

  protected getInitData(): Uint8Array {
    return new Uint8Array(0);
  }

  protected doInit(): boolean {
    console.info(`${TAG} 初始化 DualSense 控制器`);
    const initData = this.getInitData();
    if (initData.length > 0) {
      this.sendCommand(initData);
    }
    return true;
  }

  rumble(lowFreqMotor: number, highFreqMotor: number): void {
    if (lowFreqMotor !== 0 || highFreqMotor !== 0) {
      if (lowFreqMotor === this.lastRumbleLow && highFreqMotor === this.lastRumbleHigh) {
        return;
      }
    }
    this.lastRumbleLow = lowFreqMotor;
    this.lastRumbleHigh = highFreqMotor;

    const data = new Uint8Array(48);
    data[0] = 0x02;
    data[1] = 0xff;
    data[2] = 0xf7;

    data[3] = (highFreqMotor >> 8) & 0xff;
    data[4] = (lowFreqMotor >> 8) & 0xff;

    data[11] = 0x00;
    data[22] = 0x00;

    data[45] = 0x02;
    data[46] = 0x00; // R
    data[47] = 0x00; // G

    this.bulkWrite(data);
  }

  rumbleTriggers(leftTrigger: number, rightTrigger: number): void {
    const data = new Uint8Array(48);
    data[0] = 0x02;
    data[1] = 0x04;
    data[2] = 0x00;

    data[11] = 0x01;
    data[12] = 0x00;
    data[13] = (rightTrigger >> 8) & 0xff;

    data[22] = 0x01;
    data[23] = 0x00;
    data[24] = (leftTrigger >> 8) & 0xff;

    this.bulkWrite(data);
  }
}
