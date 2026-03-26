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
import { AXIS_MAX, TRIGGER_MAX, RUMBLE_MAX } from "../GamepadTypes";
import {
  NativeHidParserService,
  NativeGamepadState,
  NativeGamepadType,
  NativeButtonFlags,
} from "./NativeHidParserService";
import { isHardwareError, createUsbError, UsbError } from "./UsbErrorCodes";

const TAG = "[USB-NativeHID]";

export class NativeHidController extends AbstractController {
  private device: usbManager.USBDevice;
  private pipe: usbManager.USBDevicePipe;
  private running: boolean = false;
  private inputEndpoint: number = 0;
  private outputEndpoint: number = 0;
  private inputMaxPacketSize: number = 64;
  private interfaceId: number = 0;
  private nativeParser: NativeHidParserService;
  private forceProtocolType: number = 0;

  private lastActivityTime: number = 0;
  private consecutiveTimeouts: number = 0;
  private static readonly SILENT_DISCONNECT_TIMEOUT_COUNT = 10;

  static readonly PROTOCOL_AUTO = 0;
  static readonly PROTOCOL_XBOX = 1;
  static readonly PROTOCOL_DS4 = 2;
  static readonly PROTOCOL_SWITCH = 3;
  static readonly PROTOCOL_GENERIC = 4;
  static readonly PROTOCOL_DUALSENSE = 5;

  constructor(
    device: usbManager.USBDevice,
    pipe: usbManager.USBDevicePipe,
    deviceId: number,
    listener: UsbDriverListener,
  ) {
    super(deviceId, listener, device.vendorId, device.productId);
    this.device = device;
    this.pipe = pipe;
    this.nativeParser = NativeHidParserService.getInstance();

    this.nativeParser.init();

    const nativeType = this.nativeParser.getGamepadType(device.vendorId, device.productId);
    this.deviceName = this.nativeParser.getGamepadName(device.vendorId, device.productId);

    switch (nativeType) {
      case NativeGamepadType.XBOX:
        this.type = ControllerType.XBOX;
        break;
      case NativeGamepadType.PLAYSTATION:
        this.type = ControllerType.PS;
        break;
      case NativeGamepadType.SWITCH:
        this.type = ControllerType.NINTENDO;
        break;
      default:
        this.type = ControllerType.XBOX;
    }

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

    console.info(`${TAG} 创建控制器: ${this.deviceName} (type=${nativeType})`);
  }

  setForceProtocolType(protocolType: number): void {
    this.forceProtocolType = protocolType;
    console.info(`${TAG} 设置强制协议类型: ${protocolType}`);
  }

  getForceProtocolType(): number {
    return this.forceProtocolType;
  }

  private static readonly HID_SUBCLASS_BOOT = 1;
  private static readonly HID_PROTOCOL_KEYBOARD = 1;
  private static readonly HID_PROTOCOL_MOUSE = 2;

  static canClaimDevice(device: usbManager.USBDevice): boolean {
    const parser = NativeHidParserService.getInstance();
    parser.init();

    if (parser.isSupportedGamepad(device.vendorId, device.productId)) {
      console.info(
        `${TAG} 原生支持的手柄: VID=0x${device.vendorId.toString(16)}, PID=0x${device.productId.toString(16)}`,
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
        if (iface.subClass === NativeHidController.HID_SUBCLASS_BOOT) {
          if (iface.protocol === NativeHidController.HID_PROTOCOL_KEYBOARD) {
            console.info(
              `${TAG} 跳过键盘设备: VID=0x${device.vendorId.toString(16)}, PID=0x${device.productId.toString(16)}`,
            );
            return false;
          }
          if (iface.protocol === NativeHidController.HID_PROTOCOL_MOUSE) {
            console.info(
              `${TAG} 跳过鼠标设备: VID=0x${device.vendorId.toString(16)}, PID=0x${device.productId.toString(16)}`,
            );
            return false;
          }
        }

        const nameLower = device.name.toLowerCase();
        if (nameLower.includes("keyboard") || nameLower.includes("键盘")) {
          console.info(`${TAG} 通过名称跳过键盘: ${device.name}`);
          return false;
        }
        if (nameLower.includes("mouse") || nameLower.includes("鼠标")) {
          console.info(`${TAG} 通过名称跳过鼠标: ${device.name}`);
          return false;
        }

        console.info(
          `${TAG} 检测到 HID 接口设备: VID=0x${device.vendorId.toString(16)}, PID=0x${device.productId.toString(16)}, subClass=${iface.subClass}, protocol=${iface.protocol}`,
        );
        return true;
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
          console.info(
            `${TAG} 端点[${j}]: addr=0x${ep.address.toString(16)}, dir=${ep.direction & 0x80 ? "IN" : "OUT"}, type=${ep.attributes}, maxPkt=${ep.maxPacketSize}, interval=${ep.interval}ms`,
          );

          if ((ep.direction & 0x80) !== 0) {
            this.inputEndpoint = ep.address;
            this.inputMaxPacketSize = ep.maxPacketSize;
          } else {
            this.outputEndpoint = ep.address;
          }
        }

        this.interfaceId = iface.id;

        try {
          const ret = usbManager.claimInterface(this.pipe, iface, true);
          if (ret === 0) {
            console.info(`${TAG} 成功声明 HID 接口 (id=${iface.id})`);
          }
        } catch (err) {
          console.error(`${TAG} 声明接口失败:`, err);
        }

        break;
      }
    }

    console.info(
      `${TAG} 端点配置: IN=0x${this.inputEndpoint.toString(16)}, OUT=0x${this.outputEndpoint.toString(16)}`,
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

    this.markInitializing();
    this.running = true;
    this.lastActivityTime = Date.now();
    this.notifyDeviceAdded();

    this.inputLoop();

    console.info(`${TAG} 控制器已启动 (ArkTS 轮询): ${this.deviceName}`);
    return true;
  }

  stop(): void {
    if (!this.running) {
      return;
    }

    this.running = false;
    this.markStopped();

    this.notifyDeviceRemoved();

    if (this.pipe && this.device) {
      try {
        const config = this.device.configs[0];
        if (config && config.interfaces) {
          let released = false;
          for (let i = 0; i < config.interfaces.length; i++) {
            const iface = config.interfaces[i];
            if (iface.clazz === 3 /* USB_CLASS_HID */) {
              usbManager.releaseInterface(this.pipe, iface);
              console.info(`${TAG} 已释放 HID 接口 ${i}`);
              released = true;
              break;
            }
          }
          if (!released) {
            console.warn(`${TAG} 未找到 HID 接口（共 ${config.interfaces.length} 个接口）`);
          }
        }
      } catch (err) {
        console.error(`${TAG} 释放接口异常:`, err);
      }
    }

    try {
      usbManager.closePipe(this.pipe);
      console.info(`${TAG} closePipe 成功`);
    } catch (err) {
      console.error(`${TAG} closePipe 失败:`, err);
    }

    console.info(`${TAG} 控制器已停止: ${this.deviceName}`);
  }

  isConnected(): boolean {
    return this.running;
  }

  getLastActivityTime(): number {
    return this.lastActivityTime;
  }

  mayBeSilentlyDisconnected(inactivityThresholdMs: number = 30000): boolean {
    if (!this.running) {
      return true;
    }
    const now = Date.now();
    return now - this.lastActivityTime > inactivityThresholdMs;
  }

  private handlePollerError(errorCode: number): void {
    if (errorCode === -4) {
      if (this.ignoreDisconnect) {
        console.warn(`${TAG} Native 轮询: 设备不可达但忽略断开信号已启用`);
        return;
      }
      console.warn(`${TAG} Native 轮询: 设备断开 (code=${errorCode})`);
      this.stop();
    } else if (errorCode === -1 || errorCode === -9) {
      // USB_ERROR_IO / USB_ERROR_PIPE
      if (this.ignoreDisconnect) {
        console.warn(`${TAG} Native 轮询: 硬件错误但忽略断开信号已启用`);
        return;
      }
      console.error(`${TAG} Native 轮询: 硬件错误 (code=${errorCode})`);
      this.stop();
    } else {
      console.warn(`${TAG} Native 轮询: 未知错误 (code=${errorCode})`);
      if (!this.ignoreDisconnect) {
        this.stop();
      }
    }
  }

  private async inputLoop(): Promise<void> {
    const buffer = new Uint8Array(this.inputMaxPacketSize);
    let isSleepMode = false;
    let hardwareError = false;

    const BULK_READ_TIMEOUT = 3000;
    const QUICK_FAIL_THRESHOLD = 1000;

    let pollCount = 0;
    let lastStatTime = Date.now();
    const STAT_INTERVAL_MS = 5000;

    this.lastActivityTime = Date.now();
    this.consecutiveTimeouts = 0;

    while (this.running) {
      const startTime = Date.now();

      try {
        const result = await this.bulkRead(buffer);
        if (result > 0) {
          pollCount++;
          this.consecutiveTimeouts = 0;
          this.lastActivityTime = Date.now();

          this.processInputReport(buffer.slice(0, result));

          const now = Date.now();
          if (now - lastStatTime >= STAT_INTERVAL_MS) {
            const pollRate = (pollCount * 1000) / (now - lastStatTime);
            console.info(
              `${TAG} 轮询率: ${pollRate.toFixed(1)} Hz (${pollCount} 次/${((now - lastStatTime) / 1000).toFixed(1)}秒)`,
            );
            pollCount = 0;
            lastStatTime = now;
          }
        }
      } catch (err) {
        if (this.running) {
          const elapsedTime = Date.now() - startTime;

          const usbErr = err instanceof UsbError ? err : null;
          const errorCode = usbErr ? usbErr.code : 0;
          const retryable = usbErr ? usbErr.retryable : true;

          if (errorCode === -8) {
            // USB_ERROR_TIMEOUT
            if (elapsedTime < QUICK_FAIL_THRESHOLD) {
              console.warn(
                `${TAG} 检测到设备 I/O 错误（快速失败：${elapsedTime}ms < ${QUICK_FAIL_THRESHOLD}ms）`,
              );
              if (this.ignoreDisconnect) {
                console.info(`${TAG} 忽略快速失败错误（用户已启用忽略断开设置）`);
                await this.sleep(50);
                continue;
              }
              hardwareError = true;
              break;
            }

            this.consecutiveTimeouts++;
            if (this.consecutiveTimeouts >= NativeHidController.SILENT_DISCONNECT_TIMEOUT_COUNT) {
              console.warn(
                `${TAG} 检测到可能的静默断开: 连续 ${this.consecutiveTimeouts} 次超时无数据`,
              );
              if (this.ignoreDisconnect) {
                console.info(`${TAG} 忽略静默断开检测（用户已启用忽略断开设置）`);
                this.consecutiveTimeouts = 0;
                continue;
              }
              isSleepMode = true;
              break;
            }

            continue;
          } else if (errorCode === -4) {
            // USB_ERROR_NO_DEVICE
            console.warn(`${TAG} 设备不可达: ${err}`);
            if (this.ignoreDisconnect) {
              console.info(`${TAG} 忽略设备不可达错误（用户已启用忽略断开设置）`);
              await this.sleep(50);
              continue;
            }
            isSleepMode = true;
            break;
          } else if (isHardwareError(errorCode)) {
            console.error(`${TAG} 检测到硬件错误: ${err}`);
            if (this.ignoreDisconnect) {
              console.info(`${TAG} 忽略硬件错误（用户已启用忽略断开设置）`);
              await this.sleep(50);
              continue;
            }
            hardwareError = true;
            break;
          } else {
            if (elapsedTime < QUICK_FAIL_THRESHOLD) {
              console.warn(
                `${TAG} 检测到设备 I/O 错误（错误码: ${errorCode}, 耗时: ${elapsedTime}ms）`,
              );
              if (this.ignoreDisconnect) {
                console.info(`${TAG} 忽略快速失败错误（用户已启用忽略断开设置）`);
                await this.sleep(50);
                continue;
              }
              hardwareError = true;
              break;
            }
            console.error(`${TAG} 输入读取错误: ${err}`);
            if (!retryable) {
              if (this.ignoreDisconnect) {
                console.info(`${TAG} 忽略不可重试错误（用户已启用忽略断开设置）`);
                await this.sleep(50);
                continue;
              }
              break;
            }
            await this.sleep(50);
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
    const timeout: number = 3000;

    try {
      const endpoint: usbManager.USBEndpoint = {
        address: this.inputEndpoint,
        attributes: 3,
        interval: 1,
        maxPacketSize: this.inputMaxPacketSize,
        direction: 0x80 as usbManager.USBRequestDirection,
        interfaceId: 0,
        number: this.inputEndpoint,
        type: 3,
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

  private processInputReport(data: Uint8Array): void {
    const state = this.nativeParser.parseHidReport(
      this.vendorId,
      this.productId,
      data,
      this.forceProtocolType,
    );

    if (!state) {
      const hexStr = Array.from(data.slice(0, Math.min(data.length, 16)))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join(" ");
      this.fallbackParseHidReport(data, hexStr);
      return;
    }

    this.buttonFlags = this.convertNativeButtons(state.buttons);

    this.leftStickX = state.leftStickX / AXIS_MAX;
    this.leftStickY = state.leftStickY / AXIS_MAX;
    this.rightStickX = state.rightStickX / AXIS_MAX;
    this.rightStickY = state.rightStickY / AXIS_MAX;

    this.leftTrigger = state.leftTrigger / TRIGGER_MAX;
    this.rightTrigger = state.rightTrigger / TRIGGER_MAX;

    this.reportInput();
  }

  /**
   *
   * [1] = Left Stick X (0x00-0xFF, 0x80 = center)
   * [2] = Left Stick Y (0x00-0xFF, 0x80 = center)
   * [3] = Right Stick X (0x00-0xFF, 0x80 = center)
   * [4] = Right Stick Y (0x00-0xFF, 0x80 = center)
   * [5] = Triggers/misc (varies)
   * [6] = HAT/D-Pad (0x0F = center, 0-7 = directions)
   * [7] = Buttons byte 1 (function buttons: Start, Select, LS, RS, etc.)
   * [8] = Buttons byte 2 (face buttons: A, B, X, Y, LB, RB)
   * [9] = Reserved
   */
  private fallbackParseHidReport(data: Uint8Array, hexStr: string): void {
    if (data.length < 9) {
      console.warn(`${TAG} HID 数据太短: ${data.length}`);
      return;
    }

    this.leftStickX = (data[1] - 128) / 127.0;
    this.leftStickY = (data[2] - 128) / 127.0;
    this.rightStickX = (data[3] - 128) / 127.0;
    this.rightStickY = (data[4] - 128) / 127.0;

    this.leftStickX = Math.max(-1.0, Math.min(1.0, this.leftStickX));
    this.leftStickY = Math.max(-1.0, Math.min(1.0, this.leftStickY));
    this.rightStickX = Math.max(-1.0, Math.min(1.0, this.rightStickX));
    this.rightStickY = Math.max(-1.0, Math.min(1.0, this.rightStickY));

    let flags = 0;
    const hat = data[6] & 0x0f;
    switch (hat) {
      case 0: // Up
        flags |= ButtonFlags.UP_FLAG;
        break;
      case 1: // Up-Right
        flags |= ButtonFlags.UP_FLAG | ButtonFlags.RIGHT_FLAG;
        break;
      case 2: // Right
        flags |= ButtonFlags.RIGHT_FLAG;
        break;
      case 3: // Down-Right
        flags |= ButtonFlags.DOWN_FLAG | ButtonFlags.RIGHT_FLAG;
        break;
      case 4: // Down
        flags |= ButtonFlags.DOWN_FLAG;
        break;
      case 5: // Down-Left
        flags |= ButtonFlags.DOWN_FLAG | ButtonFlags.LEFT_FLAG;
        break;
      case 6: // Left
        flags |= ButtonFlags.LEFT_FLAG;
        break;
      case 7: // Up-Left
        flags |= ButtonFlags.UP_FLAG | ButtonFlags.LEFT_FLAG;
        break;
      default: // 0x0F = center, no direction
        break;
    }

    const btn1 = data[7];
    const btn2 = data[8];

    //   bit 0 = Select/Back
    //   bit 1 = Start
    //   bit 2 = Home/Guide
    //   bit 3 = Left Stick Click
    //   bit 4 = Right Stick Click
    //   bit 5 = LB
    //   bit 6 = RB
    //   bit 7 = LT (digital)
    //
    //   bit 0 = A
    //   bit 1 = B
    //   bit 2 = X
    //   bit 3 = Y

    if (btn1 & 0x01) flags |= ButtonFlags.BACK_FLAG; // Select/Back
    if (btn1 & 0x02) flags |= ButtonFlags.PLAY_FLAG; // Start
    if (btn1 & 0x04) flags |= ButtonFlags.SPECIAL_BUTTON_FLAG; // Home/Guide
    if (btn1 & 0x08) flags |= ButtonFlags.LS_CLK_FLAG; // Left Stick Click
    if (btn1 & 0x10) flags |= ButtonFlags.RS_CLK_FLAG; // Right Stick Click
    if (btn1 & 0x20) flags |= ButtonFlags.LB_FLAG; // LB
    if (btn1 & 0x40) flags |= ButtonFlags.RB_FLAG; // RB

    if (btn2 & 0x01) flags |= ButtonFlags.A_FLAG; // A
    if (btn2 & 0x02) flags |= ButtonFlags.B_FLAG; // B
    if (btn2 & 0x04) flags |= ButtonFlags.X_FLAG; // X
    if (btn2 & 0x08) flags |= ButtonFlags.Y_FLAG; // Y

    this.buttonFlags = flags;

    this.reportInput();
  }

  private convertNativeButtons(nativeButtons: number): number {
    let flags = 0;

    if (nativeButtons & NativeButtonFlags.UP) flags |= ButtonFlags.UP_FLAG;
    if (nativeButtons & NativeButtonFlags.DOWN) flags |= ButtonFlags.DOWN_FLAG;
    if (nativeButtons & NativeButtonFlags.LEFT) flags |= ButtonFlags.LEFT_FLAG;
    if (nativeButtons & NativeButtonFlags.RIGHT) flags |= ButtonFlags.RIGHT_FLAG;

    if (nativeButtons & NativeButtonFlags.START) flags |= ButtonFlags.PLAY_FLAG;
    if (nativeButtons & NativeButtonFlags.BACK) flags |= ButtonFlags.BACK_FLAG;
    if (nativeButtons & NativeButtonFlags.LS_CLK) flags |= ButtonFlags.LS_CLK_FLAG;
    if (nativeButtons & NativeButtonFlags.RS_CLK) flags |= ButtonFlags.RS_CLK_FLAG;

    if (nativeButtons & NativeButtonFlags.LB) flags |= ButtonFlags.LB_FLAG;
    if (nativeButtons & NativeButtonFlags.RB) flags |= ButtonFlags.RB_FLAG;

    if (nativeButtons & NativeButtonFlags.A) flags |= ButtonFlags.A_FLAG;
    if (nativeButtons & NativeButtonFlags.B) flags |= ButtonFlags.B_FLAG;
    if (nativeButtons & NativeButtonFlags.X) flags |= ButtonFlags.X_FLAG;
    if (nativeButtons & NativeButtonFlags.Y) flags |= ButtonFlags.Y_FLAG;

    if (nativeButtons & NativeButtonFlags.HOME) flags |= ButtonFlags.SPECIAL_BUTTON_FLAG;

    return flags;
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

    const cmd = this.nativeParser.createRumbleCommand(
      this.vendorId,
      this.productId,
      Math.round(lowFreqMotor * RUMBLE_MAX),
      Math.round(highFreqMotor * RUMBLE_MAX),
    );

    if (cmd) {
      this.sendOutputReport(cmd);
    }
  }

  private async sendOutputReport(data: Uint8Array): Promise<void> {
    if (this.outputEndpoint === 0) {
      return;
    }

    try {
      const endpoint: usbManager.USBEndpoint = {
        address: this.outputEndpoint,
        attributes: 3,
        interval: 1,
        maxPacketSize: 64,
        direction: 0x00 as usbManager.USBRequestDirection,
        interfaceId: 0,
        number: this.outputEndpoint,
        type: 3,
      };

      await usbManager.bulkTransfer(this.pipe, endpoint, data, 100);
    } catch (err) {
      console.error(`${TAG} 发送输出报告失败:`, err);
    }
  }

  rumbleTriggers(leftTrigger: number, rightTrigger: number): void {}
}
