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
 *
 *   - D-Pad:          2012-2016
 *   - F1-F12:         2090-2101
 */

const OH_KEYCODE_0 = 2000;
const OH_KEYCODE_9 = 2009;

const OH_KEYCODE_A = 2017;
const OH_KEYCODE_Z = 2042;

const OH_KEYCODE_F1 = 2090;
const OH_KEYCODE_F12 = 2101;

const OH_KEYCODE_NUMPAD_0 = 2103;
const OH_KEYCODE_NUMPAD_9 = 2112;

const VK_0 = 0x30;         // 48
const VK_A = 0x41;         // 65
const VK_F1 = 0x70;        // 112
const VK_NUMPAD0 = 0x60;   // 96

export class KeyboardTranslator {

  /**
   *
   *
   *   - 2090-2101: F1-F12
   */
  static isKeyboardKey(keyCode: number): boolean {
    if (keyCode >= 2000 && keyCode <= 2009) return true;
    if (keyCode >= 2012 && keyCode <= 2016) return true;
    if (keyCode >= 2017 && keyCode <= 2042) return true;
    if (keyCode >= 2043 && keyCode <= 2083) return true;
    // F1-F12
    if (keyCode >= 2090 && keyCode <= 2101) return true;
    if (keyCode >= 2102 && keyCode <= 2120) return true;
    return false;
  }

  /**
   *
   */
  static isGamepadKey(keyCode: number): boolean {
    if (keyCode >= 19 && keyCode <= 22) return true;
    if (keyCode >= 96 && keyCode <= 110) return true;
    // Game Controller Kit: 2300-2320
    if (keyCode >= 2300 && keyCode <= 2320) return true;
    return false;
  }

  /**
   *
   * @param keyCode HarmonyOS KeyCode
   */
  static translate(keyCode: number): number {

    if (keyCode >= OH_KEYCODE_0 && keyCode <= OH_KEYCODE_9) {
      return (keyCode - OH_KEYCODE_0) + VK_0;
    }

    if (keyCode >= OH_KEYCODE_A && keyCode <= OH_KEYCODE_Z) {
      return (keyCode - OH_KEYCODE_A) + VK_A;
    }

    // F1-F12 → VK_F1(0x70) ~ VK_F12(0x7B)
    if (keyCode >= OH_KEYCODE_F1 && keyCode <= OH_KEYCODE_F12) {
      return (keyCode - OH_KEYCODE_F1) + VK_F1;
    }

    if (keyCode >= OH_KEYCODE_NUMPAD_0 && keyCode <= OH_KEYCODE_NUMPAD_9) {
      return (keyCode - OH_KEYCODE_NUMPAD_0) + VK_NUMPAD0;
    }

    switch (keyCode) {
      case 2012: return 0x26; // KEYCODE_DPAD_UP     → VK_UP
      case 2013: return 0x28; // KEYCODE_DPAD_DOWN   → VK_DOWN
      case 2014: return 0x25; // KEYCODE_DPAD_LEFT   → VK_LEFT
      case 2015: return 0x27; // KEYCODE_DPAD_RIGHT  → VK_RIGHT
      case 2016: return 0x0D; // KEYCODE_DPAD_CENTER → VK_RETURN

      case 2043: return 0xBC; // KEYCODE_COMMA       → VK_OEM_COMMA
      case 2044: return 0xBE; // KEYCODE_PERIOD      → VK_OEM_PERIOD

      case 2045: return 0xA4; // KEYCODE_ALT_LEFT    → VK_LMENU
      case 2046: return 0xA5; // KEYCODE_ALT_RIGHT   → VK_RMENU
      case 2047: return 0xA0; // KEYCODE_SHIFT_LEFT  → VK_LSHIFT
      case 2048: return 0xA1; // KEYCODE_SHIFT_RIGHT → VK_RSHIFT

      case 2049: return 0x09; // KEYCODE_TAB         → VK_TAB
      case 2050: return 0x20; // KEYCODE_SPACE       → VK_SPACE

      case 2054: return 0x0D; // KEYCODE_ENTER       → VK_RETURN
      case 2055: return 0x08;

      case 2056: return 0xC0; // KEYCODE_GRAVE   (`) → VK_OEM_3
      case 2057: return 0xBD; // KEYCODE_MINUS   (-) → VK_OEM_MINUS
      case 2058: return 0xBB; // KEYCODE_EQUALS  (=) → VK_OEM_PLUS
      case 2059: return 0xDB; // KEYCODE_LEFT_BRACKET  ([) → VK_OEM_4
      case 2060: return 0xDD; // KEYCODE_RIGHT_BRACKET (]) → VK_OEM_6
      case 2061: return 0xDC; // KEYCODE_BACKSLASH     (\) → VK_OEM_5
      case 2062: return 0xBA; // KEYCODE_SEMICOLON     (;) → VK_OEM_1
      case 2063: return 0xDE; // KEYCODE_APOSTROPHE    (') → VK_OEM_7
      case 2064: return 0xBF; // KEYCODE_SLASH         (/) → VK_OEM_2

      case 2066: return 0xBB; // KEYCODE_PLUS    (+) → VK_OEM_PLUS
      case 2067: return 0x5D;
      case 2068: return 0x21; // KEYCODE_PAGE_UP     → VK_PRIOR
      case 2069: return 0x22; // KEYCODE_PAGE_DOWN   → VK_NEXT
      case 2070: return 0x1B; // KEYCODE_ESCAPE      → VK_ESCAPE
      case 2071: return 0x2E; // KEYCODE_FORWARD_DEL → VK_DELETE

      case 2072: return 0xA2; // KEYCODE_CTRL_LEFT   → VK_LCONTROL
      case 2073: return 0xA3; // KEYCODE_CTRL_RIGHT  → VK_RCONTROL

      case 2074: return 0x14; // KEYCODE_CAPS_LOCK   → VK_CAPITAL
      case 2075: return 0x91; // KEYCODE_SCROLL_LOCK → VK_SCROLL

      case 2076: return 0x5B; // KEYCODE_META_LEFT   → VK_LWIN
      case 2077: return 0x5C; // KEYCODE_META_RIGHT  → VK_RWIN

      case 2079: return 0x2C; // KEYCODE_SYSRQ       → VK_SNAPSHOT (PrintScreen)
      case 2080: return 0x13; // KEYCODE_BREAK       → VK_PAUSE
      case 2081: return 0x24; // KEYCODE_MOVE_HOME   → VK_HOME
      case 2082: return 0x23; // KEYCODE_MOVE_END    → VK_END
      case 2083: return 0x2D; // KEYCODE_INSERT      → VK_INSERT

      case 2102: return 0x90; // KEYCODE_NUM_LOCK        → VK_NUMLOCK
      case 2113: return 0x6F; // KEYCODE_NUMPAD_DIVIDE   → VK_DIVIDE
      case 2114: return 0x6A; // KEYCODE_NUMPAD_MULTIPLY → VK_MULTIPLY
      case 2115: return 0x6D; // KEYCODE_NUMPAD_SUBTRACT → VK_SUBTRACT
      case 2116: return 0x6B; // KEYCODE_NUMPAD_ADD      → VK_ADD
      case 2117: return 0x6E; // KEYCODE_NUMPAD_DOT      → VK_DECIMAL
      case 2119: return 0x0D; // KEYCODE_NUMPAD_ENTER    → VK_RETURN

      default: return 0;
    }
  }
}
