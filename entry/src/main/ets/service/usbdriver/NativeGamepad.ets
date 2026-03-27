/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

export interface NativeGamepadState {
  deviceId: number;
  buttons: number;
  leftStickX: number;
  leftStickY: number;
  rightStickX: number;
  rightStickY: number;
  leftTrigger: number;
  rightTrigger: number;
}

export class NativeButtonFlags {
  static readonly UP: number = 0x0001;
  static readonly DOWN: number = 0x0002;
  static readonly LEFT: number = 0x0004;
  static readonly RIGHT: number = 0x0008;
  static readonly START: number = 0x0010;
  static readonly BACK: number = 0x0020;
  static readonly LS_CLK: number = 0x0040;
  static readonly RS_CLK: number = 0x0080;
  static readonly LB: number = 0x0100;
  static readonly RB: number = 0x0200;
  static readonly HOME: number = 0x0400;
  static readonly A: number = 0x1000;
  static readonly B: number = 0x2000;
  static readonly X: number = 0x4000;
  static readonly Y: number = 0x8000;
  static readonly PADDLE1: number = 0x00010000;
  static readonly PADDLE2: number = 0x00020000;
  static readonly PADDLE3: number = 0x00040000;
  static readonly PADDLE4: number = 0x00080000;
  static readonly TOUCHPAD: number = 0x00100000;
  static readonly MISC: number = 0x00200000;
}

export enum NativeGamepadType {
  UNKNOWN = 0,
  XBOX = 1,
  PLAYSTATION = 2,
  SWITCH = 3,
}

export interface NativeGamepadInterface {
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
