/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { AppColors, AppSizes, AppSpacing, AppAnimation } from '../common/Theme';

export interface DialogButton {
  text: string;
  color?: ResourceColor;
  onClick: () => void;
}

export interface ConfirmDialogConfig {
  title: string;
  message: string;
  cancelButton?: DialogButton;
  confirmButton: DialogButton;
}

@CustomDialog
export struct ConfirmDialog {
  controller: CustomDialogController;
  config: ConfirmDialogConfig = {
    title: '',
    message: '',
    confirmButton: { text: 'OK', onClick: () => {} }
  };

  build() {
    Column() {
      Text(this.config.title)
        .fontSize(AppSizes.FontTitle)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .margin({ bottom: AppSpacing.Medium })

      Text(this.config.message)
        .fontSize(AppSizes.FontBody)
        .fontColor(AppColors.TextSecondary)
        .textAlign(TextAlign.Center)
        .margin({ bottom: AppSpacing.Large })

      Row({ space: AppSpacing.Medium }) {
        Button(this.config.cancelButton?.text ?? 'Cancel')
          .layoutWeight(1)
          .height(48)
          .fontSize(AppSizes.FontBody)
          .fontColor(AppColors.TextSecondary)
          .backgroundColor(AppColors.Surface)
          .borderRadius(12)
          .onClick(() => {
            if (this.config.cancelButton?.onClick) {
              this.config.cancelButton.onClick();
            }
            this.controller.close();
          })

        Button(this.config.confirmButton.text)
          .layoutWeight(1)
          .height(48)
          .fontSize(AppSizes.FontBody)
          .fontColor(Color.White)
          .backgroundColor(this.config.confirmButton.color ?? AppColors.Primary)
          .borderRadius(12)
          .onClick(() => {
            this.config.confirmButton.onClick();
            this.controller.close();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(AppSpacing.Large)
    .backgroundColor(AppColors.Background)
    .borderRadius(16)
    .transition(TransitionEffect.OPACITY.animation({ duration: AppAnimation.Normal, curve: Curve.EaseOut })
      .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }).animation({ duration: AppAnimation.Normal, curve: Curve.EaseOut })))
  }
}

export interface InfoDialogConfig {
  title: string;
  content: string;
  closeButtonText?: string;
  onClose?: () => void;
}

@CustomDialog
export struct InfoDialog {
  controller: CustomDialogController;
  config: InfoDialogConfig = {
    title: '',
    content: ''
  };

  build() {
    Column() {
      Text(this.config.title)
        .fontSize(AppSizes.FontTitle)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .margin({ bottom: AppSpacing.Medium })

      Scroll() {
        Text(this.config.content)
          .fontSize(AppSizes.FontBody)
          .fontColor(AppColors.TextSecondary)
          .textAlign(TextAlign.Start)
      }
      .scrollBar(BarState.Auto)
      .constraintSize({ maxHeight: 300 })
      .width('100%')
      .margin({ bottom: AppSpacing.Large })

      Button(this.config.closeButtonText ?? 'OK')
        .width('100%')
        .height(48)
        .fontSize(AppSizes.FontBody)
        .fontColor(Color.White)
        .backgroundColor(AppColors.Primary)
        .borderRadius(12)
        .onClick(() => {
          if (this.config.onClose) {
            this.config.onClose();
          }
          this.controller.close();
        })
    }
    .width('100%')
    .padding(AppSpacing.Large)
    .backgroundColor(AppColors.Background)
    .borderRadius(16)
    .transition(TransitionEffect.OPACITY.animation({ duration: AppAnimation.Normal, curve: Curve.EaseOut })
      .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }).animation({ duration: AppAnimation.Normal, curve: Curve.EaseOut })))
  }
}

export interface ActionButton {
  text: string;
  subtitle?: string;
  color?: ResourceColor;
  backgroundColor?: ResourceColor;
  onClick: () => void;
}

export interface ActionDialogConfig {
  title: string;
  message?: string;
  actions: ActionButton[];
  cancelText?: string;
  onCancel?: () => void;
}

@CustomDialog
export struct ActionDialog {
  controller: CustomDialogController;
  config: ActionDialogConfig = {
    title: '',
    actions: []
  };

  build() {
    Column() {
      Text(this.config.title)
        .fontSize(AppSizes.FontTitle)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .margin({ bottom: this.config.message ? AppSpacing.Small : AppSpacing.Medium })

      if (this.config.message) {
        Text(this.config.message)
          .fontSize(AppSizes.FontBody)
          .fontColor(AppColors.TextSecondary)
          .textAlign(TextAlign.Center)
          .margin({ bottom: AppSpacing.Medium })
      }

      ForEach(this.config.actions, (action: ActionButton) => {
        Button() {
          Column() {
            Text(action.text)
              .fontSize(AppSizes.FontBody)
              .fontWeight(FontWeight.Medium)
              .fontColor(action.color ?? AppColors.TextPrimary)
            if (action.subtitle) {
              Text(action.subtitle)
                .fontSize(AppSizes.FontCaption)
                .fontColor(AppColors.TextTertiary)
                .margin({ top: 2 })
            }
          }
        }
        .width('100%')
        .height(action.subtitle ? 56 : 48)
        .backgroundColor(action.backgroundColor ?? AppColors.Surface)
        .borderRadius(12)
        .margin({ bottom: AppSpacing.Small })
        .onClick(() => {
          action.onClick();
          this.controller.close();
        })
      })

      Button(this.config.cancelText ?? 'Cancel')
        .width('100%')
        .height(48)
        .fontSize(AppSizes.FontBody)
        .fontColor(AppColors.TextSecondary)
        .backgroundColor(AppColors.Surface)
        .borderRadius(12)
        .margin({ top: AppSpacing.Small })
        .onClick(() => {
          if (this.config.onCancel) {
            this.config.onCancel();
          }
          this.controller.close();
        })
    }
    .width('100%')
    .padding(AppSpacing.Large)
    .backgroundColor(AppColors.Background)
    .borderRadius(16)
    .transition(TransitionEffect.OPACITY.animation({ duration: AppAnimation.Normal, curve: Curve.EaseOut })
      .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }).animation({ duration: AppAnimation.Normal, curve: Curve.EaseOut })))
  }
}
