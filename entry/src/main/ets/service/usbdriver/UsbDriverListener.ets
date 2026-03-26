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

import { AbstractController } from './AbstractController';

export interface UsbDriverListener {
  reportControllerState(
    controllerId: number,
    buttonFlags: number,
    leftStickX: number,
    leftStickY: number,
    rightStickX: number,
    rightStickY: number,
    leftTrigger: number,
    rightTrigger: number
  ): void;

  reportControllerMotion(
    controllerId: number,
    motionType: number,
    x: number,
    y: number,
    z: number
  ): void;

  reportTouchpadInput(
    controllerId: number,
    active: boolean,
    x: number,
    y: number
  ): void;

  deviceRemoved(controller: AbstractController): void;

  deviceAdded(controller: AbstractController): void;
}

export interface UsbDriverStateListener {
  onUsbPermissionPromptStarting(): void;

  onUsbPermissionPromptCompleted(): void;
}
