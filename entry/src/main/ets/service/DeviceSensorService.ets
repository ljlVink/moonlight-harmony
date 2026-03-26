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
 */

import { sensor } from '@kit.SensorServiceKit';
import { display } from '@kit.ArkUI';

// =============================================================================
// =============================================================================

/**
export const LI_MOTION_TYPE_ACCEL = 0x01;
export const LI_MOTION_TYPE_GYRO = 0x02;

/**
const RAD_TO_DEG = 57.2957795;

export type SensorDataCallback = (
  controllerNumber: number,
  motionType: number,
  x: number,
  y: number,
  z: number
) => void;

/**
 * 
 */
export class DeviceSensorService {
  private static instance: DeviceSensorService;

  private gyroEnabled: boolean = false;
  private accelEnabled: boolean = false;
  private gyroReportRateHz: number = 0;
  private accelReportRateHz: number = 0;

  private controllerNumber: number = 0;

  private dataCallback: SensorDataCallback | null = null;

  private lastGyroValues: number[] = [0, 0, 0];
  private lastAccelValues: number[] = [0, 0, 0];

  private gyroAvailable: boolean = false;
  private accelAvailable: boolean = false;
  private availabilityChecked: boolean = false;

  private constructor() {}

  static getInstance(): DeviceSensorService {
    if (!DeviceSensorService.instance) {
      DeviceSensorService.instance = new DeviceSensorService();
    }
    return DeviceSensorService.instance;
  }

  hasGyroscope(): boolean {
    this.checkAvailability();
    return this.gyroAvailable;
  }

  hasAccelerometer(): boolean {
    this.checkAvailability();
    return this.accelAvailable;
  }

  private checkAvailability(): void {
    if (this.availabilityChecked) {
      return;
    }

    try {
      sensor.once(sensor.SensorId.GYROSCOPE, (_data: sensor.GyroscopeResponse) => {
      });
      this.gyroAvailable = true;
    } catch {
      this.gyroAvailable = false;
    }

    try {
      sensor.once(sensor.SensorId.ACCELEROMETER, (_data: sensor.AccelerometerResponse) => {
      });
      this.accelAvailable = true;
    } catch {
      this.accelAvailable = false;
    }

    this.availabilityChecked = true;
    console.info(`[DeviceSensor] 可用性检查: gyro=${this.gyroAvailable}, accel=${this.accelAvailable}`);
  }

  setDataCallback(callback: SensorDataCallback | null): void {
    this.dataCallback = callback;
  }

  setControllerNumber(controllerNumber: number): void {
    this.controllerNumber = controllerNumber;
  }

  private getDeviceRotation(): number {
    try {
      const defaultDisplay = display.getDefaultDisplaySync();
      return defaultDisplay.rotation * 90;
    } catch {
      return 0;
    }
  }

  /**
   * 
   */
  private correctOrientation(rawX: number, rawY: number, rawZ: number): number[] {
    const rotation = this.getDeviceRotation();
    let x: number, y: number, z: number;

    switch (rotation) {
      case 0:
        x = rawX;
        y = rawZ;
        z = -rawY;
        break;
      case 90:
        x = rawY;
        y = rawZ;
        z = rawX;
        break;
      case 180:
        x = -rawX;
        y = rawZ;
        z = rawY;
        break;
      case 270:
        x = -rawY;
        y = rawZ;
        z = -rawX;
        break;
      default:
        x = rawX;
        y = rawY;
        z = rawZ;
        break;
    }

    return [x, y, z];
  }

  /**
   * 
   */
  setMotionEventState(motionType: number, reportRateHz: number): void {
    if (motionType === LI_MOTION_TYPE_GYRO) {
      this.setGyroState(reportRateHz);
    } else if (motionType === LI_MOTION_TYPE_ACCEL) {
      this.setAccelState(reportRateHz);
    }
  }

  private setGyroState(reportRateHz: number): void {
    if (this.gyroEnabled) {
      try {
        sensor.off(sensor.SensorId.GYROSCOPE);
      } catch (err) {
        console.warn(`[DeviceSensor] 取消陀螺仪订阅失败: ${err}`);
      }
      this.gyroEnabled = false;
    }

    this.gyroReportRateHz = reportRateHz;

    if (reportRateHz === 0) {
      console.info('[DeviceSensor] 陀螺仪已禁用');
      if (this.dataCallback) {
        this.dataCallback(this.controllerNumber, LI_MOTION_TYPE_GYRO, 0, 0, 0);
      }
      return;
    }

    const intervalUs = Math.floor(1000000 / Math.min(200, reportRateHz));

    try {
      sensor.on(sensor.SensorId.GYROSCOPE, (data: sensor.GyroscopeResponse) => {
        if (data.x === this.lastGyroValues[0] &&
            data.y === this.lastGyroValues[1] &&
            data.z === this.lastGyroValues[2]) {
          return;
        }
        this.lastGyroValues[0] = data.x;
        this.lastGyroValues[1] = data.y;
        this.lastGyroValues[2] = data.z;

        const rawX = data.x * RAD_TO_DEG;
        const rawY = data.y * RAD_TO_DEG;
        const rawZ = data.z * RAD_TO_DEG;

        const corrected = this.correctOrientation(rawX, rawY, rawZ);
        const cx = corrected[0];
        const cy = corrected[1];
        const cz = corrected[2];

        if (this.dataCallback) {
          this.dataCallback(this.controllerNumber, LI_MOTION_TYPE_GYRO, cx, cy, cz);
        }
      }, { interval: intervalUs });

      this.gyroEnabled = true;
      console.info(`[DeviceSensor] 陀螺仪已启用: rate=${reportRateHz}Hz, interval=${intervalUs}us`);
    } catch (err) {
      console.error(`[DeviceSensor] 启用陀螺仪失败: ${err}`);
      this.gyroAvailable = false;
    }
  }

  private setAccelState(reportRateHz: number): void {
    if (this.accelEnabled) {
      try {
        sensor.off(sensor.SensorId.ACCELEROMETER);
      } catch (err) {
        console.warn(`[DeviceSensor] 取消加速度计订阅失败: ${err}`);
      }
      this.accelEnabled = false;
    }

    this.accelReportRateHz = reportRateHz;

    if (reportRateHz === 0) {
      console.info('[DeviceSensor] 加速度计已禁用');
      return;
    }

    const intervalUs = Math.floor(1000000 / Math.min(200, reportRateHz));

    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
        if (data.x === this.lastAccelValues[0] &&
            data.y === this.lastAccelValues[1] &&
            data.z === this.lastAccelValues[2]) {
          return;
        }
        this.lastAccelValues[0] = data.x;
        this.lastAccelValues[1] = data.y;
        this.lastAccelValues[2] = data.z;

        const rawX = data.x;
        const rawY = data.y;
        const rawZ = data.z;

        const corrected = this.correctOrientation(rawX, rawY, rawZ);
        const cx = corrected[0];
        const cy = corrected[1];
        const cz = corrected[2];

        if (this.dataCallback) {
          this.dataCallback(this.controllerNumber, LI_MOTION_TYPE_ACCEL, cx, cy, cz);
        }
      }, { interval: intervalUs });

      this.accelEnabled = true;
      console.info(`[DeviceSensor] 加速度计已启用: rate=${reportRateHz}Hz, interval=${intervalUs}us`);
    } catch (err) {
      console.error(`[DeviceSensor] 启用加速度计失败: ${err}`);
      this.accelAvailable = false;
    }
  }

  disableAll(): void {
    this.setGyroState(0);
    this.setAccelState(0);
    this.dataCallback = null;
    console.info('[DeviceSensor] 所有传感器已禁用');
  }

  reenableActiveSensors(): void {
    if (this.gyroReportRateHz > 0) {
      this.setGyroState(this.gyroReportRateHz);
    }
    if (this.accelReportRateHz > 0) {
      this.setAccelState(this.accelReportRateHz);
    }
  }

  isActive(): boolean {
    return this.gyroEnabled || this.accelEnabled;
  }

  isGyroActive(): boolean {
    return this.gyroEnabled;
  }

  isAccelActive(): boolean {
    return this.accelEnabled;
  }

  getGyroReportRate(): number {
    return this.gyroReportRateHz;
  }

  getAccelReportRate(): number {
    return this.accelReportRateHz;
  }

  getLastGyroValues(): number[] {
    return [...this.lastGyroValues];
  }

  getLastAccelValues(): number[] {
    return [...this.lastAccelValues];
  }

  getCurrentRotation(): number {
    return this.getDeviceRotation();
  }
}
