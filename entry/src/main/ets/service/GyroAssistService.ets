/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */


import { DeviceSensorService, LI_MOTION_TYPE_GYRO, SensorDataCallback } from './DeviceSensorService';

const STICK_MAX: number = 0x7FFE; // 32766

export const GYRO_ACTIVATION_ALWAYS: number = -1;
export const GYRO_ACTIVATION_LT: number = 0;
export const GYRO_ACTIVATION_RT: number = 1;

const TRIGGER_ACTIVATE_THRESHOLD: number = 51; // 255 * 0.2


const DEFAULT_SENSITIVITY: number = 2.0;


const GYRO_REPORT_RATE_HZ: number = 120;

const PHYS_EPSILON: number = 512;

export type GyroSendCallback = (
  deviceId: number,
  buttons: number,
  leftStickX: number,
  leftStickY: number,
  rightStickX: number,
  rightStickY: number,
  leftTrigger: number,
  rightTrigger: number,
  controllerType: number
) => void;

export class GyroAssistService {
  private static instance: GyroAssistService | null = null;

  private _enabled: boolean = false;
  private _sensitivityMultiplier: number = DEFAULT_SENSITIVITY;
  private _invertX: boolean = false;
  private _invertY: boolean = false;
  private _activationKey: number = GYRO_ACTIVATION_ALWAYS;

  private gyroStickX: number = 0;
  private gyroStickY: number = 0;
  private holdActive: boolean = false;
  private sensorListening: boolean = false;
  private controllerNumber: number = 0;

  private lastDeviceId: number = 0;
  private lastButtons: number = 0;
  private lastLeftStickX: number = 0;
  private lastLeftStickY: number = 0;
  private lastPhysRightStickX: number = 0;
  private lastPhysRightStickY: number = 0;
  private lastLeftTrigger: number = 0;
  private lastRightTrigger: number = 0;
  private lastControllerType: number = 1; // Xbox
  private sendCallback: GyroSendCallback | null = null;

  private sensorService: DeviceSensorService;

  private originalSensorCallback: SensorDataCallback | null = null;

  private constructor() {
    this.sensorService = DeviceSensorService.getInstance();
  }

  static getInstance(): GyroAssistService {
    if (!GyroAssistService.instance) {
      GyroAssistService.instance = new GyroAssistService();
    }
    return GyroAssistService.instance;
  }

  get enabled(): boolean {
    return this._enabled;
  }

  get sensitivityMultiplier(): number {
    return this._sensitivityMultiplier;
  }

  get invertX(): boolean {
    return this._invertX;
  }

  get invertY(): boolean {
    return this._invertY;
  }

  get activationKey(): number {
    return this._activationKey;
  }

  setEnabled(enabled: boolean): void {
    if (this._enabled === enabled) return;
    this._enabled = enabled;

    if (enabled) {
      this.startListening();
    } else {
      this.stopListening();
    }
  }

  setSensitivity(multiplier: number): void {
    this._sensitivityMultiplier = Math.max(0.5, Math.min(10.0, multiplier));
  }

  setInvertX(invert: boolean): void {
    this._invertX = invert;
  }

  setInvertY(invert: boolean): void {
    this._invertY = invert;
  }


  setActivationKey(key: number): void {
    this._activationKey = key;
    if (key === GYRO_ACTIVATION_ALWAYS) {
      this.holdActive = true;
    } else {
      this.holdActive = false;
      this.gyroStickX = 0;
      this.gyroStickY = 0;
    }
  }

  loadSettings(settings: GyroAssistSettings): void {
    this._sensitivityMultiplier = settings.sensitivity;
    this._invertX = settings.invertX;
    this._invertY = settings.invertY;
    this._activationKey = settings.activationKey;

    if (this._activationKey === GYRO_ACTIVATION_ALWAYS) {
      this.holdActive = true;
    }
  }


  private onGyroData(controllerNumber: number, motionType: number,
    gx: number, gy: number, gz: number): void {
    if (motionType !== LI_MOTION_TYPE_GYRO) return;
    if (!this._enabled || !this.holdActive) {
      this.gyroStickX = 0;
      this.gyroStickY = 0;
      return;
    }

    const effectiveSensitivity = 180.0 / this._sensitivityMultiplier;

    let scaledX = -this.clampFloat(gz / effectiveSensitivity, -1.0, 1.0);
    let scaledY = this.clampFloat(gx / effectiveSensitivity, -1.0, 1.0);

    if (this._invertX) scaledX = -scaledX;
    if (this._invertY) scaledY = -scaledY;

    this.gyroStickX = Math.round(scaledX * STICK_MAX);
    this.gyroStickY = Math.round(scaledY * STICK_MAX);

    if (this.sendCallback !== null) {
      const px = this.denoisePhys(this.lastPhysRightStickX);
      const py = this.denoisePhys(this.lastPhysRightStickY);
      const fusedX = this.clampShort(px + this.gyroStickX);
      const fusedY = this.clampShort(py + this.gyroStickY);
      this.sendCallback(
        this.lastDeviceId,
        this.lastButtons,
        this.lastLeftStickX,
        this.lastLeftStickY,
        fusedX,
        fusedY,
        this.lastLeftTrigger,
        this.lastRightTrigger,
        this.lastControllerType
      );
    }
  }

  updateActivation(leftTrigger: number, rightTrigger: number): void {
    if (this._activationKey === GYRO_ACTIVATION_ALWAYS) {
      this.holdActive = true;
      return;
    }

    const wasActive = this.holdActive;

    if (this._activationKey === GYRO_ACTIVATION_LT) {
      this.holdActive = leftTrigger >= TRIGGER_ACTIVATE_THRESHOLD;
    } else if (this._activationKey === GYRO_ACTIVATION_RT) {
      this.holdActive = rightTrigger >= TRIGGER_ACTIVATE_THRESHOLD;
    }

    if (wasActive && !this.holdActive) {
      this.gyroStickX = 0;
      this.gyroStickY = 0;
    }
  }


  fuseRightStick(physRsX: number, physRsY: number): StickXY {
    const result: StickXY = { x: physRsX, y: physRsY };
    if (!this._enabled || !this.holdActive) {
      return result;
    }

    result.x = this.clampShort(this.denoisePhys(physRsX) + this.gyroStickX);
    result.y = this.clampShort(this.denoisePhys(physRsY) + this.gyroStickY);
    return result;
  }

  updateGamepadState(
    deviceId: number,
    buttons: number,
    leftStickX: number,
    leftStickY: number,
    physRightStickX: number,
    physRightStickY: number,
    leftTrigger: number,
    rightTrigger: number,
    controllerType: number
  ): void {
    this.lastDeviceId = deviceId;
    this.lastButtons = buttons;
    this.lastLeftStickX = leftStickX;
    this.lastLeftStickY = leftStickY;
    this.lastPhysRightStickX = physRightStickX;
    this.lastPhysRightStickY = physRightStickY;
    this.lastLeftTrigger = leftTrigger;
    this.lastRightTrigger = rightTrigger;
    this.lastControllerType = controllerType;
  }

  setSendCallback(callback: GyroSendCallback | null): void {
    this.sendCallback = callback;
  }

  getGyroStickValues(): StickXY {
    const values: StickXY = { x: this.gyroStickX, y: this.gyroStickY };
    return values;
  }

  isHoldActive(): boolean {
    return this.holdActive;
  }

  private startListening(): void {
    if (this.sensorListening) return;
    if (!this.sensorService.hasGyroscope()) {
      console.warn('[GyroAssist] 设备没有陀螺仪');
      return;
    }

    this.sensorService.setControllerNumber(this.controllerNumber);
    this.sensorService.setDataCallback(
      (cn: number, mt: number, x: number, y: number, z: number) => {
        this.onGyroData(cn, mt, x, y, z);
        if (this.originalSensorCallback) {
          this.originalSensorCallback(cn, mt, x, y, z);
        }
      }
    );

    this.sensorService.setMotionEventState(LI_MOTION_TYPE_GYRO, GYRO_REPORT_RATE_HZ);
    this.sensorListening = true;

    if (this._activationKey === GYRO_ACTIVATION_ALWAYS) {
      this.holdActive = true;
    }

    console.info(`[GyroAssist] 体感助手已启动 (灵敏度: ${this._sensitivityMultiplier}x, ` +
      `激活键: ${this._activationKey === GYRO_ACTIVATION_ALWAYS ? '始终' :
        this._activationKey === GYRO_ACTIVATION_LT ? 'LT' : 'RT'})`);
  }

  private stopListening(): void {
    if (!this.sensorListening) return;

    this.sensorService.setMotionEventState(LI_MOTION_TYPE_GYRO, 0);
    this.sensorListening = false;
    this.holdActive = false;
    this.gyroStickX = 0;
    this.gyroStickY = 0;

    console.info('[GyroAssist] 体感助手已停止');
  }

  setOriginalSensorCallback(callback: SensorDataCallback | null): void {
    this.originalSensorCallback = callback;
  }

  setControllerNumber(num: number): void {
    this.controllerNumber = num;
  }

  dispose(): void {
    this.stopListening();
    this.originalSensorCallback = null;
    this.sendCallback = null;
  }

  private clampFloat(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
  }

  private clampShort(value: number): number {
    return Math.max(-32767, Math.min(32767, Math.round(value)));
  }

  private denoisePhys(v: number): number {
    return Math.abs(v) <= PHYS_EPSILON ? 0 : v;
  }
}

export interface GyroAssistSettings {
  sensitivity: number;
  invertX: boolean;
  invertY: boolean;
  activationKey: number;
}


export interface StickXY {
  x: number;
  y: number;
}
