/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { AppAnimation, AppColors, AppSizes, AppSpacing } from "../common/Theme";
import { ColorMetrics, LengthMetrics } from "@kit.ArkUI";

export interface OptionItem {
  title: string;
  subtitle?: string;
  value: string | number;
  icon?: Resource;
  checked?: boolean;
}

export interface SliderConfig {
  title: string;
  value: number;
  min: number;
  max: number;
  step: number;
  onChange: (value: number) => void;
}

export interface OptionPickerDialogConfig {
  title: string;
  subtitle?: string;
  options: OptionItem[];
  selectedValue?: string | number;
  onSelect: (option: OptionItem) => void;
  onCancel?: () => void;
  sliderConfig?: SliderConfig;
  closeOnSelect?: boolean;
  refreshOptions?: () => OptionItem[];
}
@CustomDialog
export struct OptionPickerDialog {
  controller: CustomDialogController;
  config: OptionPickerDialogConfig = {
    title: "",
    options: [],
    onSelect: () => {},
  };
  @State liveOptions: OptionItem[] = [];
  @State sliderValue: number = 0;
  @State showSlider: boolean = false;
  @State sliderTitle: string = "";
  @State sliderMin: number = 0;
  @State sliderMax: number = 100;
  @State sliderStep: number = 5;

  aboutToAppear(): void {
    this.liveOptions = [...this.config.options];
    if (this.config.sliderConfig) {
      this.sliderValue = this.config.sliderConfig.value;
      this.sliderTitle = this.config.sliderConfig.title;
      this.sliderMin = this.config.sliderConfig.min;
      this.sliderMax = this.config.sliderConfig.max;
      this.sliderStep = this.config.sliderConfig.step;
      this.showSlider = true;
    }
  }

  build() {
    Column() {
      Row() {
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
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Stack() {
          Text("✕")
            .fontSize(20)
            .fontColor(AppColors.TextSecondary)
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor(AppColors.Surface)
        .onClick(() => {
          if (this.config.onCancel) {
            this.config.onCancel();
          }
          this.controller.close();
        })
      }
      .width("100%")
      .padding({
        top: AppSpacing.Large,
        bottom: AppSpacing.Medium,
        left: AppSpacing.Medium,
        right: AppSpacing.Medium,
      })
      .alignItems(VerticalAlign.Top)
      Divider()
        .strokeWidth(0.5)
        .color(AppColors.Divider)
      Scroll() {
        Column() {
          ForEach(
            this.liveOptions,
            (option: OptionItem, index: number) => {
              Row() {
                if (option.checked !== undefined) {
                  Checkbox()
                    .select(option.checked)
                    .width(20)
                    .height(20)
                    .margin({ right: AppSpacing.Medium })
                    .onChange(() => {
                      this.config.onSelect(option);
                      if (this.config.closeOnSelect === false && this.config.refreshOptions) {
                        this.liveOptions = this.config.refreshOptions();
                      }
                    });
                }

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
                      this.config.selectedValue === option.value
                        ? FontWeight.Bold
                        : FontWeight.Normal,
                    )
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  if (option.subtitle) {
                    Text(option.subtitle)
                      .fontSize(AppSizes.FontCaption)
                      .fontColor(AppColors.TextSecondary)
                      .margin({ top: 2 })
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis });
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (this.config.selectedValue === option.value) {
                  Image($r("sys.media.ohos_ic_public_ok"))
                    .width(24)
                    .height(24)
                    .fillColor(AppColors.Primary);
                }
              }
              .width("100%")
              .constraintSize({ minHeight: 56 })
              .padding({ left: AppSpacing.Medium, right: AppSpacing.Medium, top: 10, bottom: 10 })
              .backgroundColor(
                this.config.selectedValue === option.value ? AppColors.Surface : Color.Transparent,
              )
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
                  if (event.keyCode === 2054 || event.keyCode === 2050) {
                    this.config.onSelect(option);
                    if (this.config.closeOnSelect !== false) {
                      this.controller.close();
                    } else if (this.config.refreshOptions) {
                      this.liveOptions = this.config.refreshOptions();
                    }
                    return true;
                  }
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
                this.config.onSelect(option);
                if (this.config.closeOnSelect === false) {
                  if (this.config.refreshOptions) {
                    this.liveOptions = this.config.refreshOptions();
                  }
                } else {
                  this.controller.close();
                }
              });
            },
            (option: OptionItem, index: number) => `option_${index}_${option.title}`,
          )

          if (this.showSlider) {
            Divider()
              .strokeWidth(0.5)
              .color(AppColors.Divider)
              .margin({ top: AppSpacing.Small, bottom: AppSpacing.Small });

            Row() {
              Text(this.sliderTitle)
                .fontSize(AppSizes.FontBody)
                .fontColor(AppColors.TextPrimary)
              Blank()
              Text(`${Math.round(this.sliderValue)}%`)
                .fontSize(AppSizes.FontBody)
                .fontColor(AppColors.Primary)
                .fontWeight(FontWeight.Medium)
            }
            .width("100%")
            .padding({ left: AppSpacing.Medium, right: AppSpacing.Medium });

            Slider({
              value: this.sliderValue,
              min: this.sliderMin,
              max: this.sliderMax,
              step: this.sliderStep,
              style: SliderStyle.OutSet,
            })
              .width("100%")
              .blockColor(AppColors.Primary)
              .trackColor(AppColors.Surface)
              .selectedColor(AppColors.Primary)
              .showSteps(false)
              .showTips(false)
              .sliderInteractionMode(SliderInteraction.SLIDE_ONLY)
              .padding({ left: AppSpacing.Medium, right: AppSpacing.Medium })
              .onChange((value: number) => {
                this.sliderValue = value;
                this.config.sliderConfig?.onChange(value);
              });
          }
        }.width("100%")
      }
      .scrollBar(BarState.Auto)
      .constraintSize({ maxHeight: "60%" })
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
