/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

export class ButtonFlags {
  static readonly UP_FLAG: number = 0x0001;
  static readonly DOWN_FLAG: number = 0x0002;
  static readonly LEFT_FLAG: number = 0x0004;
  static readonly RIGHT_FLAG: number = 0x0008;
  static readonly PLAY_FLAG: number = 0x0010; // Start
  static readonly BACK_FLAG: number = 0x0020; // Select/Back
  static readonly LS_CLK_FLAG: number = 0x0040;
  static readonly RS_CLK_FLAG: number = 0x0080;
  static readonly LB_FLAG: number = 0x0100;
  static readonly RB_FLAG: number = 0x0200;
  static readonly SPECIAL_BUTTON_FLAG: number = 0x0400;
  static readonly A_FLAG: number = 0x1000;
  static readonly B_FLAG: number = 0x2000;
  static readonly X_FLAG: number = 0x4000;
  static readonly Y_FLAG: number = 0x8000;
  static readonly PADDLE1_FLAG: number = 0x010000;
  static readonly PADDLE2_FLAG: number = 0x020000;
  static readonly PADDLE3_FLAG: number = 0x040000;
  static readonly PADDLE4_FLAG: number = 0x080000;
  static readonly TOUCHPAD_FLAG: number = 0x100000;
  static readonly MISC_FLAG: number = 0x200000;
}

export class ControllerType {
  static readonly UNKNOWN: number = 0;
  static readonly XBOX: number = 1;
  static readonly PS: number = 2;
  static readonly NINTENDO: number = 3;
}

export class ControllerCapabilities {
  static readonly ANALOG_TRIGGERS: number = 0x01;
  static readonly RUMBLE: number = 0x02;
  static readonly TRIGGER_RUMBLE: number = 0x04;
  static readonly TOUCHPAD: number = 0x08;
  static readonly ACCEL: number = 0x10;
  static readonly GYRO: number = 0x20;
  static readonly BATTERY: number = 0x40;
  static readonly RGB_LED: number = 0x80; // RGB LED
}

export class MotionType {
  static readonly GYRO: number = 1;
  static readonly ACCEL: number = 2;
}

export class DPadDirection {
  static readonly UP: number = 0;
  static readonly UP_RIGHT: number = 1;
  static readonly RIGHT: number = 2;
  static readonly DOWN_RIGHT: number = 3;
  static readonly DOWN: number = 4;
  static readonly DOWN_LEFT: number = 5;
  static readonly LEFT: number = 6;
  static readonly UP_LEFT: number = 7;
  static readonly NEUTRAL: number = 8;
}

export class UsbClass {
  static readonly USB_CLASS_HID: number = 3;
  static readonly USB_CLASS_VENDOR_SPEC: number = 255;
}

export class UsbDirection {
  static readonly USB_DIR_IN: number = 0x80;
  static readonly USB_DIR_OUT: number = 0x00;
}

export class Xbox360 {
  static readonly IFACE_SUBCLASS: number = 93;
  static readonly IFACE_PROTOCOL: number = 1; // Wired only
  static readonly SUPPORTED_VENDORS: number[] = [
    0x0079, // GPD Win 2
    0x044f, // Thrustmaster
    0x045e, // Microsoft
    0x046d, // Logitech
    0x056e, // Elecom
    0x06a3, // Saitek
    0x0738, // Mad Catz
    0x07ff, // Mad Catz
    0x0e6f, // Unknown
    0x0f0d, // Hori
    0x1038, // SteelSeries
    0x11c9, // Nacon
    0x1209, // Ardwiino
    0x12ab, // Unknown
    0x1430, // RedOctane
    0x146b, // BigBen
    0x1532, // Razer Sabertooth
    0x15e4, // Numark
    0x162e, // Joytech
    0x1689, // Razer Onza
    0x1949, // Lab126 (Amazon Luna)
    0x1bad, // Harmonix
    0x20d6, // PowerA
    0x24c6, // PowerA
    0x2f24, // GameSir
    0x3537, // GameSir (G7 Pro/Cyclone 2/Kaleid Flux)
    0x2dc8, // 8BitDo
  ];
}

export class XboxOne {
  static readonly IFACE_SUBCLASS: number = 71;
  static readonly IFACE_PROTOCOL: number = 208;
  static readonly SUPPORTED_VENDORS: number[] = [
    0x045e, // Microsoft
    0x0738, // Mad Catz
    0x0e6f, // Unknown
    0x0f0d, // Hori
    0x1532, // Razer Wildcat
    0x20d6, // PowerA
    0x24c6, // PowerA
    0x2e24, // Hyperkin
    0x2dc8, // 8BitDo
    0x2f24, // GameSir
    0x3537, // GameSir (G7 Pro/Cyclone 2/Kaleid Flux)
  ];
}

export class DualShock4 {
  static readonly VID: number = 0x054c; // Sony
  static readonly PIDS: number[] = [
    0x05c4, // DualShock 4 v1
    0x09cc, // DualShock 4 v2
  ];
}

export class DualSense {
  static readonly VID: number = 0x054c; // Sony
  static readonly PIDS: number[] = [
    0x0ce6, // DualSense
    0x0df2, // DualSense Edge
  ];
}

export class SwitchPro {
  static readonly VID: number = 0x057e; // Nintendo
  static readonly PRO_PID: number = 0x2009;
  static readonly JOYCON_LEFT_PID: number = 0x2006;
  static readonly JOYCON_RIGHT_PID: number = 0x2007;
  static readonly JOYCON_PAIR_PID: number = 0x2008;
}
