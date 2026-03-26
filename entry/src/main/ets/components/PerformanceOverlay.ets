/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { promptAction } from "@kit.ArkUI";
import { batteryInfo } from "@kit.BasicServicesKit";
import {
  OptionPickerDialog,
  OptionPickerDialogConfig,
  OptionItem,
  SliderConfig,
} from "./OptionPickerDialog";
import {
  PerformanceItem,
  PerformanceData,
  PerfIcons,
  PerfLabels,
  getMoonPhaseIcon,
  isClockTime,
  formatDataRate,
  getDecoderString,
  getPacketLossColor,
  getLatencyColor,
  getBatteryColor,
  calculateSnapPosition,
  findNearestSnapPosition,
  getPerformanceItemInfo,
  getSnapBorderRadius,
  SnapPosition,
} from "./PerformanceOverlayManager";
import { StreamViewModel } from "../viewmodel/StreamViewModel";
import { PreferencesUtil } from "../utils/PreferencesUtil";
import { SettingsKeys } from "../service/SettingsService";

const CLICK_THRESHOLD = 10;
const DOUBLE_CLICK_TIMEOUT = 300;

// AppStorage key: sync with StreamPage unlock state
const PERF_OVERLAY_LOCKED_STORAGE_KEY = "perf_overlay_locked";
@Component
export struct PerformanceOverlay {
  // External ViewModel
  @ObjectLink viewModel: StreamViewModel;

  @Prop screenWidth: number = 0;
  @Prop screenHeight: number = 0;

  @StorageLink(PERF_OVERLAY_LOCKED_STORAGE_KEY) overlayLocked: boolean = false;

  @State perfFps: number = 0;
  @State perfRenderedFps: number = 0;
  @State perfBitrate: number = 0;
  @State perfLatency: number = 0;
  @State perfNetworkLatency: number = 0;
  @State perfHostLatency: number = 0;
  @State perfPacketLoss: number = 0;
  @State perfBatteryLevel: number = 100;
  @State perfIsCharging: boolean = false;

  @State overlayX: number = 8;
  @State overlayY: number = 8;
  @State overlayOpacity: number = 1.0;
  @State overlayScale: number = 1.0;
  @State isVertical: boolean = true;
  @State overlayBgOpacity: number = 0.53;
  @State currentSnapPosition: SnapPosition = SnapPosition.TOP_RIGHT;
  @State overlayDragging: boolean = false; // Show full rounded corners while dragging

  @State showGuide: boolean = false;

  @State lockFlashBorderOpacity: number = 0;

  @State clockIconScale: number = 1.0;
  @State clockHourAngle: number = 0;
  @State clockMinuteAngle: number = 0;
  private wasClockTime: boolean = false;

  @State enabledItemsList: string[] = [];

  private dragStartX: number = 0;
  private dragStartY: number = 0;
  private clickStartTime: number = 0;
  private lastClickTime: number = 0;
  private moveDistance: number = 0;
  private overlayWidth: number = 200;
  private overlayHeight: number = 200;

  private updateTimer: number = -1;
  private guideTimer: number = -1;

  private settingsDialogController: CustomDialogController | null = null;

  aboutToAppear(): void {
    // Initialize position and layout
    this.initPosition();

    AppStorage.setOrCreate(
      PERF_OVERLAY_LOCKED_STORAGE_KEY,
      this.viewModel.overlayState.config.isLocked,
    );

    this.overlayBgOpacity = this.viewModel.overlayState.config.bgOpacity;

    this.enabledItemsList = Array.from(this.viewModel.overlayState.config.enabledItems);

    this.startUpdateTimer();

    this.checkAndShowGuide();
  }

  aboutToDisappear(): void {
    this.stopUpdateTimer();
    if (this.guideTimer !== -1) {
      clearTimeout(this.guideTimer);
    }
  }

  private async checkAndShowGuide(): Promise<void> {
    try {
      const shown = await PreferencesUtil.get<boolean>(
        SettingsKeys.PERF_OVERLAY_GUIDE_SHOWN,
        false,
      );
      if (!shown) {
        // Delay 500ms to let overlay render first
        setTimeout(() => {
          this.showGuide = true;
          // Auto-close after 5 seconds
          this.guideTimer = setTimeout(() => {
            this.dismissGuide();
          }, 5000);
        }, 500);
        PreferencesUtil.put(SettingsKeys.PERF_OVERLAY_GUIDE_SHOWN, true);
      }
    } catch (_) {
      // Ignore
    }
  }

  private dismissGuide(): void {
    if (this.showGuide) {
      animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
        this.showGuide = false;
      });
    }
  }

  private initPosition(): void {
    this.currentSnapPosition = this.viewModel.overlayState.config.position;
    const snapPos = calculateSnapPosition(
      this.currentSnapPosition,
      this.screenWidth,
      this.screenHeight,
      this.overlayWidth,
      this.overlayHeight,
    );
    this.overlayX = snapPos.x;
    this.overlayY = snapPos.y;
    this.isVertical = this.viewModel.overlayState.config.isVertical;
  }

  private startUpdateTimer(): void {
    let batteryUpdateCounter = 0;
    this.updateTimer = setInterval(() => {
      // Get session from ViewModel and update performance data
      const session = this.viewModel.getSession();
      if (session) {
        const stats = session.getStats();
        this.perfFps = stats.fps;
        this.perfRenderedFps = stats.renderedFps;
        this.perfBitrate = stats.bitrate;
        this.perfLatency = stats.latency;
        this.perfNetworkLatency = stats.networkLatency;
        this.perfHostLatency = stats.hostLatency;
        this.perfPacketLoss = stats.packetLoss;
      }

      batteryUpdateCounter++;
      if (batteryUpdateCounter >= 15) {
        const clockNow = isClockTime();
        if (clockNow) {
          this.updateClockAngles();
          if (!this.wasClockTime) {
            this.triggerClockBounce();
          }
        }
        this.wasClockTime = clockNow;
        batteryUpdateCounter = 0;
        try {
          this.perfBatteryLevel = batteryInfo.batterySOC;
          this.perfIsCharging =
            batteryInfo.chargingStatus === batteryInfo.BatteryChargeState.ENABLE ||
            batteryInfo.chargingStatus === batteryInfo.BatteryChargeState.FULL;
        } catch (e) {
          // Ignore battery info fetch failure
        }
      }
    }, 1000);

    try {
      this.perfBatteryLevel = batteryInfo.batterySOC;
      this.perfIsCharging =
        batteryInfo.chargingStatus === batteryInfo.BatteryChargeState.ENABLE ||
        batteryInfo.chargingStatus === batteryInfo.BatteryChargeState.FULL;
    } catch (e) {}
  }

  private stopUpdateTimer(): void {
    if (this.updateTimer !== -1) {
      clearInterval(this.updateTimer);
      this.updateTimer = -1;
    }
  }

  /** Clock icon bounce animation on appearance */
  private triggerClockBounce(): void {
    // Rotate hands from previous quarter-hour position to current time
    const now = new Date();
    const prevTime = new Date(now.getTime() - 15 * 60 * 1000);
    const prevH = prevTime.getHours() % 12;
    const prevM = prevTime.getMinutes();
    this.clockHourAngle = prevH * 30 + prevM * 0.5;
    this.clockMinuteAngle = prevM * 6;
    setTimeout(() => {
      this.updateClockAngles();
    }, 50);
    // Scale pulse
    let step = 0;
    const bounce = () => {
      if (step >= 6) {
        this.clockIconScale = 1.0;
        return;
      }
      this.clockIconScale = step % 2 === 0 ? 4.0 : 1.0;
      step++;
      setTimeout(bounce, 200);
    };
    bounce();
  }

  /** Update clock hand angles */
  private updateClockAngles(): void {
    const now = new Date();
    const h = now.getHours() % 12;
    const m = now.getMinutes();
    // Hour hand: 30° per hour, 0.5° per minute
    this.clockHourAngle = h * 30 + m * 0.5;
    // Minute hand: 6° per minute
    this.clockMinuteAngle = m * 6;
  }

  /** Draw minimal clock (hour + minute hands) */
  @Builder
  MiniClock(size: number) {
    Stack() {
      // Hour hand (short and thick)
      Line()
        .width(1.5)
        .height(size * 0.28)
        .backgroundColor("#FFFFFF")
        .borderRadius(1)
        .rotate({ angle: this.clockHourAngle, centerX: "50%", centerY: "100%" })
        .animation({ duration: 800, curve: Curve.EaseOut })
        .position({ x: size / 2 - 0.75, y: size / 2 - size * 0.28 })
      // Minute hand (long and thin)
      Line()
        .width(1)
        .height(size * 0.4)
        .backgroundColor("#FFFFFF")
        .borderRadius(0.5)
        .rotate({ angle: this.clockMinuteAngle, centerX: "50%", centerY: "100%" })
        .animation({ duration: 800, curve: Curve.EaseOut })
        .position({ x: size / 2 - 0.5, y: size / 2 - size * 0.4 })
      // Center point
      Circle()
        .width(2)
        .height(2)
        .fill("#FFFFFF")
        .position({ x: size / 2 - 1, y: size / 2 - 1 })
    }
    .width(size)
    .height(size)
    .scale({ x: this.clockIconScale, y: this.clockIconScale })
    .animation({ duration: 200, curve: Curve.EaseOut });
  }

  /** Play gold border flash animation on lock (flash 3 times) */
  private playLockFlash(): void {
    let count = 0;
    const flash = () => {
      if (count >= 3) {
        this.lockFlashBorderOpacity = 0;
        return;
      }
      animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        this.lockFlashBorderOpacity = 0.8;
      });
      setTimeout(() => {
        animateTo({ duration: 150, curve: Curve.EaseIn }, () => {
          this.lockFlashBorderOpacity = 0;
        });
        count++;
        setTimeout(flash, 180);
      }, 180);
    };
    flash();
  }

  build() {
    Stack() {
      // Main overlay
      Column() {
        if (this.isVertical) {
          this.VerticalContent();
        } else {
          this.HorizontalContent();
        }
      }
      .padding(this.isVertical ? 12 : { left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(
        `#${Math.round(this.overlayBgOpacity * 255)
          .toString(16)
          .padStart(2, "0")}161616`,
      )
      .borderRadius(this.overlayDragging ? 12 : getSnapBorderRadius(this.currentSnapPosition, 12))
      .border({
        width: this.lockFlashBorderOpacity > 0 ? 2 : 0,
        color: `#${Math.round(this.lockFlashBorderOpacity * 255)
          .toString(16)
          .padStart(2, "0")}FFD700`,
      })
      .opacity(this.overlayOpacity)
      .scale({ x: this.overlayScale, y: this.overlayScale })
      .position({ x: this.overlayX, y: this.overlayY })
      // Pass-through touch to underlying stream view when locked, intercept when unlocked
      .hitTestBehavior(this.overlayLocked ? HitTestMode.Transparent : HitTestMode.Block)
      .focusable(false)
      // Disable controller focus to ensure game receives input
      .onAreaChange((oldValue: Area, newValue: Area) => {
        const oldWidth = this.overlayWidth;
        const oldHeight = this.overlayHeight;
        this.overlayWidth = newValue.width as number;
        this.overlayHeight = newValue.height as number;

        if (
          oldWidth === 200 &&
          oldHeight === 200 &&
          (this.overlayWidth !== 200 || this.overlayHeight !== 200)
        ) {
          // Recalculate position on first render (size not accurate in aboutToAppear)
          this.initPosition();
        } else if (oldWidth !== this.overlayWidth || oldHeight !== this.overlayHeight) {
          // Size changed (digit count change etc.), re-align to current snap position
          const snapPos = calculateSnapPosition(
            this.currentSnapPosition,
            this.screenWidth,
            this.screenHeight,
            this.overlayWidth,
            this.overlayHeight,
          );
          this.overlayX = snapPos.x;
          this.overlayY = snapPos.y;
        }
      })
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5 })
          .onActionStart((event: GestureEvent) => {
            if (this.overlayLocked) return;
            this.handleDragStart(event);
          })
          .onActionUpdate((event: GestureEvent) => {
            if (this.overlayLocked) return;
            this.handleDragUpdate(event);
          })
          .onActionEnd((event: GestureEvent) => {
            if (this.overlayLocked) return;
            this.handleDragEnd(event);
          }),
      )
      .gesture(
        LongPressGesture({ repeat: false, duration: 500 }).onAction(() => {
          if (this.overlayLocked) return;
          this.overlayLocked = true;
          this.viewModel.overlayState.config.isLocked = true;
          this.viewModel.overlayState.configVersion++;
          PreferencesUtil.put(SettingsKeys.PERF_OVERLAY_LOCKED, true);
          this.playLockFlash();
          try {
            promptAction.showToast({ message: "� 已锁定，触摸将透传至游戏", duration: 1500 });
          } catch (_) {}
        }),
      )
      .onClick(() => {
        if (this.overlayLocked) return;
        this.handleClick();
      })

      if (this.showGuide) {
        Column({ space: 6 }) {
          Text("操作提示")
            .fontSize(12)
            .fontColor("#FFD700")
            .fontWeight(FontWeight.Bold)
          Text("👆 单击 → 设置显示项")
            .fontSize(11)
            .fontColor("#DDFFFFFF")
          Text("👆👆 双击 → 切换横竖布局")
            .fontSize(11)
            .fontColor("#DDFFFFFF")
          Text("✋ 拖动 → 调整位置")
            .fontSize(11)
            .fontColor("#DDFFFFFF")
          Text("👇 长按 → 锁定(触摸穿透)")
            .fontSize(11)
            .fontColor("#DDFFFFFF")
        }
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor("#E0161616")
        .borderRadius(10)
        .border({ width: 1, color: "#30FFD700" })
        .position({
          x: this.overlayX + this.overlayWidth + 8,
          y: this.overlayY,
        })
        .hitTestBehavior(HitTestMode.None)
        .transition(TransitionEffect.OPACITY.animation({ duration: 200 }));
      }
    }
    .width("100%")
    .height("100%")
    .hitTestBehavior(HitTestMode.Transparent);
  }

  @Builder
  VerticalContent() {
    if (this.enabledItemsList.includes(PerformanceItem.RESOLUTION)) {
      Row() {
        if (isClockTime()) {
          this.MiniClock(14);
        } else {
          Text(getMoonPhaseIcon(this.overlayLocked)).fontSize(13).fontWeight(FontWeight.Bold);
        }
        Text(
          ` ${this.viewModel.displayInfo.streamWidth}x${this.viewModel.displayInfo.streamHeight}@${this.viewModel.streamConfig?.fps || 60}`,
        )
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor("#FFFFFF")
      }
      .margin({ bottom: 4 });
    }

    if (this.enabledItemsList.includes(PerformanceItem.DECODER)) {
      Row() {
        Text(getDecoderString(this.viewModel.actualCodec || "HEVC", this.viewModel.actualHdr))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor("#FFFFFF")
      }
      .margin({ bottom: 4 });
    }

    if (this.enabledItemsList.includes(PerformanceItem.RENDER_FPS)) {
      Row() {
        Text(`Rx ${this.perfFps} / Rd ${this.perfRenderedFps}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor("#0DDAF4")
        Text(" FPS")
          .fontSize(11)
          .fontColor("#CCFFFFFF")
      }
      .margin({ bottom: 4 });
    }

    if (this.enabledItemsList.includes(PerformanceItem.PACKET_LOSS)) {
      Row() {
        Text(PerfIcons.PACKET_LOSS).fontSize(13)
        Text(` ${this.perfPacketLoss.toFixed(2)}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(getPacketLossColor(this.perfPacketLoss))
        Text("%")
          .fontSize(11)
          .fontColor("#CCFFFFFF")
      }
      .margin({ bottom: 4 });
    }

    if (this.enabledItemsList.includes(PerformanceItem.BITRATE)) {
      Row() {
        Text(PerfIcons.BITRATE).fontSize(13)
        Text(` ${formatDataRate(this.perfBitrate)}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor("#BCEDD3")
      }
      .margin({ bottom: 4 });
    }

    if (this.enabledItemsList.includes(PerformanceItem.NETWORK_LATENCY)) {
      Row() {
        Text(PerfIcons.NETWORK).fontSize(13)
        Text(this.perfNetworkLatency > 0 ? ` ${this.perfNetworkLatency}` : " N/A")
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.perfNetworkLatency > 50 ? "#FFA726" : "#4CAF50")
        Text(" ms")
          .fontSize(11)
          .fontColor("#CCFFFFFF")
      }
      .margin({ bottom: 4 });
    }

    if (this.enabledItemsList.includes(PerformanceItem.DECODE_LATENCY)) {
      Row() {
        Text(this.perfLatency < 20 ? PerfIcons.DECODE_NORMAL : PerfIcons.DECODE_HOT).fontSize(13)
        Text(` ${this.perfLatency.toFixed(2)}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(getLatencyColor(this.perfLatency))
        Text(" ms")
          .fontSize(11)
          .fontColor("#CCFFFFFF")
      }
      .margin({ bottom: 4 });
    }

    if (this.enabledItemsList.includes(PerformanceItem.HOST_LATENCY)) {
      Row() {
        Text(PerfIcons.HOST).fontSize(13)
        Text(this.perfHostLatency > 0 ? ` ${this.perfHostLatency.toFixed(1)}` : " N/A")
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor("#009688")
        Text(" ms")
          .fontSize(11)
          .fontColor("#CCFFFFFF")
      }
      .margin({ bottom: 4 });
    }

    if (this.enabledItemsList.includes(PerformanceItem.BATTERY)) {
      Row() {
        Text(this.perfIsCharging ? PerfIcons.CHARGING : PerfIcons.BATTERY).fontSize(13)
        Text(` ${this.perfBatteryLevel}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(getBatteryColor(this.perfBatteryLevel))
        Text("%")
          .fontSize(11)
          .fontColor("#CCFFFFFF")
      };
    }
  }

  @Builder
  HorizontalContent() {
    Row() {
      if (this.enabledItemsList.includes(PerformanceItem.RESOLUTION)) {
        if (isClockTime()) {
          this.MiniClock(13);
        } else {
          Text(getMoonPhaseIcon(this.overlayLocked)).fontSize(12).fontWeight(FontWeight.Bold);
        }
        Text(
          ` ${this.viewModel.displayInfo.streamWidth}x${this.viewModel.displayInfo.streamHeight}@${this.viewModel.streamConfig?.fps || 60}`,
        )
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor("#FFFFFF");
        if (this.hasNextItem(PerformanceItem.RESOLUTION)) this.Separator();
      }

      if (this.enabledItemsList.includes(PerformanceItem.DECODER)) {
        Text(getDecoderString(this.viewModel.actualCodec || "HEVC", this.viewModel.actualHdr))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor("#FFFFFF");
        if (this.hasNextItem(PerformanceItem.DECODER)) this.Separator();
      }

      // FPS
      if (this.enabledItemsList.includes(PerformanceItem.RENDER_FPS)) {
        Text(`${this.perfFps}/${this.perfRenderedFps}`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor("#0DDAF4");
        Text(" FPS").fontSize(10).fontColor("#CCFFFFFF");
        if (this.hasNextItem(PerformanceItem.RENDER_FPS)) this.Separator();
      }

      if (this.enabledItemsList.includes(PerformanceItem.PACKET_LOSS)) {
        Text(PerfIcons.PACKET_LOSS).fontSize(12);
        Text(` ${this.perfPacketLoss.toFixed(1)}%`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(getPacketLossColor(this.perfPacketLoss));
        if (this.hasNextItem(PerformanceItem.PACKET_LOSS)) this.Separator();
      }

      if (this.enabledItemsList.includes(PerformanceItem.BITRATE)) {
        Text(PerfIcons.BITRATE).fontSize(12);
        Text(` ${formatDataRate(this.perfBitrate)}`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor("#BCEDD3");
        if (this.hasNextItem(PerformanceItem.BITRATE)) this.Separator();
      }

      if (this.enabledItemsList.includes(PerformanceItem.NETWORK_LATENCY)) {
        Text(PerfIcons.NETWORK).fontSize(12);
        Text(this.perfNetworkLatency > 0 ? ` ${this.perfNetworkLatency} ms` : " N/A")
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.perfNetworkLatency > 50 ? "#FFA726" : "#4CAF50");
        if (this.hasNextItem(PerformanceItem.NETWORK_LATENCY)) this.Separator();
      }

      if (this.enabledItemsList.includes(PerformanceItem.DECODE_LATENCY)) {
        Text(this.perfLatency < 20 ? PerfIcons.DECODE_NORMAL : PerfIcons.DECODE_HOT).fontSize(12);
        Text(` ${this.perfLatency.toFixed(1)} ms`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(getLatencyColor(this.perfLatency));
        if (this.hasNextItem(PerformanceItem.DECODE_LATENCY)) this.Separator();
      }

      if (this.enabledItemsList.includes(PerformanceItem.HOST_LATENCY)) {
        Text(PerfIcons.HOST).fontSize(12);
        Text(this.perfHostLatency > 0 ? ` ${this.perfHostLatency.toFixed(1)} ms` : " N/A")
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor("#009688");
        if (this.hasNextItem(PerformanceItem.HOST_LATENCY)) this.Separator();
      }

      if (this.enabledItemsList.includes(PerformanceItem.BATTERY)) {
        Text(this.perfIsCharging ? PerfIcons.CHARGING : PerfIcons.BATTERY).fontSize(12);
        Text(` ${this.perfBatteryLevel}%`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(getBatteryColor(this.perfBatteryLevel));
      }
    };
  }

  @Builder
  Separator() {
    Text("  |  ").fontSize(11).fontColor("#66FFFFFF");
  }

  private hasNextItem(currentItem: PerformanceItem): boolean {
    const orderedItems = [
      PerformanceItem.RESOLUTION,
      PerformanceItem.DECODER,
      PerformanceItem.RENDER_FPS,
      PerformanceItem.PACKET_LOSS,
      PerformanceItem.BITRATE,
      PerformanceItem.NETWORK_LATENCY,
      PerformanceItem.DECODE_LATENCY,
      PerformanceItem.HOST_LATENCY,
      PerformanceItem.BATTERY,
    ];

    const currentIndex = orderedItems.indexOf(currentItem);
    for (let i = currentIndex + 1; i < orderedItems.length; i++) {
      if (this.enabledItemsList.includes(orderedItems[i])) {
        return true;
      }
    }
    return false;
  }

  private handleDragStart(event: GestureEvent): void {
    this.overlayDragging = true;
    this.dragStartX = this.overlayX;
    this.dragStartY = this.overlayY;
    this.clickStartTime = Date.now();
    this.moveDistance = 0;

    this.overlayOpacity = 0.7;
    this.overlayScale = 1.05;
  }

  private handleDragUpdate(event: GestureEvent): void {
    if (!this.overlayDragging) return;

    const offsetX = event.offsetX;
    const offsetY = event.offsetY;

    this.moveDistance += Math.abs(offsetX) + Math.abs(offsetY);

    let newX = this.dragStartX + offsetX;
    let newY = this.dragStartY + offsetY;

    newX = Math.max(0, Math.min(newX, this.screenWidth - this.overlayWidth));
    newY = Math.max(0, Math.min(newY, this.screenHeight - this.overlayHeight));

    this.overlayX = newX;
    this.overlayY = newY;
  }

  private handleDragEnd(event: GestureEvent): void {
    this.overlayOpacity = 1.0;
    this.overlayScale = 1.0;

    const duration = Date.now() - this.clickStartTime;
    if (this.moveDistance < CLICK_THRESHOLD && duration < 500) {
      this.overlayDragging = false;
      const timeSinceLastClick = Date.now() - this.lastClickTime;
      if (timeSinceLastClick < DOUBLE_CLICK_TIMEOUT && this.lastClickTime > 0) {
        this.toggleLayout();
        this.lastClickTime = 0;
      } else {
        this.lastClickTime = Date.now();
        setTimeout(() => {
          if (Date.now() - this.lastClickTime >= DOUBLE_CLICK_TIMEOUT) {
            this.showInfo();
          }
        }, DOUBLE_CLICK_TIMEOUT);
      }
    } else {
      this.snapToPosition();
    }
  }

  private snapToPosition(): void {
    const nearestPos = findNearestSnapPosition(
      this.overlayX,
      this.overlayY,
      this.screenWidth,
      this.screenHeight,
      this.overlayWidth,
      this.overlayHeight,
    );

    const snapPos = calculateSnapPosition(
      nearestPos,
      this.screenWidth,
      this.screenHeight,
      this.overlayWidth,
      this.overlayHeight,
    );

    this.getUIContext()?.animateTo(
      {
        duration: 200,
        curve: Curve.EaseOut,
      },
      () => {
        this.overlayX = snapPos.x;
        this.overlayY = snapPos.y;
        this.currentSnapPosition = nearestPos;
        this.overlayDragging = false;
      },
    );

    this.viewModel.overlayState.config.position = nearestPos;
  }

  private handleClick(): void {
    const now = Date.now();
    const timeSinceLastClick = now - this.lastClickTime;

    if (timeSinceLastClick < DOUBLE_CLICK_TIMEOUT && this.lastClickTime > 0) {
      this.toggleLayout();
      this.lastClickTime = 0;
    } else {
      const clickTime = now;
      this.lastClickTime = clickTime;
      setTimeout(() => {
        if (this.lastClickTime === clickTime) {
          this.showInfo();
          this.lastClickTime = 0;
        }
      }, DOUBLE_CLICK_TIMEOUT);
    }
  }

  private toggleLayout(): void {
    this.isVertical = !this.isVertical;
    this.viewModel.overlayState.config.isVertical = this.isVertical;

    try {
      promptAction.showToast({
        message: this.isVertical ? "已切换为垂直布局" : "已切换为水平布局",
        duration: 1500,
      });
    } catch (e) {}
  }

  private showInfo(): void {
    const perfData = this.getPerformanceData();
    this.showSettingsDialog(perfData);
  }

  private getPerformanceData(): PerformanceData {
    const data = new PerformanceData();
    data.streamWidth = this.viewModel.displayInfo.streamWidth;
    data.streamHeight = this.viewModel.displayInfo.streamHeight;
    data.targetFps = this.viewModel.streamConfig?.fps || 60;
    data.codec = this.viewModel.actualCodec || "HEVC";
    data.isHdr = this.viewModel.actualHdr;
    data.receivedFps = this.perfFps;
    data.renderedFps = this.perfRenderedFps;
    data.packetLoss = this.perfPacketLoss;
    data.bitrate = this.perfBitrate;
    data.networkLatency = this.perfNetworkLatency;
    data.decodeLatency = this.perfLatency;
    data.hostLatency = this.perfHostLatency;
    data.batteryLevel = this.perfBatteryLevel;
    data.isCharging = this.perfIsCharging;
    return data;
  }

  private static readonly ALL_ITEMS: PerformanceItem[] = [
    PerformanceItem.RESOLUTION,
    PerformanceItem.DECODER,
    PerformanceItem.RENDER_FPS,
    PerformanceItem.PACKET_LOSS,
    PerformanceItem.BITRATE,
    PerformanceItem.NETWORK_LATENCY,
    PerformanceItem.DECODE_LATENCY,
    PerformanceItem.HOST_LATENCY,
    PerformanceItem.BATTERY,
  ];

  private buildSettingsOptions(): OptionItem[] {
    const enabledItems = this.viewModel.overlayState.config.enabledItems;
    const options: OptionItem[] = [];

    for (let i = 0; i < PerformanceOverlay.ALL_ITEMS.length; i++) {
      const item = PerformanceOverlay.ALL_ITEMS[i];
      const info = getPerformanceItemInfo(item);
      const isEnabled = enabledItems.has(item);
      const opt: OptionItem = {
        title: info.title,
        subtitle: info.description,
        value: `item_${i}`,
        checked: isEnabled,
      };
      options.push(opt);
    }

    return options;
  }

  private showSettingsDialog(perfData: PerformanceData): void {
    const allItems = PerformanceOverlay.ALL_ITEMS;
    const currentPercent = Math.round(this.overlayBgOpacity * 100);

    const sliderCfg: SliderConfig = {
      title: "🎨 背景透明度",
      value: currentPercent,
      min: 0,
      max: 100,
      step: 5,
      onChange: (value: number) => {
        this.updateBgOpacity(value / 100);
      },
    };

    const config: OptionPickerDialogConfig = {
      title: "性能覆盖层",
      subtitle: "单击设置显示/隐藏项目，拖动调整位置，双击切换布局，长按锁定事件穿透",
      options: this.buildSettingsOptions(),
      selectedValue: "",
      sliderConfig: sliderCfg,
      closeOnSelect: false,
      refreshOptions: (): OptionItem[] => {
        return this.buildSettingsOptions();
      },
      onSelect: (option: OptionItem) => {
        const val = option.value as string;
        if (val.startsWith("item_")) {
          const itemIndex = parseInt(val.replace("item_", ""));
          if (itemIndex >= 0 && itemIndex < allItems.length) {
            this.toggleItem(allItems[itemIndex]);
          }
        }
      },
    };

    this.settingsDialogController = new CustomDialogController({
      builder: OptionPickerDialog({ config: config }),
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      backgroundColor: Color.Transparent,
    });
    this.settingsDialogController.open();
  }

  private toggleItem(item: PerformanceItem): void {
    const config = this.viewModel.overlayState.config;
    if (config.enabledItems.has(item)) {
      config.enabledItems.delete(item);
    } else {
      config.enabledItems.add(item);
    }
    this.enabledItemsList = Array.from(config.enabledItems);
    PreferencesUtil.put(SettingsKeys.PERF_OVERLAY_ITEMS, this.enabledItemsList.join(","));
  }

  private updateBgOpacity(value: number): void {
    this.overlayBgOpacity = value;
    this.viewModel.overlayState.config.bgOpacity = value;
    PreferencesUtil.put(SettingsKeys.PERF_OVERLAY_BG_OPACITY, value);
  }
}
