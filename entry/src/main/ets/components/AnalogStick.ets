/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import {
  ControllerAxis,
  ControllerAxisEvent,
  InputType,
  ControllerButton,
  ControllerButtonEvent,
  InputEvent,
} from "../model/InputEvent";

export interface AnalogStickConfig {
  isLeftStick: boolean;
  outerRadius?: number;
  innerRadius?: number;
  deadzone?: number;
  opacity?: number;
  enableClick?: boolean;
}
@Component
export struct AnalogStick {
  @Prop config: AnalogStickConfig = { isLeftStick: true };

  onAxisChange: (
    xAxis: ControllerAxis,
    xValue: number,
    yAxis: ControllerAxis,
    yValue: number,
  ) => void = () => {};
  onStickClick: (button: ControllerButton) => void = () => {};
  onInput: (event: InputEvent) => void = () => {};

  @State stickX: number = 0;
  @State stickY: number = 0;
  @State isPressed: boolean = false;
  @State showClickFeedback: boolean = false;

  private stickOuterRadius: number = 60;
  private stickInnerRadius: number = 28;
  private stickDeadzone: number = 0.15;
  private stickOpacity: number = 0.8;

  private lastTapTime: number = 0;
  private doubleTapThreshold: number = 300;

  private trackingTouchId: number = -1;

  aboutToAppear(): void {
    if (this.config.outerRadius) {
      this.stickOuterRadius = this.config.outerRadius;
    }
    if (this.config.innerRadius) {
      this.stickInnerRadius = this.config.innerRadius;
    }
    if (this.config.deadzone !== undefined) {
      this.stickDeadzone = this.config.deadzone;
    }
    if (this.config.opacity !== undefined) {
      this.stickOpacity = this.config.opacity;
    }
  }

  build() {
    Stack() {
      Circle()
        .width(this.stickOuterRadius * 2)
        .height(this.stickOuterRadius * 2)
        .fill("transparent")
        .stroke("#FFFFFF")
        .strokeWidth(1)
        .strokeOpacity(0.15)
      Circle()
        .width(this.stickInnerRadius * 2)
        .height(this.stickInnerRadius * 2)
        .fill(this.isPressed ? "#005090FF" : "transparent")
        .stroke(this.isPressed ? "#5090FF" : "#FFFFFF")
        .strokeWidth(1.5)
        .strokeOpacity(this.isPressed ? 0.7 : 0.35)
        .translate({
          x: this.stickX * (this.stickOuterRadius - this.stickInnerRadius),
          y: this.stickY * (this.stickOuterRadius - this.stickInnerRadius),
        })
        .animation({
          duration: this.isPressed ? 0 : 100,
          curve: Curve.EaseOut,
        })

      if (this.showClickFeedback) {
        Circle()
          .width(this.stickInnerRadius * 2 + 16)
          .height(this.stickInnerRadius * 2 + 16)
          .fill("transparent")
          .stroke("#5090FF")
          .strokeWidth(2)
          .strokeOpacity(0.6)
          .translate({
            x: this.stickX * (this.stickOuterRadius - this.stickInnerRadius),
            y: this.stickY * (this.stickOuterRadius - this.stickInnerRadius),
          });
      }
      Text(this.config.isLeftStick ? "L" : "R")
        .fontSize(11)
        .fontColor("#FFFFFF")
        .fontWeight(FontWeight.Medium)
        .opacity(0.3)
        .translate({
          x: this.stickX * (this.stickOuterRadius - this.stickInnerRadius),
          y: this.stickY * (this.stickOuterRadius - this.stickInnerRadius),
        })
    }
    .width(this.stickOuterRadius * 2)
    .height(this.stickOuterRadius * 2)
    .opacity(this.stickOpacity)
    .hitTestBehavior(HitTestMode.Block)
    .onTouch((event) => this.handleTouch(event));
  }

  private handleTouch(event: TouchEvent): void {
    const centerX = this.stickOuterRadius;
    const centerY = this.stickOuterRadius;

    switch (event.type) {
      case TouchType.Down: {
        const changed = event.changedTouches;
        if (changed.length === 0) return;
        const touch = changed[0];
        this.trackingTouchId = touch.id;
        this.isPressed = true;
        this.updateStickPosition(touch.x - centerX, touch.y - centerY);
        this.checkDoubleTap();
        break;
      }

      case TouchType.Move: {
        if (!this.isPressed) break;
        const touch = this.findTrackedTouch(event.touches);
        if (touch) {
          this.updateStickPosition(touch.x - centerX, touch.y - centerY);
        }
        break;
      }

      case TouchType.Up:
      case TouchType.Cancel: {
        const changed = event.changedTouches;
        const isOurFinger = changed.some((t) => t.id === this.trackingTouchId);
        if (isOurFinger) {
          this.trackingTouchId = -1;
          this.isPressed = false;
          this.resetStick();
        }
        break;
      }
    }
  }

  private findTrackedTouch(touches: TouchObject[]): TouchObject | null {
    for (const t of touches) {
      if (t.id === this.trackingTouchId) {
        return t;
      }
    }
    return null;
  }

  private updateStickPosition(dx: number, dy: number): void {
    const maxDistance = this.stickOuterRadius - this.stickInnerRadius;

    let distance = Math.sqrt(dx * dx + dy * dy);
    const angle = Math.atan2(dy, dx);

    if (distance > maxDistance) {
      distance = maxDistance;
    }

    let normalizedX = (distance / maxDistance) * Math.cos(angle);
    let normalizedY = (distance / maxDistance) * Math.sin(angle);

    const magnitude = Math.sqrt(normalizedX * normalizedX + normalizedY * normalizedY);
    if (magnitude < this.stickDeadzone) {
      normalizedX = 0;
      normalizedY = 0;
    } else {
      const remapScale = (magnitude - this.stickDeadzone) / (1 - this.stickDeadzone);
      const normalizedMagnitude = magnitude > 0 ? remapScale / magnitude : 0;
      normalizedX *= normalizedMagnitude;
      normalizedY *= normalizedMagnitude;
    }

    this.stickX = (distance / maxDistance) * Math.cos(angle);
    this.stickY = (distance / maxDistance) * Math.sin(angle);

    const xAxis = this.config.isLeftStick ? ControllerAxis.LEFT_X : ControllerAxis.RIGHT_X;
    const yAxis = this.config.isLeftStick ? ControllerAxis.LEFT_Y : ControllerAxis.RIGHT_Y;

    const xValue = Math.round(normalizedX * 32767);
    const yValue = Math.round(-normalizedY * 32767);

    this.onAxisChange(xAxis, xValue, yAxis, yValue);

    const xEvent: ControllerAxisEvent = {
      type: InputType.CONTROLLER_AXIS,
      timestamp: Date.now(),
      controllerIndex: 0,
      axis: xAxis,
      value: xValue,
    };
    const yEvent: ControllerAxisEvent = {
      type: InputType.CONTROLLER_AXIS,
      timestamp: Date.now(),
      controllerIndex: 0,
      axis: yAxis,
      value: yValue,
    };
    this.onInput(xEvent);
    this.onInput(yEvent);
  }

  private resetStick(): void {
    this.stickX = 0;
    this.stickY = 0;

    const xAxis = this.config.isLeftStick ? ControllerAxis.LEFT_X : ControllerAxis.RIGHT_X;
    const yAxis = this.config.isLeftStick ? ControllerAxis.LEFT_Y : ControllerAxis.RIGHT_Y;

    this.onAxisChange(xAxis, 0, yAxis, 0);

    const xEvent: ControllerAxisEvent = {
      type: InputType.CONTROLLER_AXIS,
      timestamp: Date.now(),
      controllerIndex: 0,
      axis: xAxis,
      value: 0,
    };
    const yEvent: ControllerAxisEvent = {
      type: InputType.CONTROLLER_AXIS,
      timestamp: Date.now(),
      controllerIndex: 0,
      axis: yAxis,
      value: 0,
    };
    this.onInput(xEvent);
    this.onInput(yEvent);
  }

  private checkDoubleTap(): void {
    if (!this.config.enableClick) return;

    const now = Date.now();
    if (now - this.lastTapTime < this.doubleTapThreshold) {
      const button = this.config.isLeftStick ? ControllerButton.LS : ControllerButton.RS;
      this.onStickClick(button);

      const pressEvent: ControllerButtonEvent = {
        type: InputType.CONTROLLER_BUTTON,
        timestamp: Date.now(),
        controllerIndex: 0,
        button: button,
        isPressed: true,
      };
      this.onInput(pressEvent);

      setTimeout(() => {
        const releaseEvent: ControllerButtonEvent = {
          type: InputType.CONTROLLER_BUTTON,
          timestamp: Date.now(),
          controllerIndex: 0,
          button: button,
          isPressed: false,
        };
        this.onInput(releaseEvent);
      }, 50);

      this.showClickFeedback = true;
      setTimeout(() => {
        this.showClickFeedback = false;
      }, 200);

      this.lastTapTime = 0;
    } else {
      this.lastTapTime = now;
    }
  }
}
