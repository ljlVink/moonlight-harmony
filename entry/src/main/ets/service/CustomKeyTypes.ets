/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

export interface KeyboardAction {
  type: "keyboard";
  /** Windows Virtual-Key Code */
  vk: number;
}

export interface MouseButtonAction {
  type: "mouse";
  button: number;
}

export interface MouseScrollAction {
  type: "mouseScroll";
  direction: number;
}

export interface GamepadButtonAction {
  type: "gamepadButton";
  mask: number;
}

export interface GamepadTriggerAction {
  type: "gamepadTrigger";
  trigger: "left" | "right";
}

export interface GamepadStickAction {
  type: "gamepadStick";
  stick: "left" | "right";
  direction: "up" | "down" | "left" | "right";
}

export interface AnalogStickAction {
  type: "analogStick";
  stick: "left" | "right";
  invisible?: boolean;
  sensitivity?: number;
}

export interface DPadAction {
  type: "dpad";
}

export interface WheelPadSegment {
  label: string;
  action: KeyAction;
}

export interface WheelPadAction {
  type: "wheelPad";
  segments: WheelPadSegment[];
}

export interface DigitalStickAction {
  type: "digitalStick";
  upAction: KeyAction;
  downAction: KeyAction;
  leftAction: KeyAction;
  rightAction: KeyAction;
  clickAction?: KeyAction;
}

export interface ComboAction {
  type: "combo";
  actions: KeyAction[];
}

export interface ShortcutAction {
  type: "shortcut";
  keys: number[];
  keySequence?: number[][];
}

export interface SpecialAction {
  type: "special";
  id: SpecialActionId;
}

export type SpecialActionId =
  | "toggleKeyboard"
  | "toggleIME"
  | "toggleMouseMode"
  | "switchProfile"
  | "openGameMenu"
  | "editMode"
  | "hideCustomKeys"
  | "none";

export type KeyAction =
  | KeyboardAction
  | MouseButtonAction
  | MouseScrollAction
  | GamepadButtonAction
  | GamepadTriggerAction
  | GamepadStickAction
  | AnalogStickAction
  | DPadAction
  | WheelPadAction
  | DigitalStickAction
  | ComboAction
  | ShortcutAction
  | SpecialAction;

export type KeyShape = "rect" | "circle";

export type KeyBehavior = "momentary" | "toggle";

export interface CustomKeyDef {
  id: string;
  label: string;
  action: KeyAction;
  shape: KeyShape;
  behavior: KeyBehavior;
  xPercent: number;
  yPercent: number;
  x?: number;
  y?: number;
  width: number;
  height: number;
  layer: number;
  opacity: number;
  borderRadius: number;
  normalColor: string;
  pressedColor: string;
  bgColor: string;
  textColor: string;
  fontSize: number;
  borderWidth: number;
  haptic: string;
}

export interface CustomKeyProfile {
  name: string;
  keys: CustomKeyDef[];
}

export function generateKeyId(): string {
  return Date.now().toString(36) + Math.random().toString(36).substring(2, 6);
}

export function cloneKeyDef(src: CustomKeyDef): CustomKeyDef {
  const dst: CustomKeyDef = {
    id: src.id,
    label: src.label,
    action: src.action,
    shape: src.shape,
    behavior: src.behavior,
    xPercent: src.xPercent,
    yPercent: src.yPercent,
    width: src.width,
    height: src.height,
    layer: src.layer,
    opacity: src.opacity,
    borderRadius: src.borderRadius,
    normalColor: src.normalColor,
    pressedColor: src.pressedColor,
    bgColor: src.bgColor,
    textColor: src.textColor,
    fontSize: src.fontSize,
    borderWidth: src.borderWidth ?? 1,
    haptic: src.haptic ?? "light",
  };
  return dst;
}

export function createDefaultKeyDef(partial?: Partial<CustomKeyDef>): CustomKeyDef {
  const def: CustomKeyDef = {
    id: generateKeyId(),
    label: "Key",
    action: { type: "keyboard", vk: 0x41 } as KeyboardAction,
    shape: "rect",
    behavior: "momentary",
    xPercent: 0.5,
    yPercent: 0.5,
    width: 60,
    height: 60,
    layer: 0,
    opacity: 80,
    borderRadius: 12,
    normalColor: "#60FFFFFF",
    pressedColor: "#80A8D8EA",
    bgColor: "#30FFFFFF",
    textColor: "#E0FFFFFF",
    fontSize: 14,
    borderWidth: 1,
    haptic: "light",
  };
  if (partial) {
    if (partial.id !== undefined) def.id = partial.id;
    if (partial.label !== undefined) def.label = partial.label;
    if (partial.action !== undefined) def.action = partial.action;
    if (partial.shape !== undefined) def.shape = partial.shape;
    if (partial.behavior !== undefined) def.behavior = partial.behavior;
    if (partial.xPercent !== undefined) def.xPercent = partial.xPercent;
    if (partial.yPercent !== undefined) def.yPercent = partial.yPercent;
    if (partial.width !== undefined) def.width = partial.width;
    if (partial.height !== undefined) def.height = partial.height;
    if (partial.layer !== undefined) def.layer = partial.layer;
    if (partial.opacity !== undefined) def.opacity = partial.opacity;
    if (partial.borderRadius !== undefined) def.borderRadius = partial.borderRadius;
    if (partial.normalColor !== undefined) def.normalColor = partial.normalColor;
    if (partial.pressedColor !== undefined) def.pressedColor = partial.pressedColor;
    if (partial.bgColor !== undefined) def.bgColor = partial.bgColor;
    if (partial.textColor !== undefined) def.textColor = partial.textColor;
    if (partial.fontSize !== undefined) def.fontSize = partial.fontSize;
    if (partial.borderWidth !== undefined) def.borderWidth = partial.borderWidth;
    if (partial.haptic !== undefined) def.haptic = partial.haptic;
  }
  return def;
}

export function createDefaultProfile(name: string = "默认"): CustomKeyProfile {
  return {
    name,
    keys: [],
  };
}

export class VirtualKey {
  static readonly VK_SHIFT = 0x10;
  static readonly VK_CONTROL = 0x11;
  static readonly VK_MENU = 0x12; // Alt
  static readonly VK_LWIN = 0x5b;
  static readonly VK_RWIN = 0x5c;
  static readonly VK_LSHIFT = 0xa0;
  static readonly VK_RSHIFT = 0xa1;
  static readonly VK_LCONTROL = 0xa2;
  static readonly VK_RCONTROL = 0xa3;
  static readonly VK_LMENU = 0xa4;
  static readonly VK_RMENU = 0xa5;
  static readonly VK_ESCAPE = 0x1b;
  static readonly VK_TAB = 0x09;
  static readonly VK_RETURN = 0x0d;
  static readonly VK_BACK = 0x08; // Backspace
  static readonly VK_SPACE = 0x20;
  static readonly VK_DELETE = 0x2e;
  static readonly VK_INSERT = 0x2d;
  static readonly VK_HOME = 0x24;
  static readonly VK_END = 0x23;
  static readonly VK_PRIOR = 0x21; // Page Up
  static readonly VK_NEXT = 0x22; // Page Down
  static readonly VK_CAPITAL = 0x14; // Caps Lock
  static readonly VK_SNAPSHOT = 0x2c; // Print Screen
  static readonly VK_SCROLL = 0x91; // Scroll Lock
  static readonly VK_PAUSE = 0x13;
  static readonly VK_NUMLOCK = 0x90;
  static readonly VK_LEFT = 0x25;
  static readonly VK_UP = 0x26;
  static readonly VK_RIGHT = 0x27;
  static readonly VK_DOWN = 0x28;
  static readonly VK_F1 = 0x70;
  static readonly VK_F2 = 0x71;
  static readonly VK_F3 = 0x72;
  static readonly VK_F4 = 0x73;
  static readonly VK_F5 = 0x74;
  static readonly VK_F6 = 0x75;
  static readonly VK_F7 = 0x76;
  static readonly VK_F8 = 0x77;
  static readonly VK_F9 = 0x78;
  static readonly VK_F10 = 0x79;
  static readonly VK_F11 = 0x7a;
  static readonly VK_F12 = 0x7b;
  static readonly VK_A = 0x41;
  static readonly VK_B = 0x42;
  static readonly VK_C = 0x43;
  static readonly VK_D = 0x44;
  static readonly VK_E = 0x45;
  static readonly VK_F = 0x46;
  static readonly VK_G = 0x47;
  static readonly VK_H = 0x48;
  static readonly VK_I = 0x49;
  static readonly VK_J = 0x4a;
  static readonly VK_K = 0x4b;
  static readonly VK_L = 0x4c;
  static readonly VK_M = 0x4d;
  static readonly VK_N = 0x4e;
  static readonly VK_O = 0x4f;
  static readonly VK_P = 0x50;
  static readonly VK_Q = 0x51;
  static readonly VK_R = 0x52;
  static readonly VK_S = 0x53;
  static readonly VK_T = 0x54;
  static readonly VK_U = 0x55;
  static readonly VK_V = 0x56;
  static readonly VK_W = 0x57;
  static readonly VK_X = 0x58;
  static readonly VK_Y = 0x59;
  static readonly VK_Z = 0x5a;
  static readonly VK_VOLUME_MUTE = 0xad;
  static readonly VK_VOLUME_DOWN = 0xae;
  static readonly VK_VOLUME_UP = 0xaf;
  static readonly VK_MEDIA_NEXT_TRACK = 0xb0;
  static readonly VK_MEDIA_PREV_TRACK = 0xb1;
  static readonly VK_MEDIA_STOP = 0xb2;
  static readonly VK_MEDIA_PLAY_PAUSE = 0xb3;
}

export class GamepadButton {
  // D-Pad
  static readonly UP = 0x0001;
  static readonly DOWN = 0x0002;
  static readonly LEFT = 0x0004;
  static readonly RIGHT = 0x0008;
  static readonly START = 0x0010; // Play/Menu
  static readonly BACK = 0x0020; // Select/View
  static readonly LS = 0x0040; // Left Stick Click (L3)
  static readonly RS = 0x0080; // Right Stick Click (R3)
  static readonly LB = 0x0100;
  static readonly RB = 0x0200;
  static readonly GUIDE = 0x0400;
  static readonly A = 0x1000;
  static readonly B = 0x2000;
  static readonly X = 0x4000;
  static readonly Y = 0x8000;
  static readonly PADDLE1 = 0x010000;
  static readonly PADDLE2 = 0x020000;
  static readonly PADDLE3 = 0x040000;
  static readonly PADDLE4 = 0x080000;
  static readonly TOUCHPAD = 0x100000;
  static readonly MISC = 0x200000;
  static readonly DPAD_MASK = 0x000f; // UP | DOWN | LEFT | RIGHT
}

export const VK_DISPLAY_NAMES: Record<number, string> = {
  0x41: "A",
  0x42: "B",
  0x43: "C",
  0x44: "D",
  0x45: "E",
  0x46: "F",
  0x47: "G",
  0x48: "H",
  0x49: "I",
  0x4a: "J",
  0x4b: "K",
  0x4c: "L",
  0x4d: "M",
  0x4e: "N",
  0x4f: "O",
  0x50: "P",
  0x51: "Q",
  0x52: "R",
  0x53: "S",
  0x54: "T",
  0x55: "U",
  0x56: "V",
  0x57: "W",
  0x58: "X",
  0x59: "Y",
  0x5a: "Z",
  0x30: "0",
  0x31: "1",
  0x32: "2",
  0x33: "3",
  0x34: "4",
  0x35: "5",
  0x36: "6",
  0x37: "7",
  0x38: "8",
  0x39: "9",
  0x70: "F1",
  0x71: "F2",
  0x72: "F3",
  0x73: "F4",
  0x74: "F5",
  0x75: "F6",
  0x76: "F7",
  0x77: "F8",
  0x78: "F9",
  0x79: "F10",
  0x7a: "F11",
  0x7b: "F12",
  0x1b: "ESC",
  0x09: "Tab",
  0x14: "Caps",
  0x0d: "Enter",
  0x08: "Backspace",
  0x20: "Space",
  0x2d: "Insert",
  0x2e: "Delete",
  0x24: "Home",
  0x23: "End",
  0x21: "PgUp",
  0x22: "PgDn",
  0x25: "←",
  0x26: "↑",
  0x27: "→",
  0x28: "↓",
  0x10: "Shift",
  0x11: "Ctrl",
  0x12: "Alt",
  0xa0: "LShift",
  0xa1: "RShift",
  0xa2: "LCtrl",
  0xa3: "RCtrl",
  0xa4: "LAlt",
  0xa5: "RAlt",
  0x5b: "LWin",
  0x5c: "RWin",
  0xc0: "`",
  0xbd: "-",
  0xbb: "=",
  0xdb: "[",
  0xdd: "]",
  0xdc: "\\",
  0xba: ";",
  0xde: "'",
  0xbc: ",",
  0xbe: ".",
  0xbf: "/",
  0x2c: "PrtSc",
  0x91: "ScrLk",
  0x13: "Pause",
  0x90: "NumLk",
  0x60: "Num0",
  0x61: "Num1",
  0x62: "Num2",
  0x63: "Num3",
  0x64: "Num4",
  0x65: "Num5",
  0x66: "Num6",
  0x67: "Num7",
  0x68: "Num8",
  0x69: "Num9",
  0x6a: "Num*",
  0x6b: "Num+",
  0x6d: "Num-",
  0x6e: "Num.",
  0x6f: "Num/",
  0xad: "🔇",
  0xae: "🔉",
  0xaf: "🔊",
  0xb0: "⏭",
  0xb1: "⏮",
  0xb2: "⏹",
  0xb3: "⏯",
};

export function getVkDisplayName(vk: number): string {
  return VK_DISPLAY_NAMES[vk] ?? `0x${vk.toString(16).toUpperCase()}`;
}

export const GAMEPAD_DISPLAY_NAMES: Record<number, string> = {
  0x1000: "A",
  0x2000: "B",
  0x4000: "X",
  0x8000: "Y",
  0x0100: "LB",
  0x0200: "RB",
  0x0010: "Start",
  0x0020: "Back",
  0x0040: "L3",
  0x0080: "R3",
  0x0400: "Guide",
  0x0001: "D↑",
  0x0002: "D↓",
  0x0004: "D←",
  0x0008: "D→",
  0x010000: "P1",
  0x020000: "P2",
  0x040000: "P3",
  0x080000: "P4",
  0x100000: "Touchpad",
  0x200000: "Misc",
};

export function getGamepadDisplayName(mask: number): string {
  return GAMEPAD_DISPLAY_NAMES[mask] ?? `手柄0x${mask.toString(16)}`;
}

export function getActionDisplayName(action: KeyAction): string {
  switch (action.type) {
    case "keyboard":
      return getVkDisplayName(action.vk);
    case "mouse":
      const mouseNames: Record<number, string> = {
        1: "鼠标左键",
        2: "鼠标中键",
        3: "鼠标右键",
        4: "侧键1",
        5: "侧键2",
      };
      return mouseNames[action.button] ?? `鼠标${action.button}`;
    case "mouseScroll":
      return action.direction > 0 ? "滚轮↑" : "滚轮↓";
    case "gamepadButton":
      return getGamepadDisplayName(action.mask);
    case "gamepadTrigger":
      return action.trigger === "left" ? "LT" : "RT";
    case "gamepadStick": {
      const stickName = action.stick === "left" ? "LS" : "RS";
      const dirMap = new Map<string, string>([["up", "↑"], ["down", "↓"], ["left", "←"], ["right", "→"]]);
      return `${stickName}${dirMap.get(action.direction) ?? action.direction}`;
    }
    case "analogStick": {
      const asAction = action as AnalogStickAction;
      const stickName = asAction.stick === "left" ? "左摇杆" : "右摇杆";
      let name = asAction.invisible ? `隐形${stickName}` : stickName;
      if (asAction.sensitivity !== undefined && asAction.sensitivity !== 1.0) {
        name += `(${asAction.sensitivity.toFixed(1)}x)`;
      }
      return name;
    }
    case "dpad":
      return "十字键";
    case "wheelPad": {
      const wpAction = action as WheelPadAction;
      return `轮盘(${wpAction.segments.length})`;
    }
    case "digitalStick": {
      const dsAction = action as DigitalStickAction;
      const dirs = [
        dsAction.upAction,
        dsAction.downAction,
        dsAction.leftAction,
        dsAction.rightAction,
      ].map((a) => getActionDisplayName(a));
      return `数字摇杆(${dirs.join("/")})`;
    }
    case "combo":
      return action.actions.map((a) => getActionDisplayName(a)).join("+");
    case "shortcut": {
      if (action.keySequence && action.keySequence.length > 0) {
        return action.keySequence
          .map((step) => step.map((vk) => getVkDisplayName(vk)).join("+"))
          .join(" → ");
      }
      return action.keys.map((vk) => getVkDisplayName(vk)).join("+");
    }
    case "special":
      const specialNames = new Map<string, string>([
        ["toggleKeyboard", "键盘"],
        ["toggleIME", "输入法"],
        ["toggleMouseMode", "鼠标模式"],
        ["switchProfile", "切换配置"],
        ["openGameMenu", "菜单"],
        ["editMode", "编辑"],
        ["none", "无"],
      ]);
      return specialNames.get(action.id) ?? action.id;
    default:
      return "未知";
  }
}

export interface KeyPresetCategory {
  name: string;
  presets: KeyPreset[];
}

export interface KeyPreset {
  label: string;
  action: KeyAction;
}

export const KEY_PRESET_CATEGORIES: KeyPresetCategory[] = [
  {
    name: "常用键",
    presets: [
      { label: "ESC", action: { type: "keyboard", vk: 0x1b } },
      { label: "Enter", action: { type: "keyboard", vk: 0x0d } },
      { label: "Space", action: { type: "keyboard", vk: 0x20 } },
      { label: "Tab", action: { type: "keyboard", vk: 0x09 } },
      { label: "Shift", action: { type: "keyboard", vk: 0xa0 } },
      { label: "Ctrl", action: { type: "keyboard", vk: 0xa2 } },
      { label: "Alt", action: { type: "keyboard", vk: 0xa4 } },
      { label: "Win", action: { type: "keyboard", vk: 0x5b } },
      { label: "Backspace", action: { type: "keyboard", vk: 0x08 } },
      { label: "Delete", action: { type: "keyboard", vk: 0x2e } },
      { label: "Insert", action: { type: "keyboard", vk: 0x2d } },
      { label: "Home", action: { type: "keyboard", vk: 0x24 } },
      { label: "End", action: { type: "keyboard", vk: 0x23 } },
      { label: "PgUp", action: { type: "keyboard", vk: 0x21 } },
      { label: "PgDn", action: { type: "keyboard", vk: 0x22 } },
      { label: "Caps", action: { type: "keyboard", vk: 0x14 } },
      { label: "PrtSc", action: { type: "keyboard", vk: 0x2c } },
    ],
  },
  {
    name: "功能键",
    presets: [
      { label: "F1", action: { type: "keyboard", vk: 0x70 } },
      { label: "F2", action: { type: "keyboard", vk: 0x71 } },
      { label: "F3", action: { type: "keyboard", vk: 0x72 } },
      { label: "F4", action: { type: "keyboard", vk: 0x73 } },
      { label: "F5", action: { type: "keyboard", vk: 0x74 } },
      { label: "F6", action: { type: "keyboard", vk: 0x75 } },
      { label: "F7", action: { type: "keyboard", vk: 0x76 } },
      { label: "F8", action: { type: "keyboard", vk: 0x77 } },
      { label: "F9", action: { type: "keyboard", vk: 0x78 } },
      { label: "F10", action: { type: "keyboard", vk: 0x79 } },
      { label: "F11", action: { type: "keyboard", vk: 0x7a } },
      { label: "F12", action: { type: "keyboard", vk: 0x7b } },
    ],
  },
  {
    name: "鼠标",
    presets: [
      { label: "左键", action: { type: "mouse", button: 1 } },
      { label: "中键", action: { type: "mouse", button: 2 } },
      { label: "右键", action: { type: "mouse", button: 3 } },
      { label: "滚轮↑", action: { type: "mouseScroll", direction: 1 } },
      { label: "滚轮↓", action: { type: "mouseScroll", direction: -1 } },
    ],
  },
  {
    name: "手柄",
    presets: [
      { label: "A", action: { type: "gamepadButton", mask: GamepadButton.A } },
      { label: "B", action: { type: "gamepadButton", mask: GamepadButton.B } },
      { label: "X", action: { type: "gamepadButton", mask: GamepadButton.X } },
      { label: "Y", action: { type: "gamepadButton", mask: GamepadButton.Y } },
      { label: "LB", action: { type: "gamepadButton", mask: GamepadButton.LB } },
      { label: "RB", action: { type: "gamepadButton", mask: GamepadButton.RB } },
      { label: "LT", action: { type: "gamepadTrigger", trigger: "left" } as GamepadTriggerAction },
      { label: "RT", action: { type: "gamepadTrigger", trigger: "right" } as GamepadTriggerAction },
      { label: "Start", action: { type: "gamepadButton", mask: GamepadButton.START } },
      { label: "Back", action: { type: "gamepadButton", mask: GamepadButton.BACK } },
      { label: "L3", action: { type: "gamepadButton", mask: GamepadButton.LS } },
      { label: "R3", action: { type: "gamepadButton", mask: GamepadButton.RS } },
      { label: "Guide", action: { type: "gamepadButton", mask: GamepadButton.GUIDE } },
      { label: "D↑", action: { type: "gamepadButton", mask: GamepadButton.UP } },
      { label: "D↓", action: { type: "gamepadButton", mask: GamepadButton.DOWN } },
      { label: "D←", action: { type: "gamepadButton", mask: GamepadButton.LEFT } },
      { label: "D→", action: { type: "gamepadButton", mask: GamepadButton.RIGHT } },
      { label: "P1", action: { type: "gamepadButton", mask: GamepadButton.PADDLE1 } },
      {
        label: "LS↑",
        action: { type: "gamepadStick", stick: "left", direction: "up" } as GamepadStickAction,
      },
      {
        label: "LS↓",
        action: { type: "gamepadStick", stick: "left", direction: "down" } as GamepadStickAction,
      },
      {
        label: "LS←",
        action: { type: "gamepadStick", stick: "left", direction: "left" } as GamepadStickAction,
      },
      {
        label: "LS→",
        action: { type: "gamepadStick", stick: "left", direction: "right" } as GamepadStickAction,
      },
      {
        label: "RS↑",
        action: { type: "gamepadStick", stick: "right", direction: "up" } as GamepadStickAction,
      },
      {
        label: "RS↓",
        action: { type: "gamepadStick", stick: "right", direction: "down" } as GamepadStickAction,
      },
      {
        label: "RS←",
        action: { type: "gamepadStick", stick: "right", direction: "left" } as GamepadStickAction,
      },
      {
        label: "RS→",
        action: { type: "gamepadStick", stick: "right", direction: "right" } as GamepadStickAction,
      },
      { label: "P2", action: { type: "gamepadButton", mask: GamepadButton.PADDLE2 } },
      { label: "P3", action: { type: "gamepadButton", mask: GamepadButton.PADDLE3 } },
      { label: "P4", action: { type: "gamepadButton", mask: GamepadButton.PADDLE4 } },
      { label: "Touchpad", action: { type: "gamepadButton", mask: GamepadButton.TOUCHPAD } },
      { label: "Misc", action: { type: "gamepadButton", mask: GamepadButton.MISC } },
      { label: "左摇杆", action: { type: "analogStick", stick: "left" } as AnalogStickAction },
      { label: "右摇杆", action: { type: "analogStick", stick: "right" } as AnalogStickAction },
      {
        label: "隐形左摇杆",
        action: { type: "analogStick", stick: "left", invisible: true } as AnalogStickAction,
      },
      {
        label: "隐形右摇杆",
        action: { type: "analogStick", stick: "right", invisible: true } as AnalogStickAction,
      },
      { label: "十字键", action: { type: "dpad" } as DPadAction },
    ],
  },
  {
    name: "方向键",
    presets: [
      { label: "↑", action: { type: "keyboard", vk: 0x26 } },
      { label: "↓", action: { type: "keyboard", vk: 0x28 } },
      { label: "←", action: { type: "keyboard", vk: 0x25 } },
      { label: "→", action: { type: "keyboard", vk: 0x27 } },
    ],
  },
  {
    name: "字母",
    presets: buildLetterPresets(),
  },
  {
    name: "数字",
    presets: buildNumberPresets(),
  },
  {
    name: "符号",
    presets: [
      { label: "`", action: { type: "keyboard", vk: 0xc0 } },
      { label: "-", action: { type: "keyboard", vk: 0xbd } },
      { label: "=", action: { type: "keyboard", vk: 0xbb } },
      { label: "[", action: { type: "keyboard", vk: 0xdb } },
      { label: "]", action: { type: "keyboard", vk: 0xdd } },
      { label: "\\", action: { type: "keyboard", vk: 0xdc } },
      { label: ";", action: { type: "keyboard", vk: 0xba } },
      { label: "'", action: { type: "keyboard", vk: 0xde } },
      { label: ",", action: { type: "keyboard", vk: 0xbc } },
      { label: ".", action: { type: "keyboard", vk: 0xbe } },
      { label: "/", action: { type: "keyboard", vk: 0xbf } },
    ],
  },
  {
    name: "特殊功能",
    presets: [
      { label: "键盘", action: { type: "special", id: "toggleKeyboard" } as SpecialAction },
      { label: "输入法", action: { type: "special", id: "toggleIME" } as SpecialAction },
      { label: "鼠标模式", action: { type: "special", id: "toggleMouseMode" } as SpecialAction },
      { label: "切换配置", action: { type: "special", id: "switchProfile" } as SpecialAction },
      { label: "菜单", action: { type: "special", id: "openGameMenu" } as SpecialAction },
      { label: "编辑", action: { type: "special", id: "editMode" } as SpecialAction },
      { label: "隐藏按键", action: { type: "special", id: "hideCustomKeys" } as SpecialAction },
    ],
  },
  {
    name: "快捷键",
    presets: [
      {
        label: "Alt+Tab",
        action: { type: "shortcut", keys: [0x12, 0x09], keySequence: undefined } as ShortcutAction,
      },
      {
        label: "Alt+F4",
        action: { type: "shortcut", keys: [0x12, 0x73], keySequence: undefined } as ShortcutAction,
      },
      {
        label: "Ctrl+C",
        action: { type: "shortcut", keys: [0x11, 0x43], keySequence: undefined } as ShortcutAction,
      },
      {
        label: "Ctrl+V",
        action: { type: "shortcut", keys: [0x11, 0x56], keySequence: undefined } as ShortcutAction,
      },
      {
        label: "Ctrl+Z",
        action: { type: "shortcut", keys: [0x11, 0x5a], keySequence: undefined } as ShortcutAction,
      },
      {
        label: "Ctrl+A",
        action: { type: "shortcut", keys: [0x11, 0x41], keySequence: undefined } as ShortcutAction,
      },
      {
        label: "Ctrl+S",
        action: { type: "shortcut", keys: [0x11, 0x53], keySequence: undefined } as ShortcutAction,
      },
      {
        label: "Win",
        action: { type: "shortcut", keys: [0x5b], keySequence: undefined } as ShortcutAction,
      },
      {
        label: "Win+D",
        action: { type: "shortcut", keys: [0x5b, 0x44], keySequence: undefined } as ShortcutAction,
      },
      {
        label: "Win+E",
        action: { type: "shortcut", keys: [0x5b, 0x45], keySequence: undefined } as ShortcutAction,
      },
      {
        label: "Ctrl+Alt+Del",
        action: {
          type: "shortcut",
          keys: [0x11, 0x12, 0x2e],
          keySequence: undefined,
        } as ShortcutAction,
      },
      {
        label: "休眠",
        action: {
          type: "shortcut",
          keys: [],
          keySequence: [[0x5b, 0x58], [0x55], [0x53]],
        } as ShortcutAction,
      },
    ],
  },
  {
    name: "轮盘",
    presets: buildWheelPadPresets(),
  },
  {
    name: "数字摇杆",
    presets: buildDigitalStickPresets(),
  },
];

function buildLetterPresets(): KeyPreset[] {
  const list: KeyPreset[] = [];
  for (let i = 0; i < 26; i++) {
    const preset: KeyPreset = {
      label: String.fromCharCode(65 + i),
      action: { type: "keyboard", vk: 0x41 + i } as KeyboardAction,
    };
    list.push(preset);
  }
  return list;
}

function buildNumberPresets(): KeyPreset[] {
  const list: KeyPreset[] = [];
  for (let i = 0; i < 10; i++) {
    const preset: KeyPreset = {
      label: i.toString(),
      action: { type: "keyboard", vk: 0x30 + i } as KeyboardAction,
    };
    list.push(preset);
  }
  return list;
}

function buildWheelPadPresets(): KeyPreset[] {
  const seg1: WheelPadSegment = {
    label: "1",
    action: { type: "keyboard", vk: 0x31 } as KeyboardAction,
  };
  const seg2: WheelPadSegment = {
    label: "2",
    action: { type: "keyboard", vk: 0x32 } as KeyboardAction,
  };
  const seg3: WheelPadSegment = {
    label: "3",
    action: { type: "keyboard", vk: 0x33 } as KeyboardAction,
  };
  const seg4: WheelPadSegment = {
    label: "4",
    action: { type: "keyboard", vk: 0x34 } as KeyboardAction,
  };

  const segA: WheelPadSegment = {
    label: "A",
    action: { type: "gamepadButton", mask: GamepadButton.A } as GamepadButtonAction,
  };
  const segB: WheelPadSegment = {
    label: "B",
    action: { type: "gamepadButton", mask: GamepadButton.B } as GamepadButtonAction,
  };
  const segX: WheelPadSegment = {
    label: "X",
    action: { type: "gamepadButton", mask: GamepadButton.X } as GamepadButtonAction,
  };
  const segY: WheelPadSegment = {
    label: "Y",
    action: { type: "gamepadButton", mask: GamepadButton.Y } as GamepadButtonAction,
  };

  const segW: WheelPadSegment = {
    label: "W",
    action: { type: "keyboard", vk: 0x57 } as KeyboardAction,
  };
  const segAKey: WheelPadSegment = {
    label: "A",
    action: { type: "keyboard", vk: 0x41 } as KeyboardAction,
  };
  const segS: WheelPadSegment = {
    label: "S",
    action: { type: "keyboard", vk: 0x53 } as KeyboardAction,
  };
  const segD: WheelPadSegment = {
    label: "D",
    action: { type: "keyboard", vk: 0x44 } as KeyboardAction,
  };

  const list: KeyPreset[] = [
    {
      label: "技能轮盘",
      action: { type: "wheelPad", segments: [seg1, seg2, seg3, seg4] } as WheelPadAction,
    },
    {
      label: "ABXY轮盘",
      action: { type: "wheelPad", segments: [segA, segB, segX, segY] } as WheelPadAction,
    },
    {
      label: "WASD轮盘",
      action: { type: "wheelPad", segments: [segW, segD, segS, segAKey] } as WheelPadAction,
    },
  ];
  return list;
}

/**
 *
 */
export function sendShortcutKeys(
  sendKeysFn: (keyCodes: number[]) => void,
  keys: number[],
  keySequence?: number[][],
): void {
  if (keySequence && keySequence.length > 0) {
    keySequence.forEach((stepKeys: number[], index: number) => {
      setTimeout(() => {
        sendKeysFn(stepKeys);
      }, index * 200);
    });
  } else if (keys.length > 0) {
    sendKeysFn(keys);
  }
}

function buildDigitalStickPresets(): KeyPreset[] {
  const list: KeyPreset[] = [
    {
      label: "WASD数字摇杆",
      action: {
        type: "digitalStick",
        upAction: { type: "keyboard", vk: 0x57 } as KeyboardAction,
        downAction: { type: "keyboard", vk: 0x53 } as KeyboardAction,
        leftAction: { type: "keyboard", vk: 0x41 } as KeyboardAction,
        rightAction: { type: "keyboard", vk: 0x44 } as KeyboardAction,
      } as DigitalStickAction,
    },
    {
      label: "方向键数字摇杆",
      action: {
        type: "digitalStick",
        upAction: { type: "keyboard", vk: 0x26 } as KeyboardAction,
        downAction: { type: "keyboard", vk: 0x28 } as KeyboardAction,
        leftAction: { type: "keyboard", vk: 0x25 } as KeyboardAction,
        rightAction: { type: "keyboard", vk: 0x27 } as KeyboardAction,
      } as DigitalStickAction,
    },
    {
      label: "DPAD数字摇杆",
      action: {
        type: "digitalStick",
        upAction: { type: "gamepadButton", mask: GamepadButton.UP } as GamepadButtonAction,
        downAction: { type: "gamepadButton", mask: GamepadButton.DOWN } as GamepadButtonAction,
        leftAction: { type: "gamepadButton", mask: GamepadButton.LEFT } as GamepadButtonAction,
        rightAction: { type: "gamepadButton", mask: GamepadButton.RIGHT } as GamepadButtonAction,
        clickAction: { type: "gamepadButton", mask: GamepadButton.LS } as GamepadButtonAction,
      } as DigitalStickAction,
    },
  ];
  return list;
}
