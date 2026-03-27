/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import nativelib from "libmoonlight_nativelib.so";
import { NativeGamepadState, NativeButtonFlags, NativeGamepadType } from "./NativeGamepad";

const TAG = "[NativeHidParser]";

interface NativeGamepadModule {
  parseHidReport(
    vendorId: number,
    productId: number,
    data: Uint8Array,
    forceType?: number,
  ): NativeGamepadState;
  getGamepadType(vendorId: number, productId: number): number;
  isSupportedGamepad(vendorId: number, productId: number): boolean;
  getGamepadName(vendorId: number, productId: number): string;
  createRumbleCommand(
    vendorId: number,
    productId: number,
    lowFreq: number,
    highFreq: number,
  ): Uint8Array | null;
}

export class NativeHidParserService {
  private static instance: NativeHidParserService | null = null;
  private gamepadModule: NativeGamepadModule | null = null;
  private initialized: boolean = false;

  private constructor() {}

  static getInstance(): NativeHidParserService {
    if (!NativeHidParserService.instance) {
      NativeHidParserService.instance = new NativeHidParserService();
    }
    return NativeHidParserService.instance;
  }

  init(): boolean {
    if (this.initialized) {
      return true;
    }

    try {
      interface NativeLibWithGamepad {
        Gamepad?: NativeGamepadModule;
      }
      const lib = nativelib as NativeLibWithGamepad;
      if (lib.Gamepad !== undefined) {
        this.gamepadModule = lib.Gamepad;
        this.initialized = true;
        console.info(`${TAG} 原生 Gamepad 模块已加载`);
        return true;
      } else {
        console.error(`${TAG} 原生库中未找到 Gamepad 模块`);
        return false;
      }
    } catch (err) {
      console.error(`${TAG} 加载原生库失败:`, err);
      return false;
    }
  }

  isInitialized(): boolean {
    return this.initialized;
  }

  parseHidReport(
    vendorId: number,
    productId: number,
    data: Uint8Array,
    forceType?: number,
  ): NativeGamepadState | null {
    if (!this.gamepadModule) {
      console.warn(`${TAG} 服务未初始化`);
      return null;
    }

    try {
      return this.gamepadModule.parseHidReport(vendorId, productId, data, forceType ?? 0);
    } catch (err) {
      console.error(`${TAG} 解析 HID 报告失败:`, err);
      return null;
    }
  }

  getGamepadType(vendorId: number, productId: number): NativeGamepadType {
    if (!this.gamepadModule) {
      return NativeGamepadType.UNKNOWN;
    }

    try {
      return this.gamepadModule.getGamepadType(vendorId, productId) as NativeGamepadType;
    } catch (err) {
      return NativeGamepadType.UNKNOWN;
    }
  }

  isSupportedGamepad(vendorId: number, productId: number): boolean {
    if (!this.gamepadModule) {
      return false;
    }

    try {
      return this.gamepadModule.isSupportedGamepad(vendorId, productId);
    } catch (err) {
      return false;
    }
  }

  getGamepadName(vendorId: number, productId: number): string {
    if (!this.gamepadModule) {
      return "Unknown Gamepad";
    }

    try {
      return this.gamepadModule.getGamepadName(vendorId, productId);
    } catch (err) {
      return "Unknown Gamepad";
    }
  }

  createRumbleCommand(
    vendorId: number,
    productId: number,
    lowFreq: number,
    highFreq: number,
  ): Uint8Array | null {
    if (!this.gamepadModule) {
      return null;
    }

    try {
      return this.gamepadModule.createRumbleCommand(vendorId, productId, lowFreq, highFreq);
    } catch (err) {
      return null;
    }
  }
}

export { NativeGamepadState, NativeButtonFlags, NativeGamepadType } from "./NativeGamepad";
