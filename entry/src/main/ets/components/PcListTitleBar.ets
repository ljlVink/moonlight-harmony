/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { AppColors, AppSizes, AppSpacing } from "../common/Theme";

export interface TitleBarConfig {
  onlineCount: number;
  totalCount: number;
  onAboutClick: () => void;
  onScanImport: () => void;
  onSettingsClick: () => void;
}
@Component
export struct PcListTitleBar {
  @StorageProp("topSafeHeight") topSafeHeight: number = 56;
  @Prop config: TitleBarConfig = {
    onlineCount: 0,
    totalCount: 0,
    onAboutClick: () => {},
    onScanImport: () => {},
    onSettingsClick: () => {},
  };

  build() {
    Row() {
      Column() {
        Row() {
          Image($r("app.media.vplus"))
            .width(44)
            .height(44)
            .borderRadius(12)
            .objectFit(ImageFit.Cover)
            .margin({ right: AppSpacing.Medium })
            .flexShrink(0)
          Column() {
            Text("Moonlight V+")
              .fontSize(AppSizes.FontLargeTitle)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.Primary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .minFontSize(14)
              .maxFontSize(AppSizes.FontLargeTitle)
              .heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)

            if (this.config.totalCount > 0) {
              Row() {
                Circle()
                  .width(6)
                  .height(6)
                  .fill(AppColors.Online)
                  .margin({ right: 6 })
                Text(`${this.config.onlineCount} 在线`)
                  .fontSize(AppSizes.FontCaption)
                  .fontColor(AppColors.Online)
                Text(` / ${this.config.totalCount} 台设备`)
                  .fontSize(AppSizes.FontCaption)
                  .fontColor(AppColors.TextSecondary)
              }
              .margin({ top: 4 });
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ right: AppSpacing.Small })
      Button({ type: ButtonType.Circle }) {
        Image($r("app.media.ic_info"))
          .width(AppSizes.IconMedium)
          .height(AppSizes.IconMedium)
          .fillColor(AppColors.Primary)
      }
      .width(44)
      .height(44)
      .backgroundColor(AppColors.Surface)
      .borderWidth(1)
      .borderColor(AppColors.CardBorder)
      .flexShrink(0)
      .margin({ right: AppSpacing.Small })
      .onClick(() => {
        this.config.onAboutClick();
      })
      Button({ type: ButtonType.Circle }) {
        Image($r("app.media.ic_scan"))
          .width(AppSizes.IconMedium)
          .height(AppSizes.IconMedium)
          .fillColor(AppColors.Primary)
      }
      .width(44)
      .height(44)
      .backgroundColor(AppColors.Surface)
      .borderWidth(1)
      .borderColor(AppColors.CardBorder)
      .flexShrink(0)
      .margin({ right: AppSpacing.Small })
      .onClick(() => {
        this.config.onScanImport();
      })
      Button({ type: ButtonType.Circle }) {
        Image($r("app.media.ic_settings"))
          .width(AppSizes.IconMedium)
          .height(AppSizes.IconMedium)
          .fillColor(AppColors.Primary)
      }
      .width(44)
      .height(44)
      .backgroundColor(AppColors.Surface)
      .borderWidth(1)
      .borderColor(AppColors.CardBorder)
      .flexShrink(0)
      .onClick(() => {
        this.config.onSettingsClick();
      })
    }
    .width("100%")
    .padding({
      left: AppSpacing.Large,
      right: AppSpacing.Large,
      top: this.topSafeHeight,
      bottom: AppSpacing.Large,
    });
  }
}
