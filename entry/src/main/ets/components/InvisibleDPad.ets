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
 * Invisible Virtual Digital Stick Component
 *
 * Based on Android InvisibleDigitalStick.java design:
 * - Completely transparent when not touched (edit mode shows dashed border)
 * - On touch, touch point becomes joystick center, joystick appears at that position
 * - Finger sliding produces up/down/left/right digital direction input (not analog)
 * - On finger lift, joystick disappears, all directions released
 *
 * Output direction bitmask (consistent with VirtualDPad/GamepadButton)
 */

import { DPAD_LEFT, DPAD_UP, DPAD_RIGHT, DPAD_DOWN } from "./VirtualDPad";

/** Direction change callback, parameter is direction bitmask combination (0 = no direction) */
export type InvisibleDPadDirectionCallback = (direction: number) => void;

/** Double tap callback */
export type InvisibleDPadClickCallback = () => void;

/** Release callback */
export type InvisibleDPadRevokeCallback = () => void;

/** Whether in edit mode */
export type InvisibleDPadEditModeGetter = () => boolean;
@Component
export struct InvisibleDPad {
  /** Touch area width (vp) */
  @Prop areaWidth: number = 200;
  /** Touch area height (vp) */
  @Prop areaHeight: number = 200;
  /** Joystick visible radius (vp) */
  @Prop stickRadius: number = 60;
  /** Direction threshold ratio (0-1), above this ratio counts as that direction */
  @Prop directionThreshold: number = 0.3;
  /** Outer ring color */
  @Prop ringColor: string = "#6050C080";
  /** Inner joystick color */
  @Prop stickColor: string = "#A050C080";
  /** Pressed color */
  @Prop pressedColor: string = "#C070E090";
  /** Border color in edit mode */
  @Prop editBorderColor: string = "#80FFFFFF";
  /** Opacity 0-100 */
  @Prop opacity_: number = 80;

  // Callbacks
  onDirectionChange: InvisibleDPadDirectionCallback = (_dir: number): void => {};
  onStickClick: InvisibleDPadClickCallback = (): void => {};
  onDoubleClick: InvisibleDPadClickCallback = (): void => {};
  onRevoke: InvisibleDPadRevokeCallback = (): void => {};
  isEditMode: InvisibleDPadEditModeGetter = (): boolean => false;

  // === Internal state ===
  @State private isPressed: boolean = false;
  @State private centerX: number = 0;
  @State private centerY: number = 0;
  @State private stickOffsetX: number = 0;
  @State private stickOffsetY: number = 0;
  /** Current direction bitmask */
  @State private currentDir: number = 0;

  // Pre-calculated sizes
  private innerRadius: number = 15;
  private maxTravel: number = 45;

  // Dead zone
  private deadzone: number = 0.15;
  private static readonly DEADZONE_TIMEOUT_MS: number = 150;
  private touchDownTime: number = 0;
  private deadzoneActive: boolean = true;

  // Touch tracking
  private trackingTouchId: number = -1;

  // Double tap detection
  private lastTapTime: number = 0;
  private static readonly DOUBLE_TAP_MS: number = 300;

  aboutToAppear(): void {
    this.innerRadius = this.stickRadius * 0.25;
    this.maxTravel = this.stickRadius - this.innerRadius;
  }

  build() {
    Stack() {
      // Transparent touch area
      Rect()
        .width("100%")
        .height("100%")
        .fill("#01000000")

      // Edit mode shows dashed border
      if (this.isEditMode()) {
        Rect()
          .width("100%")
          .height("100%")
          .fill("transparent")
          .stroke(this.editBorderColor)
          .strokeWidth(1.5)
          .strokeDashArray([6, 4])
          .borderRadius(4);

        // Edit mode draws preview joystick outline at center
        Circle()
          .width(this.stickRadius * 2)
          .height(this.stickRadius * 2)
          .fill("transparent")
          .stroke(this.ringColor)
          .strokeWidth(1)
          .strokeOpacity(0.3)
          .position({
            x: this.areaWidth / 2 - this.stickRadius,
            y: this.areaHeight / 2 - this.stickRadius,
          });
      }

      // On press, show joystick at touch point
      if (this.isPressed) {
        // Outer ring
        Circle()
          .width(this.stickRadius * 2)
          .height(this.stickRadius * 2)
          .fill("transparent")
          .stroke(this.ringColor)
          .strokeWidth(1.5)
          .position({
            x: this.centerX - this.stickRadius,
            y: this.centerY - this.stickRadius,
          });

        // Direction indicator lines (cross)
        Rect()
          .width(1)
          .height(this.stickRadius * 0.3)
          .fill((this.currentDir & DPAD_UP) > 0 ? this.pressedColor : this.ringColor)
          .fillOpacity(0.5)
          .position({
            x: this.centerX - 0.5,
            y: this.centerY - this.stickRadius * 0.8,
          });
        Rect()
          .width(1)
          .height(this.stickRadius * 0.3)
          .fill((this.currentDir & DPAD_DOWN) > 0 ? this.pressedColor : this.ringColor)
          .fillOpacity(0.5)
          .position({
            x: this.centerX - 0.5,
            y: this.centerY + this.stickRadius * 0.5,
          });
        Rect()
          .width(this.stickRadius * 0.3)
          .height(1)
          .fill((this.currentDir & DPAD_LEFT) > 0 ? this.pressedColor : this.ringColor)
          .fillOpacity(0.5)
          .position({
            x: this.centerX - this.stickRadius * 0.8,
            y: this.centerY - 0.5,
          });
        Rect()
          .width(this.stickRadius * 0.3)
          .height(1)
          .fill((this.currentDir & DPAD_RIGHT) > 0 ? this.pressedColor : this.ringColor)
          .fillOpacity(0.5)
          .position({
            x: this.centerX + this.stickRadius * 0.5,
            y: this.centerY - 0.5,
          });

        // Inner joystick head
        Circle()
          .width(this.innerRadius * 2)
          .height(this.innerRadius * 2)
          .fill(this.pressedColor)
          .stroke(this.pressedColor)
          .strokeWidth(1.5)
          .position({
            x: this.centerX - this.innerRadius + this.stickOffsetX,
            y: this.centerY - this.innerRadius + this.stickOffsetY,
          });
      }
    }
    .width(this.areaWidth)
    .height(this.areaHeight)
    .clip(true)
    .opacity(this.opacity_ / 100)
    .hitTestBehavior(HitTestMode.Block)
    .onTouch((event: TouchEvent): void => {
      if (this.isEditMode()) return;
      this.handleTouch(event);
    });
  }

  private handleTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      const changed: TouchObject[] = event.changedTouches;
      if (changed.length === 0) return;
      const touch: TouchObject = changed[0];

      if (this.trackingTouchId >= 0) return;

      this.trackingTouchId = touch.id;
      this.isPressed = true;

      // Touch point becomes joystick center
      this.centerX = touch.x;
      this.centerY = touch.y;
      this.stickOffsetX = 0;
      this.stickOffsetY = 0;
      this.currentDir = 0;

      this.touchDownTime = Date.now();
      this.deadzoneActive = true;

      this.checkDoubleTap();
      return;
    }

    if (event.type === TouchType.Move) {
      if (this.trackingTouchId < 0) return;
      const touch: TouchObject | null = this.findTrackedTouch(event.touches);
      if (touch !== null) {
        this.updateStickPosition(touch.x - this.centerX, touch.y - this.centerY);
      }
      return;
    }

    // Up / Cancel
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      const changed: TouchObject[] = event.changedTouches;
      let isOurFinger: boolean = false;
      for (let i = 0; i < changed.length; i++) {
        if (changed[i].id === this.trackingTouchId) {
          isOurFinger = true;
          break;
        }
      }
      if (isOurFinger) {
        this.trackingTouchId = -1;
        this.isPressed = false;
        this.stickOffsetX = 0;
        this.stickOffsetY = 0;
        this.currentDir = 0;
        this.onDirectionChange(0);
        this.onRevoke();
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

  /**
   * Update joystick position and send direction events
   * Based on Android InvisibleDigitalStick: convert normalized coordinates to up/down/left/right keys
   */
  private updateStickPosition(dx: number, dy: number): void {
    let distance: number = Math.sqrt(dx * dx + dy * dy);
    const angle: number = Math.atan2(dy, dx);

    if (distance > this.maxTravel) {
      distance = this.maxTravel;
    }

    // Visual offset
    this.stickOffsetX = distance * Math.cos(angle);
    this.stickOffsetY = distance * Math.sin(angle);

    // Normalized coordinates
    const normalizedX: number = this.stickOffsetX / this.maxTravel;
    const normalizedY: number = this.stickOffsetY / this.maxTravel;
    const magnitude: number = Math.sqrt(normalizedX * normalizedX + normalizedY * normalizedY);

    // Dead zone timeout check
    if (
      this.deadzoneActive &&
      Date.now() - this.touchDownTime > InvisibleDPad.DEADZONE_TIMEOUT_MS
    ) {
      this.deadzoneActive = false;
    }
    if (magnitude > this.deadzone) {
      this.deadzoneActive = false;
    }

    // Calculate direction bitmask
    let newDir: number = 0;
    if (!this.deadzoneActive || magnitude >= this.deadzone) {
      if (normalizedX < -this.directionThreshold) {
        newDir |= DPAD_LEFT;
      }
      if (normalizedX > this.directionThreshold) {
        newDir |= DPAD_RIGHT;
      }
      if (normalizedY < -this.directionThreshold) {
        newDir |= DPAD_UP;
      }
      if (normalizedY > this.directionThreshold) {
        newDir |= DPAD_DOWN;
      }
    }

    if (newDir !== this.currentDir) {
      this.currentDir = newDir;
      this.onDirectionChange(newDir);
    }
  }

  private checkDoubleTap(): void {
    const now: number = Date.now();
    if (now - this.lastTapTime < InvisibleDPad.DOUBLE_TAP_MS) {
      this.onDoubleClick();
      this.lastTapTime = 0;
    } else {
      this.onStickClick();
      this.lastTapTime = now;
    }
  }
}
