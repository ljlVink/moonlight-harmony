/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { KeyAction, WheelPadSegment } from '../service/CustomKeyTypes';

export type WheelSegmentActionCallback = (action: KeyAction, isDown: boolean) => void;

export type WheelEditModeGetter = () => boolean;

@Component
export struct VirtualWheelPad {
  @Prop wheelSize: number = 150;
  @Prop normalColor: string = '#6050C080';
  @Prop pressedColor: string = '#C070E090';
  @Prop bgColor: string = '#3050C080';
  @Prop textColor: string = '#E0FFFFFF';
  @Prop opacity_: number = 80;
  segments: WheelPadSegment[] = [];
  onSegmentAction: WheelSegmentActionCallback = (_a: KeyAction, _d: boolean): void => {
  };
  isEditMode: WheelEditModeGetter = (): boolean => false;

  @State @Watch('onActiveChanged') private activeIndex: number = -1;

  private trackingTouchId: number = -1;

  // Canvas
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private canvasReady: boolean = false;

  private wheelRadius: number = 75;
  private innerRadius: number = 22;

  aboutToAppear(): void {
    this.wheelRadius = this.wheelSize / 2;
    this.innerRadius = this.wheelRadius * 0.30;
  }

  build() {
    Stack() {
      Canvas(this.ctx)
        .width(this.wheelSize)
        .height(this.wheelSize)
        .backgroundColor('#01000000')
        .onReady(() => {
          this.canvasReady = true;
          this.drawWheel();
        })
    }
    .width(this.wheelSize)
    .height(this.wheelSize)
    .opacity(this.opacity_ / 100)
    .hitTestBehavior(HitTestMode.Block)
    .onTouch((event: TouchEvent): void => {
      if (this.isEditMode()) return;
      event.stopPropagation();
      this.handleTouch(event);
    })
  }

  private onActiveChanged(): void {
    if (this.canvasReady) {
      this.drawWheel();
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  private drawWheel(): void {
    const ctx: CanvasRenderingContext2D = this.ctx;
    const cx: number = this.wheelRadius;
    const cy: number = this.wheelRadius;
    const outerR: number = this.wheelRadius - 2;
    const innerR: number = this.innerRadius;
    const N: number = this.segments.length;
    if (N === 0) return;

    const sweepRad: number = (2 * Math.PI) / N;

    ctx.clearRect(0, 0, this.wheelSize, this.wheelSize);

    for (let i = 0; i < N; i++) {
      const startAngle: number = i * sweepRad - Math.PI / 2 - sweepRad / 2;
      const endAngle: number = startAngle + sweepRad;

      ctx.beginPath();
      ctx.arc(cx, cy, outerR, startAngle, endAngle, false);
      ctx.arc(cx, cy, innerR, endAngle, startAngle, true);
      ctx.closePath();
      ctx.fillStyle = (i === this.activeIndex) ? this.pressedColor : this.bgColor;
      ctx.fill();

      const lineStartX: number = cx + innerR * Math.cos(startAngle);
      const lineStartY: number = cy + innerR * Math.sin(startAngle);
      const lineEndX: number = cx + outerR * Math.cos(startAngle);
      const lineEndY: number = cy + outerR * Math.sin(startAngle);
      ctx.beginPath();
      ctx.moveTo(lineStartX, lineStartY);
      ctx.lineTo(lineEndX, lineEndY);
      ctx.strokeStyle = this.normalColor;
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }

    ctx.beginPath();
    ctx.arc(cx, cy, outerR, 0, 2 * Math.PI, false);
    ctx.strokeStyle = this.normalColor;
    ctx.lineWidth = 1.5;
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(cx, cy, innerR, 0, 2 * Math.PI, false);
    ctx.fillStyle = '#CC1A1A2E';
    ctx.fill();
    ctx.strokeStyle = this.normalColor;
    ctx.lineWidth = 1.5;
    ctx.stroke();

    const textR: number = innerR + (outerR - innerR) * 0.55;
    const fontSize: number = Math.max(8, (outerR - innerR) * 0.28);
    ctx.font = `bold ${fontSize}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    for (let i = 0; i < N; i++) {
      const midAngle: number = i * sweepRad - Math.PI / 2;
      const tx: number = cx + textR * Math.cos(midAngle);
      const ty: number = cy + textR * Math.sin(midAngle);

      ctx.fillStyle = (i === this.activeIndex) ? '#FFFFFFFF' : this.textColor;
      ctx.fillText(this.segments[i].label, tx, ty);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  private handleTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      const changed: TouchObject[] = event.changedTouches;
      if (changed.length === 0) return;
      if (this.trackingTouchId >= 0) return;

      this.trackingTouchId = changed[0].id;
      this.updateActiveSegment(changed[0].x, changed[0].y);
      return;
    }

    if (event.type === TouchType.Move) {
      if (this.trackingTouchId < 0) return;
      const touch: TouchObject | null = this.findTrackedTouch(event.touches);
      if (touch !== null) {
        this.updateActiveSegment(touch.x, touch.y);
      }
      return;
    }

    // Up / Cancel
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      const changed: TouchObject[] = event.changedTouches;
      let isOurs: boolean = false;
      for (let i = 0; i < changed.length; i++) {
        if (changed[i].id === this.trackingTouchId) {
          isOurs = true;
          break;
        }
      }
      if (isOurs) {
        if (this.activeIndex >= 0 && this.activeIndex < this.segments.length) {
          this.onSegmentAction(this.segments[this.activeIndex].action, false);
        }
        this.trackingTouchId = -1;
        this.activeIndex = -1;
      }
    }
  }

  private updateActiveSegment(x: number, y: number): void {
    const cx: number = this.wheelRadius;
    const cy: number = this.wheelRadius;
    const dx: number = x - cx;
    const dy: number = y - cy;
    const dist: number = Math.sqrt(dx * dx + dy * dy);

    if (dist < this.innerRadius) {
      if (this.activeIndex >= 0 && this.activeIndex < this.segments.length) {
        this.onSegmentAction(this.segments[this.activeIndex].action, false);
      }
      this.activeIndex = -1;
      return;
    }

    const N: number = this.segments.length;
    if (N === 0) return;

    const sweepRad: number = (2 * Math.PI) / N;

    let angle: number = Math.atan2(dy, dx) + Math.PI / 2 + sweepRad / 2;
    if (angle < 0) angle += 2 * Math.PI;
    if (angle >= 2 * Math.PI) angle -= 2 * Math.PI;

    let newIndex: number = Math.floor(angle / sweepRad);
    if (newIndex >= N) newIndex = N - 1;

    if (newIndex !== this.activeIndex) {
      if (this.activeIndex >= 0 && this.activeIndex < this.segments.length) {
        this.onSegmentAction(this.segments[this.activeIndex].action, false);
      }
      this.activeIndex = newIndex;
      if (this.activeIndex >= 0 && this.activeIndex < this.segments.length) {
        this.onSegmentAction(this.segments[this.activeIndex].action, true);
      }
    }
  }

  private findTrackedTouch(touches: TouchObject[]): TouchObject | null {
    for (let i = 0; i < touches.length; i++) {
      if (touches[i].id === this.trackingTouchId) {
        return touches[i];
      }
    }
    return null;
  }
}
