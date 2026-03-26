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
 *
 */

/**
export const DPAD_LEFT: number = 0x0004;
export const DPAD_UP: number = 0x0001;
export const DPAD_RIGHT: number = 0x0008;
export const DPAD_DOWN: number = 0x0002;

/**
export type DPadDirectionCallback = (direction: number) => void;

/**
export type DPadEditModeGetter = () => boolean;

@Component
export struct VirtualDPad {
  /**
  @Prop dpadSize: number = 120;
  /**
  @Prop normalColor: string = '#6050C080';
  /**
  @Prop pressedColor: string = '#C070E090';
  /**
  @Prop bgColor: string = '#3050C080';
  /**
  @Prop opacity_: number = 80;

  onDirectionChange: DPadDirectionCallback = (_dir: number): void => {};
  isEditMode: DPadEditModeGetter = (): boolean => false;

  /**
  @State private currentDir: number = 0;

  private trackingTouchId: number = -1;

  private padSize: number = 120;
  /**
  private threshold33: number = 40;
  private threshold66: number = 80;
  /**
  private bandWidth: number = 40;

  aboutToAppear(): void {
    this.padSize = this.dpadSize;
    this.threshold33 = this.padSize * 0.33;
    this.threshold66 = this.padSize * 0.66;
    this.bandWidth = this.padSize * 0.33;
  }

  build() {
    Stack() {
      Rect()
        .width(this.padSize)
        .height(this.padSize)
        .fill('#01000000')
        .borderRadius(8)

      if (this.currentDir === 0) {
        Rect()
          .width(this.bandWidth)
          .height(this.bandWidth)
          .fill('transparent')
          .stroke(this.normalColor)
          .strokeWidth(1.5)
          .borderRadius(4)
      }

      Rect()
        .width(this.bandWidth)
        .height(this.threshold33)
        .fill('transparent')
        .stroke((this.currentDir & DPAD_UP) > 0 ? this.pressedColor : this.normalColor)
        .strokeWidth(1.5)
        .borderRadius(4)
        .position({ x: this.threshold33, y: 0 })

      Rect()
        .width(this.bandWidth)
        .height(this.threshold33)
        .fill('transparent')
        .stroke((this.currentDir & DPAD_DOWN) > 0 ? this.pressedColor : this.normalColor)
        .strokeWidth(1.5)
        .borderRadius(4)
        .position({ x: this.threshold33, y: this.threshold66 })

      Rect()
        .width(this.threshold33)
        .height(this.bandWidth)
        .fill('transparent')
        .stroke((this.currentDir & DPAD_LEFT) > 0 ? this.pressedColor : this.normalColor)
        .strokeWidth(1.5)
        .borderRadius(4)
        .position({ x: 0, y: this.threshold33 })

      Rect()
        .width(this.threshold33)
        .height(this.bandWidth)
        .fill('transparent')
        .stroke((this.currentDir & DPAD_RIGHT) > 0 ? this.pressedColor : this.normalColor)
        .strokeWidth(1.5)
        .borderRadius(4)
        .position({ x: this.threshold66, y: this.threshold33 })

      Text('▲')
        .fontSize(this.padSize * 0.12)
        .fontColor((this.currentDir & DPAD_UP) > 0 ? this.pressedColor : this.normalColor)
        .position({ x: this.padSize / 2 - this.padSize * 0.06, y: this.threshold33 * 0.25 })
      Text('▼')
        .fontSize(this.padSize * 0.12)
        .fontColor((this.currentDir & DPAD_DOWN) > 0 ? this.pressedColor : this.normalColor)
        .position({ x: this.padSize / 2 - this.padSize * 0.06, y: this.threshold66 + this.threshold33 * 0.25 })
      Text('◀')
        .fontSize(this.padSize * 0.12)
        .fontColor((this.currentDir & DPAD_LEFT) > 0 ? this.pressedColor : this.normalColor)
        .position({ x: this.threshold33 * 0.2, y: this.padSize / 2 - this.padSize * 0.07 })
      Text('▶')
        .fontSize(this.padSize * 0.12)
        .fontColor((this.currentDir & DPAD_RIGHT) > 0 ? this.pressedColor : this.normalColor)
        .position({ x: this.threshold66 + this.threshold33 * 0.2, y: this.padSize / 2 - this.padSize * 0.07 })
    }
    .width(this.padSize)
    .height(this.padSize)
    .opacity(this.opacity_ / 100)
    .hitTestBehavior(HitTestMode.Block)
    .onTouch((event: TouchEvent): void => {
      if (this.isEditMode()) return;
      event.stopPropagation();
      this.handleTouch(event);
    })
  }

  private handleTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      const changed: TouchObject[] = event.changedTouches;
      if (changed.length === 0) return;
      const touch: TouchObject = changed[0];

      if (this.trackingTouchId >= 0) return;
      this.trackingTouchId = touch.id;

      this.updateDirection(touch.x, touch.y);
      return;
    }

    if (event.type === TouchType.Move) {
      if (this.trackingTouchId < 0) return;
      const touch: TouchObject | null = this.findTrackedTouch(event.touches);
      if (touch !== null) {
        this.updateDirection(touch.x, touch.y);
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
        this.currentDir = 0;
        this.onDirectionChange(0);
      }
    }
  }

  /**
   * - X < 33% → LEFT,  X > 66% → RIGHT
   * - Y < 33% → UP,    Y > 66% → DOWN
   */
  private updateDirection(x: number, y: number): void {
    let newDir: number = 0;

    if (x < this.threshold33) {
      newDir |= DPAD_LEFT;
    }
    if (x > this.threshold66) {
      newDir |= DPAD_RIGHT;
    }
    if (y < this.threshold33) {
      newDir |= DPAD_UP;
    }
    if (y > this.threshold66) {
      newDir |= DPAD_DOWN;
    }

    if (newDir !== this.currentDir) {
      this.currentDir = newDir;
      this.onDirectionChange(newDir);
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
