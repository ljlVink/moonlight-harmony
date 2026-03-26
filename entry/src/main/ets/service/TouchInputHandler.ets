/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */


import nativeLib from 'libmoonlight_nativelib.so';
import { PointXY } from './PanZoomHandler';
import {
  BUTTON_ACTION_PRESS,
  BUTTON_ACTION_RELEASE,
  BUTTON_LEFT,
  BUTTON_RIGHT,
  LI_ROT_UNKNOWN,
  LI_TOOL_TYPE_PEN,
  TOUCH_EVENT_CANCEL,
  TOUCH_EVENT_DOWN,
  TOUCH_EVENT_MOVE,
  TOUCH_EVENT_UP
} from './MoonBridge';

export enum TouchInputMode {
  TRACKPAD = 'trackpad',
  DIRECT = 'direct',
  MOUSE = 'mouse'
}

interface NativeInputModule {
  sendMouseMove(deltaX: number, deltaY: number): void;
  sendMousePosition(x: number, y: number, refWidth: number, refHeight: number): void;
  sendMouseButton(buttonEvent: number, mouseButton: number): void;
  sendMouseHighResScroll(scrollAmount: number): void;
  sendTouchEvent(eventType: number, pointerId: number, x: number, y: number,
    pressureOrDistance: number, contactAreaMajor: number, contactAreaMinor: number,
    rotation: number): void;
  sendPenEvent(eventType: number, toolType: number, penButtons: number,
    x: number, y: number, pressureOrDistance: number,
    contactAreaMajor: number, contactAreaMinor: number,
    rotation: number, tilt: number): number;
}

interface TouchState {
  startX: number;
  startY: number;
  lastX: number;
  lastY: number;
  startTime: number;
}

export interface TouchInputConfig {

  sensitivity?: number;
  clickThreshold?: number;
  clickTimeThreshold?: number;
}

export class TouchInputHandler {
  private nativeInput: NativeInputModule;
  private mode: TouchInputMode = TouchInputMode.TRACKPAD;
  private touchStates: Map<number, TouchState> = new Map();
  private config: TouchInputConfig;
  private lastForce: Map<number, number> = new Map();
  private lastSize: Map<number, number> = new Map();
  private penUnsupported: boolean = false;
  private penFirstEventLogged: boolean = false;
  private static readonly FORCE_MAX = 65535.0;
  private twoFingerDownTime: number = 0;
  private firstFingerUpTime: number = 0;
  private twoFingerTapPending: boolean = false;
  private twoFingerMoved: boolean = false;
  private twoFingerStartX: number = 0;
  private twoFingerStartY: number = 0;
  private activePointerCount: number = 0;
  private maxPointerCountInGesture: number = 0;
  private confirmedScroll: boolean = false;
  private secondFingerLastY: number = 0;
  private twoFingerTapThreshold: number = 250;
  private static readonly TWO_FINGER_MOVE_THRESHOLD = 30;
  private static readonly SCROLL_SPEED_FACTOR = 5;
  private mouseDownX: number = 0;
  private mouseDownY: number = 0;
  private mouseDownTime: number = 0;
  private mouseLastUpX: number = 0;
  private mouseLastUpY: number = 0;
  private mouseLastUpTime: number = 0;
  private mouseLastX: number = 0;
  private mouseLastY: number = 0;
  private mouseCancelled: boolean = false;
  private mouseConfirmedTap: boolean = false;
  private mouseConfirmedLongPress: boolean = false;
  private mouseLongPressTimer: number = -1;
  private mouseTapDownTimer: number = -1;
  private mouseLeftButtonUpTimer: number = -1;
  private mousePrimaryFingerId: number = -1;
  private mouseSecondFingerId: number = -1;
  private mouseSecondFingerLastY: number = 0;
  private mouseAreaWidth: number = 0;
  private mouseAreaHeight: number = 0;
  private coordinateTransform: ((x: number, y: number) => PointXY) | null = null;
  private static readonly MOUSE_LONG_PRESS_TIME = 650;
  private static readonly MOUSE_LONG_PRESS_DISTANCE = 30;
  private static readonly MOUSE_DEADZONE_TIME = 100;
  private static readonly MOUSE_DEADZONE_DISTANCE = 20;
  private mouseDoubleTapTime: number = 250;
  private static readonly MOUSE_DOUBLE_TAP_DISTANCE = 60;
  private static readonly MOUSE_SCROLL_SPEED_FACTOR = 3;

  private static readonly DEFAULT_SENSITIVITY = 1.5;
  private static readonly DEFAULT_CLICK_THRESHOLD = 20;
  private static readonly DEFAULT_CLICK_TIME_THRESHOLD = 300;
  
  constructor(config?: TouchInputConfig) {
    this.nativeInput = nativeLib as NativeInputModule;
    this.config = {
      sensitivity: config?.sensitivity ?? TouchInputHandler.DEFAULT_SENSITIVITY,
      clickThreshold: config?.clickThreshold ?? TouchInputHandler.DEFAULT_CLICK_THRESHOLD,
      clickTimeThreshold: config?.clickTimeThreshold ?? TouchInputHandler.DEFAULT_CLICK_TIME_THRESHOLD,
    };
  }

  setDoubleTapTimeThreshold(threshold: number): void {
    this.twoFingerTapThreshold = threshold;
    this.mouseDoubleTapTime = threshold;
  }

  setCoordinateTransform(transform: ((x: number, y: number) => PointXY) | null): void {
    this.coordinateTransform = transform;
  }
  
  private normalizeForce(force: number): number {
    if (force <= 0) {
      return 0;
    }
    if (force > 1.0) {
      return Math.min(1.0, force / TouchInputHandler.FORCE_MAX);
    }
    return force;
  }
  
  private getTrackedForce(pointerId: number, defaultForce: number = 1.0): number {
    const force = this.lastForce.get(pointerId);
    return force !== undefined ? force : defaultForce;
  }
  
  private getTrackedSize(pointerId: number, defaultSize: number = 0.05): number {
    const size = this.lastSize.get(pointerId);
    return size !== undefined ? size : defaultSize;
  }
  
  setMode(mode: TouchInputMode): void {
    this.mode = mode;
    console.info(`TouchInputHandler: 模式切换为 ${mode}`);
  }
  
  getMode(): TouchInputMode {
    return this.mode;
  }
  
  setSensitivity(sensitivity: number): void {
    this.config.sensitivity = sensitivity;
  }
  
  handleTouchEvent(event: TouchEvent): void {
    const touches = event.touches;
    if (touches.length === 0) {
      return;
    }

    if (event.sourceTool === SourceTool.Pen && this.mode === TouchInputMode.DIRECT && !this.penUnsupported) {
      this.handlePenEvent(event);
      return;
    }
    
    if (this.mode === TouchInputMode.DIRECT) {
      this.handleMultiTouchEvent(event);
      return;
    }
    
    if (this.mode === TouchInputMode.TRACKPAD) {
      this.handleTrackpadEvent(event);
      return;
    }
    
    this.handleMouseEvent(event);
  }
  
  private handleMultiTouchEvent(event: TouchEvent): void {
    const touches = event.touches;
    const changedTouches = event.changedTouches;
    const areaWidth = event.target.area.width as number;
    const areaHeight = event.target.area.height as number;
    
    switch (event.type) {
      case TouchType.Down:
        for (let i = 0; i < changedTouches.length; i++) {
          const touch = changedTouches[i];
          this.touchStates.set(touch.id, {
            startX: touch.x,
            startY: touch.y,
            lastX: touch.x,
            lastY: touch.y,
            startTime: Date.now()
          });
          this.lastForce.set(touch.id, 1.0);
          this.lastSize.set(touch.id, 0.05);
          this.sendNormalizedTouch(TOUCH_EVENT_DOWN, touch, event);
        }
        break;
        
      case TouchType.Move:
        try {
          const historicalPoints = event.getHistoricalPoints();
          if (historicalPoints && historicalPoints.length > 0) {
            const now = Date.now();
            const maxAge = 100;
            
            for (let i = 0; i < historicalPoints.length; i++) {
              const histPoint = historicalPoints[i];
              
              if (histPoint.timestamp && (now - histPoint.timestamp) > maxAge) {
                continue;
              }
              
              const histTouch = histPoint.touchObject;
              const state = this.touchStates.get(histTouch.id);
              if (state) {
                const normalizedForce = histPoint.force > 0
                  ? this.normalizeForce(histPoint.force) : this.getTrackedForce(histTouch.id);
                const contactSize = histPoint.size || this.getTrackedSize(histTouch.id);
                
                this.lastForce.set(histTouch.id, normalizedForce);
                this.lastSize.set(histTouch.id, contactSize);
                
                this.sendNormalizedTouchDirect(
                  TOUCH_EVENT_MOVE,
                  histTouch.id,
                  histTouch.x,
                  histTouch.y,
                  areaWidth,
                  areaHeight,
                  normalizedForce,
                  contactSize
                );
              }
            }
          }
        } catch (e) {
        }
        
        for (let i = 0; i < touches.length; i++) {
          const touch = touches[i];
          const state = this.touchStates.get(touch.id);
          if (state) {
            state.lastX = touch.x;
            state.lastY = touch.y;
            this.sendNormalizedTouch(TOUCH_EVENT_MOVE, touch, event);
          }
        }
        break;
        
      case TouchType.Up:
      case TouchType.Cancel:
        for (let i = 0; i < changedTouches.length; i++) {
          const touch = changedTouches[i];
          this.sendNormalizedTouch(TOUCH_EVENT_UP, touch, event);
          this.touchStates.delete(touch.id);
          this.lastForce.delete(touch.id);
          this.lastSize.delete(touch.id);
        }
        break;
    }
  }


  private handleTrackpadEvent(event: TouchEvent): void {
    const touches = event.touches;
    const changedTouches = event.changedTouches;
    
    switch (event.type) {
      case TouchType.Down:
        this.handleTrackpadDown(touches, changedTouches, event);
        break;
      case TouchType.Move:
        this.handleTrackpadMove(touches, event);
        break;
      case TouchType.Up:
      case TouchType.Cancel:
        this.handleTrackpadUp(touches, changedTouches, event);
        break;
    }
  }

  private handleTrackpadDown(touches: TouchObject[], changedTouches: TouchObject[], event: TouchEvent): void {
    this.activePointerCount = touches.length;
    if (this.activePointerCount > this.maxPointerCountInGesture) {
      this.maxPointerCountInGesture = this.activePointerCount;
    }

    for (const touch of changedTouches) {
      this.touchStates.set(touch.id, {
        startX: touch.x,
        startY: touch.y,
        lastX: touch.x,
        lastY: touch.y,
        startTime: Date.now()
      });
    }

    if (touches.length === 2) {
      this.twoFingerDownTime = Date.now();
      this.twoFingerStartX = touches[0].x;
      this.twoFingerStartY = touches[0].y;
      this.twoFingerMoved = false;
      this.twoFingerTapPending = false;
      this.confirmedScroll = false;
      this.secondFingerLastY = touches[1].y;
    }
  }

  private handleTrackpadMove(touches: TouchObject[], event: TouchEvent): void {
    if (touches.length === 1 && this.maxPointerCountInGesture === 1) {
      const touch = touches[0];
      const state = this.touchStates.get(touch.id);
      if (!state) return;

      const deltaX = touch.x - state.lastX;
      const deltaY = touch.y - state.lastY;
      state.lastX = touch.x;
      state.lastY = touch.y;

      const sensitivity = this.config.sensitivity!;
      this.nativeInput.sendMouseMove(
        Math.floor(deltaX * sensitivity),
        Math.floor(deltaY * sensitivity)
      );
    } else if (touches.length === 2) {
      if (!this.twoFingerMoved) {
        const dx = touches[0].x - this.twoFingerStartX;
        const dy = touches[0].y - this.twoFingerStartY;
        if (Math.sqrt(dx * dx + dy * dy) > TouchInputHandler.TWO_FINGER_MOVE_THRESHOLD) {
          this.twoFingerMoved = true;
          this.confirmedScroll = true;
        }
      }

      if (this.confirmedScroll) {
        const touch = touches[0];
        const state = this.touchStates.get(touch.id);
        if (state) {
          const deltaY = touch.y - state.lastY;
          state.lastX = touch.x;
          state.lastY = touch.y;

          if (Math.abs(deltaY) > 0) {
            const scrollAmount = Math.round(-deltaY * TouchInputHandler.SCROLL_SPEED_FACTOR);
            this.nativeInput.sendMouseHighResScroll(scrollAmount);
          }
        }

        const secondState = this.touchStates.get(touches[1].id);
        if (secondState) {
          secondState.lastX = touches[1].x;
          secondState.lastY = touches[1].y;
        }
      }
    }
  }

  private handleTrackpadUp(touches: TouchObject[], changedTouches: TouchObject[], event: TouchEvent): void {
    const now = Date.now();
    const remainingPointers = Math.max(0, this.activePointerCount - changedTouches.length);

    if (this.activePointerCount === 2 && remainingPointers === 1 && !this.twoFingerMoved) {
      const elapsed = now - this.twoFingerDownTime;
      if (elapsed < this.twoFingerTapThreshold) {
        this.nativeInput.sendMouseButton(BUTTON_ACTION_PRESS, BUTTON_RIGHT);
        setTimeout(() => {
          this.nativeInput.sendMouseButton(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
        }, 50);
        this.twoFingerTapPending = false;
        this.twoFingerMoved = true;
        this.resetTrackpadGesture(changedTouches);
        this.activePointerCount = remainingPointers;
        return;
      } else {
        this.firstFingerUpTime = now;
        this.twoFingerTapPending = true;
      }
    }

    if (remainingPointers === 0) {
      if (this.twoFingerTapPending && !this.twoFingerMoved) {
        const elapsed = now - this.firstFingerUpTime;
        if (elapsed < this.twoFingerTapThreshold) {
          this.nativeInput.sendMouseButton(BUTTON_ACTION_PRESS, BUTTON_RIGHT);
          setTimeout(() => {
            this.nativeInput.sendMouseButton(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
          }, 50);
          this.twoFingerTapPending = false;
          this.resetTrackpadGesture(changedTouches);
          this.activePointerCount = 0;
          this.maxPointerCountInGesture = 0;
          return;
        }
      }
      this.twoFingerTapPending = false;

      if (this.maxPointerCountInGesture === 1) {
        for (const touch of changedTouches) {
          const state = this.touchStates.get(touch.id);
          if (state) {
            this.checkForClick(touch, state);
          }
        }
      }

      this.maxPointerCountInGesture = 0;
    }

    this.resetTrackpadGesture(changedTouches);
    this.activePointerCount = remainingPointers;
  }

  private resetTrackpadGesture(changedTouches: TouchObject[]): void {
    for (const touch of changedTouches) {
      this.touchStates.delete(touch.id);
    }
  }

  private mouseDistanceExceeds(deltaX: number, deltaY: number, limit: number): boolean {
    return Math.sqrt(deltaX * deltaX + deltaY * deltaY) > limit;
  }

  private mouseUpdatePosition(eventX: number, eventY: number): void {
    let posX = eventX;
    let posY = eventY;
    if (this.coordinateTransform) {
      const transformed = this.coordinateTransform(posX, posY);
      posX = transformed.x;
      posY = transformed.y;
    }
    const x = Math.min(Math.max(posX, 0), this.mouseAreaWidth);
    const y = Math.min(Math.max(posY, 0), this.mouseAreaHeight);
    this.nativeInput.sendMousePosition(
      Math.floor(x), Math.floor(y),
      Math.floor(this.mouseAreaWidth), Math.floor(this.mouseAreaHeight)
    );
  }

  private mouseTapConfirmed(): void {
    if (this.mouseConfirmedTap || this.mouseConfirmedLongPress) {
      return;
    }
    this.mouseConfirmedTap = true;
    this.cancelMouseTapDownTimer();

    if (this.mouseDownTime - this.mouseLastUpTime > this.mouseDoubleTapTime ||
        this.mouseDistanceExceeds(
          this.mouseDownX - this.mouseLastUpX,
          this.mouseDownY - this.mouseLastUpY,
          TouchInputHandler.MOUSE_DOUBLE_TAP_DISTANCE)) {
      this.mouseUpdatePosition(this.mouseDownX, this.mouseDownY);
    }
    this.nativeInput.sendMouseButton(BUTTON_ACTION_PRESS, BUTTON_LEFT);
  }

  private mouseCancelTouch(): void {
    this.mouseCancelled = true;
    this.cancelMouseLongPressTimer();
    this.cancelMouseTapDownTimer();

    if (this.mouseConfirmedLongPress) {
      this.nativeInput.sendMouseButton(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
    } else if (this.mouseConfirmedTap) {
      this.nativeInput.sendMouseButton(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
    }
  }

  private startMouseLongPressTimer(): void {
    this.cancelMouseLongPressTimer();
    this.mouseLongPressTimer = setTimeout(() => {
      this.cancelMouseTapDownTimer();
      this.mouseConfirmedLongPress = true;
      if (this.mouseConfirmedTap) {
        this.nativeInput.sendMouseButton(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
      }
      this.nativeInput.sendMouseButton(BUTTON_ACTION_PRESS, BUTTON_RIGHT);
    }, TouchInputHandler.MOUSE_LONG_PRESS_TIME);
  }

  private cancelMouseLongPressTimer(): void {
    if (this.mouseLongPressTimer !== -1) {
      clearTimeout(this.mouseLongPressTimer);
      this.mouseLongPressTimer = -1;
    }
  }

  private startMouseTapDownTimer(): void {
    this.cancelMouseTapDownTimer();
    this.mouseTapDownTimer = setTimeout(() => {
      this.mouseTapConfirmed();
    }, TouchInputHandler.MOUSE_DEADZONE_TIME);
  }

  private cancelMouseTapDownTimer(): void {
    if (this.mouseTapDownTimer !== -1) {
      clearTimeout(this.mouseTapDownTimer);
      this.mouseTapDownTimer = -1;
    }
  }

  private handleMouseEvent(event: TouchEvent): void {
    this.mouseAreaWidth = event.target.area.width as number;
    this.mouseAreaHeight = event.target.area.height as number;

    const changedTouches = event.changedTouches;

    switch (event.type) {
      case TouchType.Down: {
        for (const touch of changedTouches) {
          if (this.mousePrimaryFingerId === -1) {
            this.mousePrimaryFingerId = touch.id;
            this.mouseDownX = this.mouseLastX = touch.x;
            this.mouseDownY = this.mouseLastY = touch.y;
            this.mouseDownTime = Date.now();
            this.mouseCancelled = false;
            this.mouseConfirmedTap = false;
            this.mouseConfirmedLongPress = false;

            this.startMouseTapDownTimer();
            this.startMouseLongPressTimer();
          } else if (this.mouseSecondFingerId === -1) {
            this.mouseSecondFingerId = touch.id;
            this.mouseSecondFingerLastY = touch.y;
            this.mouseCancelTouch();
          }
        }
        break;
      }

      case TouchType.Move: {
        for (const touch of changedTouches) {
          if (touch.id === this.mousePrimaryFingerId && !this.mouseCancelled) {
            if (this.mouseDistanceExceeds(
              touch.x - this.mouseDownX, touch.y - this.mouseDownY,
              TouchInputHandler.MOUSE_LONG_PRESS_DISTANCE)) {
              this.cancelMouseLongPressTimer();
            }

            if (this.mouseConfirmedTap ||
                this.mouseDistanceExceeds(
                  touch.x - this.mouseDownX, touch.y - this.mouseDownY,
                  TouchInputHandler.MOUSE_DEADZONE_DISTANCE)) {
              this.mouseTapConfirmed();
              this.mouseUpdatePosition(touch.x, touch.y);
            }

            this.mouseLastX = touch.x;
            this.mouseLastY = touch.y;
          } else if (touch.id === this.mouseSecondFingerId) {
            const deltaY = touch.y - this.mouseSecondFingerLastY;
            this.nativeInput.sendMouseHighResScroll(
              Math.floor(deltaY * TouchInputHandler.MOUSE_SCROLL_SPEED_FACTOR)
            );
            this.mouseSecondFingerLastY = touch.y;
          }
        }
        break;
      }

      case TouchType.Up:
      case TouchType.Cancel: {
        for (const touch of changedTouches) {
          if (touch.id === this.mousePrimaryFingerId) {
            this.mousePrimaryFingerId = -1;

            if (!this.mouseCancelled) {
              this.cancelMouseLongPressTimer();
              this.cancelMouseTapDownTimer();

              if (this.mouseConfirmedLongPress) {
                this.nativeInput.sendMouseButton(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
              } else if (this.mouseConfirmedTap) {
                this.nativeInput.sendMouseButton(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
              } else {
                this.mouseTapConfirmed();
                if (this.mouseLeftButtonUpTimer !== -1) {
                  clearTimeout(this.mouseLeftButtonUpTimer);
                }
                this.mouseLeftButtonUpTimer = setTimeout(() => {
                  this.nativeInput.sendMouseButton(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
                  this.mouseLeftButtonUpTimer = -1;
                }, 100);
              }
            }

            this.mouseLastUpX = touch.x;
            this.mouseLastUpY = touch.y;
            this.mouseLastUpTime = Date.now();
          } else if (touch.id === this.mouseSecondFingerId) {
            this.mouseSecondFingerId = -1;
          }
        }
        break;
      }
    }
  }
  
  private sendNormalizedTouch(eventType: number, touch: TouchObject, event: TouchEvent): void {
    const areaWidth = event.target.area.width as number;
    const areaHeight = event.target.area.height as number;
    
    let touchX = touch.x;
    let touchY = touch.y;
    if (this.coordinateTransform) {
      const transformed = this.coordinateTransform(touchX, touchY);
      touchX = transformed.x;
      touchY = transformed.y;
    }
    
    const normalizedX = Math.max(0, Math.min(1, touchX / areaWidth));
    const normalizedY = Math.max(0, Math.min(1, touchY / areaHeight));
    
    let pressure: number;
    let contactArea: number;
    if (eventType === TOUCH_EVENT_UP) {
      pressure = 0;
      contactArea = 0;
    } else {
      pressure = this.getTrackedForce(touch.id);
      contactArea = this.getTrackedSize(touch.id);
    }
    
    this.nativeInput.sendTouchEvent(
      eventType,
      touch.id,
      normalizedX,
      normalizedY,
      pressure,
      contactArea,
      contactArea,
      0  // rotation
    );
  }
  
  private sendNormalizedTouchDirect(
    eventType: number,
    pointerId: number,
    x: number,
    y: number,
    areaWidth: number,
    areaHeight: number,
    pressure: number,
    size: number
  ): void {
    let touchX = x;
    let touchY = y;
    if (this.coordinateTransform) {
      const transformed = this.coordinateTransform(touchX, touchY);
      touchX = transformed.x;
      touchY = transformed.y;
    }
    
    const normalizedX = Math.max(0, Math.min(1, touchX / areaWidth));
    const normalizedY = Math.max(0, Math.min(1, touchY / areaHeight));
    
    this.nativeInput.sendTouchEvent(
      eventType,
      pointerId,
      normalizedX,
      normalizedY,
      pressure,
      size,
      size,
      0
    );
  }

  private getPenToolType(): number {
    return LI_TOOL_TYPE_PEN;
  }


  private computePenTilt(tiltX: number, tiltY: number): number {
    if (tiltX === 0 && tiltY === 0) {
      return 0;
    }
    const tiltXRad = tiltX * Math.PI / 180;
    const tiltYRad = tiltY * Math.PI / 180;
    const tanTiltX = Math.tan(tiltXRad);
    const tanTiltY = Math.tan(tiltYRad);
    const tiltRad = Math.atan(Math.sqrt(tanTiltX * tanTiltX + tanTiltY * tanTiltY));
    return Math.min(90, Math.round(tiltRad * 180 / Math.PI));
  }

  private computePenRotation(event: TouchEvent): number {
    const rollAngle = event.rollAngle;
    if (rollAngle !== undefined && rollAngle !== null) {
      let degrees = Math.round(rollAngle);
      if (degrees < 0) {
        degrees += 360;
      }
      return degrees % 360;
    }
    return LI_ROT_UNKNOWN;
  }

  private handlePenEvent(event: TouchEvent): void {
    const touches = event.touches;
    const changedTouches = event.changedTouches;
    const areaWidth = event.target.area.width as number;
    const areaHeight = event.target.area.height as number;

    const eventPressure = event.pressure ?? 0;
    const tiltX = event.tiltX ?? 0;
    const tiltY = event.tiltY ?? 0;
    const tilt = this.computePenTilt(tiltX, tiltY);
    const rotation = this.computePenRotation(event);
    const toolType = this.getPenToolType();

    if (!this.penFirstEventLogged) {
      this.penFirstEventLogged = true;
      console.info(`手写笔首次事件: sourceTool=${event.sourceTool}, pressure=${eventPressure}, ` +
        `tiltX=${tiltX}, tiltY=${tiltY}, computedTilt=${tilt}, rotation=${rotation}, ` +
        `type=${event.type}, pointers=${touches.length}`);
    }

    switch (event.type) {
      case TouchType.Down:
        for (let i = 0; i < changedTouches.length; i++) {
          const touch = changedTouches[i];
          this.touchStates.set(touch.id, {
            startX: touch.x, startY: touch.y,
            lastX: touch.x, lastY: touch.y,
            startTime: Date.now()
          });

          const normalizedX = Math.max(0, Math.min(1, touch.x / areaWidth));
          const normalizedY = Math.max(0, Math.min(1, touch.y / areaHeight));
          const pressure = eventPressure;
          const contactW = touch.width ?? 0;
          const contactH = touch.height ?? 0;
          const areaMajor = areaWidth > 0 ? Math.min(contactW, areaWidth) / areaWidth : 0;
          const areaMinor = areaHeight > 0 ? Math.min(contactH, areaHeight) / areaHeight : 0;

          const ret = this.nativeInput.sendPenEvent(
            TOUCH_EVENT_DOWN, toolType, 0,
            normalizedX, normalizedY, pressure,
            areaMajor, areaMinor, rotation, tilt
          );
          if (ret === -7) { // LI_ERR_UNSUPPORTED = -7
            console.warn('手写笔: 主机不支持 Pen 事件，回退到 Touch 事件');
            this.penUnsupported = true;
            this.sendNormalizedTouch(TOUCH_EVENT_DOWN, touch, event);
            return;
          }
        }
        break;

      case TouchType.Move:
        try {
          const historicalPoints = event.getHistoricalPoints();
          if (historicalPoints && historicalPoints.length > 0) {
            const now = Date.now();
            for (let i = 0; i < historicalPoints.length; i++) {
              const histPoint = historicalPoints[i];
              if (histPoint.timestamp && (now - histPoint.timestamp) > 100) {
                continue;
              }
              const histTouch = histPoint.touchObject;
              const state = this.touchStates.get(histTouch.id);
              if (state) {
                const normalizedX = Math.max(0, Math.min(1, histTouch.x / areaWidth));
                const normalizedY = Math.max(0, Math.min(1, histTouch.y / areaHeight));
                const histPressure = histPoint.force > 0
                  ? this.normalizeForce(histPoint.force) : eventPressure;
                const histSize = histPoint.size || 0;

                this.nativeInput.sendPenEvent(
                  TOUCH_EVENT_MOVE, toolType, 0,
                  normalizedX, normalizedY, histPressure,
                  histSize, histSize, rotation, tilt
                );
              }
            }
          }
        } catch (_e) {
        }

        for (let i = 0; i < touches.length; i++) {
          const touch = touches[i];
          const state = this.touchStates.get(touch.id);
          if (state) {
            state.lastX = touch.x;
            state.lastY = touch.y;

            const normalizedX = Math.max(0, Math.min(1, touch.x / areaWidth));
            const normalizedY = Math.max(0, Math.min(1, touch.y / areaHeight));
            const pressure = touch.pressure ?? eventPressure;
            const contactW = touch.width ?? 0;
            const contactH = touch.height ?? 0;
            const areaMajor = areaWidth > 0 ? Math.min(contactW, areaWidth) / areaWidth : 0;
            const areaMinor = areaHeight > 0 ? Math.min(contactH, areaHeight) / areaHeight : 0;

            this.nativeInput.sendPenEvent(
              TOUCH_EVENT_MOVE, toolType, 0,
              normalizedX, normalizedY, pressure,
              areaMajor, areaMinor, rotation, tilt
            );
          }
        }
        break;

      case TouchType.Up:
      case TouchType.Cancel:
        for (let i = 0; i < changedTouches.length; i++) {
          const touch = changedTouches[i];
          const normalizedX = Math.max(0, Math.min(1, touch.x / areaWidth));
          const normalizedY = Math.max(0, Math.min(1, touch.y / areaHeight));

          const upEventType = event.type === TouchType.Cancel ? TOUCH_EVENT_CANCEL : TOUCH_EVENT_UP;

          this.nativeInput.sendPenEvent(
            upEventType, toolType, 0,
            normalizedX, normalizedY, 0, // pressure = 0 on up
            0, 0, rotation, tilt
          );
          this.touchStates.delete(touch.id);
        }
        break;
    }
  }
  
  private checkForClick(touch: TouchObject, state: TouchState): void {
    const moveDistance = Math.abs(touch.x - state.startX) + Math.abs(touch.y - state.startY);
    
    const touchDuration = Date.now() - state.startTime;
    
    if (moveDistance < this.config.clickThreshold! && touchDuration < this.config.clickTimeThreshold!) {
      this.nativeInput.sendMouseButton(BUTTON_ACTION_PRESS, BUTTON_LEFT);
      setTimeout(() => {
        this.nativeInput.sendMouseButton(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
      }, 50);
    }
  }
  
  sendRightClick(): void {
    this.nativeInput.sendMouseButton(BUTTON_ACTION_PRESS, BUTTON_RIGHT);
    setTimeout(() => {
      this.nativeInput.sendMouseButton(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
    }, 50);
  }
  
  sendLeftClick(): void {
    this.nativeInput.sendMouseButton(BUTTON_ACTION_PRESS, BUTTON_LEFT);
    setTimeout(() => {
      this.nativeInput.sendMouseButton(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
    }, 50);
  }
  
  dispose(): void {
    this.touchStates.clear();
    this.lastForce.clear();
    this.lastSize.clear();
    this.penUnsupported = false;
    this.penFirstEventLogged = false;
  }
}
