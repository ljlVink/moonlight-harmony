/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */



import { promptAction } from '@kit.ArkUI';
import { fileIo, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { BUTTON_ACTION_PRESS, BUTTON_ACTION_RELEASE, MoonBridge } from './MoonBridge';
import { CustomKeyStore } from './CustomKeyStore';
import {
  ComboAction,
  GamepadButton,
  GamepadButtonAction,
  GamepadStickAction,
  GamepadTriggerAction,
  KeyAction,
  KeyboardAction,
  MouseButtonAction,
  MouseScrollAction,
  sendShortcutKeys,
  ShortcutAction,
  SpecialAction
} from './CustomKeyTypes';


export interface CustomKeyManagerHost {

  getSession(): SessionLike | null;

  toggleVirtualKeyboard(): void;

  showIME(): void;

  openGameMenu(): void;

  toggleMouseMode(): void;

  switchProfile(): void;

  toggleEditMode(): void;

  hideCustomKeys(): void;

  onCustomKeysImported(): void;
}


export interface SessionLike {
  sendKeyboardInput(vk: number, flags: number): void;

  sendKeys(keyCodes: number[]): void;

  sendVirtualControllerInput(
    buttonFlags: number,
    leftTrigger: number,
    rightTrigger: number,
    leftStickX: number,
    leftStickY: number,
    rightStickX: number,
    rightStickY: number,
  ): void;
}


// Manager


export class CustomKeyManager {
  private host: CustomKeyManagerHost;
  private gamepadInputMap: number = 0;
  private gamepadLeftTrigger: number = 0;
  private gamepadRightTrigger: number = 0;
  private static readonly STICK_MAX = 32767;
  private leftStickX: number = 0;
  private leftStickY: number = 0;
  private rightStickX: number = 0;
  private rightStickY: number = 0;

  constructor(host: CustomKeyManagerHost) {
    this.host = host;
  }

  async init(): Promise<void> {
    await CustomKeyStore.init();
  }

  reset(): void {
    if (this.gamepadInputMap !== 0 || this.gamepadLeftTrigger !== 0 || this.gamepadRightTrigger !== 0 ||
        this.leftStickX !== 0 || this.leftStickY !== 0 || this.rightStickX !== 0 || this.rightStickY !== 0) {
      this.gamepadInputMap = 0;
      this.gamepadLeftTrigger = 0;
      this.gamepadRightTrigger = 0;
      this.leftStickX = 0;
      this.leftStickY = 0;
      this.rightStickX = 0;
      this.rightStickY = 0;
      this.sendGamepadState();
    }
  }

  handleAction(action: KeyAction, isDown: boolean): void {
    const session = this.host.getSession();
    if (!session) return;

    switch (action.type) {
      case 'keyboard': {
        const kbAction = action as KeyboardAction;
        session.sendKeyboardInput(kbAction.vk, isDown ? 0x03 : 0x04);
        break;
      }
      case 'mouse': {
        const mouseAction = action as MouseButtonAction;
        MoonBridge.sendMouseButton(
          isDown ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE,
          mouseAction.button
        );
        break;
      }
      case 'mouseScroll': {
        const scrollAction = action as MouseScrollAction;
        if (isDown) {
          MoonBridge.sendMouseHighResScroll(scrollAction.direction > 0 ? 120 : -120);
        }
        break;
      }
      case 'gamepadButton': {
        const gpAction = action as GamepadButtonAction;
        const mask: number = gpAction.mask;
        if (isDown) {
          this.gamepadInputMap |= mask;
        } else {
          this.gamepadInputMap &= ~mask;
        }
        this.sendGamepadState();
        break;
      }
      case 'gamepadTrigger': {
        const trigAction = action as GamepadTriggerAction;
        if (trigAction.trigger === 'left') {
          this.gamepadLeftTrigger = isDown ? 0xFF : 0;
        } else {
          this.gamepadRightTrigger = isDown ? 0xFF : 0;
        }
        this.sendGamepadState();
        break;
      }
      case 'gamepadStick': {
        const stickAction = action as GamepadStickAction;
        const posMax: number = CustomKeyManager.STICK_MAX;
        const negMax: number = 0 - posMax;
        if (stickAction.stick === 'left') {
          if (stickAction.direction === 'up') this.leftStickY = isDown ? negMax : 0;
          else if (stickAction.direction === 'down') this.leftStickY = isDown ? posMax : 0;
          else if (stickAction.direction === 'left') this.leftStickX = isDown ? negMax : 0;
          else if (stickAction.direction === 'right') this.leftStickX = isDown ? posMax : 0;
        } else {
          if (stickAction.direction === 'up') this.rightStickY = isDown ? negMax : 0;
          else if (stickAction.direction === 'down') this.rightStickY = isDown ? posMax : 0;
          else if (stickAction.direction === 'left') this.rightStickX = isDown ? negMax : 0;
          else if (stickAction.direction === 'right') this.rightStickX = isDown ? posMax : 0;
        }
        this.sendGamepadState();
        break;
      }
      case 'combo': {
        const comboAction = action as ComboAction;
        for (const subAction of comboAction.actions) {
          this.handleAction(subAction, isDown);
        }
        break;
      }
      case 'shortcut': {
        if (isDown) {
          const scAction = action as ShortcutAction;
          this.executeShortcut(scAction, session);
        }
        break;
      }
      case 'special': {
        const specialAction = action as SpecialAction;
        if (isDown) {
          this.handleSpecialAction(specialAction.id);
        }
        break;
      }
    }
  }

  private sendGamepadState(): void {
    const session = this.host.getSession();
    if (!session) return;
    session.sendVirtualControllerInput(
      this.gamepadInputMap,
      this.gamepadLeftTrigger,
      this.gamepadRightTrigger,
      this.leftStickX,
      this.leftStickY,
      this.rightStickX,
      this.rightStickY
    );
  }

  handleAnalogStickMovement(stick: string, x: number, y: number): void {
    const axisX = Math.round(x * 0x7FFE);
    const negY: number = 0 - y;
    const axisY = Math.round(negY * 0x7FFE);
    if (stick === 'left') {
      this.leftStickX = axisX;
      this.leftStickY = axisY;
    } else {
      this.rightStickX = axisX;
      this.rightStickY = axisY;
    }
    this.sendGamepadState();
  }


  handleAnalogStickClick(stick: string): void {
    const mask: number = stick === 'left' ? GamepadButton.LS : GamepadButton.RS;
    this.gamepadInputMap |= mask;
    this.sendGamepadState();
    setTimeout(() => {
      this.gamepadInputMap &= ~mask;
      this.sendGamepadState();
    }, 50);
  }

  handleDPadDirectionChange(direction: number): void {
    const dpadMask: number = GamepadButton.DPAD_MASK;
    this.gamepadInputMap = (this.gamepadInputMap & (~dpadMask)) | (direction & dpadMask);
    this.sendGamepadState();
  }

  private executeShortcut(action: ShortcutAction, session: SessionLike): void {
    sendShortcutKeys((keys: number[]) => session.sendKeys(keys), action.keys, action.keySequence);
  }

  handleSpecialAction(actionId: string): void {
    switch (actionId) {
      case 'toggleKeyboard':
        this.host.toggleVirtualKeyboard();
        break;
      case 'toggleIME':
        this.host.showIME();
        break;
      case 'toggleMouseMode':
        this.host.toggleMouseMode();
        break;
      case 'switchProfile':
        this.host.switchProfile();
        break;
      case 'openGameMenu':
        this.host.openGameMenu();
        break;
      case 'editMode':
        this.host.toggleEditMode();
        break;
      case 'hideCustomKeys':
        this.host.hideCustomKeys();
        break;
      case 'none':
      default:
        break;
    }
  }

  async exportProfile(): Promise<void> {
    try {
      const json = await CustomKeyStore.exportProfile();
      const profileName = await CustomKeyStore.getActiveProfileName();

      const documentPicker = new picker.DocumentViewPicker();
      const saveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = [`moonlight-keys-${profileName}.json`];
      saveOptions.fileSuffixChoices = ['.json'];
      const uris = await documentPicker.save(saveOptions);

      if (uris && uris.length > 0) {
        const file = fileIo.openSync(uris[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
        fileIo.writeSync(file.fd, json);
        fileIo.closeSync(file);
        promptAction.showToast({ message: `配置 "${profileName}" 已导出`, duration: 2000 });
      }
    } catch (e) {
      console.error('[CustomKeyManager] 导出失败:', JSON.stringify(e));
      promptAction.showToast({ message: '导出失败', duration: 2000 });
    }
  }

  async importProfile(): Promise<boolean> {
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const selectOptions = new picker.DocumentSelectOptions();
      selectOptions.maxSelectNumber = 1;
      selectOptions.fileSuffixFilters = ['.json'];
      const uris = await documentPicker.select(selectOptions);

      if (uris && uris.length > 0) {
        const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
        const stat = fileIo.statSync(file.fd);
        const buf = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buf);
        fileIo.closeSync(file);

        const json = new util.TextDecoder('utf-8').decodeToString(new Uint8Array(buf));
        const success = await CustomKeyStore.importProfile(json);

        if (success) {
          const name = await CustomKeyStore.getActiveProfileName();
          promptAction.showToast({ message: `配置 "${name}" 已导入`, duration: 2000 });
          this.host.onCustomKeysImported();
          return true;
        } else {
          promptAction.showToast({ message: '导入失败：配置文件格式无效', duration: 2000 });
        }
      }
    } catch (e) {
      console.error('[CustomKeyManager] 导入失败:', JSON.stringify(e));
      promptAction.showToast({ message: '导入失败', duration: 2000 });
    }
    return false;
  }
}
