/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import nativeLib from "libmoonlight_nativelib.so";

export interface GameControllerDeviceInfo {
  deviceId: string;
  name: string;
  product: number;
  deviceType: number;
  isConnected: boolean;
  physicalAddress?: string;
}

export type DeviceCallback = (
  deviceId: string,
  isConnected: boolean,
  info: GameControllerDeviceInfo,
) => void;

export type ButtonCallback = (deviceId: string, buttonCode: number, isPressed: boolean) => void;

export type AxisCallback = (deviceId: string, axisType: number, x: number, y: number) => void;

interface NativeGameController {
  isAvailable(): boolean;
  init(): number;
  uninit(): void;
  startMonitor(): number;
  stopMonitor(): void;
  pauseInputMonitor(): void;
  resumeInputMonitor(): void;
  setDeviceCallback(callback: DeviceCallback | null): void;
  setButtonCallback(callback: ButtonCallback | null): void;
  setAxisCallback(callback: AxisCallback | null): void;
  getDeviceCount(): number;
  getDeviceInfo(index: number): GameControllerDeviceInfo | null;
  heartbeatCheck(): number;
  refreshDevices(): number;

  AXIS_LEFT_THUMBSTICK: number;
  AXIS_RIGHT_THUMBSTICK: number;
  AXIS_DPAD: number;
  AXIS_LEFT_TRIGGER: number;
  AXIS_RIGHT_TRIGGER: number;

  KEYCODE_BUTTON_A: number;
  KEYCODE_BUTTON_B: number;
  KEYCODE_BUTTON_X: number;
  KEYCODE_BUTTON_Y: number;
}

interface NativeLibModule {
  GameController?: NativeGameController;
}

const native = (nativeLib as NativeLibModule).GameController;

export class AxisType {
  static readonly LEFT_THUMBSTICK = 0;
  static readonly RIGHT_THUMBSTICK = 1;
  static readonly DPAD = 2;
  static readonly LEFT_TRIGGER = 3;
  static readonly RIGHT_TRIGGER = 4;
}

export class ButtonCode {
  static readonly BUTTON_A = 2301;
  static readonly BUTTON_B = 2302;
  static readonly BUTTON_C = 2303;
  static readonly BUTTON_X = 2304;
  static readonly BUTTON_Y = 2305;
  static readonly LEFT_SHOULDER = 2307;
  static readonly RIGHT_SHOULDER = 2308;
  static readonly LEFT_TRIGGER = 2309;
  static readonly RIGHT_TRIGGER = 2310;
  static readonly BUTTON_HOME = 2311;
  static readonly BUTTON_MENU = 2312;
  static readonly LEFT_THUMBSTICK = 2314;
  static readonly RIGHT_THUMBSTICK = 2315;
  static readonly DPAD_UP = 2012;
  static readonly DPAD_DOWN = 2013;
  static readonly DPAD_LEFT = 2014;
  static readonly DPAD_RIGHT = 2015;
}

export class GameControllerService {
  private static instance: GameControllerService;
  private initialized: boolean = false;
  private monitoring: boolean = false;

  private deviceCallback: DeviceCallback | null = null;
  private buttonCallback: ButtonCallback | null = null;
  private axisCallback: AxisCallback | null = null;

  private constructor() {}

  static getInstance(): GameControllerService {
    if (!GameControllerService.instance) {
      GameControllerService.instance = new GameControllerService();
    }
    return GameControllerService.instance;
  }

  isAvailable(): boolean {
    if (!native) {
      console.warn("[GameController] Native 模块不可用");
      return false;
    }
    return native.isAvailable();
  }

  init(): boolean {
    if (!native) {
      console.error("[GameController] Native 模块不可用");
      return false;
    }

    if (this.initialized) {
      console.warn("[GameController] 已初始化");
      return true;
    }

    const result = native.init();
    if (result === 0) {
      this.initialized = true;
      console.info("[GameController] 初始化成功");
      return true;
    } else {
      console.error(`[GameController] 初始化失败: ${result}`);
      return false;
    }
  }

  uninit(): void {
    if (!native || !this.initialized) return;

    this.stopMonitor();
    native.uninit();
    this.initialized = false;
    console.info("[GameController] 已反初始化");
  }

  setDeviceCallback(callback: DeviceCallback | null): void {
    this.deviceCallback = callback;
    if (native) {
      native.setDeviceCallback(callback);
    }
  }

  setButtonCallback(callback: ButtonCallback | null): void {
    this.buttonCallback = callback;
    if (native) {
      native.setButtonCallback(callback);
    }
  }

  setAxisCallback(callback: AxisCallback | null): void {
    this.axisCallback = callback;
    if (native) {
      native.setAxisCallback(callback);
    }
  }

  startMonitor(): boolean {
    if (!native || !this.initialized) {
      console.error("[GameController] 未初始化");
      return false;
    }

    if (this.monitoring) {
      native.startMonitor();
      return true;
    }

    const result = native.startMonitor();
    if (result === 0) {
      this.monitoring = true;
      console.info("[GameController] 开始监听");
      return true;
    } else {
      console.error(`[GameController] 开始监听失败: ${result}`);
      return false;
    }
  }

  stopMonitor(): void {
    if (!native || !this.monitoring) return;

    native.stopMonitor();
    this.monitoring = false;
    console.info("[GameController] 停止监听");
  }

  pauseInputMonitor(): void {
    if (!native || !this.monitoring) return;
    native.pauseInputMonitor();
    console.info("[GameController] 暂停输入监听（设备监听保持活跃）");
  }

  resumeInputMonitor(): void {
    if (!native || !this.monitoring) return;
    native.resumeInputMonitor();
    console.info("[GameController] 恢复输入监听");
  }

  getDeviceCount(): number {
    if (!native) return 0;
    return native.getDeviceCount();
  }

  getDeviceInfo(index: number): GameControllerDeviceInfo | null {
    if (!native) return null;
    return native.getDeviceInfo(index);
  }

  getAllDevices(): GameControllerDeviceInfo[] {
    const devices: GameControllerDeviceInfo[] = [];
    const count = this.getDeviceCount();
    for (let i = 0; i < count; i++) {
      const info = this.getDeviceInfo(i);
      if (info) {
        devices.push(info);
      }
    }
    return devices;
  }

  /**
   *
   *
   *
   */
  refreshDeviceCache(): number {
    if (!native || !this.initialized) {
      console.warn("[GameController] refreshDeviceCache: 未初始化");
      return -1;
    }
    const result = native.refreshDevices();
    console.info(`[GameController] refreshDeviceCache: 新发现 ${result} 个设备`);
    return result;
  }

  /**
   *
   *
   */
  heartbeatCheck(): number {
    if (!native || !this.initialized || !this.monitoring) {
      return 0;
    }
    return native.heartbeatCheck();
  }
}

export const gameControllerService = GameControllerService.getInstance();
