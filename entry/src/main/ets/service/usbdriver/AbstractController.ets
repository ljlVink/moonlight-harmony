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
 * USB Controller abstract base class
 *
 * Reference: Android moonlight-android AbstractController
 */

import { UsbDriverListener } from "./UsbDriverListener";
import { ControllerType, ControllerCapabilities, ButtonFlags } from "./ControllerConstants";

export enum ControllerState {
  Created,
  Initializing,
  Ready,
  Stopped,
}

export abstract class AbstractController {
  protected deviceId: number;
  protected vendorId: number;
  protected productId: number;
  protected listener: UsbDriverListener;
  protected deviceName: string = "Unknown Controller";

  // Device unique identifier (to distinguish multiple devices of the same model)
  protected busNum: number = 0;
  protected devAddress: number = 0;
  protected serial: string = "";

  // Configuration options
  protected ignoreDisconnect: boolean = false;
  protected ddkActive: boolean = false;
  protected ddkPollingEnabled: boolean = false;

  // Lifecycle state
  private controllerState: ControllerState = ControllerState.Created;

  // Input state
  protected buttonFlags: number = 0;
  protected supportedButtonFlags: number = 0;
  protected leftTrigger: number = 0;
  protected rightTrigger: number = 0;
  protected leftStickX: number = 0;
  protected leftStickY: number = 0;
  protected rightStickX: number = 0;
  protected rightStickY: number = 0;

  // Touchpad state (DualSense/DualShock4)
  protected touchpadActive: boolean = false;
  protected touchpadX: number = 0;
  protected touchpadY: number = 0;

  // Controller properties
  protected capabilities: number = 0;
  protected type: number = ControllerType.UNKNOWN;

  constructor(deviceId: number, listener: UsbDriverListener, vendorId: number, productId: number) {
    this.deviceId = deviceId;
    this.listener = listener;
    this.vendorId = vendorId;
    this.productId = productId;
  }

  setDeviceLocation(busNum: number, devAddress: number, serial: string): void {
    this.busNum = busNum;
    this.devAddress = devAddress;
    this.serial = serial;
  }

  setIgnoreDisconnect(ignore: boolean): void {
    this.ignoreDisconnect = ignore;
  }

  setDdkPollingEnabled(enabled: boolean): void {
    this.ddkPollingEnabled = enabled;
  }

  getIgnoreDisconnect(): boolean {
    return this.ignoreDisconnect;
  }

  isDdkPolling(): boolean {
    return this.ddkActive;
  }

  getDeviceKey(): string {
    return `${this.vendorId}:${this.productId}:${this.busNum}:${this.devAddress}`;
  }

  getName(): string {
    return this.deviceName;
  }

  getDeviceId(): number {
    return this.deviceId;
  }

  getControllerId(): number {
    return this.deviceId;
  }

  getVendorId(): number {
    return this.vendorId;
  }

  getProductId(): number {
    return this.productId;
  }

  getSupportedButtonFlags(): number {
    return this.supportedButtonFlags;
  }

  getCapabilities(): number {
    return this.capabilities;
  }

  getType(): number {
    return this.type;
  }

  getControllerType(): number {
    return this.type;
  }

  protected setButtonFlag(buttonFlag: number, data: number): void {
    if (data !== 0) {
      this.buttonFlags |= buttonFlag;
    } else {
      this.buttonFlags &= ~buttonFlag;
    }
  }

  protected reportInput(): void {
    if (this.listener) {
      this.listener.reportControllerState(
        this.deviceId,
        this.buttonFlags,
        this.leftStickX,
        this.leftStickY,
        this.rightStickX,
        this.rightStickY,
        this.leftTrigger,
        this.rightTrigger,
      );
    }
  }

  protected notifyDeviceRemoved(): void {
    if (this.listener) {
      this.listener.deviceRemoved(this);
    }
  }

  protected notifyDeviceAdded(): void {
    if (
      this.controllerState === ControllerState.Ready ||
      this.controllerState === ControllerState.Stopped
    )
      return;
    this.controllerState = ControllerState.Ready;
    if (this.listener) {
      this.listener.deviceAdded(this);
    }
  }

  getState(): ControllerState {
    return this.controllerState;
  }

  isReady(): boolean {
    return this.controllerState === ControllerState.Ready;
  }

  protected markInitializing(): void {
    this.controllerState = ControllerState.Initializing;
  }

  protected markStopped(): void {
    this.controllerState = ControllerState.Stopped;
  }

  protected notifyControllerMotion(motionType: number, x: number, y: number, z: number): void {
    if (this.listener) {
      this.listener.reportControllerMotion(this.deviceId, motionType, x, y, z);
    }
  }

  protected notifyTouchpadInput(active: boolean, x: number, y: number): void {
    if (this.listener) {
      this.listener.reportTouchpadInput(this.deviceId, active, x, y);
    }
  }

  abstract start(): boolean;

  abstract stop(): void;

  abstract isConnected(): boolean;

  getLastActivityTime(): number {
    return 0;
  }

  mayBeSilentlyDisconnected(inactivityThresholdMs: number = 30000): boolean {
    return false;
  }

  abstract rumble(lowFreqMotor: number, highFreqMotor: number): void;

  abstract rumbleTriggers(leftTrigger: number, rightTrigger: number): void;
}
