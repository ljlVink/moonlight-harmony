/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { SegmentButton, SegmentButtonOptions, SegmentButtonTextItem } from '@kit.ArkUI';
import { AppColors } from '../common/Theme';

/**
 * Inline Segment Picker - Wrapper for HarmonyOS SegmentButton
 * For settings with 2-5 options, replaces popup-style pickers
 */
@Component
export struct InlineSegmentPicker {
  /** Option display text array (set at initialization, not dynamically modifiable) */
  labels: string[] = []
  /** Initial selected value (only read in aboutToAppear, then managed internally) */
  selectedValue: string = ''
  /** Option actual values array (optional, defaults to same as labels) */
  values: string[] = []
  /** Whether disabled */
  @Prop disabled: boolean = false
  /** Selection change callback */
  onValueChange?: (value: string) => void

  @State @Watch('onSelectedIndexesChange') selectedIndexes: number[] = [0]
  @State segmentOptions: SegmentButtonOptions | undefined = undefined
  private isInitialized: boolean = false

  aboutToAppear(): void {
    this.buildOptions()
    this.initSelectedIndex()
    this.isInitialized = true
  }

  /**
   * Build SegmentButtonOptions (only called once in aboutToAppear)
   */
  private buildOptions(): void {
    const len = this.labels.length
    if (len < 2 || len > 5) {
      return
    }
    // Create SegmentButtonTextItem array
    const items: SegmentButtonTextItem[] = []
    for (let i = 0; i < len; i++) {
      const item: SegmentButtonTextItem = { text: this.labels[i] } as SegmentButtonTextItem
      items.push(item)
    }
    // Build SegmentButtonOptions by option count, tuple literal passed to capsule()
    if (len === 2) {
      this.segmentOptions = SegmentButtonOptions.capsule({
        buttons: [items[0], items[1]],
        multiply: false,
        fontColor: AppColors.TextSecondary,
        selectedFontColor: AppColors.TextOnPrimary,
        selectedBackgroundColor: AppColors.Primary
      })
    } else if (len === 3) {
      this.segmentOptions = SegmentButtonOptions.capsule({
        buttons: [items[0], items[1], items[2]],
        multiply: false,
        fontColor: AppColors.TextSecondary,
        selectedFontColor: AppColors.TextOnPrimary,
        selectedBackgroundColor: AppColors.Primary
      })
    } else if (len === 4) {
      this.segmentOptions = SegmentButtonOptions.capsule({
        buttons: [items[0], items[1], items[2], items[3]],
        multiply: false,
        fontColor: AppColors.TextSecondary,
        selectedFontColor: AppColors.TextOnPrimary,
        selectedBackgroundColor: AppColors.Primary
      })
    } else {
      this.segmentOptions = SegmentButtonOptions.capsule({
        buttons: [items[0], items[1], items[2], items[3], items[4]],
        multiply: false,
        fontColor: AppColors.TextSecondary,
        selectedFontColor: AppColors.TextOnPrimary,
        selectedBackgroundColor: AppColors.Primary
      })
    }
  }

  private initSelectedIndex(): void {
    const actualValues: string[] = this.values.length > 0 ? this.values : this.labels
    const idx: number = actualValues.indexOf(this.selectedValue)
    this.selectedIndexes = [idx >= 0 ? idx : 0]
  }

  private onSelectedIndexesChange(): void {
    if (!this.isInitialized) {
      return
    }
    const callback: ((value: string) => void) | undefined = this.onValueChange
    if (callback === undefined) {
      return
    }
    if (this.selectedIndexes.length > 0) {
      const actualValues: string[] = this.values.length > 0 ? this.values : this.labels
      const selectedIdx: number = this.selectedIndexes[0]
      if (selectedIdx >= 0 && selectedIdx < actualValues.length) {
        const newValue: string = actualValues[selectedIdx]
        // Only trigger callback when value actually changes, avoid loops from prop updates
        if (newValue !== this.selectedValue) {
          // Delay callback to avoid SegmentButton internal animation being interrupted by parent re-render
          setTimeout(() => {
            callback(newValue)
          }, 0)
        }
      }
    }
  }

  build() {
    if (this.segmentOptions) {
      // SegmentButton doesn't support common attributes, must apply width/enabled/opacity through container
      Column() {
        SegmentButton({
          options: this.segmentOptions,
          selectedIndexes: $selectedIndexes
        })
      }
      .width('100%')
      .constraintSize({ maxWidth: 448 })
      .enabled(!this.disabled)
      .opacity(this.disabled ? 0.5 : 1.0)
    }
  }
}
