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
 * Invisible Joystick Component
 *
 * Based on Android InvisibleAnalogStick.java design:
 * - Completely transparent when not touched (edit mode shows dashed border)
 * - On touch, touch point becomes joystick center, joystick appears at that position
 * - Finger sliding produces analog input relative to touch point
 * - On finger lift, joystick disappears, input zeros
 *
 * Provides JoystickMovementCallback outputting normalized x/y (-1.0 ~ 1.0)
 */

/**
 * Joystick movement callback
 * @param x Horizontal axis -1.0(left) ~ 0 ~ 1.0(right)
 * @param y Vertical axis -1.0(up) ~ 0 ~ 1.0(down) (screen coordinate system)
 */
export type InvisibleJoystickMovementCallback = (x: number, y: number) => void;

/** Joystick double tap callback (L3/R3 short press trigger) */
export type InvisibleJoystickClickCallback = () => void;

/** Joystick release callback (finger lifted, joystick zeros) */
export type InvisibleJoystickRevokeCallback = () => void;

/** Whether in edit mode (edit mode disables joystick input but shows border) */
export type InvisibleEditModeGetter = () => boolean;

@Component
export struct InvisibleJoystick {
  /** Touch area width (vp) */
  @Prop areaWidth: number = 200;
  /** Touch area height (vp) */
  @Prop areaHeight: number = 200;
  /** Joystick visible radius (vp), radius of circle that appears on touch */
  @Prop stickRadius: number = 60;
  /** Outer ring color */
  @Prop ringColor: string = '#6050C080';
  /** Inner joystick color */
  @Prop stickColor: string = '#A050C080';
  /** Pressed color */
  @Prop pressedColor: string = '#C070E090';
  /** Border color in edit mode */
  @Prop editBorderColor: string = '#80FFFFFF';
  /** Opacity 0-100 */
  @Prop opacity_: number = 80;

  // Callbacks
  onMovement: InvisibleJoystickMovementCallback = (_x: number, _y: number): void => {};
  onStickClick: InvisibleJoystickClickCallback = (): void => {};
  onDoubleClick: InvisibleJoystickClickCallback = (): void => {};
  onRevoke: InvisibleJoystickRevokeCallback = (): void => {};
  isEditMode: InvisibleEditModeGetter = (): boolean => false;

  // === Internal state ===
  /** Whether finger is pressed */
  @State private isPressed: boolean = false;
  /** Joystick center X (relative to touch area, dynamically equals ACTION_DOWN coordinate) */
  @State private centerX: number = 0;
  /** Joystick center Y */
  @State private centerY: number = 0;
  /** Inner joystick head visual offset X (relative to center, px unit, for translate) */
  @State private stickOffsetX: number = 0;
  /** Inner joystick head visual offset Y */
  @State private stickOffsetY: number = 0;

  // Pre-calculated size values
  private innerRadius: number = 15;
  private maxTravel: number = 45;

  // Dead zone ratio
  private deadzone: number = 0.15;

  // Dead zone timeout (150ms then auto-release dead zone, allowing fine control)
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
      // Transparent touch area (always present for hit testing)
      Rect()
        .width('100%')
        .height('100%')
        .fill('#01000000')

      // Edit mode shows dashed border indicating touch area
      if (this.isEditMode()) {
        Rect()
          .width('100%')
          .height('100%')
          .fill('transparent')
          .stroke(this.editBorderColor)
          .strokeWidth(1.5)
          .strokeDashArray([6, 4])
          .borderRadius(4)

        // Edit mode draws preview joystick outline at center
        Circle()
          .width(this.stickRadius * 2)
          .height(this.stickRadius * 2)
          .fill('transparent')
          .stroke(this.ringColor)
          .strokeWidth(1)
          .strokeOpacity(0.3)
          .position({
            x: this.areaWidth / 2 - this.stickRadius,
            y: this.areaHeight / 2 - this.stickRadius
          })
      }

      // On press, show joystick at touch point
      if (this.isPressed) {
        // Outer ring
        Circle()
          .width(this.stickRadius * 2)
          .height(this.stickRadius * 2)
          .fill('transparent')
          .stroke(this.ringColor)
          .strokeWidth(1.5)
          .position({
            x: this.centerX - this.stickRadius,
            y: this.centerY - this.stickRadius
          })

        // Dead zone circle
        Circle()
          .width(this.stickRadius * 2 * this.deadzone)
          .height(this.stickRadius * 2 * this.deadzone)
          .fill('transparent')
          .stroke(this.ringColor)
          .strokeWidth(0.5)
          .strokeOpacity(0.3)
          .position({
            x: this.centerX - this.stickRadius * this.deadzone,
            y: this.centerY - this.stickRadius * this.deadzone
          })

        // Inner joystick head
        Circle()
          .width(this.innerRadius * 2)
          .height(this.innerRadius * 2)
          .fill(this.pressedColor)
          .stroke(this.pressedColor)
          .strokeWidth(1.5)
          .position({
            x: this.centerX - this.innerRadius + this.stickOffsetX,
            y: this.centerY - this.innerRadius + this.stickOffsetY
          })
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
    })
  }

  private handleTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      const changed: TouchObject[] = event.changedTouches;
      if (changed.length === 0) return;
      const touch: TouchObject = changed[0];

      // Only track one finger
      if (this.trackingTouchId >= 0) return;

      this.trackingTouchId = touch.id;
      this.isPressed = true;

      // ★ Core: touch point becomes joystick center
      this.centerX = touch.x;
      this.centerY = touch.y;
      this.stickOffsetX = 0;
      this.stickOffsetY = 0;

      // Record press time for dead zone timeout
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
        this.onMovement(0, 0);
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
   * Update joystick position and send movement events
   * Based on Android InvisibleAnalogStick.updatePosition + dead zone timeout mechanism
   */
  private updateStickPosition(dx: number, dy: number): void {
    // Polar coordinates
    let distance: number = Math.sqrt(dx * dx + dy * dy);
    const angle: number = Math.atan2(dy, dx);

    // Limit to movable range
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

    // Dead zone timeout check (150ms then auto-release dead zone, consistent with Android)
    if (this.deadzoneActive && Date.now() - this.touchDownTime > InvisibleJoystick.DEADZONE_TIMEOUT_MS) {
      this.deadzoneActive = false;
    }
    // Once outside dead zone range, permanently release
    if (magnitude > this.deadzone) {
      this.deadzoneActive = false;
    }

    let outX: number = 0;
    let outY: number = 0;

    if (this.deadzoneActive && magnitude < this.deadzone) {
      // In dead zone and not timed out, don't send movement
      outX = 0;
      outY = 0;
    } else {
      // Dead zone released, continuous remapping
      if (magnitude > 0) {
        const effectiveDeadzone: number = this.deadzoneActive ? this.deadzone : 0;
        if (magnitude > effectiveDeadzone) {
          const remapScale: number = effectiveDeadzone > 0
            ? (magnitude - effectiveDeadzone) / (1 - effectiveDeadzone)
            : magnitude;
          const factor: number = remapScale / magnitude;
          outX = normalizedX * factor;
          outY = normalizedY * factor;
        }
      }
    }

    this.onMovement(outX, outY);
  }

  /**
   * Double tap detection (300ms threshold consistent with VirtualJoystick)
   */
  private checkDoubleTap(): void {
    const now: number = Date.now();
    if (now - this.lastTapTime < InvisibleJoystick.DOUBLE_TAP_MS) {
      this.onDoubleClick();
      this.lastTapTime = 0;
    } else {
      this.onStickClick();
      this.lastTapTime = now;
    }
  }
}
