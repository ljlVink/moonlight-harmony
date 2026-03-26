/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import nativeLib from "libmoonlight_nativelib.so";

export interface InterceptedKeyEvent {
  keyCode: number;
  action: number; // 1 = KEY_DOWN, 2 = KEY_UP
  actionTime: number;
  deviceId: number;
}

export type KeyInterceptCallback = (event: InterceptedKeyEvent) => void;

interface InputInterceptorNative {
  addKeyInterceptor(callback: (event: InterceptedKeyEvent) => void): number;
  removeKeyInterceptor(): number;
  isKeyInterceptorActive(): boolean;
  isInjectApiAvailable(): boolean;
}

interface MouseInterceptorNative {
  addMouseInterceptor(): number;
  removeMouseInterceptor(): number;
  configureMouseInterceptor(
    windowX: number,
    windowY: number,
    windowWidth: number,
    windowHeight: number,
    screenWidth: number,
    screenHeight: number,
    relativeMode: boolean,
  ): void;
  isMouseInterceptorActive(): boolean;
}

export class InputInterceptorService {
  private static instance: InputInterceptorService;
  private native: InputInterceptorNative;
  private active: boolean = false;

  private constructor() {
    this.native = (nativeLib as Record<string, Object>)[
      "InputInterceptor"
    ] as InputInterceptorNative;
  }

  static getInstance(): InputInterceptorService {
    if (!InputInterceptorService.instance) {
      InputInterceptorService.instance = new InputInterceptorService();
    }
    return InputInterceptorService.instance;
  }

  start(callback: KeyInterceptCallback): number {
    if (this.active) {
      this.stop();
    }

    if (!this.native) {
      console.warn("InputInterceptor: Native 模块不可用");
      return -1;
    }

    const result = this.native.addKeyInterceptor(callback);
    if (result === 0) {
      this.active = true;
      console.info("InputInterceptor: 按键拦截器已启动");
    } else {
      console.warn(`InputInterceptor: 启动失败，错误码=${result}`);
    }
    return result;
  }

  stop(): void {
    if (!this.active || !this.native) {
      return;
    }

    this.native.removeKeyInterceptor();
    this.active = false;
    console.info("InputInterceptor: 按键拦截器已停止");
  }

  isActive(): boolean {
    if (this.native) {
      return this.native.isKeyInterceptorActive();
    }
    return false;
  }

  isInjectApiAvailable(): boolean {
    if (this.native) {
      return this.native.isInjectApiAvailable();
    }
    return false;
  }
}

/**
 *
 *
 */
export class MouseInterceptorService {
  private static instance: MouseInterceptorService;
  private native: MouseInterceptorNative | null;
  private active: boolean = false;

  private constructor() {
    this.native = (nativeLib as Record<string, Object>)[
      "MouseInterceptor"
    ] as MouseInterceptorNative;
  }

  static getInstance(): MouseInterceptorService {
    if (!MouseInterceptorService.instance) {
      MouseInterceptorService.instance = new MouseInterceptorService();
    }
    return MouseInterceptorService.instance;
  }

  configure(
    windowX: number,
    windowY: number,
    windowWidth: number,
    windowHeight: number,
    screenWidth: number,
    screenHeight: number,
    relativeMode: boolean,
  ): void {
    if (!this.native) return;
    this.native.configureMouseInterceptor(
      windowX,
      windowY,
      windowWidth,
      windowHeight,
      screenWidth,
      screenHeight,
      relativeMode,
    );
  }

  start(): number {
    if (this.active) {
      this.stop();
    }
    if (!this.native) {
      console.warn("MouseInterceptor: Native 模块不可用");
      return -1;
    }

    const result = this.native.addMouseInterceptor();
    if (result === 0) {
      this.active = true;
      console.info("MouseInterceptor: 鼠标拦截器已启动（全速轮询）");
    } else {
      console.warn(`MouseInterceptor: 启动失败，错误码=${result}`);
    }
    return result;
  }

  stop(): void {
    if (!this.active || !this.native) return;
    this.native.removeMouseInterceptor();
    this.active = false;
    console.info("MouseInterceptor: 鼠标拦截器已停止");
  }

  isActive(): boolean {
    if (this.native) {
      return this.native.isMouseInterceptorActive();
    }
    return false;
  }
}
