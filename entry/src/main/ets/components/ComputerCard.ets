/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { ObservableComputer } from "../viewmodel/ComputerViewModel";
import {
  AppColors,
  AppSizes,
  AppSpacing,
  AppAnimation,
  AppShadows,
  StatusColors,
} from "../common/Theme";
import { LengthMetrics, ColorMetrics } from "@kit.ArkUI";
@Component
export struct ComputerCard {
  @ObjectLink computer: ObservableComputer;

  onTap: () => void = () => {};
  onLongPress: () => void = () => {};
  onQuickStream: () => void = () => {};

  @State private isPressed: boolean = false;
  @State private cardScale: number = 1;
  @State private boxArtLoadFailed: boolean = false;
  @State private quickStreamPressed: boolean = false;
  @State private quickStreamClicked: boolean = false;

  private readonly AVATAR_SIZE: number = AppSizes.AvatarLarge;
  private readonly ICON_SIZE: number = 40;
  private readonly STATUS_DOT_SIZE: number = 14;
  private readonly PRESS_SCALE: number = 0.98;

  aboutToAppear() {
    this.boxArtLoadFailed = false;
  }

  private getBoxArtSource(): string {
    const url = this.computer.boxArtUrl;
    if (!url) return "";
    if (url.startsWith("http")) return url;
    return "file://" + url;
  }

  private shouldShowBoxArt(): boolean {
    return !!this.computer.boxArtUrl && !this.boxArtLoadFailed;
  }

  private getStatusDotColor(): string {
    if (!this.computer.isOnline) return StatusColors.OfflineDark;
    if (!this.computer.isPaired) return StatusColors.UnpairedDark;
    if (this.computer.isGaming) return StatusColors.GamingDark;
    return StatusColors.OnlineDark;
  }

  private getImageOpacity(): number {
    return this.computer.isOnline ? 1 : 0.5;
  }

  private canQuickStream(): boolean {
    return this.computer.isOnline && this.computer.isPaired;
  }

  @Builder
  private DefaultIcon() {
    Column() {
      Image($r("app.media.ic_pc_default"))
        .width(this.ICON_SIZE)
        .height(this.ICON_SIZE)
        .objectFit(ImageFit.Contain)
        .opacity(this.getImageOpacity())
    }
    .width(this.AVATAR_SIZE)
    .height(this.AVATAR_SIZE)
    .borderRadius(AppSizes.RadiusLarge)
    .backgroundColor(AppColors.Surface)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  private AvatarSection() {
    Stack() {
      if (this.shouldShowBoxArt()) {
        this.BoxArtWithFallback();
      } else {
        this.DefaultIcon();
      }
    }
    .width(this.AVATAR_SIZE)
    .height(this.AVATAR_SIZE)
    .borderRadius(AppSizes.RadiusLarge)
    .clip(true)
    .margin({ right: AppSpacing.Large });
  }

  @Builder
  private BoxArtWithFallback() {
    Stack() {
      this.DefaultIcon()
      Image(this.getBoxArtSource())
        .width(this.AVATAR_SIZE)
        .height(this.AVATAR_SIZE)
        .borderRadius(AppSizes.RadiusLarge)
        .objectFit(ImageFit.Cover)
        .opacity(this.getImageOpacity())
        .onError(() => {
          this.boxArtLoadFailed = true;
        })
    }
    .width(this.AVATAR_SIZE)
    .height(this.AVATAR_SIZE);
  }

  private getStatusTextColor(): string {
    if (!this.computer.isOnline) return StatusColors.OfflineDark;
    if (!this.computer.isPaired) return StatusColors.UnpairedDark;
    if (this.computer.isGaming) return StatusColors.GamingDark;
    return StatusColors.OnlineDark;
  }

  @Builder
  private InfoSection() {
    Column() {
      Text(this.computer.name)
        .fontSize(AppSizes.FontTitle)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.computer.isOnline ? AppColors.Primary : AppColors.TextSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width("100%")
      Text(this.computer.manualAddress || this.computer.address)
        .fontSize(AppSizes.FontBody)
        .fontColor(AppColors.TextSecondary)
        .fontFamily("monospace")
        .margin({ top: AppSpacing.XSmall })
      Row() {
        Circle()
          .width(8)
          .height(8)
          .fill(this.getStatusDotColor())
          .margin({ right: 6 })
        Text(this.computer.statusText)
          .fontSize(AppSizes.FontCaption)
          .fontColor(this.getStatusTextColor())
      }
      .margin({ top: AppSpacing.Small })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1);
  }

  @Builder
  private QuickStreamButton() {
    Column() {
      Image($r("app.media.ic_play"))
        .width(20)
        .height(20)
        .fillColor(Color.White)
    }
    .width(44)
    .height(44)
    .borderRadius(22)
    .backgroundColor(this.quickStreamPressed ? AppColors.PrimaryDark : AppColors.Primary)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .shadow({
      radius: this.quickStreamPressed ? 4 : 8,
      color: AppColors.GlowGreen,
      offsetX: 0,
      offsetY: 2,
    })
    .scale({ x: this.quickStreamPressed ? 0.95 : 1, y: this.quickStreamPressed ? 0.95 : 1 })
    .animation({ duration: 100 })
    .onClick(() => {
      this.quickStreamClicked = true;
      this.onQuickStream();
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.quickStreamPressed = true;
        this.quickStreamClicked = false;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.quickStreamPressed = false;
      }
    });
  }

  build() {
    Column() {
      Row() {
        this.AvatarSection()

        this.InfoSection()

        if (this.canQuickStream()) {
          this.QuickStreamButton();
        } else {
          Image($r("app.media.ic_arrow_right"))
            .width(AppSizes.IconMedium)
            .height(AppSizes.IconMedium)
            .fillColor(this.computer.isOnline ? AppColors.Primary : AppColors.TextTertiary);
        }
      }
      .width("100%")
      .padding(AppSpacing.Large)
    }
    .width("100%")
    .backgroundColor(AppColors.CardBackground)
    .borderRadius(AppSizes.RadiusLarge)
    .borderWidth(1)
    .borderColor(this.isPressed ? AppColors.Primary : AppColors.CardBorder)
    .shadow(this.isPressed ? AppShadows.GlowGreen : AppShadows.Medium)
    .scale({ x: this.cardScale, y: this.cardScale })
    .animation({
      duration: AppAnimation.Fast,
      curve: AppAnimation.Spring,
    })
    .focusable(true)
    .focusOnTouch(true)
    .focusBox({
      margin: LengthMetrics.vp(2),
      strokeColor: ColorMetrics.rgba(0, 212, 255, 1),
      strokeWidth: LengthMetrics.vp(2),
    })
    .onKeyEvent((event: KeyEvent) => {
      if (event.type === KeyType.Down) {
        if (event.keyCode === 2054 || event.keyCode === 2050) {
          this.onTap();
          return true;
        }
        if (event.keyCode === 2051) {
          this.onLongPress();
          return true;
        }
      }
      return false;
    })
    .onClick(() => {
      if (this.quickStreamClicked) {
        this.quickStreamClicked = false;
        return;
      }
      this.onTap();
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
        this.cardScale = this.PRESS_SCALE;
        this.quickStreamClicked = false;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
        this.cardScale = 1;
      }
    })
    .gesture(LongPressGesture({ duration: 500 }).onAction(() => this.onLongPress()));
  }
}
