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

import { GamepadState, MoonlightButton } from './GamepadTypes';

/**
const MOUSE_EMULATION_REPORT_PERIOD = 50;

export interface MouseEmulationCallback {
  sendMouseMove(deltaX: number, deltaY: number): void;
  sendMouseButtonDown(button: number): void;
  sendMouseButtonUp(button: number): void;
  sendMouseHighResScroll(scrollAmount: number): void;
  sendMouseHighResHScroll(scrollAmount: number): void;
}

/**
class StickMovement {
  x: number = 0;
  y: number = 0;
  mag: number = 0;

  constructor(x: number, y: number, mag: number) {
    this.x = x;
    this.y = y;
    this.mag = mag;
  }
}

/**
 * 
 */
export class MouseEmulationService {
  /**
  private active = false;
  /**
  private callback: MouseEmulationCallback | null = null;
  /**
  private timerId: number = -1;
  /**
  private lastButtons: number = 0;
  /**
  private leftStickX: number = 0;
  private leftStickY: number = 0;
  /**
  private rightStickX: number = 0;
  private rightStickY: number = 0;

  constructor() {
  }

  setCallback(callback: MouseEmulationCallback | null): void {
    this.callback = callback;
  }

  toggle(): void {
    if (this.active) {
      this.stop();
    } else {
      this.start();
    }
  }

  isActive(): boolean {
    return this.active;
  }

  /**
   * 
   */
  intercept(state: GamepadState, onSendZeroState: () => void): boolean {
    if (!this.active) {
      return false;
    }

    this.leftStickX = state.leftStickX;
    this.leftStickY = state.leftStickY;
    this.rightStickX = state.rightStickX;
    this.rightStickY = state.rightStickY;

    this.handleButtons(state.buttons);

    onSendZeroState();

    return true;
  }

  cleanup(): void {
    this.stop();
    this.callback = null;
  }

  private start(): void {
    this.active = true;
    this.lastButtons = 0;
    this.leftStickX = 0;
    this.leftStickY = 0;
    this.rightStickX = 0;
    this.rightStickY = 0;

    this.timerId = setInterval(() => {
      this.tick();
    }, MOUSE_EMULATION_REPORT_PERIOD);

    console.info('[MOUSE-EMU] 鼠标模拟模式已启动');
  }

  private stop(): void {
    this.active = false;
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.lastButtons = 0;
    console.info('[MOUSE-EMU] 鼠标模拟模式已停止');
  }

  private convertStickToPixelMovement(stickX: number, stickY: number): StickMovement {
    let nx = stickX / 32766.0;
    let ny = stickY / 32766.0;
    nx *= 4;
    ny *= 4;
    const mag = Math.sqrt(nx * nx + ny * ny);
    if (mag > 0) {
      const accel = mag * mag;
      const scale = accel / mag;
      nx *= scale;
      ny *= scale;
    }
    return new StickMovement(nx, ny, mag);
  }

  private tick(): void {
    if (!this.active || !this.callback) {
      return;
    }

    const move = this.convertStickToPixelMovement(this.leftStickX, this.leftStickY);
    if (move.mag >= 1) {
      this.callback.sendMouseMove(
        Math.round(move.x), Math.round(-move.y)
      );
    }

    const scroll = this.convertStickToPixelMovement(this.rightStickX, this.rightStickY);
    if (scroll.mag >= 1) {
      this.callback.sendMouseHighResScroll(Math.round(scroll.y));
      this.callback.sendMouseHighResHScroll(Math.round(scroll.x));
    }
  }

  private handleButtons(buttons: number): void {
    if (!this.callback) return;

    const changed = buttons ^ this.lastButtons;
    this.lastButtons = buttons;

    if (changed & MoonlightButton.A) {
      if (buttons & MoonlightButton.A) {
        this.callback.sendMouseButtonDown(0x01); // BUTTON_LEFT
      } else {
        this.callback.sendMouseButtonUp(0x01);
      }
    }

    if (changed & MoonlightButton.B) {
      if (buttons & MoonlightButton.B) {
        this.callback.sendMouseButtonDown(0x03); // BUTTON_RIGHT
      } else {
        this.callback.sendMouseButtonUp(0x03);
      }
    }

    if ((changed & MoonlightButton.UP) && (buttons & MoonlightButton.UP)) {
      this.callback.sendMouseHighResScroll(1);
    }
    if ((changed & MoonlightButton.DOWN) && (buttons & MoonlightButton.DOWN)) {
      this.callback.sendMouseHighResScroll(-1);
    }
    if ((changed & MoonlightButton.RIGHT) && (buttons & MoonlightButton.RIGHT)) {
      this.callback.sendMouseHighResHScroll(1);
    }
    if ((changed & MoonlightButton.LEFT) && (buttons & MoonlightButton.LEFT)) {
      this.callback.sendMouseHighResHScroll(-1);
    }
  }
}
