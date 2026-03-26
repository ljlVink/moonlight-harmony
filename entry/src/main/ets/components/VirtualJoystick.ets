/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

export type JoystickMovementCallback = (x: number, y: number) => void;

export type JoystickClickCallback = () => void;

export type JoystickRevokeCallback = () => void;

export type EditModeGetter = () => boolean;
@Component
export struct VirtualJoystick {
  @Prop joystickSize: number = 120;
  @Prop ringColor: string = "#6050C080";
  @Prop stickColor: string = "#A050C080";
  @Prop pressedColor: string = "#C070E090";
  @Prop opacity_: number = 80;
  @Prop invisibleMode: boolean = false;

  onMovement: JoystickMovementCallback = (_x: number, _y: number): void => {};
  onStickClick: JoystickClickCallback = (): void => {};
  onDoubleClick: JoystickClickCallback = (): void => {};
  onRevoke: JoystickRevokeCallback = (): void => {};
  isEditMode: EditModeGetter = (): boolean => false;

  @State private stickX: number = 0;
  @State private stickY: number = 0;
  @State private isPressed: boolean = false;

  @State private dynamicOffsetX: number = 0;
  @State private dynamicOffsetY: number = 0;

  private stickOuterRadius: number = 60;
  private stickInnerRadius: number = 15;
  private stickMaxTravel: number = 45;

  private deadzone: number = 0.15;

  private trackingTouchId: number = -1;

  private lastTapTime: number = 0;
  private static readonly DOUBLE_TAP_MS: number = 300;

  aboutToAppear(): void {
    if (this.invisibleMode) {
      this.stickOuterRadius = 60;
    } else {
      this.stickOuterRadius = this.joystickSize / 2;
    }
    this.stickInnerRadius = this.stickOuterRadius * 0.25;
    this.stickMaxTravel = this.stickOuterRadius - this.stickInnerRadius;
  }

  build() {
    Stack() {
      if (this.invisibleMode) {
        Column().width("100%").height("100%").backgroundColor("#01000000");
      }
      Circle()
        .width(this.stickOuterRadius * 2)
        .height(this.stickOuterRadius * 2)
        .fill("#01000000")
        .stroke(this.isPressed ? this.pressedColor : this.ringColor)
        .strokeWidth(1.5)
        .translate(this.invisibleMode ? { x: this.dynamicOffsetX, y: this.dynamicOffsetY } : {})
        .opacity(this.invisibleMode && !this.isPressed ? 0 : 1)
      Circle()
        .width(this.stickInnerRadius * 2)
        .height(this.stickInnerRadius * 2)
        .fill(this.isPressed ? this.pressedColor : this.stickColor)
        .stroke(this.isPressed ? this.pressedColor : this.ringColor)
        .strokeWidth(1)
        .translate({
          x: this.stickX * this.stickMaxTravel + (this.invisibleMode ? this.dynamicOffsetX : 0),
          y: this.stickY * this.stickMaxTravel + (this.invisibleMode ? this.dynamicOffsetY : 0),
        })
        .opacity(this.invisibleMode && !this.isPressed ? 0 : 1)
    }
    .width(this.invisibleMode ? this.joystickSize : this.stickOuterRadius * 2)
    .height(this.invisibleMode ? this.joystickSize : this.stickOuterRadius * 2)
    .clip(false)
    .alignContent(Alignment.Center)
    .opacity(this.opacity_ / 100)
    .hitTestBehavior(HitTestMode.Block)
    .onTouch((event: TouchEvent): void => {
      event.stopPropagation();
      if (this.isEditMode()) return;
      this.handleTouch(event);
    });
  }

  private handleTouch(event: TouchEvent): void {
    const compCenterX: number = this.invisibleMode ? this.joystickSize / 2 : this.stickOuterRadius;
    const compCenterY: number = this.invisibleMode ? this.joystickSize / 2 : this.stickOuterRadius;

    if (event.type === TouchType.Down) {
      const changed: TouchObject[] = event.changedTouches;
      if (changed.length === 0) return;
      const touch: TouchObject = changed[0];

      if (this.trackingTouchId >= 0) return;

      this.trackingTouchId = touch.id;
      this.isPressed = true;

      if (this.invisibleMode) {
        this.dynamicOffsetX = touch.x - compCenterX;
        this.dynamicOffsetY = touch.y - compCenterY;
      } else {
        this.updateStickPosition(touch.x - compCenterX, touch.y - compCenterY);
      }
      this.checkDoubleTap();
      return;
    }

    if (event.type === TouchType.Move) {
      if (this.trackingTouchId < 0) return;
      const touch: TouchObject | null = this.findTrackedTouch(event.touches);
      if (touch !== null) {
        if (this.invisibleMode) {
          const dynCenterX: number = compCenterX + this.dynamicOffsetX;
          const dynCenterY: number = compCenterY + this.dynamicOffsetY;
          this.updateStickPosition(touch.x - dynCenterX, touch.y - dynCenterY);
        } else {
          this.updateStickPosition(touch.x - compCenterX, touch.y - compCenterY);
        }
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
        this.resetStick();
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

  private updateStickPosition(dx: number, dy: number): void {
    const maxDistance: number = this.stickMaxTravel;

    let distance: number = Math.sqrt(dx * dx + dy * dy);
    const angle: number = Math.atan2(dy, dx);

    if (distance > maxDistance) {
      distance = maxDistance;
    }

    const visualNorm: number = distance / maxDistance;
    this.stickX = visualNorm * Math.cos(angle);
    this.stickY = visualNorm * Math.sin(angle);

    let normalizedX: number = this.stickX;
    let normalizedY: number = this.stickY;

    const magnitude: number = Math.sqrt(normalizedX * normalizedX + normalizedY * normalizedY);
    if (magnitude < this.deadzone) {
      normalizedX = 0;
      normalizedY = 0;
    } else {
      const remapScale: number = (magnitude - this.deadzone) / (1 - this.deadzone);
      const factor: number = remapScale / magnitude;
      normalizedX = normalizedX * factor;
      normalizedY = normalizedY * factor;
    }

    this.onMovement(normalizedX, normalizedY);
  }

  private resetStick(): void {
    this.stickX = 0;
    this.stickY = 0;
    this.onMovement(0, 0);
    this.onRevoke();
  }

  private checkDoubleTap(): void {
    const now: number = Date.now();
    if (now - this.lastTapTime < VirtualJoystick.DOUBLE_TAP_MS) {
      this.onDoubleClick();
      this.lastTapTime = 0;
    } else {
      this.lastTapTime = now;
    }
  }
}
