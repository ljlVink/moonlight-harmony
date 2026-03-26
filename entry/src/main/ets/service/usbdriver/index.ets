/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */


export { AbstractController } from './AbstractController';
export { UsbDriverListener, UsbDriverStateListener } from './UsbDriverListener';
export { UsbDriverService } from './UsbDriverService';
export { Xbox360Controller } from './Xbox360Controller';
export { XboxOneController } from './XboxOneController';
export { Dualshock4Controller } from './Dualshock4Controller';
export { DualSenseController } from './DualSenseController';
export { SwitchProController } from './SwitchProController';
export { NativeHidController } from './NativeHidController';
export { 
  ButtonFlags, 
  ControllerType, 
  ControllerCapabilities, 
  MotionType,
  DPadDirection,
  Xbox360,
  XboxOne,
  DualShock4,
  DualSense,
  SwitchPro
} from './ControllerConstants';

export { NativeHidParserService } from './NativeHidParserService';
export { NativeButtonFlags, NativeGamepadType } from './NativeGamepad';
export type { NativeGamepadState } from './NativeGamepad';

export enum ProtocolType {
  AUTO = 0,
  XBOX = 1,
  DS4 = 2,
  SWITCH = 3,
  GENERIC = 4,
  DUALSENSE = 5
}
