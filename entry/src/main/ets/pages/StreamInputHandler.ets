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
import { display, window, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { StreamViewModel } from '../viewmodel/StreamViewModel';
import { GamepadManager } from '../service/GamepadManager';

import {
  MoonBridge,
  BUTTON_ACTION_PRESS,
  BUTTON_ACTION_RELEASE,
  BUTTON_LEFT,
  BUTTON_MIDDLE,
  BUTTON_RIGHT,
  BUTTON_X1,
  BUTTON_X2,
  KEY_ACTION_DOWN,
  KEY_ACTION_UP,
  MODIFIER_SHIFT,
  MODIFIER_CTRL,
  MODIFIER_ALT,
  MODIFIER_META
} from '../service/MoonBridge';
import { KeyboardTranslator } from '../service/KeyboardTranslator';
import { InputInterceptorService, MouseInterceptorService } from '../service/InputInterceptorService';

export class StreamInputHandler {
  private modifierFlags: number = 0;
  private activeVkKeys: Set<number> = new Set<number>();

  private mouseInterceptorActive: boolean = false;

  private viewWidthVp: number = 0;
  private viewHeightVp: number = 0;

  private screenWidthPx: number = 1080;
  private screenHeightPx: number = 2400;

  private lastEscUpTime: number = 0;
  private hasShownEscHint: boolean = false;
  private static readonly ESC_DOUBLE_TAP_INTERVAL: number = 500;
  private static readonly KEYCODE_ESCAPE: number = 2070;
  private menuKeyCode: number = 2070;
  private onShowStreamMenu: (() => void) | null = null;

  private appVolume: number = 1.0;
  private preMuteVolume: number = 1.0;
  private static readonly VOLUME_STEP: number = 0.1;

  private knownGamepadDeviceIds: Set<number> = new Set<number>();

  private viewModel: StreamViewModel | null = null;
  private gamepadManager: GamepadManager | null = null;

  initialize(viewModel: StreamViewModel, gamepadManager: GamepadManager): void {
    this.viewModel = viewModel;
    this.gamepadManager = gamepadManager;
  }

  setOnShowStreamMenu(callback: () => void): void {
    this.onShowStreamMenu = callback;
  }

  setMenuKey(keyName: string): void {
    switch (keyName) {
      case 'F1':
        this.menuKeyCode = 2090;
        break;
      case 'F12':
        this.menuKeyCode = 2101;
        break;
      case '~':
        this.menuKeyCode = 2056;
        break;
      default:
        this.menuKeyCode = StreamInputHandler.KEYCODE_ESCAPE;
        break;
    }
  }

  resetState(): void {
    this.releaseAllKeys();
    this.modifierFlags = 0;
    this.lastEscUpTime = 0;
    this.hasShownEscHint = false;
    this.knownGamepadDeviceIds.clear();
    this.stopMouseInterceptor();
  }

  releaseAllKeys(): void {
    if (this.activeVkKeys.size === 0) return;
    const session = this.viewModel?.getSession();
    if (session) {
      this.activeVkKeys.forEach((vkCode: number) => {
        session.sendKeyboardInput(vkCode, KEY_ACTION_UP, 0);
      });
    }
    this.activeVkKeys.clear();
  }

  /**
   * Start mouse high-speed polling
   */
  startMouseInterceptor(viewWidth: number, viewHeight: number): boolean {
    const mouseInterceptor = MouseInterceptorService.getInstance();

    this.viewWidthVp = viewWidth;
    this.viewHeightVp = viewHeight;

    let screenWidthPx = 1080;
    let screenHeightPx = 2400;
    try {
      const displayInfo = display.getDefaultDisplaySync();
      screenWidthPx = displayInfo.width;
      screenHeightPx = displayInfo.height;
    } catch (_) {}

    this.screenWidthPx = screenWidthPx;
    this.screenHeightPx = screenHeightPx;

    const relativeMode = this.viewModel?.inputSettings?.gameMouseMode ?? false;

    mouseInterceptor.configure(0, 0, screenWidthPx, screenHeightPx,
                                screenWidthPx, screenHeightPx, relativeMode);

    const result = mouseInterceptor.start();
    if (result === 0) {
      this.mouseInterceptorActive = true;
      const modeLabel = relativeMode ? 'relative/game' : 'absolute/desktop';
      console.info(`StreamInputHandler: C++ mouse Monitor started (${screenWidthPx}x${screenHeightPx}px, ${modeLabel})`);

      this.fetchAndUpdateWindowRect();
      return true;
    }

    this.mouseInterceptorActive = false;
    console.info(`StreamInputHandler: C++ Monitor unavailable (${result}), will use keepalive animation for .onMouse`);
    return false;
  }

  updateXComponentActualSize(widthVp: number, heightVp: number): void {
    this.viewWidthVp = widthVp;
    this.viewHeightVp = heightVp;
  }

  updateXComponentScreenPosition(screenX: number, screenY: number): void {
    if (this.mouseInterceptorActive) {
      this.fetchAndUpdateWindowRect();
    }
  }

  private fetchAndUpdateWindowRect(): void {
    try {
      const context = getContext() as common.UIAbilityContext;
      window.getLastWindow(context).then((win: window.Window) => {
        const rect = win.getWindowProperties().windowRect;
        if (rect && this.mouseInterceptorActive) {
          const relativeMode = this.viewModel?.inputSettings?.gameMouseMode ?? false;
          MouseInterceptorService.getInstance().configure(
            rect.left, rect.top, rect.width, rect.height,
            this.screenWidthPx, this.screenHeightPx, relativeMode
          );
          console.info(`StreamInputHandler: Window rect updated (${rect.left},${rect.top},${rect.width}x${rect.height})`);
        }
      }).catch((err: Error) => {
        console.warn(`StreamInputHandler: Failed to get window rect: ${err?.message}`);
      });
    } catch (_) {}
  }

  stopMouseInterceptor(): void {
    if (!this.mouseInterceptorActive) return;
    MouseInterceptorService.getInstance().stop();
    this.mouseInterceptorActive = false;
  }

  isMouseInterceptorActive(): boolean {
    return this.mouseInterceptorActive;
  }

  handleMouseEvent(event: MouseEvent): void {
    if (!this.viewModel?.isConnected) return;

    event.stopPropagation();

    if (this.mouseInterceptorActive) return;

    if (event.action === MouseAction.Move) {
      const relativeMode = this.viewModel?.inputSettings?.gameMouseMode ?? false;
      if (relativeMode) {
        const dx = vp2px(event.rawDeltaX ?? 0) * 1.5;
        const dy = vp2px(event.rawDeltaY ?? 0) * 1.5;
        if (dx !== 0 || dy !== 0) {
          MoonBridge.sendMouseMove(Math.round(dx), Math.round(dy));
        }
      } else {
        MoonBridge.sendMousePosition(
          Math.round(event.x), Math.round(event.y),
          this.viewWidthVp, this.viewHeightVp
        );
      }
    } else if (event.action === MouseAction.Press || event.action === MouseAction.Release) {
      const button = this.mapMouseButton(event.button);
      if (button > 0) {
        const action = event.action === MouseAction.Press
          ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE;
        MoonBridge.sendMouseButton(action, button);
      }
    }
  }

  handleAxisEvent(event: AxisEvent): void {
    if (!this.viewModel?.isConnected) return;

    const vertical = event.getVerticalAxisValue();
    const horizontal = event.getHorizontalAxisValue();

    const scrollStep = (event.scrollStep && event.scrollStep > 0) ? event.scrollStep : 1;

    if (vertical !== 0) {
      const scrollAmount = Math.round(-vertical / scrollStep * 8);
      console.info(`Scroll: vertical=${vertical.toFixed(2)}, scrollStep=${scrollStep}, send=${scrollAmount}`);
      MoonBridge.sendMouseHighResScroll(scrollAmount);
    }

    if (horizontal !== 0) {
      MoonBridge.sendMouseHighResHScroll(Math.round(-horizontal / scrollStep * 8));
    }
  }

  /**
   * Handle key events
   */
  handleKeyEvent(event: KeyEvent): boolean {
    const keyCode = event.keyCode;
    const isGamepadKey = KeyboardTranslator.isGamepadKey(keyCode);

    if (!this.viewModel?.isConnected) {
      return isGamepadKey;
    }

    if (isGamepadKey) {
      const deviceId = event.deviceId ?? 0;
      if (deviceId > 0) {
        this.knownGamepadDeviceIds.add(deviceId);
      }
      this.gamepadManager?.handleKeyEvent(
        deviceId,
        keyCode,
        event.type === KeyType.Down
      );
      return true;
    }

    if (keyCode >= 2012 && keyCode <= 2015 && this.gamepadManager?.hasActiveGcGamepad()) {
      const deviceId = event.deviceId ?? 0;
      if (this.knownGamepadDeviceIds.has(deviceId)) {
        return true;
      }
    }

    if (keyCode === this.menuKeyCode) {
      if (this.checkEscDoubleTap(event.type === KeyType.Down)) {
        return true;
      }
    }

    if (KeyboardTranslator.isKeyboardKey(keyCode)) {
      const vkCode = KeyboardTranslator.translate(keyCode);
      if (vkCode > 0) {
        this.updateModifierFlags(vkCode, event.type === KeyType.Down);
        const session = this.viewModel?.getSession();
        if (session) {
          const keyAction = event.type === KeyType.Down ? KEY_ACTION_DOWN : KEY_ACTION_UP;
          session.sendKeyboardInput(vkCode, keyAction, this.modifierFlags);
          if (event.type === KeyType.Down) {
            this.activeVkKeys.add(vkCode);
          } else {
            this.activeVkKeys.delete(vkCode);
          }
        }
      }
      return true;
    }

    return false;
  }

  startKeyInterceptor(): void {
    const result = InputInterceptorService.getInstance().start((event) => {
      if (!this.viewModel?.isConnected) {
        return;
      }
      const keyCode = event.keyCode;
      // action: 1=KEY_DOWN, 2=KEY_UP
      const isPressed = event.action === 1;

      if ((keyCode >= 2300 && keyCode <= 2320) || keyCode === 110) {
        const deviceId = event.deviceId ?? -1;
        if (deviceId > 0) {
          this.knownGamepadDeviceIds.add(deviceId);
        }
        this.gamepadManager?.handleKeyEvent(0, keyCode, isPressed);
        return;
      }

      if (keyCode >= 2012 && keyCode <= 2015 && this.gamepadManager?.hasActiveGcGamepad()) {
        const deviceId = event.deviceId ?? -1;
        if (deviceId >= 0 && this.knownGamepadDeviceIds.has(deviceId)) {
          return;
        }
      }

      if (keyCode === 16 || keyCode === 17 || keyCode === 22) {
        if (isPressed) {
          this.handleVolumeKey(keyCode);
        }
        return;
      }

      if (keyCode === this.menuKeyCode) {
        if (this.checkEscDoubleTap(isPressed)) {
          return;
        }
      }

      if (KeyboardTranslator.isKeyboardKey(keyCode)) {
        const vkCode = KeyboardTranslator.translate(keyCode);
        if (vkCode > 0) {
          this.updateModifierFlags(vkCode, isPressed);
          const session = this.viewModel?.getSession();
          if (session) {
            const keyAction = isPressed ? KEY_ACTION_DOWN : KEY_ACTION_UP;
            session.sendKeyboardInput(vkCode, keyAction, this.modifierFlags);
          }
        }
        return;
      }

      const SYSTEM_HIJACKED_KEYS: Set<number> = new Set([
        1, 2, 3,                   // Home, Back, Recent
        10, 11, 12, 13             // Media keys
      ]);

      if (SYSTEM_HIJACKED_KEYS.has(keyCode)) {
        const session = this.viewModel?.getSession();
        if (session) {
          const vkCode = this.mapSystemKeyToVK(keyCode);
          if (vkCode > 0) {
            const keyAction = isPressed ? 0x03 : 0x04; // KEY_DOWN : KEY_UP
            session.sendKeyboardInput(vkCode, keyAction, this.modifierFlags);
          }
        }
      }
    });
    if (result !== 0) {
      console.warn(`StreamPage: Key interceptor start failed (${result}), gamepad Home key may be hijacked by system`);
      promptAction.showToast({
        message: 'Key anti-hijack failed: Bluetooth gamepad Home key may cause exit (requires system-level signature)',
        duration: 3500
      });
    }
  }

  private mapSystemKeyToVK(keyCode: number): number {
    switch (keyCode) {
      case 1: return 0;
      case 2: return 0x1B; // Back → VK_ESCAPE
      case 3: return 0;
      case 10: return 0xB3; // Media Play/Pause → VK_MEDIA_PLAY_PAUSE
      case 11: return 0xB2; // Media Stop → VK_MEDIA_STOP
      case 12: return 0xB0; // Media Next → VK_MEDIA_NEXT_TRACK
      case 13: return 0xB1; // Media Previous → VK_MEDIA_PREV_TRACK
      default: return 0;
    }
  }

  private mapMouseButton(button: MouseButton): number {
    switch (button) {
      case MouseButton.Left: return BUTTON_LEFT;       // 0x01
      case MouseButton.Middle: return BUTTON_MIDDLE;   // 0x02
      case MouseButton.Right: return BUTTON_RIGHT;     // 0x03
      case MouseButton.Back:
        return this.viewModel?.inputSettings?.mouseNavButtons ? BUTTON_X1 : 0;
      case MouseButton.Forward:
        return this.viewModel?.inputSettings?.mouseNavButtons ? BUTTON_X2 : 0;
      default: return 0;
    }
  }

  /**
   * Update modifier key flags
   */
  private updateModifierFlags(vkCode: number, isDown: boolean): void {
    let mask = 0;
    switch (vkCode) {
      case 0xA0: // VK_LSHIFT
      case 0xA1: // VK_RSHIFT
        mask = MODIFIER_SHIFT;
        break;
      case 0xA2: // VK_LCONTROL
      case 0xA3: // VK_RCONTROL
        mask = MODIFIER_CTRL;
        break;
      case 0xA4: // VK_LMENU (Alt Left)
      case 0xA5: // VK_RMENU (Alt Right)
        mask = MODIFIER_ALT;
        break;
      case 0x5B: // VK_LWIN
      case 0x5C: // VK_RWIN
        mask = MODIFIER_META;
        break;
    }
    if (mask !== 0) {
      if (isDown) {
        this.modifierFlags |= mask;
      } else {
        this.modifierFlags &= ~mask;
      }
    }
  }

  /**
   * Check for ESC double tap to show menu
   */
  private checkEscDoubleTap(isDown: boolean): boolean {
    if (isDown) {
      if (this.hasShownEscHint && Date.now() - this.lastEscUpTime <= StreamInputHandler.ESC_DOUBLE_TAP_INTERVAL) {
        return true;
      }
      return false;
    }

    const now = Date.now();
    if (this.hasShownEscHint && now - this.lastEscUpTime <= StreamInputHandler.ESC_DOUBLE_TAP_INTERVAL) {
      this.lastEscUpTime = 0;
      this.hasShownEscHint = false;
      this.releaseAllKeys();
      this.onShowStreamMenu?.();
      return true;
    }

    this.lastEscUpTime = now;
    this.hasShownEscHint = true;
    const keyLabel = this.getMenuKeyLabel();
    promptAction.showToast({ message: `Press ${keyLabel} again to open stream menu`, duration: 1500 });
    return false;
  }

  private getMenuKeyLabel(): string {
    switch (this.menuKeyCode) {
      case 2090: return 'F1';
      case 2101: return 'F12';
      case 2056: return '~';
      default: return 'ESC';
    }
  }

  private handleVolumeKey(keyCode: number): void {
    const session = this.viewModel?.getSession();
    if (!session) {
      return;
    }

    if (keyCode === 16) {
      this.appVolume = Math.min(1.0, this.appVolume + StreamInputHandler.VOLUME_STEP);
    } else if (keyCode === 17) {
      this.appVolume = Math.max(0.0, this.appVolume - StreamInputHandler.VOLUME_STEP);
    } else if (keyCode === 22) {
      if (this.appVolume > 0) {
        this.preMuteVolume = this.appVolume;
        this.appVolume = 0.0;
      } else {
        this.appVolume = this.preMuteVolume > 0 ? this.preMuteVolume : 1.0;
      }
    }

    this.appVolume = Math.round(this.appVolume * 10) / 10;
    session.setAudioVolume(this.appVolume);

    const percent = Math.round(this.appVolume * 100);
    const icon = this.appVolume === 0 ? '🔇' : (this.appVolume < 0.5 ? '🔉' : '🔊');
    promptAction.showToast({
      message: `${icon} Volume ${percent}%`,
      duration: 1000
    });
  }
}
