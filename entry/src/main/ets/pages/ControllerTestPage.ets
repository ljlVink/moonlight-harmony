/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { router } from "@kit.ArkUI";
import { UsbControllerTestView } from "../components/UsbControllerTestView";
import { GameControllerTestView } from "../components/GameControllerTestView";
import { SensorTestView } from "../components/SensorTestView";
import { AppColors, AppSizes, AppSpacing } from "../common/Theme";
import { GamepadManager } from "../service/GamepadManager";

@Entry
@Component
struct ControllerTestPage {
  @StorageProp("topSafeHeight") topSafeHeight: number = 56;
  @State currentTabIndex: number = 0;
  @State keyEventLogs: string[] = [];

  private gcKeyEventHandler: ((event: KeyEvent) => boolean) | null = null;

  /**
   * Restore GamepadManager callbacks when page is destroyed.
   */
  aboutToDisappear(): void {
    try {
      GamepadManager.getInstance().reattachInputCallbacks();
      console.info("[ControllerTestPage] Page destroyed, GamepadManager callbacks restored");
    } catch (err) {
      console.error("[ControllerTestPage] Failed to restore GamepadManager callbacks:", err);
    }
  }

  /**
   * Handle all key events
   */
  handleKeyEvent(event: KeyEvent): boolean {
    const timestamp = new Date().toLocaleTimeString();
    const keyCode = event.keyCode;
    const isPressed = event.type === KeyType.Down;

    const logEntry = `[${timestamp}] KeyEvent: code=${keyCode} ${isPressed ? "DOWN" : "UP"}`;
    this.keyEventLogs = [logEntry, ...this.keyEventLogs.slice(0, 19)];

    if (this.currentTabIndex === 1 && this.gcKeyEventHandler) {
      return this.gcKeyEventHandler(event);
    }

    return true;
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) {
          Image($r("app.media.ic_back"))
            .width(AppSizes.IconMedium)
            .height(AppSizes.IconMedium)
            .fillColor(AppColors.Primary)
        }
        .width(40)
        .height(40)
        .backgroundColor(AppColors.Surface)
        .borderWidth(1)
        .borderColor(AppColors.CardBorder)
        .onClick(() => {
          router.back();
        })
        Column() {
          Text("手柄测试")
            .fontSize(AppSizes.FontTitle)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.Primary)
          Text(
            this.currentTabIndex === 0
              ? "USB 驱动模式"
              : this.currentTabIndex === 1
                ? "Game Controller Kit 模式"
                : "设备传感器测试",
          )
            .fontSize(AppSizes.FontCaption)
            .fontColor(AppColors.TextSecondary)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: AppSpacing.Medium })
        Blank()
        Row({ space: 4 }) {
          Circle()
            .width(8)
            .height(8)
            .fill(
              this.currentTabIndex === 0
                ? "#4CAF50"
                : this.currentTabIndex === 1
                  ? "#2196F3"
                  : "#FF9800",
            )
          Text(
            this.currentTabIndex === 0 ? "USB" : this.currentTabIndex === 1 ? "GC Kit" : "传感器",
          )
            .fontSize(11)
            .fontColor(AppColors.TextSecondary)
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(AppColors.SurfaceTransparent)
        .borderRadius(12)
      }
      .width("100%")
      .padding({
        left: AppSpacing.Large,
        right: AppSpacing.Large,
        top: this.topSafeHeight,
        bottom: AppSpacing.Medium,
      })
      Row({ space: 0 }) {
        this.TabButton("USB 驱动", "有线手柄", 0)
        this.TabButton("系统/蓝牙", "GC Kit", 1)
        this.TabButton("传感器", "陀螺仪/加速度计", 2)
      }
      .width("100%")
      .padding({
        left: AppSpacing.Large,
        right: AppSpacing.Large,
        top: AppSpacing.Small,
        bottom: AppSpacing.Small,
      })
      .backgroundColor(AppColors.Surface)
      .border({ width: { bottom: 1 }, color: AppColors.Divider })

      if (this.currentTabIndex === 0) {
        UsbControllerTestView();
      } else if (this.currentTabIndex === 1) {
        GameControllerTestView({
          onKeyEventRef: (handler: (event: KeyEvent) => boolean) => {
            this.gcKeyEventHandler = handler;
          },
        });
      } else {
        SensorTestView();
      }

      if (this.keyEventLogs.length > 0) {
        Column() {
          Text("KeyEvent 日志 (直接按键)")
            .fontSize(AppSizes.FontCaption)
            .fontColor(AppColors.TextSecondary)
            .margin({ bottom: AppSpacing.XSmall })
          ForEach(this.keyEventLogs, (log: string) => {
            Text(log).fontSize(11).fontColor(AppColors.TextTertiary).fontFamily("monospace");
          })
        }
        .width("100%")
        .padding(AppSpacing.Medium)
        .backgroundColor(AppColors.SurfaceTransparent)
        .borderRadius(AppSizes.RadiusMedium)
        .margin({ left: AppSpacing.Large, right: AppSpacing.Large, bottom: AppSpacing.Large })
        .alignItems(HorizontalAlign.Start);
      }
    }
    .width("100%")
    .height("100%")
    .backgroundColor(AppColors.Background)
    .focusable(true)
    .defaultFocus(true)
    .onKeyEvent((event: KeyEvent) => {
      return this.handleKeyEvent(event);
    });
  }

  @Builder
  TabButton(title: string, subtitle: string, index: number) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(AppSizes.FontBody)
        .fontWeight(this.currentTabIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTabIndex === index ? AppColors.Primary : AppColors.TextSecondary)
      Text(subtitle)
        .fontSize(10)
        .fontColor(AppColors.TextTertiary)
    }
    .layoutWeight(1)
    .padding({ top: AppSpacing.Small, bottom: AppSpacing.Small })
    .backgroundColor(
      this.currentTabIndex === index ? AppColors.SurfaceTransparent : Color.Transparent,
    )
    .borderRadius(AppSizes.RadiusMedium)
    .onClick(() => {
      this.currentTabIndex = index;
    });
  }
}
