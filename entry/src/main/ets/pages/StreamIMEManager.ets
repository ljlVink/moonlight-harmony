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
 * StreamPage IME keyboard manager
 */
import { window } from '@kit.ArkUI';
import { inputMethod } from '@kit.IMEKit';
import { StreamViewModel } from '../viewmodel/StreamViewModel';

/**
 * IME callbacks interface for StreamPage
 */
export interface IMECallbacks {
  onKeyboardVisibilityChanged: (visible: boolean) => void;
  onKeyboardHeightChanged: (height: number) => void;
}

export class StreamIMEManager {
  private imeController: inputMethod.InputMethodController | null = null;
  private imeReadyTime: number = 0;

  private viewModel: StreamViewModel | null = null;
  private callbacks: IMECallbacks | null = null;
  private context: Context;

  constructor(context: Context) {
    this.context = context;
  }

  /**
   * Initialize dependencies
   */
  initialize(viewModel: StreamViewModel, callbacks: IMECallbacks): void {
    this.viewModel = viewModel;
    this.callbacks = callbacks;
  }

  /**
   * IME ready timestamp
   */
  get readyTime(): number {
    return this.imeReadyTime;
  }

  /**
   * Whether IME is currently visible
   */
  get isVisible(): boolean {
    return this.imeController !== null;
  }

  /**
   * Show system keyboard using InputMethod API (no TextInput component needed)
   */
  async show(): Promise<void> {
    const session = this.viewModel?.getSession();
    if (!session) return;

    try {
      const win = await window.getLastWindow(this.context);
      win.on('keyboardHeightChange', (height: number) => {
        this.callbacks?.onKeyboardHeightChanged(px2vp(height));
      });

      const controller = inputMethod.getController();
      this.imeController = controller;

      const textConfig: inputMethod.TextConfig = {
        inputAttribute: {
          textInputType: inputMethod.TextInputType.TEXT,
          enterKeyType: inputMethod.EnterKeyType.SEND
        }
      };
      await controller.attach(true, textConfig);
      
      controller.on('insertText', (text: string) => {
        session.sendUtf8Text(text);
      });

      controller.on('deleteLeft', (length: number) => {
        for (let i = 0; i < length; i++) {
          session.sendKeyboardInput(0x08, 0x03); // VK_BACK DOWN
          session.sendKeyboardInput(0x08, 0x04); // VK_BACK UP
        }
      });

      controller.on('sendFunctionKey', (key: inputMethod.FunctionKey) => {
        session.sendKeyboardInput(0x0D, 0x03); // VK_RETURN DOWN
        session.sendKeyboardInput(0x0D, 0x04); // VK_RETURN UP
      });

      controller.on('sendKeyboardStatus', (status: inputMethod.KeyboardStatus) => {
        if (status === inputMethod.KeyboardStatus.HIDE && Date.now() - this.imeReadyTime > 300) {
          this.hide();
        }
      });

      this.callbacks?.onKeyboardVisibilityChanged(true);
      this.imeReadyTime = Date.now();
    } catch (err) {
      console.error(`[StreamPage] Failed to show IME: ${JSON.stringify(err)}`);
    }
  }

  /**
   * Hide system keyboard and cleanup callbacks
   */
  hide(): void {
    try {
      if (this.imeController) {
        this.imeController.off('insertText');
        this.imeController.off('deleteLeft');
        this.imeController.off('sendFunctionKey');
        this.imeController.off('sendKeyboardStatus');
        this.imeController.detach();
        this.imeController = null;
      }
      window.getLastWindow(this.context).then((win) => {
        win.off('keyboardHeightChange');
      });
    } catch (err) {
      console.error(`[StreamPage] Failed to hide IME: ${JSON.stringify(err)}`);
    }
    this.callbacks?.onKeyboardVisibilityChanged(false);
    this.callbacks?.onKeyboardHeightChanged(0);
  }
}
