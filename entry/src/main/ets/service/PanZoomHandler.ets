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
 *
 */

export interface PointXY {
  x: number;
  y: number;
}

export interface PanZoomState {
  /**
  scale: number;
  /**
  translateX: number;
  /**
  translateY: number;
}

export class PanZoomHandler {
  private static readonly MAX_SCALE: number = 10.0;
  private static readonly MIN_SCALE: number = 1.0;

  private scaleFactor: number = 1.0;
  private translateX: number = 0;
  private translateY: number = 0;

  private parentWidth: number = 0;
  private parentHeight: number = 0;

  private initialPinchDistance: number = 0;
  private initialScaleFactor: number = 1.0;
  private pinchFocusX: number = 0;
  private pinchFocusY: number = 0;
  private initialTranslateX: number = 0;
  private initialTranslateY: number = 0;

  private lastPanX: number = 0;
  private lastPanY: number = 0;

  private pointers: Map<number, PointXY> = new Map();

  private onStateChanged: ((state: PanZoomState) => void) | null = null;

  setParentSize(width: number, height: number): void {
    this.parentWidth = width;
    this.parentHeight = height;
  }

  setOnStateChanged(callback: (state: PanZoomState) => void): void {
    this.onStateChanged = callback;
  }

  reset(): void {
    this.scaleFactor = 1.0;
    this.translateX = 0;
    this.translateY = 0;
    this.pointers.clear();
    this.notifyStateChanged();
  }

  getState(): PanZoomState {
    const state: PanZoomState = {
      scale: this.scaleFactor,
      translateX: this.translateX,
      translateY: this.translateY
    };
    return state;
  }

  isZoomed(): boolean {
    return this.scaleFactor > 1.01;
  }

  handleTouchEvent(event: TouchEvent): boolean {
    const touches = event.touches;
    const changedTouches = event.changedTouches;

    for (const touch of changedTouches) {
      if (touch.type === TouchType.Down) {
        const downPt: PointXY = { x: touch.x, y: touch.y };
        this.pointers.set(touch.id, downPt);
      } else if (touch.type === TouchType.Move) {
        const movePt: PointXY = { x: touch.x, y: touch.y };
        this.pointers.set(touch.id, movePt);
      } else if (touch.type === TouchType.Up || touch.type === TouchType.Cancel) {
        this.pointers.delete(touch.id);
      }
    }

    if (touches.length === 2) {
      const p1: PointXY = { x: touches[0].x, y: touches[0].y };
      const p2: PointXY = { x: touches[1].x, y: touches[1].y };
      const currentDistance = this.distance(p1.x, p1.y, p2.x, p2.y);
      const focusX = (p1.x + p2.x) / 2;
      const focusY = (p1.y + p2.y) / 2;

      if (changedTouches[0]?.type === TouchType.Down ||
          (this.initialPinchDistance === 0 && changedTouches[0]?.type === TouchType.Move)) {
        this.initialPinchDistance = currentDistance;
        this.initialScaleFactor = this.scaleFactor;
        this.pinchFocusX = focusX;
        this.pinchFocusY = focusY;
        this.initialTranslateX = this.translateX;
        this.initialTranslateY = this.translateY;
        this.lastPanX = focusX;
        this.lastPanY = focusY;
      } else if (changedTouches[0]?.type === TouchType.Move && this.initialPinchDistance > 0) {
        const scaleRatio = currentDistance / this.initialPinchDistance;
        let newScale = this.initialScaleFactor * scaleRatio;
        newScale = Math.max(PanZoomHandler.MIN_SCALE, Math.min(newScale, PanZoomHandler.MAX_SCALE));

        const oldScale = this.scaleFactor;
        if (oldScale > 0) {
          const dPivotX = (this.translateX - focusX) / oldScale * newScale;
          const dPivotY = (this.translateY - focusY) / oldScale * newScale;
          this.translateX = focusX + dPivotX;
          this.translateY = focusY + dPivotY;
        }

        const panDeltaX = focusX - this.lastPanX;
        const panDeltaY = focusY - this.lastPanY;
        this.translateX += panDeltaX;
        this.translateY += panDeltaY;

        this.scaleFactor = newScale;
        this.lastPanX = focusX;
        this.lastPanY = focusY;

        this.constrainToBounds();
        this.notifyStateChanged();
      }
    } else if (touches.length === 1 && this.isZoomed()) {
      const touch = touches[0];
      if (changedTouches[0]?.type === TouchType.Down) {
        this.lastPanX = touch.x;
        this.lastPanY = touch.y;
      } else if (changedTouches[0]?.type === TouchType.Move) {
        const dx = touch.x - this.lastPanX;
        const dy = touch.y - this.lastPanY;
        this.translateX += dx;
        this.translateY += dy;
        this.lastPanX = touch.x;
        this.lastPanY = touch.y;

        this.constrainToBounds();
        this.notifyStateChanged();
      }
    }

    if (this.pointers.size === 0) {
      this.initialPinchDistance = 0;
      if (this.scaleFactor < 1.05) {
        this.reset();
      }
    }

    return true;
  }

  /**
   *
   */
  inverseTransform(screenX: number, screenY: number): PointXY {
    const result: PointXY = {
      x: (screenX - this.translateX) / this.scaleFactor,
      y: (screenY - this.translateY) / this.scaleFactor
    };
    return result;
  }

  /**
   *
   */
  private constrainToBounds(): void {
    if (this.parentWidth <= 0 || this.parentHeight <= 0) return;

    const childWidth = this.parentWidth * this.scaleFactor;
    const childHeight = this.parentHeight * this.scaleFactor;

    if (this.parentWidth >= childWidth) {
      this.translateX = (this.parentWidth - childWidth) / 2;
    } else {
      this.translateX = Math.max(this.parentWidth - childWidth, Math.min(this.translateX, 0));
    }

    if (this.parentHeight >= childHeight) {
      this.translateY = (this.parentHeight - childHeight) / 2;
    } else {
      this.translateY = Math.max(this.parentHeight - childHeight, Math.min(this.translateY, 0));
    }
  }

  private distance(x1: number, y1: number, x2: number, y2: number): number {
    const dx = x1 - x2;
    const dy = y1 - y2;
    return Math.sqrt(dx * dx + dy * dy);
  }

  private notifyStateChanged(): void {
    if (this.onStateChanged) {
      this.onStateChanged(this.getState());
    }
  }
}
