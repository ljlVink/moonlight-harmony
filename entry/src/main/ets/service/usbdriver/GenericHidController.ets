/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

/**
 *
 */

import { usbManager } from "@kit.BasicServicesKit";
import { AbstractController } from "./AbstractController";
import { UsbDriverListener } from "./UsbDriverListener";
import {
  ButtonFlags,
  UsbClass,
  ControllerType,
  ControllerCapabilities,
} from "./ControllerConstants";
import { isHardwareError, createUsbError, UsbError } from "./UsbErrorCodes";

const TAG = "[USB-HID]";

export class GenericHidVendors {
  static readonly SUPPORTED_VENDORS: number[] = [
    0x413d,
    0x0079, // DragonRise
    0x11c0, // Generic
    0x2563, // ShenZhen ShanWan
    0x20bc, // ShenZhen Sailtel
    0x11c1, // Generic gamepad
    0x1345, // Generic
    0x1949, // Lab126 (Amazon Luna)
    0x0583, // Generic gamepad
    0x2dc8,
    0x2f24, // GameSir
  ];
}

export class GenericHidController extends AbstractController {
  private device: usbManager.USBDevice;
  private pipe: usbManager.USBDevicePipe;
  private running: boolean = false;
  private inputEndpoint: number = 0;
  private outputEndpoint: number = 0;
  private inputMaxPacketSize: number = 64;

  private reportOffset: number = 0;
  private lastHexReport: string = "";

  constructor(
    device: usbManager.USBDevice,
    pipe: usbManager.USBDevicePipe,
    deviceId: number,
    listener: UsbDriverListener,
  ) {
    super(deviceId, listener, device.vendorId, device.productId);
    this.device = device;
    this.pipe = pipe;
    this.type = ControllerType.XBOX;
    this.deviceName = `Generic HID Controller (${device.name || "Unknown"})`;
    this.capabilities = ControllerCapabilities.ANALOG_TRIGGERS | ControllerCapabilities.RUMBLE;

    this.supportedButtonFlags =
      ButtonFlags.A_FLAG |
      ButtonFlags.B_FLAG |
      ButtonFlags.X_FLAG |
      ButtonFlags.Y_FLAG |
      ButtonFlags.UP_FLAG |
      ButtonFlags.DOWN_FLAG |
      ButtonFlags.LEFT_FLAG |
      ButtonFlags.RIGHT_FLAG |
      ButtonFlags.LB_FLAG |
      ButtonFlags.RB_FLAG |
      ButtonFlags.LS_CLK_FLAG |
      ButtonFlags.RS_CLK_FLAG |
      ButtonFlags.BACK_FLAG |
      ButtonFlags.PLAY_FLAG |
      ButtonFlags.SPECIAL_BUTTON_FLAG;

    this.findEndpoints();
  }

  static canClaimDevice(device: usbManager.USBDevice): boolean {
    if (GenericHidVendors.SUPPORTED_VENDORS.includes(device.vendorId)) {
      console.info(
        `${TAG} 检测到通用 HID 手柄: VID=0x${device.vendorId.toString(16)}, PID=0x${device.productId.toString(16)}`,
      );
      return true;
    }

    if (!device.configs || device.configs.length === 0) {
      return false;
    }

    const config = device.configs[0];
    if (!config.interfaces || config.interfaces.length === 0) {
      return false;
    }

    for (let i = 0; i < config.interfaces.length; i++) {
      const iface = config.interfaces[i];
      if (iface.clazz === UsbClass.USB_CLASS_HID) {
        console.info(
          `${TAG} 检测到 HID 接口的设备: VID=0x${device.vendorId.toString(16)}, PID=0x${device.productId.toString(16)}`,
        );
        return false;
      }
    }

    return false;
  }

  private findEndpoints(): void {
    if (!this.device.configs || this.device.configs.length === 0) {
      return;
    }

    const config = this.device.configs[0];
    if (!config.interfaces || config.interfaces.length === 0) {
      return;
    }

    for (let i = 0; i < config.interfaces.length; i++) {
      const iface = config.interfaces[i];
      if (iface.clazz === UsbClass.USB_CLASS_HID && iface.endpoints) {
        for (let j = 0; j < iface.endpoints.length; j++) {
          const ep = iface.endpoints[j];
          if ((ep.direction & 0x80) !== 0) {
            this.inputEndpoint = ep.address;
            this.inputMaxPacketSize = ep.maxPacketSize;
          } else {
            this.outputEndpoint = ep.address;
          }
        }

        try {
          const ret = usbManager.claimInterface(this.pipe, iface, true);
          if (ret === 0) {
            console.info(`${TAG} 成功声明 HID 接口`);
          }
        } catch (err) {
          console.error(`${TAG} 声明接口失败:`, err);
        }

        break;
      }
    }

    console.info(
      `${TAG} 端点配置: IN=0x${this.inputEndpoint.toString(16)}, OUT=0x${this.outputEndpoint.toString(16)}, MaxPacket=${this.inputMaxPacketSize}`,
    );
  }

  start(): boolean {
    if (this.running) {
      return true;
    }

    if (this.inputEndpoint === 0) {
      console.error(`${TAG} 无法启动: 未找到输入端点`);
      return false;
    }

    this.running = true;
    this.notifyDeviceAdded();

    this.inputLoop();

    console.info(`${TAG} 控制器已启动: ${this.deviceName}`);
    return true;
  }

  stop(): void {
    if (!this.running) {
      return;
    }

    this.running = false;
    this.notifyDeviceRemoved();

    if (this.pipe && this.device) {
      try {
        const config = this.device.configs[0];
        if (config && config.interfaces) {
          for (let i = 0; i < config.interfaces.length; i++) {
            const iface = config.interfaces[i];
            if (iface.clazz === UsbClass.USB_CLASS_HID) {
              usbManager.releaseInterface(this.pipe, iface);
              console.info(`${TAG} 已释放 HID 接口`);
              break;
            }
          }
        }
      } catch (err) {
        console.error(`${TAG} 释放接口失败:`, err);
      }
    }

    try {
      usbManager.closePipe(this.pipe);
    } catch (err) {
      console.error(`${TAG} 关闭管道失败:`, err);
    }

    console.info(`${TAG} 控制器已停止: ${this.deviceName}`);
  }

  private async inputLoop(): Promise<void> {
    const buffer = new Uint8Array(this.inputMaxPacketSize);
    let isSleepMode = false;
    let hardwareError = false;
    let consecutiveTimeouts = 0;
    const MAX_CONSECUTIVE_TIMEOUTS = 100;

    while (this.running) {
      try {
        const result = await this.bulkRead(buffer);
        if (result > 0) {
          consecutiveTimeouts = 0;
          this.processInputReport(buffer, result);
        }
      } catch (err) {
        if (this.running) {
          const usbErr = err instanceof UsbError ? err : null;
          const errorCode = usbErr ? usbErr.code : 0;
          const retryable = usbErr ? usbErr.retryable : true;

          if (errorCode === -8) {
            // USB_ERROR_TIMEOUT
            consecutiveTimeouts++;
            if (consecutiveTimeouts >= MAX_CONSECUTIVE_TIMEOUTS) {
              console.warn(`${TAG} 连续 ${consecutiveTimeouts} 次超时，设备可能进入省电模式`);
              isSleepMode = true;
              break;
            }
            continue;
          } else if (errorCode === -4) {
            // USB_ERROR_NO_DEVICE
            console.warn(`${TAG} 设备不可达: ${err}`);
            isSleepMode = true;
            break;
          } else if (isHardwareError(errorCode)) {
            console.error(`${TAG} 检测到硬件错误: ${err}`);
            hardwareError = true;
            break;
          } else {
            console.error(`${TAG} 输入读取错误: ${err}`);
            if (!retryable) {
              break;
            }
            await this.sleep(10);
          }
        }
      }
    }

    if (this.running) {
      if (hardwareError) {
        console.error(`${TAG} 由于硬件错误，自动停止控制器`);
        this.stop();
      } else if (isSleepMode) {
        console.info(`${TAG} 设备进入省电模式，等待自动重连...`);
        this.notifyDeviceRemoved();
      } else {
        console.warn(`${TAG} 由于 IO 错误，自动停止控制器`);
        this.stop();
      }
    }
  }

  private async bulkRead(buffer: Uint8Array): Promise<number> {
    const timeout: number = 100;

    try {
      const endpoint: usbManager.USBEndpoint = {
        address: this.inputEndpoint,
        attributes: 3, // Interrupt
        interval: 1,
        maxPacketSize: this.inputMaxPacketSize,
        direction: 0x80 as usbManager.USBRequestDirection, // IN
        interfaceId: 0,
        number: this.inputEndpoint,
        type: 3, // Interrupt type
      };

      const ret: number = await usbManager.bulkTransfer(this.pipe, endpoint, buffer, timeout);

      if (ret < 0) {
        throw createUsbError(ret);
      }

      return ret;
    } catch (err) {
      throw err as Error;
    }
  }

  /**
   *
   * [0] = Report ID (0x01)
   */
  private processInputReport(data: Uint8Array, length: number): void {
    if (length < 8) {
      return;
    }

    let offset = 0;
    if (data[0] === 0x01 || data[0] === 0x07 || data[0] === 0x20) {
      offset = 1;
    }

    const hexStr = Array.from(data.slice(0, Math.min(length, 16)))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join(" ");

    const currentHex = hexStr;
    if (this.lastHexReport !== currentHex) {
      console.info(`${TAG} 原始报告: ${currentHex}`);

      if (length >= 10) {
        console.info(
          `${TAG} 解析: LX=${data[1]} LY=${data[2]} RX=${data[3]} RY=${data[4]} ` +
            `B5=0x${data[5].toString(16)} B6=0x${data[6].toString(16)} ` +
            `B7=0x${data[7].toString(16)} B8=0x${data[8].toString(16)} B9=0x${data[9].toString(16)}`,
        );
      }
      this.lastHexReport = currentHex;
    }

    if (length >= offset + 8) {
      const lx = data[offset];
      const ly = data[offset + 1];
      const rx = data[offset + 2];
      const ry = data[offset + 3];

      this.leftStickX = this.convertAxis(lx);
      this.leftStickY = -this.convertAxis(ly);
      this.rightStickX = this.convertAxis(rx);
      this.rightStickY = -this.convertAxis(ry);

      if (length >= offset + 6) {
        const hatByte = data[offset + 5];
        const hat = hatByte & 0x0f;

        const highButtons = hatByte & 0xf0;

        this.processHat(hat);

        if ((highButtons & 0x10) !== 0) {
          this.buttonFlags |= ButtonFlags.LS_CLK_FLAG;
        }
        if ((highButtons & 0x20) !== 0) {
          this.buttonFlags |= ButtonFlags.RS_CLK_FLAG;
        }
      }

      if (length >= offset + 8) {
        const buttons1 = data[offset + 6];
        const buttons2 = data[offset + 7];

        const beforeFlags = this.buttonFlags;
        this.processButtonsGeneric(buttons1, buttons2);

        if (this.buttonFlags !== 0 || buttons1 !== 0 || buttons2 !== 0) {
          console.info(
            `${TAG} B7=0x${buttons1.toString(16)} B8=0x${buttons2.toString(16)} ` +
              `flags: 0x${beforeFlags.toString(16)} -> 0x${this.buttonFlags.toString(16)}`,
          );
        }
      }
    }

    this.reportInput();
  }

  private convertAxis(value: number): number {
    // 0-255 -> -1.0 to 1.0
    const normalized = value - 128;
    return normalized / 127;
  }

  /**
   *
   *
   *
   */
  private processHat(hat: number): void {
    this.buttonFlags &= ~(
      ButtonFlags.UP_FLAG |
      ButtonFlags.DOWN_FLAG |
      ButtonFlags.LEFT_FLAG |
      ButtonFlags.RIGHT_FLAG
    );

    if (hat === 0 || hat > 7) {
      return;
    }

    switch (hat) {
      case 1:
        this.buttonFlags |= ButtonFlags.UP_FLAG;
        break;
      case 2:
        this.buttonFlags |= ButtonFlags.UP_FLAG | ButtonFlags.RIGHT_FLAG;
        break;
      case 3:
        this.buttonFlags |= ButtonFlags.RIGHT_FLAG;
        break;
      case 4:
        this.buttonFlags |= ButtonFlags.DOWN_FLAG | ButtonFlags.RIGHT_FLAG;
        break;
      case 5:
        this.buttonFlags |= ButtonFlags.DOWN_FLAG;
        break;
      case 6:
        this.buttonFlags |= ButtonFlags.DOWN_FLAG | ButtonFlags.LEFT_FLAG;
        break;
      case 7:
        this.buttonFlags |= ButtonFlags.LEFT_FLAG;
        break;
    }
  }

  /**
   *
   *   - bit0 = Back/Select (0x01)
   *   - bit2 = Start (0x04)
   *   - bit3 = Guide (0x08)
   *
   *   - bit0 = A (0x01)
   *   - bit1 = B (0x02)
   *   - bit2 = X (0x04)
   *   - bit3 = Y (0x08)
   *   - bit4 = LB (0x10)
   *   - bit5 = RB (0x20)
   *   - bit6 = LT (0x40)
   *   - bit7 = RT (0x80)
   */
  private processButtonsGeneric(byte1: number, byte2: number): void {
    const preserveFlags =
      ButtonFlags.UP_FLAG |
      ButtonFlags.DOWN_FLAG |
      ButtonFlags.LEFT_FLAG |
      ButtonFlags.RIGHT_FLAG |
      ButtonFlags.LS_CLK_FLAG |
      ButtonFlags.RS_CLK_FLAG;
    this.buttonFlags &= preserveFlags;

    if ((byte1 & 0x01) !== 0) this.buttonFlags |= ButtonFlags.BACK_FLAG; // bit0 = Back/Select
    if ((byte1 & 0x04) !== 0) this.buttonFlags |= ButtonFlags.PLAY_FLAG; // bit2 = Start
    if ((byte1 & 0x08) !== 0) this.buttonFlags |= ButtonFlags.SPECIAL_BUTTON_FLAG; // bit3 = Guide

    if ((byte2 & 0x01) !== 0) this.buttonFlags |= ButtonFlags.A_FLAG; // bit0 = A
    if ((byte2 & 0x02) !== 0) this.buttonFlags |= ButtonFlags.B_FLAG; // bit1 = B
    if ((byte2 & 0x04) !== 0) this.buttonFlags |= ButtonFlags.X_FLAG; // bit2 = X
    if ((byte2 & 0x08) !== 0) this.buttonFlags |= ButtonFlags.Y_FLAG; // bit3 = Y
    if ((byte2 & 0x10) !== 0) this.buttonFlags |= ButtonFlags.LB_FLAG; // bit4 = LB
    if ((byte2 & 0x20) !== 0) this.buttonFlags |= ButtonFlags.RB_FLAG; // bit5 = RB

    if ((byte2 & 0x40) !== 0) {
      this.leftTrigger = 1.0;
    } else {
      this.leftTrigger = 0.0;
    }
    if ((byte2 & 0x80) !== 0) {
      this.rightTrigger = 1.0;
    } else {
      this.rightTrigger = 0.0;
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(() => resolve(), ms);
    });
  }

  rumble(lowFreqMotor: number, highFreqMotor: number): void {
    if (this.outputEndpoint === 0) {
      return;
    }
  }

  rumbleTriggers(leftTrigger: number, rightTrigger: number): void {}
}
