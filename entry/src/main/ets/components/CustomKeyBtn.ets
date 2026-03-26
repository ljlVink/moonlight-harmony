/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { CustomKeyDef, KeyAction, createDefaultKeyDef } from "../service/CustomKeyTypes";
import { OV_TEXT_WHITE } from "../common/OverlayConstants";
import {
  EDIT_BORDER_COLOR,
  SELECT_BORDER_COLOR,
  DRAG_THRESHOLD,
  SnapResult,
  doKeyHaptic,
} from "./CustomKeyConstants";
@Component
export struct CustomKeyBtn {
  keyDef: CustomKeyDef = createDefaultKeyDef();
  @Prop editMode: boolean = false;
  @Prop isSelected: boolean = false;

  onAction: (action: KeyAction, isDown: boolean) => void = () => {};
  onDragFinish: (keyId: string, deltaX: number, deltaY: number) => void = () => {};
  onSelect: (keyId: string) => void = () => {};
  onLongPress: (keyId: string) => void = () => {};

  snapCalculator: (keyId: string, rawDx: number, rawDy: number) => SnapResult | null = () => null;

  @State private isPressed: boolean = false;
  @State private isToggled: boolean = false;
  @State private dragOffsetX: number = 0;
  @State private dragOffsetY: number = 0;

  private dragging: boolean = false;
  private dragStartX: number = 0;
  private dragStartY: number = 0;
  private longPressTimer: number = -1;

  build() {
    Text(this.keyDef.label)
      .fontSize(this.keyDef.fontSize)
      .fontColor(this.isPressed || this.isToggled ? OV_TEXT_WHITE : this.keyDef.textColor)
      .fontWeight(FontWeight.Bold)
      .textAlign(TextAlign.Center)
      .width(this.keyDef.width)
      .height(this.keyDef.height)
      .borderRadius(
        this.keyDef.shape === "circle" ? this.keyDef.width / 2 : this.keyDef.borderRadius,
      )
      .backgroundColor(
        this.isPressed || this.isToggled ? this.keyDef.pressedColor : this.keyDef.bgColor,
      )
      .border({
        width: this.editMode ? 2 : (this.keyDef.borderWidth ?? 1),
        color: this.editMode
          ? this.isSelected
            ? SELECT_BORDER_COLOR
            : EDIT_BORDER_COLOR
          : this.isPressed || this.isToggled
            ? this.keyDef.pressedColor
            : this.keyDef.normalColor,
        style: this.editMode ? BorderStyle.Dashed : BorderStyle.Solid,
      })
      .shadow({
        radius: this.isPressed || this.isToggled ? 8 : 3,
        color: this.isPressed || this.isToggled ? "#40A8D8EA" : "#20000000",
        offsetY: 1,
      })
      .opacity(this.keyDef.opacity / 100)
      .translate({ x: this.dragOffsetX, y: this.dragOffsetY })
      .hitTestBehavior(HitTestMode.Block)
      .onTouch((event: TouchEvent) => {
        event.stopPropagation();
        if (this.editMode) {
          this.handleEditTouch(event);
        } else {
          this.handlePlayTouch(event);
        }
      });
  }

  private handlePlayTouch(event: TouchEvent): void {
    if (this.keyDef.behavior === "toggle") {
      if (event.type === TouchType.Down) {
        this.isToggled = !this.isToggled;
        this.onAction(this.keyDef.action, this.isToggled);
        this.doHaptic();
      }
      return;
    }
    if (event.type === TouchType.Down) {
      this.isPressed = true;
      this.onAction(this.keyDef.action, true);
      this.doHaptic();
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.isPressed = false;
      this.onAction(this.keyDef.action, false);
    }
  }

  private handleEditTouch(event: TouchEvent): void {
    const touch = event.touches[0];
    if (!touch) return;

    switch (event.type) {
      case TouchType.Down:
        this.dragStartX = touch.windowX;
        this.dragStartY = touch.windowY;
        this.dragOffsetX = 0;
        this.dragOffsetY = 0;
        this.dragging = false;

        this.cancelLongPress();
        this.longPressTimer = setTimeout(() => {
          if (!this.dragging) {
            this.onLongPress(this.keyDef.id);
            this.doHaptic();
          }
          this.longPressTimer = -1;
        }, 500) as number;
        break;

      case TouchType.Move: {
        const dx = touch.windowX - this.dragStartX;
        const dy = touch.windowY - this.dragStartY;
        if (!this.dragging && Math.abs(dx) + Math.abs(dy) > DRAG_THRESHOLD) {
          this.dragging = true;
          this.cancelLongPress();
        }
        if (this.dragging) {
          const snapResult = this.snapCalculator(this.keyDef.id, dx, dy);
          if (snapResult) {
            this.dragOffsetX = snapResult.dx;
            this.dragOffsetY = snapResult.dy;
          } else {
            this.dragOffsetX = dx;
            this.dragOffsetY = dy;
          }
        }
        break;
      }

      case TouchType.Up:
      case TouchType.Cancel:
        this.cancelLongPress();
        if (this.dragging) {
          this.onDragFinish(this.keyDef.id, this.dragOffsetX, this.dragOffsetY);
        } else {
          this.onSelect(this.keyDef.id);
        }
        this.dragging = false;
        break;
    }
  }

  private cancelLongPress(): void {
    if (this.longPressTimer !== -1) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = -1;
    }
  }

  private doHaptic(): void {
    doKeyHaptic(this.keyDef.haptic ?? "light");
  }
}
