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
import { AbstractXboxController } from "./AbstractXboxController";
import { UsbDriverListener } from "./UsbDriverListener";
import { ButtonFlags, Xbox360, UsbClass } from "./ControllerConstants";
import { readShortLE, AXIS_MAX, TRIGGER_MAX } from "../GamepadTypes";

const TAG = "[USB-X360]";

export class Xbox360Controller extends AbstractXboxController {
  private lastRumbleLow: number = -1;
  private lastRumbleHigh: number = -1;

  constructor(
    device: usbManager.USBDevice,
    pipe: usbManager.USBDevicePipe,
    deviceId: number,
    listener: UsbDriverListener,
  ) {
    super(device, pipe, deviceId, listener);
    this.deviceName = "Xbox 360 Controller";
  }

  static canClaimDevice(device: usbManager.USBDevice): boolean {
    if (!Xbox360.SUPPORTED_VENDORS.includes(device.vendorId)) {
      return false;
    }

    if (!device.configs || device.configs.length === 0) {
      return false;
    }

    const config = device.configs[0];
    if (!config.interfaces || config.interfaces.length === 0) {
      return false;
    }

    const iface = config.interfaces[0];

    const isXbox360 =
      iface.clazz === UsbClass.USB_CLASS_VENDOR_SPEC &&
      iface.subClass === Xbox360.IFACE_SUBCLASS &&
      iface.protocol === Xbox360.IFACE_PROTOCOL;

    if (isXbox360) {
      console.info(
        `${TAG} 检测到 Xbox 360 控制器: VID=0x${device.vendorId.toString(16)}, PID=0x${device.productId.toString(16)}`,
      );
    }

    return isXbox360;
  }

  private unsignByte(b: number): number {
    return b & 0xff;
  }

  protected handleRead(buffer: Uint8Array): boolean {
    if (buffer.length < 14) {
      console.warn(`${TAG} 读取数据太短: ${buffer.length}`);
      return false;
    }

    if (buffer[0] !== 0x00 || buffer[1] !== 0x14) {
      return false;
    }

    let offset = 2;

    const b = buffer[offset++];
    this.setButtonFlag(ButtonFlags.LEFT_FLAG, b & 0x04);
    this.setButtonFlag(ButtonFlags.RIGHT_FLAG, b & 0x08);
    this.setButtonFlag(ButtonFlags.UP_FLAG, b & 0x01);
    this.setButtonFlag(ButtonFlags.DOWN_FLAG, b & 0x02);
    this.setButtonFlag(ButtonFlags.PLAY_FLAG, b & 0x10);
    this.setButtonFlag(ButtonFlags.BACK_FLAG, b & 0x20);
    this.setButtonFlag(ButtonFlags.LS_CLK_FLAG, b & 0x40);
    this.setButtonFlag(ButtonFlags.RS_CLK_FLAG, b & 0x80);

    const b2 = buffer[offset++];
    this.setButtonFlag(ButtonFlags.A_FLAG, b2 & 0x10);
    this.setButtonFlag(ButtonFlags.B_FLAG, b2 & 0x20);
    this.setButtonFlag(ButtonFlags.X_FLAG, b2 & 0x40);
    this.setButtonFlag(ButtonFlags.Y_FLAG, b2 & 0x80);
    this.setButtonFlag(ButtonFlags.LB_FLAG, b2 & 0x01);
    this.setButtonFlag(ButtonFlags.RB_FLAG, b2 & 0x02);
    this.setButtonFlag(ButtonFlags.SPECIAL_BUTTON_FLAG, b2 & 0x04);

    this.leftTrigger = this.unsignByte(buffer[offset++]) / TRIGGER_MAX;
    this.rightTrigger = this.unsignByte(buffer[offset++]) / TRIGGER_MAX;

    this.leftStickX = readShortLE(buffer, offset) / AXIS_MAX;
    offset += 2;
    this.leftStickY = -readShortLE(buffer, offset) / AXIS_MAX;
    offset += 2;

    this.rightStickX = readShortLE(buffer, offset) / AXIS_MAX;
    offset += 2;
    this.rightStickY = -readShortLE(buffer, offset) / AXIS_MAX;

    return true;
  }

  private async sendLedCommand(command: number): Promise<boolean> {
    const commandBuffer = new Uint8Array([0x01, 0x03, command]);

    const res = await this.bulkWrite(commandBuffer);
    if (res !== commandBuffer.length) {
      console.warn(`${TAG} LED 设置失败: ${res}`);
      return false;
    }

    return true;
  }

  protected doInit(): boolean {
    this.sendLedCommand(2 + (this.getControllerId() % 4));

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

    const data = new Uint8Array([
      0x00,
      0x08,
      0x00,
      (lowFreqMotor >> 8) & 0xff,
      (highFreqMotor >> 8) & 0xff,
      0x00,
      0x00,
      0x00,
    ]);

    this.bulkWrite(data);
  }

  rumbleTriggers(_leftTrigger: number, _rightTrigger: number): void {}
}
