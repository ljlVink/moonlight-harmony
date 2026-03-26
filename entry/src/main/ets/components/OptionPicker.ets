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

export interface OptionItem {
  title: string;
  subtitle?: string;
  value: string | number;
  icon?: Resource;
}

export interface OptionPickerConfig {
  title: string;
  subtitle?: string;
  options: OptionItem[];
  selectedValue: string | number;
  onSelect: (option: OptionItem) => void;
  onCancel?: () => void;
}
@Component
export struct OptionPicker {
  @Prop config: OptionPickerConfig;
  @Link isShow: boolean;

  build() {
    Column() {
      Column() {
        Text(this.config.title)
          .fontSize(AppSizes.FontTitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .margin({ bottom: 4 })

        if (this.config.subtitle) {
          Text(this.config.subtitle)
            .fontSize(AppSizes.FontCaption)
            .fontColor(AppColors.TextSecondary);
        }
      }
      .width("100%")
      .padding({ top: AppSpacing.Large, bottom: AppSpacing.Medium })
      .alignItems(HorizontalAlign.Center)
      Divider()
        .strokeWidth(0.5)
        .color(AppColors.Divider)
      Scroll() {
        Column() {
          ForEach(this.config.options, (option: OptionItem, index: number) => {
            this.OptionItemView(option, index);
          })
        }.width("100%")
      }
      .scrollBar(BarState.Off)
      .constraintSize({ maxHeight: 400 })
      Button("取消")
        .width("100%")
        .height(52)
        .fontSize(AppSizes.FontBody)
        .fontColor(AppColors.TextSecondary)
        .backgroundColor(AppColors.Surface)
        .borderRadius(12)
        .margin({ top: AppSpacing.Medium })
        .onClick(() => {
          this.isShow = false;
          if (this.config.onCancel) {
            this.config.onCancel();
          }
        })
    }
    .width("100%")
    .padding({ left: AppSpacing.Large, right: AppSpacing.Large, bottom: AppSpacing.Large })
    .backgroundColor(AppColors.Background);
  }

  @Builder
  OptionItemView(option: OptionItem, index: number) {
    Row() {
      if (option.icon) {
        Image(option.icon)
          .width(24)
          .height(24)
          .fillColor(AppColors.TextPrimary)
          .margin({ right: AppSpacing.Medium });
      }
      Column() {
        Text(option.title)
          .fontSize(AppSizes.FontBody)
          .fontColor(AppColors.TextPrimary)
          .fontWeight(
            this.config.selectedValue === option.value ? FontWeight.Bold : FontWeight.Normal,
          )

        if (option.subtitle) {
          Text(option.subtitle)
            .fontSize(AppSizes.FontCaption)
            .fontColor(AppColors.TextSecondary)
            .margin({ top: 2 });
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.config.selectedValue === option.value) {
        Image($r("sys.media.ohos_ic_public_ok")).width(24).height(24).fillColor(AppColors.Primary);
      }
    }
    .width("100%")
    .height(60)
    .padding({ left: AppSpacing.Medium, right: AppSpacing.Medium })
    .backgroundColor(
      this.config.selectedValue === option.value ? AppColors.Surface : Color.Transparent,
    )
    .borderRadius(12)
    .margin({ top: index === 0 ? AppSpacing.Small : 4 })
    .focusable(true)
    .onClick(() => {
      this.isShow = false;
      setTimeout(() => {
        this.config.onSelect(option);
      }, 50);
    });
  }
}
