/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

export interface GamepadState {
  buttons: number;
  leftStickX: number;
  leftStickY: number;
  rightStickX: number;
  rightStickY: number;
  leftTrigger: number;
  rightTrigger: number;
}

export interface GamepadInfo {
  id: number;
  name: string;
  bus?: number;
  vendor?: number;
  product?: number;
  isUsb?: boolean;
  isBluetooth?: boolean;
}

export interface GamepadInputListener {
  onGamepadConnected: (deviceId: number, name: string, controllerType: number) => void;
  onGamepadDisconnected: (deviceId: number) => void;
  onGamepadInput: (deviceId: number, state: GamepadState) => void;
}

export class DeviceBusType {
  static readonly BUS_USB = 0x03;
  static readonly BUS_BLUETOOTH = 0x05;
}

export class MoonlightButton {
  static readonly UP = 0x0001;
  static readonly DOWN = 0x0002;
  static readonly LEFT = 0x0004;
  static readonly RIGHT = 0x0008;
  static readonly START = 0x0010;
  static readonly BACK = 0x0020;
  static readonly LS = 0x0040;
  static readonly RS = 0x0080;
  static readonly LB = 0x0100;
  static readonly RB = 0x0200;
  static readonly SPECIAL = 0x0400;
  static readonly A = 0x1000;
  static readonly B = 0x2000;
  static readonly X = 0x4000;
  static readonly Y = 0x8000;
  static readonly DPAD_MASK =
    MoonlightButton.UP | MoonlightButton.DOWN | MoonlightButton.LEFT | MoonlightButton.RIGHT;
}

export type GCButton2313Action =
  | "guide"
  | "select"
  | "toggle_mouse"
  | "toggle_perf"
  | "show_menu"
  | "none";

export interface GCButton2313ActionCallback {
  onToggleMouse?: () => void;
  onTogglePerf?: () => void;
  onShowMenu?: () => void;
}

export const AXIS_MAX = 32767;
export const TRIGGER_MAX = 255;
export const RUMBLE_MAX = 65535;

export function toSigned16(value: number): number {
  return value > 32767 ? value - 65536 : value;
}

export function readShortLE(buffer: Uint8Array, offset: number): number {
  const value = buffer[offset] | (buffer[offset + 1] << 8);
  return toSigned16(value);
}

export const SPECIAL_KEYCODE_MIN = 2311;
export const SPECIAL_KEYCODE_MAX = 2315;

export class VendorId {
  static readonly MICROSOFT = 0x045e;
  static readonly SONY = 0x054c;
  static readonly NINTENDO = 0x057e;
}

export class ProductId {
  // Sony
  static readonly DUALSENSE = 0x0ce6;
  static readonly DUALSENSE_EDGE = 0x0df2;
  // Nintendo
  static readonly SWITCH_PRO = 0x2009;
}

/**
 * 0=Unknown, 1=Xbox, 2=PS, 3=Nintendo
 */
export class MoonlightControllerType {
  static readonly UNKNOWN = 0;
  static readonly XBOX = 1;
  static readonly PS = 2;
  static readonly NINTENDO = 3;

  static fromVendorProduct(vendorId: number, _productId: number): number {
    switch (vendorId) {
      case VendorId.MICROSOFT:
        return MoonlightControllerType.XBOX;
      case VendorId.SONY:
        return MoonlightControllerType.PS;
      case VendorId.NINTENDO:
        return MoonlightControllerType.NINTENDO;
      default:
        return MoonlightControllerType.XBOX;
    }
  }

  static fromDeviceName(name: string): number {
    const lower = name.toLowerCase();
    if (
      lower.includes("dualsense") ||
      lower.includes("dualshock") ||
      lower.includes("playstation") ||
      lower.includes("ps5") ||
      lower.includes("ps4")
    ) {
      return MoonlightControllerType.PS;
    }
    if (
      lower.includes("switch") ||
      lower.includes("nintendo") ||
      lower.includes("joy-con") ||
      lower.includes("joycon") ||
      lower.includes("pro controller")
    ) {
      return MoonlightControllerType.NINTENDO;
    }
    return MoonlightControllerType.XBOX;
  }
}

export const buttonMap = new Map<number, number>([
  // D-Pad
  [19, MoonlightButton.UP], // KEYCODE_DPAD_UP
  [20, MoonlightButton.DOWN], // KEYCODE_DPAD_DOWN
  [21, MoonlightButton.LEFT], // KEYCODE_DPAD_LEFT
  [22, MoonlightButton.RIGHT], // KEYCODE_DPAD_RIGHT
  // Face buttons
  [96, MoonlightButton.A], // KEYCODE_BUTTON_A
  [97, MoonlightButton.B], // KEYCODE_BUTTON_B
  [99, MoonlightButton.X], // KEYCODE_BUTTON_X
  [100, MoonlightButton.Y], // KEYCODE_BUTTON_Y
  // Shoulder buttons
  [102, MoonlightButton.LB], // KEYCODE_BUTTON_L1
  [103, MoonlightButton.RB], // KEYCODE_BUTTON_R1
  // Stick buttons
  [106, MoonlightButton.LS], // KEYCODE_BUTTON_THUMBL
  [107, MoonlightButton.RS], // KEYCODE_BUTTON_THUMBR
  // Start/Back
  [108, MoonlightButton.START], // KEYCODE_BUTTON_START
  [109, MoonlightButton.BACK], // KEYCODE_BUTTON_SELECT
  // Special
  [110, MoonlightButton.SPECIAL], // KEYCODE_BUTTON_MODE
  [2311, MoonlightButton.BACK],
  [2312, MoonlightButton.START],
  [2313, MoonlightButton.SPECIAL],
  [2314, MoonlightButton.LS],
  [2315, MoonlightButton.RS],
]);

export const gcButtonMap = new Map<number, number>([
  // Face buttons
  [2301, MoonlightButton.A], // BUTTON_A
  [2302, MoonlightButton.B], // BUTTON_B
  [2303, MoonlightButton.BACK],
  [2304, MoonlightButton.X], // BUTTON_X
  [2305, MoonlightButton.Y], // BUTTON_Y
  // Shoulder buttons
  [2307, MoonlightButton.LB], // LEFT_SHOULDER
  [2308, MoonlightButton.RB], // RIGHT_SHOULDER
  // Thumbstick buttons
  [2314, MoonlightButton.LS], // LEFT_THUMBSTICK
  [2315, MoonlightButton.RS], // RIGHT_THUMBSTICK
  [2311, MoonlightButton.BACK],
  [2312, MoonlightButton.START], // BUTTON_MENU (Start)
  [2313, MoonlightButton.SPECIAL],
  // D-Pad
  [2012, MoonlightButton.UP], // DPAD_UP
  [2013, MoonlightButton.DOWN], // DPAD_DOWN
  [2014, MoonlightButton.LEFT], // DPAD_LEFT
  [2015, MoonlightButton.RIGHT], // DPAD_RIGHT
]);

export const GAMEPAD_NAME_KEYWORDS: string[] = [
  "controller",
  "gamepad",
  "joystick",
  "joypad",
  "fightstick",
  "fight stick",
  "arcade stick",
  "xbox",
  "playstation",
  "dualshock",
  "dualsense",
  "switch",
  "pro controller",
  "joycon",
  "joy-con",
  "stadia",
  "ouya",
  "gamesir",
  "razer",
  "8bitdo",
  "steelseries",
  "logitech",
  "hori",
  "horipad",
  "powera",
  "scuf",
  "turtle beach",
  "thrustmaster",
  "madcatz",
  "mad catz",
  "saitek",
  "pdp",
  "nvidia",
  "shield",
  "backbone",
  "hyperkin",
  "nacon",
  "victrix",
  "qanba",
  "mayflash",
  "gulikit",
  "gpd",
  "moga",
  "elecom",
  "gamevice",
  "rotor riot",
  "astro",
  "hyperx",
  "flashfire",
  "betop",
  "beitong",
  "北通",
  "flydigi",
  "飞智",
  "pxn",
  "莱仕达",
  "ipega",
  "mocute",
  "魔操特",
  "newgame",
  "新游",
  "rapoo",
  "雷柏",
  "小鸡",
  "盖世小鸡",
  "easysmx",
  "bigbigwon",
  "谷粒",
  "aula",
  "狼蛛",
];

export const NON_GAMEPAD_KEYWORDS: string[] = [
  "keyboard",
  "键盘",
  "mouse",
  "鼠标",
  "touchpad",
  "trackpad",
  "触摸板",
  "watch",
  "手表",
  "wearable",
  "band",
  "手环",
  "smartwatch",
  "fitness",
  "huawei watch",
  "galaxy watch",
  "apple watch",
  "mi band",
  "amazfit",
];

export function isNonGamepadByName(nameLower: string): boolean {
  const hasNonGamepadKeyword = NON_GAMEPAD_KEYWORDS.some((kw) => nameLower.includes(kw));
  if (!hasNonGamepadKeyword) return false;
  const hasGamepadKeyword = GAMEPAD_NAME_KEYWORDS.some((kw) => nameLower.includes(kw));
  return !hasGamepadKeyword;
}

export const STRONG_NON_GAMEPAD_KEYWORDS: string[] = [
  "keyboard",
  "键盘",
  "mouse",
  "鼠标",
  "touchpad",
  "trackpad",
  "触摸板",
];

export function hasStrongNonGamepadKeyword(nameLower: string): boolean {
  return STRONG_NON_GAMEPAD_KEYWORDS.some((kw) => nameLower.includes(kw));
}
