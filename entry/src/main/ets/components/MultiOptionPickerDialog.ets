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
 * Multi-select option picker dialog component
 *
 * Bottom sheet multi-select picker using CustomDialogController
 */
import { AppColors, AppSizes, AppSpacing, AppAnimation } from "../common/Theme";
import { LengthMetrics, ColorMetrics } from "@kit.ArkUI";

/**
 * Multi-select option config
 */
export interface MultiOptionItem {
  /** Display title */
  title: string;
  /** Option key value */
  key: string;
  /** Icon (optional)*/
  icon?: Resource;
}

/**
 * Multi-select picker config
 */
export interface MultiOptionPickerDialogConfig {
  /** Dialog title */
  title: string;
  /** Subtitle (optional)*/
  subtitle?: string;
  /** Option list */
  options: MultiOptionItem[];
  /** Currently selected key list */
  selectedKeys: string[];
  /** Minimum selected count (optional, default 0)*/
  minSelected?: number;
  /** Selection change callback */
  onSelectionChange: (selectedKeys: string[]) => void;
  /** Cancel callback (optional)*/
  onCancel?: () => void;
}

/**
 * Multi-select option picker dialog
 */
@CustomDialog
export struct MultiOptionPickerDialog {
  controller: CustomDialogController;
  config: MultiOptionPickerDialogConfig = {
    title: "",
    options: [],
    selectedKeys: [],
    onSelectionChange: () => {},
  };

  // Local selection state
  @State localSelectedKeys: string[] = [];

  aboutToAppear(): void {
    // Copy initial selection state
    this.localSelectedKeys = [...this.config.selectedKeys];
  }

  private toggleOption(key: string): void {
    const index = this.localSelectedKeys.indexOf(key);
    if (index >= 0) {
      // Deselect - check minimum selected count
      const minSelected = this.config.minSelected ?? 0;
      if (this.localSelectedKeys.length > minSelected) {
        this.localSelectedKeys = this.localSelectedKeys.filter((k) => k !== key);
      }
    } else {
      // Select
      this.localSelectedKeys = [...this.localSelectedKeys, key];
    }
  }

  private isSelected(key: string): boolean {
    return this.localSelectedKeys.includes(key);
  }

  build() {
    Column() {
      // Title bar
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

      // Divider
      Divider()
        .strokeWidth(0.5)
        .color(AppColors.Divider)

      // Option list
      Scroll() {
        Column() {
          ForEach(
            this.config.options,
            (option: MultiOptionItem, index: number) => {
              Row() {
                // Icon (if any)
                if (option.icon) {
                  Image(option.icon)
                    .width(24)
                    .height(24)
                    .fillColor(AppColors.TextPrimary)
                    .margin({ right: AppSpacing.Medium });
                }

                // Text content
                Text(option.title)
                  .fontSize(AppSizes.FontBody)
                  .fontColor(AppColors.TextPrimary)
                  .fontWeight(this.isSelected(option.key) ? FontWeight.Bold : FontWeight.Normal)
                  .layoutWeight(1)

                // Selection mark (checkbox style)
                Stack() {
                  if (this.isSelected(option.key)) {
                    Image($r("sys.media.ohos_ic_public_ok"))
                      .width(16)
                      .height(16)
                      .fillColor(Color.White);
                  }
                }
                .width(24)
                .height(24)
                .borderRadius(4)
                .backgroundColor(
                  this.isSelected(option.key) ? AppColors.Primary : Color.Transparent,
                )
                .border({
                  width: this.isSelected(option.key) ? 0 : 2,
                  color: AppColors.TextSecondary,
                })
              }
              .width("100%")
              .height(56)
              .padding({ left: AppSpacing.Medium, right: AppSpacing.Medium })
              .backgroundColor(this.isSelected(option.key) ? AppColors.Surface : Color.Transparent)
              .borderRadius(12)
              .margin({ top: index === 0 ? AppSpacing.Small : 4 })
              .focusable(true)
              .focusOnTouch(true)
              .focusBox({
                margin: LengthMetrics.vp(1),
                strokeColor: ColorMetrics.rgba(74, 222, 128, 0.8),
                strokeWidth: LengthMetrics.vp(1.5),
              })
              .onKeyEvent((event: KeyEvent) => {
                if (event.type === KeyType.Down) {
                  // A key toggles selection
                  if (event.keyCode === 2054 || event.keyCode === 2050) {
                    this.toggleOption(option.key);
                    return true;
                  }
                  // B key closes
                  if (event.keyCode === 2070 || event.keyCode === 2012) {
                    if (this.config.onCancel) {
                      this.config.onCancel();
                    }
                    this.controller.close();
                    return true;
                  }
                }
                return false;
              })
              .onClick(() => {
                this.toggleOption(option.key);
              });
            },
            (option: MultiOptionItem, index: number) => `multi_option_${index}_${option.key}`,
          )
        }.width("100%")
      }
      .scrollBar(BarState.Off)
      .constraintSize({ maxHeight: 350 })

      // Button area
      Row({ space: AppSpacing.Medium }) {
        // Cancel button
        Button("Cancel")
          .layoutWeight(1)
          .height(48)
          .fontSize(AppSizes.FontBody)
          .fontColor(AppColors.TextSecondary)
          .backgroundColor(AppColors.Surface)
          .borderRadius(12)
          .onClick(() => {
            if (this.config.onCancel) {
              this.config.onCancel();
            }
            this.controller.close();
          })

        // Confirm button
        Button("OK")
          .layoutWeight(1)
          .height(48)
          .fontSize(AppSizes.FontBody)
          .fontColor(Color.White)
          .backgroundColor(AppColors.Primary)
          .borderRadius(12)
          .onClick(() => {
            this.config.onSelectionChange(this.localSelectedKeys);
            this.controller.close();
          })
      }
      .width("100%")
      .margin({ top: AppSpacing.Medium })
    }
    .width("100%")
    .padding({ left: AppSpacing.Large, right: AppSpacing.Large, bottom: AppSpacing.Large })
    .backgroundColor(AppColors.Background)
    .borderRadius({ topLeft: 16, topRight: 16 })
    .transition(
      TransitionEffect.OPACITY.animation({
        duration: AppAnimation.Normal,
        curve: Curve.EaseOut,
      }).combine(
        TransitionEffect.translate({ y: 150 }).animation({
          duration: AppAnimation.Normal,
          curve: Curve.EaseOut,
        }),
      ),
    );
  }
}
