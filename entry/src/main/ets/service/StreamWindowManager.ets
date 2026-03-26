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
import { window, display } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

export interface DisplaySize {
  width: number;
  height: number;
}

export interface XComponentSize {
  width: Length;
  height: Length;
}

export class StreamWindowManager {
  private context: common.UIAbilityContext;
  private streamWidth: number = 1920;
  private streamHeight: number = 1080;
  private screenWidth: number = 1920;
  private screenHeight: number = 1080;
  /**
  private _isFullscreen: boolean = true;
  /**
  private onWindowSizeChanged: (() => void) | null = null;
  /**
  private windowSizeChangeHandler: ((size: window.Size) => void) | null = null;

  /**
  get isFullscreen(): boolean {
    return this._isFullscreen;
  }
  
  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  setOnWindowSizeChanged(callback: (() => void) | null): void {
    this.onWindowSizeChanged = callback;
  }
  
  setStreamResolution(width: number, height: number): void {
    this.streamWidth = width;
    this.streamHeight = height;
  }
  
  getScreenSize(): DisplaySize {
    return {
      width: this.screenWidth,
      height: this.screenHeight
    };
  }
  
  async initScreenSize(): Promise<DisplaySize> {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      this.screenWidth = displayInfo.width / displayInfo.densityPixels;
      this.screenHeight = displayInfo.height / displayInfo.densityPixels;
      
      console.info(`StreamWindowManager: 屏幕尺寸 ${this.screenWidth}x${this.screenHeight}`);
    } catch (err) {
      console.error('获取屏幕尺寸失败:', err);
    }
    
    return this.getScreenSize();
  }

  async configureWindow(): Promise<void> {
    try {
      const win = await window.getLastWindow(this.context);
      win.setWindowKeepScreenOn(true);
      await this.enterImmersiveFullscreen(win);

      if (this.streamWidth > this.streamHeight) {
        try { await win.enableLandscapeMultiWindow(); } catch (_e) {}
      }

      this._isFullscreen = true;
      console.info('StreamWindowManager: 已配置窗口基本设置（全屏+沉浸式+装饰栏隐藏）');
    } catch (err) {
      console.error('配置窗口失败:', err);
    }
  }
  
  async restoreWindow(): Promise<void> {
    try {
      const win = await window.getLastWindow(this.context);
      this.unregisterWindowSizeListener(win);
      win.setWindowKeepScreenOn(false);
      await this.exitImmersiveFullscreen(win);

      try { await win.setWindowLayoutFullScreen(true); } catch (_e) {}

      try { await win.disableLandscapeMultiWindow(); } catch (_e) {}
      await win.setPreferredOrientation(window.Orientation.UNSPECIFIED);
      win.setWindowBrightness(-1);

      this._isFullscreen = false;
      console.info('StreamWindowManager: 已恢复窗口设置');
    } catch (err) {
      console.error('恢复窗口设置失败:', err);
    }
  }

  /**
   *
   */
  async toggleWindowMode(): Promise<void> {
    try {
      const win = await window.getLastWindow(this.context);

      if (this._isFullscreen) {
        await this.exitImmersiveFullscreen(win);
        try {
          await win.recover();
        } catch (_e) {
          console.info('StreamWindowManager: recover() 不可用，保持最大化');
        }
        this._isFullscreen = false;
        this.registerWindowSizeListener(win);
        console.info('StreamWindowManager: 已切换到窗口模式');
      } else {
        this.unregisterWindowSizeListener(win);
        await this.enterImmersiveFullscreen(win);
        this._isFullscreen = true;
        console.info('StreamWindowManager: 已切换到全屏模式');
      }
    } catch (err) {
      console.error('StreamWindowManager: 窗口模式切换失败:', err);
    }
  }

  private registerWindowSizeListener(win: window.Window): void {
    this.unregisterWindowSizeListener(win);
    let debounceTimer: number = -1;
    this.windowSizeChangeHandler = (_size: window.Size) => {
      if (debounceTimer !== -1) {
        clearTimeout(debounceTimer);
      }
      debounceTimer = Number(setTimeout(() => {
        debounceTimer = -1;
        this.onWindowSizeChanged?.();
      }, 200));
    };
    try {
      win.on('windowSizeChange', this.windowSizeChangeHandler);
    } catch (_e) {}
  }

  private unregisterWindowSizeListener(win: window.Window): void {
    if (this.windowSizeChangeHandler) {
      try {
        win.off('windowSizeChange', this.windowSizeChangeHandler);
      } catch (_e) {}
      this.windowSizeChangeHandler = null;
    }
  }

  private async enterImmersiveFullscreen(win: window.Window): Promise<void> {
    this.setDecorVisible(win, false);

    await this.maximizeImmersive(win);

    try { await win.setWindowLayoutFullScreen(true); } catch (_e) {}

    await this.setSystemBarsVisible(win, false);

    try { win.setImmersiveModeEnabledState(true); } catch (_e) {}
  }

  private async exitImmersiveFullscreen(win: window.Window): Promise<void> {
    try { win.setImmersiveModeEnabledState(false); } catch (_e) {}

    await this.setSystemBarsVisible(win, true);

    this.setDecorVisible(win, true);

    try {
      await win.maximize(window.MaximizePresentation.EXIT_IMMERSIVE);
    } catch (_e) {
      try { win.setTitleAndDockHoverShown(true); } catch (_e2) {}
    }
  }

  /**
   *
   * 2. ENTER_IMMERSIVE (API 12+) + setTitleAndDockHoverShown(false)
   * 3. maximize() + setTitleAndDockHoverShown(false)
   */
  private async maximizeImmersive(win: window.Window): Promise<void> {
    try {
      await win.maximize(window.MaximizePresentation.ENTER_IMMERSIVE_DISABLE_TITLE_AND_DOCK_HOVER);
    } catch (_e) {
      try {
        await win.maximize(window.MaximizePresentation.ENTER_IMMERSIVE);
      } catch (_e2) {
        try { await win.maximize(); } catch (_e3) {}
      }
      try { win.setTitleAndDockHoverShown(false); } catch (_e2) {}
    }
  }

  private async setSystemBarsVisible(win: window.Window, visible: boolean): Promise<void> {
    try {
      await win.setSpecificSystemBarEnabled('status', visible);
      await win.setSpecificSystemBarEnabled('navigation', visible);
      if (!visible) {
        await win.setSpecificSystemBarEnabled('navigationIndicator', false);
      }
    } catch (_e) {
      try {
        win.setWindowSystemBarEnable(visible ? ['status', 'navigation'] : []);
      } catch (_e2) {}
    }
  }

  private setDecorVisible(win: window.Window, visible: boolean): void {
    try { win.setWindowDecorVisible(visible); } catch (_e) {}
  }

  async configureOrientation(): Promise<void> {
    try {
      const win = await window.getLastWindow(this.context);

      if (this.streamWidth > this.streamHeight) {
        await win.setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE);
        console.info(`StreamWindowManager: 设置横屏模式 (${this.streamWidth}x${this.streamHeight})`);
      } else if (this.streamHeight > this.streamWidth) {
        await win.setPreferredOrientation(window.Orientation.AUTO_ROTATION_PORTRAIT);
        console.info(`StreamWindowManager: 设置竖屏模式 (${this.streamWidth}x${this.streamHeight})`);
      } else {
        await win.setPreferredOrientation(window.Orientation.AUTO_ROTATION);
        console.info(`StreamWindowManager: 设置自动旋转模式 (${this.streamWidth}x${this.streamHeight})`);
      }
    } catch (err) {
      console.error('设置屏幕方向失败:', err);
    }
  }

  async updateScreenSize(): Promise<DisplaySize> {
    try {
      await new Promise<void>((resolve) => setTimeout(resolve, 100));
      const displayInfo = display.getDefaultDisplaySync();

      if (this.streamWidth > this.streamHeight) {
        this.screenWidth = Math.max(displayInfo.width, displayInfo.height) / displayInfo.densityPixels;
        this.screenHeight = Math.min(displayInfo.width, displayInfo.height) / displayInfo.densityPixels;
      } else {
        this.screenWidth = Math.min(displayInfo.width, displayInfo.height) / displayInfo.densityPixels;
        this.screenHeight = Math.max(displayInfo.width, displayInfo.height) / displayInfo.densityPixels;
      }

      console.info(`StreamWindowManager: 更新屏幕尺寸 ${this.screenWidth}x${this.screenHeight}`);
    } catch (err) {
      console.error('更新屏幕尺寸失败:', err);
    }
    return this.getScreenSize();
  }

  /**
   *
   */
  async setHdrBrightness(enableHdr: boolean, hdrHighBrightness: boolean): Promise<void> {
    try {
      const win = await window.getLastWindow(this.context);
      if (enableHdr && hdrHighBrightness) {
        win.setWindowBrightness(1.0);
        console.info('StreamWindowManager: HDR 高亮度模式已启用 (brightness=1.0)');
      } else {
        win.setWindowBrightness(-1);
        console.info('StreamWindowManager: 使用系统默认屏幕亮度');
      }
    } catch (err) {
      console.warn('StreamWindowManager: 设置 HDR 亮度失败:', JSON.stringify(err));
    }
  }
  
  /**
   *
   *
   */
  calculateXComponentSize(stretchVideo: boolean = false): XComponentSize {
    if (stretchVideo) {
      return { width: '100%', height: '100%' };
    }

    try {
      const displayInfo = display.getDefaultDisplaySync();
      const screenWidth = displayInfo.width;
      const screenHeight = displayInfo.height;
      const density = displayInfo.densityPixels;
      const videoAspectRatio = this.streamWidth / this.streamHeight;
      const screenAspectRatio = screenWidth / screenHeight;

      let measuredWidth: number;
      let measuredHeight: number;

      if (screenAspectRatio > videoAspectRatio) {
        measuredHeight = screenHeight;
        measuredWidth = Math.floor(measuredHeight * videoAspectRatio);
      } else {
        measuredWidth = screenWidth;
        measuredHeight = Math.floor(measuredWidth / videoAspectRatio);
      }

      const widthVp = measuredWidth / density;
      const heightVp = measuredHeight / density;

      console.info(`StreamWindowManager: 视频尺寸计算 - 屏幕=${screenWidth}x${screenHeight}px, ` +
        `视频=${this.streamWidth}x${this.streamHeight}, XComponent=${widthVp.toFixed(1)}x${heightVp.toFixed(1)}vp`);

      return { width: widthVp, height: heightVp };
    } catch (err) {
      console.error('计算视频尺寸失败:', err);
      return { width: '100%', height: '100%' };
    }
  }

  /**
   * 
   */
  async initialize(): Promise<DisplaySize> {
    await this.initScreenSize();
    await this.configureWindow();
    await this.configureOrientation();
    const size = await this.updateScreenSize();
    return size;
  }
}
