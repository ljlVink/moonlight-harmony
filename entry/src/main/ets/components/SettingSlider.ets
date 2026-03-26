/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { AppColors, AppSizes } from '../common/Theme';
import { vibrator } from '@kit.SensorServiceKit';

export class LogarithmicSlider {
  static linearToLog(linearValue: number, min: number, max: number): number {
    if (linearValue <= 0 || min <= 0) return min;
    if (linearValue >= 100) return max;

    const minLog = Math.log(min);
    const maxLog = Math.log(max);
    const logRange = maxLog - minLog;

    const normalizedValue = linearValue / 100;
    const result = Math.exp(minLog + normalizedValue * logRange);
    return Math.round(result);
  }
  
  static logToLinear(logValue: number, min: number, max: number): number {
    if (logValue <= min) return 0;
    if (logValue >= max) return 100;

    const minLog = Math.log(min);
    const maxLog = Math.log(max);
    const logRange = maxLog - minLog;

    const normalizedValue = (Math.log(logValue) - minLog) / logRange;
    return Math.round(normalizedValue * 100);
  }
}

export interface SettingSliderConfig {
  value: number;
  min: number;
  max: number;
  step?: number;
  unit?: string;
  isLogarithmic?: boolean;
  snapValues?: number[];
  snapThreshold?: number;
  formatValue?: (value: number) => string;
  onChange: (value: number) => void;
}

/**
 * 
 * ```
 * SettingSlider({
 *   config: {
 *     value: this.bitrate,
 *     min: 1,
 *     max: 150,
 *     isLogarithmic: true,
 *     unit: ' Mbps',
 *     snapValues: [5, 10, 20, 50, 100],
 *     snapThreshold: 3,
 *     onChange: (value) => { this.bitrate = value; }
 *   }
 * })
 * ```
 */
@Component
export struct SettingSlider {
  config: SettingSliderConfig = {
    value: 0,
    min: 0,
    max: 100,
    onChange: (_v: number) => {}
  };
  @State private sliderPosition: number = 0;
  @State private draggingValue: number = 0;
  @State private isDragging: boolean = false;
  @State private committedValue: number = 0;
  private lastSnappedValue: number = -1;

  aboutToAppear(): void {
    this.committedValue = this.config.value;
    this.sliderPosition = this.valueToPosition(this.config.value);
  }

  private triggerSnapHaptic(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 20
      }, {
        id: 0,
        usage: 'touch'
      })
    } catch (_e) {
    }
  }

  private valueToPosition(value: number): number {
    if (this.config.isLogarithmic) {
      if (value === 0) return 0;
      return LogarithmicSlider.logToLinear(value, this.config.min, this.config.max);
    }
    return value;
  }
  
  build() {
    Row() {
      Slider({
        value: $$this.sliderPosition,
        min: this.config.isLogarithmic ? 0 : this.config.min,
        max: this.config.isLogarithmic ? 100 : this.config.max,
        step: this.config.isLogarithmic ? 1 : (this.config.step ?? 1),
        style: SliderStyle.OutSet
      })
        .layoutWeight(1)
        .selectedColor(AppColors.Primary)
        .trackColor(AppColors.SurfaceDark)
        .blockSize({ width: 28, height: 28 })
        .trackThickness(8)
        .showTips(this.isDragging, this.formatValue(this.draggingValue))
        .sliderInteractionMode(SliderInteraction.SLIDE_ONLY)
        .focusable(true)
        .defaultFocus(false)
        .focusOnTouch(true)
        .onChange((value: number, mode: SliderChangeMode) => {
          let actualValue = this.calculateActualValue(value);
          
          if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Begin) {
            let snappedValue: number = this.applySnap(actualValue);
            if (snappedValue !== actualValue) {
              this.draggingValue = snappedValue;
              if (this.lastSnappedValue !== snappedValue) {
                this.lastSnappedValue = snappedValue;
                this.triggerSnapHaptic();
              }
            } else {
              this.draggingValue = actualValue;
              this.lastSnappedValue = -1;
            }
            this.isDragging = true;
            return;
          }
          
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
            this.isDragging = false;
            
            let finalValue = this.applySnap(actualValue);
            
            this.sliderPosition = this.valueToPosition(finalValue);
            
            this.committedValue = finalValue;
            
            this.config.onChange(finalValue);
          }
        })

      Text(this.isDragging ? this.formatValue(this.draggingValue) : this.formatValue(this.committedValue))
        .fontSize(AppSizes.FontCaption)
        .fontColor(AppColors.TextSecondary)
        .width(70)
        .textAlign(TextAlign.End)
    }
    .width('100%')
  }
  
  private calculateActualValue(sliderValue: number): number {
    if (this.config.isLogarithmic) {
      if (sliderValue === 0) {
        return 0;
      }
      return LogarithmicSlider.linearToLog(
        sliderValue, 
        this.config.min, 
        this.config.max
      );
    }
    const step: number = this.config.step ?? 1;
    return Math.round(sliderValue / step) * step;
  }
  
  private applySnap(value: number): number {
    if (!this.config.snapValues || this.config.snapValues.length === 0) {
      return value;
    }
    
    if (this.config.isLogarithmic) {
      const ratio: number = this.config.snapThreshold !== undefined
        ? this.config.snapThreshold / 100
        : 0.08;
      for (const snapValue of this.config.snapValues) {
        const dynamicThreshold: number = Math.max(snapValue * ratio, 1);
        if (Math.abs(value - snapValue) <= dynamicThreshold) {
          return snapValue;
        }
      }
    } else {
      const threshold: number = this.config.snapThreshold ?? (this.config.step ?? 1);
      for (const snapValue of this.config.snapValues) {
        if (Math.abs(value - snapValue) <= threshold) {
          return snapValue;
        }
      }
    }
    
    return value;
  }
  
  private formatValue(value: number): string {
    if (this.config.formatValue) {
      return this.config.formatValue(value);
    }
    return `${Math.round(value)}${this.config.unit ?? ''}`;
  }
}
