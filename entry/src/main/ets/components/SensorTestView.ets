/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */


import { DeviceSensorService, LI_MOTION_TYPE_ACCEL, LI_MOTION_TYPE_GYRO } from '../service/DeviceSensorService';
import { AppColors } from '../common/Theme';

interface AxisBarParams {
  axis: string;
  value: number;
  maxRange: number;
  color: string;
}

class SensorDataRecord {
  timestamp: string;
  motionType: number;
  x: number;
  y: number;
  z: number;

  constructor(motionType: number, x: number, y: number, z: number) {
    this.timestamp = new Date().toLocaleTimeString();
    this.motionType = motionType;
    this.x = x;
    this.y = y;
    this.z = z;
  }
}

@Component
export struct SensorTestView {
  private sensorService: DeviceSensorService = DeviceSensorService.getInstance();

  @State gyroAvailable: boolean = false;
  @State accelAvailable: boolean = false;

  @State gyroActive: boolean = false;
  @State accelActive: boolean = false;

  @State testReportRateHz: number = 100;

  @State gyroX: number = 0;
  @State gyroY: number = 0;
  @State gyroZ: number = 0;
  @State accelX: number = 0;
  @State accelY: number = 0;
  @State accelZ: number = 0;

  @State deviceRotation: number = 0;

  @State gyroDataCount: number = 0;
  @State accelDataCount: number = 0;
  @State lastGyroUpdateTime: number = 0;
  @State lastAccelUpdateTime: number = 0;
  @State gyroEffectiveRate: number = 0;
  @State accelEffectiveRate: number = 0;

  @State gyroMaxAbs: number = 0;
  @State accelMaxAbs: number = 0;

  @State logMessages: string[] = [];

  private refreshTimer: number = -1;
  private gyroCountInternal: number = 0;
  private accelCountInternal: number = 0;
  private lastRateCalcTime: number = 0;
  private gyroCountAtLastCalc: number = 0;
  private accelCountAtLastCalc: number = 0;
  private internalGyroX: number = 0;
  private internalGyroY: number = 0;
  private internalGyroZ: number = 0;
  private internalAccelX: number = 0;
  private internalAccelY: number = 0;
  private internalAccelZ: number = 0;
  private internalGyroMaxAbs: number = 0;
  private internalAccelMaxAbs: number = 0;

  aboutToAppear(): void {
    this.addLog('传感器测试视图初始化');
    this.checkAvailability();
    this.startRefreshTimer();
  }

  aboutToDisappear(): void {
    this.stopAllTests();
    this.clearRefreshTimer();
  }

  private checkAvailability(): void {
    this.gyroAvailable = this.sensorService.hasGyroscope();
    this.accelAvailable = this.sensorService.hasAccelerometer();
    this.addLog(`陀螺仪: ${this.gyroAvailable ? '可用' : '不可用'}`);
    this.addLog(`加速度计: ${this.accelAvailable ? '可用' : '不可用'}`);
    this.deviceRotation = this.sensorService.getCurrentRotation();
    this.addLog(`屏幕方向: ${this.deviceRotation}°`);
  }

  private startRefreshTimer(): void {
    this.lastRateCalcTime = Date.now();
    this.refreshTimer = setInterval(() => {
      this.gyroX = this.internalGyroX;
      this.gyroY = this.internalGyroY;
      this.gyroZ = this.internalGyroZ;
      this.accelX = this.internalAccelX;
      this.accelY = this.internalAccelY;
      this.accelZ = this.internalAccelZ;
      this.gyroMaxAbs = this.internalGyroMaxAbs;
      this.accelMaxAbs = this.internalAccelMaxAbs;
      this.gyroDataCount = this.gyroCountInternal;
      this.accelDataCount = this.accelCountInternal;

      const now = Date.now();
      const elapsed = (now - this.lastRateCalcTime) / 1000;
      if (elapsed >= 1.0) {
        this.gyroEffectiveRate = Math.round(
          (this.gyroCountInternal - this.gyroCountAtLastCalc) / elapsed
        );
        this.accelEffectiveRate = Math.round(
          (this.accelCountInternal - this.accelCountAtLastCalc) / elapsed
        );
        this.gyroCountAtLastCalc = this.gyroCountInternal;
        this.accelCountAtLastCalc = this.accelCountInternal;
        this.lastRateCalcTime = now;
      }

      this.gyroActive = this.sensorService.isGyroActive();
      this.accelActive = this.sensorService.isAccelActive();
      this.deviceRotation = this.sensorService.getCurrentRotation();
    }, 100) as number;
  }

  private clearRefreshTimer(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  private startGyroTest(): void {
    if (!this.gyroAvailable) {
      this.addLog('错误: 设备没有陀螺仪传感器');
      return;
    }

    this.sensorService.setDataCallback(
      (controllerNumber: number, motionType: number, x: number, y: number, z: number) => {
        if (motionType === LI_MOTION_TYPE_GYRO) {
          this.internalGyroX = x;
          this.internalGyroY = y;
          this.internalGyroZ = z;
          this.gyroCountInternal++;
          const maxVal = Math.max(Math.abs(x), Math.abs(y), Math.abs(z));
          if (maxVal > this.internalGyroMaxAbs) {
            this.internalGyroMaxAbs = maxVal;
          }
        } else if (motionType === LI_MOTION_TYPE_ACCEL) {
          this.internalAccelX = x;
          this.internalAccelY = y;
          this.internalAccelZ = z;
          this.accelCountInternal++;
          const maxVal = Math.max(Math.abs(x), Math.abs(y), Math.abs(z));
          if (maxVal > this.internalAccelMaxAbs) {
            this.internalAccelMaxAbs = maxVal;
          }
        }
      }
    );

    this.sensorService.setControllerNumber(0);
    this.sensorService.setMotionEventState(LI_MOTION_TYPE_GYRO, this.testReportRateHz);
    this.gyroActive = true;
    this.addLog(`陀螺仪测试启动: ${this.testReportRateHz}Hz`);
  }

  private stopGyroTest(): void {
    this.sensorService.setMotionEventState(LI_MOTION_TYPE_GYRO, 0);
    this.gyroActive = false;
    this.addLog('陀螺仪测试停止');
  }

  private startAccelTest(): void {
    if (!this.accelAvailable) {
      this.addLog('错误: 设备没有加速度计传感器');
      return;
    }

    this.sensorService.setDataCallback(
      (controllerNumber: number, motionType: number, x: number, y: number, z: number) => {
        if (motionType === LI_MOTION_TYPE_GYRO) {
          this.internalGyroX = x;
          this.internalGyroY = y;
          this.internalGyroZ = z;
          this.gyroCountInternal++;
          const maxVal = Math.max(Math.abs(x), Math.abs(y), Math.abs(z));
          if (maxVal > this.internalGyroMaxAbs) {
            this.internalGyroMaxAbs = maxVal;
          }
        } else if (motionType === LI_MOTION_TYPE_ACCEL) {
          this.internalAccelX = x;
          this.internalAccelY = y;
          this.internalAccelZ = z;
          this.accelCountInternal++;
          const maxVal = Math.max(Math.abs(x), Math.abs(y), Math.abs(z));
          if (maxVal > this.internalAccelMaxAbs) {
            this.internalAccelMaxAbs = maxVal;
          }
        }
      }
    );

    this.sensorService.setControllerNumber(0);
    this.sensorService.setMotionEventState(LI_MOTION_TYPE_ACCEL, this.testReportRateHz);
    this.accelActive = true;
    this.addLog(`加速度计测试启动: ${this.testReportRateHz}Hz`);
  }

  private stopAccelTest(): void {
    this.sensorService.setMotionEventState(LI_MOTION_TYPE_ACCEL, 0);
    this.accelActive = false;
    this.addLog('加速度计测试停止');
  }

  private stopAllTests(): void {
    this.sensorService.disableAll();
    this.sensorService.setDataCallback(null);
    this.gyroActive = false;
    this.accelActive = false;
    this.addLog('所有传感器测试停止');
  }

  private resetStats(): void {
    this.gyroCountInternal = 0;
    this.accelCountInternal = 0;
    this.gyroDataCount = 0;
    this.accelDataCount = 0;
    this.gyroMaxAbs = 0;
    this.accelMaxAbs = 0;
    this.internalGyroMaxAbs = 0;
    this.internalAccelMaxAbs = 0;
    this.gyroEffectiveRate = 0;
    this.accelEffectiveRate = 0;
    this.gyroCountAtLastCalc = 0;
    this.accelCountAtLastCalc = 0;
    this.lastRateCalcTime = Date.now();
    this.addLog('统计数据已重置');
  }

  addLog(message: string): void {
    const timestamp = new Date().toLocaleTimeString();
    this.logMessages = [`[${timestamp}] ${message}`, ...this.logMessages.slice(0, 49)];
  }

  private formatValue(value: number): string {
    return value.toFixed(3);
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        this.buildAvailabilitySection()

        this.buildControlSection()

        this.buildGyroDataSection()

        this.buildAccelDataSection()

        this.buildOrientationSection()

        this.buildStatsSection()

        this.buildLogSection()
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Background)
  }

  @Builder
  buildAvailabilitySection() {
    Column({ space: 8 }) {
      Text('传感器可用性')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .width('100%')

      Row({ space: 16 }) {
        Row({ space: 8 }) {
          Circle()
            .width(12)
            .height(12)
            .fill(this.gyroAvailable
              ? (this.gyroActive ? '#4CAF50' : '#FFC107')
              : '#F44336')
          Column({ space: 2 }) {
            Text('陀螺仪')
              .fontSize(14)
              .fontColor(AppColors.TextPrimary)
            Text(this.gyroAvailable
              ? (this.gyroActive ? '采集中' : '可用')
              : '不可用')
              .fontSize(11)
              .fontColor(AppColors.TextSecondary)
          }
        }

        Row({ space: 8 }) {
          Circle()
            .width(12)
            .height(12)
            .fill(this.accelAvailable
              ? (this.accelActive ? '#4CAF50' : '#FFC107')
              : '#F44336')
          Column({ space: 2 }) {
            Text('加速度计')
              .fontSize(14)
              .fontColor(AppColors.TextPrimary)
            Text(this.accelAvailable
              ? (this.accelActive ? '采集中' : '可用')
              : '不可用')
              .fontSize(11)
              .fontColor(AppColors.TextSecondary)
          }
        }

        Row({ space: 8 }) {
          Circle()
            .width(12)
            .height(12)
            .fill('#2196F3')
          Column({ space: 2 }) {
            Text('屏幕方向')
              .fontSize(14)
              .fontColor(AppColors.TextPrimary)
            Text(`${this.deviceRotation}°`)
              .fontSize(11)
              .fontColor(AppColors.TextSecondary)
          }
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.Surface)
    .borderRadius(12)
  }

  @Builder
  buildControlSection() {
    Column({ space: 12 }) {
      Text('测试控制')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .width('100%')

      Row({ space: 8 }) {
        Text('采样频率:')
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)

        this.buildRateButton(50)
        this.buildRateButton(100)
        this.buildRateButton(200)
      }
      .width('100%')

      Row({ space: 8 }) {
        Button(this.gyroActive ? '停止陀螺仪' : '启动陀螺仪')
          .onClick(() => {
            if (this.gyroActive) {
              this.stopGyroTest();
            } else {
              this.startGyroTest();
            }
          })
          .backgroundColor(this.gyroActive ? AppColors.Error : AppColors.Success)
          .fontColor(AppColors.TextOnPrimary)
          .fontSize(13)
          .height(36)
          .padding({ left: 14, right: 14 })
          .borderRadius(18)
          .enabled(this.gyroAvailable)

        Button(this.accelActive ? '停止加速度计' : '启动加速度计')
          .onClick(() => {
            if (this.accelActive) {
              this.stopAccelTest();
            } else {
              this.startAccelTest();
            }
          })
          .backgroundColor(this.accelActive ? AppColors.Error : AppColors.Success)
          .fontColor(AppColors.TextOnPrimary)
          .fontSize(13)
          .height(36)
          .padding({ left: 14, right: 14 })
          .borderRadius(18)
          .enabled(this.accelAvailable)

        Button('全部停止')
          .onClick(() => {
            this.stopAllTests();
          })
          .backgroundColor(AppColors.SurfaceDark)
          .fontColor(AppColors.TextPrimary)
          .fontSize(13)
          .height(36)
          .padding({ left: 14, right: 14 })
          .borderRadius(18)
          .enabled(this.gyroActive || this.accelActive)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)

      Row() {
        Button('重置统计')
          .onClick(() => {
            this.resetStats();
          })
          .backgroundColor(AppColors.Primary)
          .fontColor(AppColors.TextOnPrimary)
          .fontSize(13)
          .height(36)
          .padding({ left: 14, right: 14 })
          .borderRadius(18)

        Button('刷新可用性')
          .onClick(() => {
            this.checkAvailability();
          })
          .backgroundColor(AppColors.Primary)
          .fontColor(AppColors.TextOnPrimary)
          .fontSize(13)
          .height(36)
          .padding({ left: 14, right: 14 })
          .borderRadius(18)
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.Surface)
    .borderRadius(12)
  }

  @Builder
  buildRateButton(rate: number) {
    Text(`${rate}Hz`)
      .fontSize(12)
      .fontColor(this.testReportRateHz === rate ? AppColors.TextOnPrimary : AppColors.TextSecondary)
      .backgroundColor(this.testReportRateHz === rate ? AppColors.Primary : AppColors.SurfaceDark)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(14)
      .onClick(() => {
        this.testReportRateHz = rate;
        this.addLog(`采样频率设置为 ${rate}Hz`);
        if (this.gyroActive) {
          this.sensorService.setMotionEventState(LI_MOTION_TYPE_GYRO, rate);
          this.addLog(`陀螺仪重新启动: ${rate}Hz`);
        }
        if (this.accelActive) {
          this.sensorService.setMotionEventState(LI_MOTION_TYPE_ACCEL, rate);
          this.addLog(`加速度计重新启动: ${rate}Hz`);
        }
      })
  }

  @Builder
  buildGyroDataSection() {
    Column({ space: 8 }) {
      Row() {
        Text('🌀 陀螺仪数据')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
        Blank()
        if (this.gyroActive) {
          Text(`${this.gyroEffectiveRate} Hz`)
            .fontSize(12)
            .fontColor('#4CAF50')
            .fontFamily('monospace')
        }
      }
      .width('100%')

      if (!this.gyroActive && this.gyroDataCount === 0) {
        Text('点击"启动陀螺仪"开始采集\n单位: deg/s (已从 rad/s 转换)')
          .fontSize(12)
          .fontColor(AppColors.TextSecondary)
          .textAlign(TextAlign.Center)
          .padding(12)
      } else {
        this.buildAxisBar({ axis: 'X', value: this.gyroX, maxRange: 500, color: '#F44336' })
        this.buildAxisBar({ axis: 'Y', value: this.gyroY, maxRange: 500, color: '#4CAF50' })
        this.buildAxisBar({ axis: 'Z', value: this.gyroZ, maxRange: 500, color: '#2196F3' })

        Row({ space: 16 }) {
          Column({ space: 2 }) {
            Text('X (deg/s)')
              .fontSize(10)
              .fontColor(AppColors.TextTertiary)
            Text(this.formatValue(this.gyroX))
              .fontSize(14)
              .fontColor('#F44336')
              .fontFamily('monospace')
          }
          Column({ space: 2 }) {
            Text('Y (deg/s)')
              .fontSize(10)
              .fontColor(AppColors.TextTertiary)
            Text(this.formatValue(this.gyroY))
              .fontSize(14)
              .fontColor('#4CAF50')
              .fontFamily('monospace')
          }
          Column({ space: 2 }) {
            Text('Z (deg/s)')
              .fontSize(10)
              .fontColor(AppColors.TextTertiary)
            Text(this.formatValue(this.gyroZ))
              .fontSize(14)
              .fontColor('#2196F3')
              .fontFamily('monospace')
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceEvenly)
        .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.Surface)
    .borderRadius(12)
  }

  @Builder
  buildAccelDataSection() {
    Column({ space: 8 }) {
      Row() {
        Text('📐 加速度计数据')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
        Blank()
        if (this.accelActive) {
          Text(`${this.accelEffectiveRate} Hz`)
            .fontSize(12)
            .fontColor('#4CAF50')
            .fontFamily('monospace')
        }
      }
      .width('100%')

      if (!this.accelActive && this.accelDataCount === 0) {
        Text('点击"启动加速度计"开始采集\n单位: m/s²')
          .fontSize(12)
          .fontColor(AppColors.TextSecondary)
          .textAlign(TextAlign.Center)
          .padding(12)
      } else {
        this.buildAxisBar({ axis: 'X', value: this.accelX, maxRange: 20, color: '#FF9800' })
        this.buildAxisBar({ axis: 'Y', value: this.accelY, maxRange: 20, color: '#9C27B0' })
        this.buildAxisBar({ axis: 'Z', value: this.accelZ, maxRange: 20, color: '#00BCD4' })

        Row({ space: 16 }) {
          Column({ space: 2 }) {
            Text('X (m/s²)')
              .fontSize(10)
              .fontColor(AppColors.TextTertiary)
            Text(this.formatValue(this.accelX))
              .fontSize(14)
              .fontColor('#FF9800')
              .fontFamily('monospace')
          }
          Column({ space: 2 }) {
            Text('Y (m/s²)')
              .fontSize(10)
              .fontColor(AppColors.TextTertiary)
            Text(this.formatValue(this.accelY))
              .fontSize(14)
              .fontColor('#9C27B0')
              .fontFamily('monospace')
          }
          Column({ space: 2 }) {
            Text('Z (m/s²)')
              .fontSize(10)
              .fontColor(AppColors.TextTertiary)
            Text(this.formatValue(this.accelZ))
              .fontSize(14)
              .fontColor('#00BCD4')
              .fontFamily('monospace')
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceEvenly)
        .margin({ top: 4 })

        Row({ space: 4 }) {
          Text('💡')
            .fontSize(11)
          Text(`合加速度: ${this.formatValue(Math.sqrt(this.accelX * this.accelX + this.accelY * this.accelY + this.accelZ * this.accelZ))} m/s² (静止时约 9.8)`)
            .fontSize(11)
            .fontColor(AppColors.TextTertiary)
        }
        .width('100%')
        .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.Surface)
    .borderRadius(12)
  }

  @Builder
  buildAxisBar($$: AxisBarParams) {
    Row({ space: 8 }) {
      Text($$.axis)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($$.color)
        .width(16)

      Stack() {
        Row()
          .width('100%')
          .height(12)
          .backgroundColor(AppColors.SurfaceDark)
          .borderRadius(6)

        Row()
          .width(1)
          .height(12)
          .backgroundColor(AppColors.TextTertiary)
          .position({ x: '50%', y: 0 })

        Row()
          .width(`${Math.min(50, Math.abs($$.value / $$.maxRange) * 50)}%`)
          .height(12)
          .backgroundColor($$.color)
          .borderRadius(6)
          .position({
            x: $$.value >= 0 ? '50%' : `${50 - Math.min(50, Math.abs($$.value / $$.maxRange) * 50)}%`,
            y: 0
          })
      }
      .layoutWeight(1)
      .height(12)
    }
    .width('100%')
  }

  @Builder
  buildOrientationSection() {
    Column({ space: 8 }) {
      Text('📱 设备方向校正')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .width('100%')

      Row({ space: 16 }) {
        this.buildOrientationIndicator(0, '竖屏')
        this.buildOrientationIndicator(90, '横屏↺')
        this.buildOrientationIndicator(180, '倒竖屏')
        this.buildOrientationIndicator(270, '横屏↻')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)

      Text('传感器数据会根据当前屏幕方向自动校正坐标轴\n确保不同握持姿势下数据方向一致')
        .fontSize(11)
        .fontColor(AppColors.TextTertiary)
        .textAlign(TextAlign.Center)
        .margin({ top: 4 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.Surface)
    .borderRadius(12)
  }

  @Builder
  buildOrientationIndicator(rotation: number, label: string) {
    Column({ space: 4 }) {
      Text(rotation === 0 ? '📱' : rotation === 90 ? '📱' : rotation === 180 ? '📱' : '📱')
        .fontSize(24)
        .rotate({ angle: rotation })
      Text(label)
        .fontSize(11)
        .fontColor(this.deviceRotation === rotation ? AppColors.Primary : AppColors.TextTertiary)
        .fontWeight(this.deviceRotation === rotation ? FontWeight.Bold : FontWeight.Normal)
      if (this.deviceRotation === rotation) {
        Text('当前')
          .fontSize(10)
          .fontColor(AppColors.Primary)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(AppColors.SurfaceTransparent)
          .borderRadius(4)
      }
    }
  }

  @Builder
  buildStatsSection() {
    Column({ space: 8 }) {
      Text('📊 统计信息')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .width('100%')

      Row({ space: 0 }) {
        Column({ space: 4 }) {
          Text('陀螺仪')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TextPrimary)
          Row({ space: 4 }) {
            Text('采样数:')
              .fontSize(11)
              .fontColor(AppColors.TextSecondary)
            Text(`${this.gyroDataCount}`)
              .fontSize(11)
              .fontColor(AppColors.TextPrimary)
              .fontFamily('monospace')
          }
          Row({ space: 4 }) {
            Text('有效频率:')
              .fontSize(11)
              .fontColor(AppColors.TextSecondary)
            Text(`${this.gyroEffectiveRate} Hz`)
              .fontSize(11)
              .fontColor(AppColors.TextPrimary)
              .fontFamily('monospace')
          }
          Row({ space: 4 }) {
            Text('峰值:')
              .fontSize(11)
              .fontColor(AppColors.TextSecondary)
            Text(`${this.gyroMaxAbs.toFixed(1)} °/s`)
              .fontSize(11)
              .fontColor(AppColors.TextPrimary)
              .fontFamily('monospace')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding(8)

        Row()
          .width(1)
          .height(60)
          .backgroundColor(AppColors.Divider)

        Column({ space: 4 }) {
          Text('加速度计')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TextPrimary)
          Row({ space: 4 }) {
            Text('采样数:')
              .fontSize(11)
              .fontColor(AppColors.TextSecondary)
            Text(`${this.accelDataCount}`)
              .fontSize(11)
              .fontColor(AppColors.TextPrimary)
              .fontFamily('monospace')
          }
          Row({ space: 4 }) {
            Text('有效频率:')
              .fontSize(11)
              .fontColor(AppColors.TextSecondary)
            Text(`${this.accelEffectiveRate} Hz`)
              .fontSize(11)
              .fontColor(AppColors.TextPrimary)
              .fontFamily('monospace')
          }
          Row({ space: 4 }) {
            Text('峰值:')
              .fontSize(11)
              .fontColor(AppColors.TextSecondary)
            Text(`${this.accelMaxAbs.toFixed(1)} m/s²`)
              .fontSize(11)
              .fontColor(AppColors.TextPrimary)
              .fontFamily('monospace')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding(8)
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.Surface)
    .borderRadius(12)
  }

  @Builder
  buildLogSection() {
    Column({ space: 8 }) {
      Text('📋 日志')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .width('100%')

      ForEach(this.logMessages.slice(0, 20), (log: string) => {
        Text(log)
          .fontSize(11)
          .fontColor(AppColors.TextSecondary)
          .width('100%')
          .padding({ top: 2, bottom: 2 })
      })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.Surface)
    .borderRadius(12)
  }
}
