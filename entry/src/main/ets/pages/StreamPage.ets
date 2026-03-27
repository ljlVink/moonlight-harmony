/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { display, LengthMetrics, promptAction, router } from "@kit.ArkUI";
import { common } from "@kit.AbilityKit";
import { displaySync } from "@kit.ArkGraphics2D";
import { VirtualControllerOverlay } from "../components/VirtualController";
import { PerformanceOverlay } from "../components/PerformanceOverlay";
import { OptionPickerDialog, OptionPickerDialogConfig } from "../components/OptionPickerDialog";
import { GameMenuCallbacks, GameMenuDialog } from "../components/GameMenuDialog";
import { StreamMenuManager } from "../components/StreamMenuManager";
import { StreamViewModel, TouchMode } from "../viewmodel/StreamViewModel";
import { TouchInputHandler, TouchInputMode } from "../service/TouchInputHandler";
import { StreamWindowManager } from "../service/StreamWindowManager";
import { Shortcut, ShortcutManager } from "../components/ShortcutManager";
import { ShortcutEditData, ShortcutEditorDialog } from "../components/ShortcutEditorDialog";
import {
  GamepadManager,
  GamepadState,
  MoonlightControllerType,
  MouseEmulationCallback,
} from "../service/GamepadManager";
import { GyroAssistService } from "../service/GyroAssistService";
import { BUTTON_ACTION_PRESS, BUTTON_ACTION_RELEASE, MoonBridge } from "../service/MoonBridge";
import { SuperCmd } from "../service/NvHttp";
import { KeyAction, sendShortcutKeys, VirtualKey } from "../service/CustomKeyTypes";
import { pointer } from "@kit.InputKit";
import { InputInterceptorService } from "../service/InputInterceptorService";
import { PreferencesUtil } from "../utils/PreferencesUtil";
import { SettingsKeys } from "../service/SettingsService";
import { StreamInputHandler } from "./StreamInputHandler";
import { StreamLifecycleManager } from "./StreamLifecycleManager";
import { StreamIMEManager } from "./StreamIMEManager";
import { VirtualKeyboard } from "../components/VirtualKeyboard";
import { CustomKeyOverlay } from "../components/CustomKeyOverlay";
import { CustomKeyManager, CustomKeyManagerHost, SessionLike } from "../service/CustomKeyManager";
import { CustomKeyStore } from "../service/CustomKeyStore";
import { PanZoomHandler, PanZoomState, PointXY } from "../service/PanZoomHandler";

class MoonBridgeMouseCallback implements MouseEmulationCallback {
  sendMouseMove(deltaX: number, deltaY: number): void {
    MoonBridge.sendMouseMove(deltaX, deltaY);
  }
  sendMouseButtonDown(button: number): void {
    MoonBridge.sendMouseButton(BUTTON_ACTION_PRESS, button);
  }
  sendMouseButtonUp(button: number): void {
    MoonBridge.sendMouseButton(BUTTON_ACTION_RELEASE, button);
  }
  sendMouseHighResScroll(scrollAmount: number): void {
    MoonBridge.sendMouseHighResScroll(scrollAmount);
  }
  sendMouseHighResHScroll(scrollAmount: number): void {
    MoonBridge.sendMouseHighResHScroll(scrollAmount);
  }
}

interface StreamPageParams {
  computerId: string;
  appId: number;
  appName?: string;
  cmdList?: string;
  displayGuid?: string;
  useVdd?: boolean;
}

class CustomKeyManagerHostImpl implements CustomKeyManagerHost {
  getSessionFn: () => SessionLike | null = () => null;
  toggleVirtualKeyboardFn: () => void = () => {};
  showIMEFn: () => void = () => {};
  openGameMenuFn: () => void = () => {};
  toggleMouseModeFn: () => void = () => {};
  switchProfileFn: () => void = () => {};
  toggleEditModeFn: () => void = () => {};
  hideCustomKeysFn: () => void = () => {};
  onCustomKeysImportedFn: () => void = () => {};

  getSession(): SessionLike | null {
    return this.getSessionFn();
  }

  toggleVirtualKeyboard(): void {
    this.toggleVirtualKeyboardFn();
  }

  showIME(): void {
    this.showIMEFn();
  }

  openGameMenu(): void {
    this.openGameMenuFn();
  }

  toggleMouseMode(): void {
    this.toggleMouseModeFn();
  }

  switchProfile(): void {
    this.switchProfileFn();
  }

  toggleEditMode(): void {
    this.toggleEditModeFn();
  }

  hideCustomKeys(): void {
    this.hideCustomKeysFn();
  }

  onCustomKeysImported(): void {
    this.onCustomKeysImportedFn();
  }
}

@Entry
@Component
struct StreamPage {
  // ViewModel
  @State viewModel: StreamViewModel = new StreamViewModel();

  @State xComponentWidth: Length = "100%";
  @State xComponentHeight: Length = "100%";
  @State xComponentAlignment: Alignment = Alignment.Center;
  @State xComponentOffsetX: number = 0;
  @State xComponentOffsetY: number = 0;
  @State showKeyboardPanel: boolean = false;
  @State keyboardHeight: number = 0;
  @State showVirtualKeyboard: boolean = false;
  @State showCustomKeys: boolean = false;
  @State customKeyEditMode: boolean = false;
  @State customKeyProfileVersion: number = 0;
  @State private customKeyHitReady: number = 0;
  private useVirtualKeyboard: boolean = false;
  private pendingShowIME: boolean = false;
  @State touchPassthrough: boolean = false;
  @State controllerScaleValue: number = 1.0;
  @State controllerOpacityValue: number = 0.75;
  @State isTouchOverrideEnabled: boolean = false;
  @State videoScale: number = 1.0;
  @State videoTranslateX: number = 0;
  @State videoTranslateY: number = 0;

  private mouseDisplaySync: displaySync.DisplaySync | null = null;

  private inputHandler: StreamInputHandler = new StreamInputHandler();
  private lifecycleManager: StreamLifecycleManager = new StreamLifecycleManager();
  private imeManager: StreamIMEManager = new StreamIMEManager(
    getContext(this) as common.UIAbilityContext,
  );

  private gameMenuDialogController: CustomDialogController | null = null;
  private shortcutEditorController: CustomDialogController | null = null;
  private optionPickerDialogController: CustomDialogController | null = null;
  private optionPickerDialogConfig: OptionPickerDialogConfig = {
    title: "",
    options: [],
    onSelect: () => {},
  };

  private xComponentActualWidthVp: number = 0;
  private xComponentActualHeightVp: number = 0;

  private xComponentController: XComponentController = new XComponentController();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private touchInputHandler: TouchInputHandler = new TouchInputHandler();
  private windowManager: StreamWindowManager | null = null;
  private menuManager: StreamMenuManager | null = null;
  private shortcutManager: ShortcutManager = ShortcutManager.getInstance();
  private gamepadManager: GamepadManager = GamepadManager.getInstance();
  private customKeyManager: CustomKeyManager | null = null;
  private panZoomHandler: PanZoomHandler = new PanZoomHandler();
  private controllerTypes: Map<number, number> = new Map(); // slot → MoonlightControllerType

  private computerId: string = "";
  private appId: number = 0;
  private appName: string = "";
  private displayGuid: string = "";
  private useVdd: boolean = false;
  private cmdList: SuperCmd[] = [];
  private enableBackgroundTask: boolean = true;
  private inputKitWasActive: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as StreamPageParams;
    if (params) {
      this.computerId = params.computerId;
      this.appId = params.appId;
      this.appName = params.appName || "";
      this.displayGuid = params.displayGuid || "";
      this.useVdd = params.useVdd || false;
      if (params.cmdList) {
        try {
          this.cmdList = JSON.parse(params.cmdList) as SuperCmd[];
        } catch {
          this.cmdList = [];
        }
      }
    }

    if (this.appId > 0) {
      CustomKeyStore.loadGameProfile(this.appId).then((profile) => {
        if (profile) {
          this.customKeyProfileVersion++;
          console.info(`[StreamPage] 自动加载游戏配置: ${profile.name}`);
        }
      });
    }

    this.windowManager = new StreamWindowManager(this.context);
    this.windowManager.setOnWindowSizeChanged(() => this.recalculateXComponentSize());

    this.shortcutManager.initialize(this.context);

    this.menuManager = new StreamMenuManager(this.viewModel, {
      onResume: () => {},
      onDisconnect: () => {
        this.stopStreaming();
      },
      onQuitGame: () => {
        this.quitGameAndReturn();
      },
      onTouchModeChanged: (mode: string) => {
        this.setTouchMode(mode);
      },
      onShowTouchModeMenu: () => {
        setTimeout(() => {
          this.showTouchModeMenu();
        }, 100);
      },
    });

    this.initializeGamepad();

    const customKeyHost = new CustomKeyManagerHostImpl();
    customKeyHost.getSessionFn = (): SessionLike | null => this.viewModel.getSession();
    customKeyHost.toggleVirtualKeyboardFn = (): void => {
      if (this.useVirtualKeyboard) {
        this.showVirtualKeyboard = !this.showVirtualKeyboard;
      } else {
        this.imeManager.show();
      }
    };
    customKeyHost.showIMEFn = (): void => {
      this.imeManager.show();
    };
    customKeyHost.openGameMenuFn = (): void => {
      this.showStreamMenu();
    };
    customKeyHost.toggleMouseModeFn = (): void => {
      this.showTouchModeMenu();
    };
    customKeyHost.switchProfileFn = (): void => {
      this.cycleCustomKeyProfile();
    };
    customKeyHost.toggleEditModeFn = (): void => {
      this.customKeyEditMode = !this.customKeyEditMode;
    };
    customKeyHost.hideCustomKeysFn = (): void => {
      this.showCustomKeys = false;
    };
    customKeyHost.onCustomKeysImportedFn = (): void => {
      this.showCustomKeys = true;
    };
    this.customKeyManager = new CustomKeyManager(customKeyHost);

    this.inputHandler.initialize(this.viewModel, this.gamepadManager);
    this.inputHandler.setOnShowStreamMenu(() => this.showStreamMenu());

    this.panZoomHandler.setOnStateChanged((state: PanZoomState) => {
      this.videoScale = state.scale;
      this.videoTranslateX = state.translateX;
      this.videoTranslateY = state.translateY;
      if (this.panZoomHandler.isZoomed()) {
        this.touchInputHandler.setCoordinateTransform((x: number, y: number): PointXY => {
          return this.panZoomHandler.inverseTransform(x, y);
        });
      } else {
        this.touchInputHandler.setCoordinateTransform(null);
      }
    });

    this.lifecycleManager.initialize(this.viewModel, this.windowManager, {
      updateXComponentSize: (width: Length, height: Length) => {
        this.xComponentWidth = width;
        this.xComponentHeight = height;
      },
      stopStreaming: () => {
        this.stopStreaming();
      },
      reconnectStreaming: () => {
        this.reconnectStreaming();
      },
    });

    this.imeManager.initialize(this.viewModel, {
      onKeyboardVisibilityChanged: (visible: boolean) => {
        this.showKeyboardPanel = visible;
      },
      onKeyboardHeightChanged: (height: number) => {
        this.keyboardHeight = height;
      },
    });

    this.initializeDisplay();

    this.lifecycleManager.registerAppStateListener();

    this.lifecycleManager.registerDisplayChangeListener();
  }
  private initializeGamepad(): void {
    this.gamepadManager.setListener({
      onGamepadConnected: (deviceId: number, name: string, controllerType: number) => {
        console.info(`手柄已连接: ${name} (ID: ${deviceId}, Type: ${controllerType})`);
        this.controllerTypes.set(deviceId, controllerType);
        promptAction.showToast({ message: `手柄已连接: ${name}` });
      },
      onGamepadDisconnected: (deviceId: number) => {
        console.info(`手柄已断开: ID ${deviceId}`);
        this.controllerTypes.delete(deviceId);
        promptAction.showToast({ message: "手柄已断开" });
      },
      onGamepadInput: (deviceId: number, state: GamepadState) => {
        this.handleGamepadInput(deviceId, state);
      },
    });

    this.gamepadManager.setMouseEmulationCallback(new MoonBridgeMouseCallback());

    this.gamepadManager.setTouchpadMouseCallback((deltaX: number, deltaY: number) => {
      MoonBridge.sendMouseMove(deltaX, deltaY);
    });

    this.gamepadManager.setShowGameMenuCallback(() => {
      this.showStreamMenu();
    });
  }

  private initializeGyroAssist(): void {
    const settings = this.viewModel.inputSettings;
    if (!settings) return;

    const gyroAssist = GyroAssistService.getInstance();
    gyroAssist.loadSettings({
      sensitivity: settings.gyroSensitivity,
      invertX: settings.gyroInvertX,
      invertY: settings.gyroInvertY,
      activationKey: settings.gyroActivationKey,
    });

    gyroAssist.setSendCallback(
      (
        deviceId: number,
        buttons: number,
        leftStickX: number,
        leftStickY: number,
        rightStickX: number,
        rightStickY: number,
        leftTrigger: number,
        rightTrigger: number,
        controllerType: number,
      ) => {
        if (this.viewModel.isConnected) {
          this.viewModel.sendGamepadState(
            deviceId,
            buttons,
            leftStickX,
            leftStickY,
            rightStickX,
            rightStickY,
            leftTrigger,
            rightTrigger,
            controllerType,
          );
        }
      },
    );

    if (settings.gyroAssistEnabled) {
      gyroAssist.setEnabled(true);
    }
  }

  private handleGamepadInput(deviceId: number, state: GamepadState): void {
    if (!this.viewModel.isConnected) {
      return;
    }

    const controllerType = this.controllerTypes.get(deviceId) ?? MoonlightControllerType.XBOX;

    const gyroAssist = GyroAssistService.getInstance();
    let rsX = state.rightStickX;
    let rsY = state.rightStickY;
    if (gyroAssist.enabled) {
      gyroAssist.updateActivation(state.leftTrigger, state.rightTrigger);
      gyroAssist.updateGamepadState(
        deviceId,
        state.buttons,
        state.leftStickX,
        state.leftStickY,
        state.rightStickX,
        state.rightStickY,
        state.leftTrigger,
        state.rightTrigger,
        controllerType,
      );
      const fused = gyroAssist.fuseRightStick(state.rightStickX, state.rightStickY);
      rsX = fused.x;
      rsY = fused.y;
    }

    this.viewModel.sendGamepadState(
      deviceId,
      state.buttons,
      state.leftStickX,
      state.leftStickY,
      rsX,
      rsY,
      state.leftTrigger,
      state.rightTrigger,
      controllerType,
    );
  }

  private async initializeDisplay(): Promise<void> {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      const screenWidth = displayInfo.width / displayInfo.densityPixels;
      const screenHeight = displayInfo.height / displayInfo.densityPixels;

      this.viewModel.displayInfo.screenWidth = screenWidth;
      this.viewModel.displayInfo.screenHeight = screenHeight;

      this.panZoomHandler.setParentSize(screenWidth, screenHeight);

      await this.windowManager?.configureWindow();
    } catch (err) {
      console.error("初始化显示失败:", err);
    }
  }

  aboutToDisappear(): void {
    console.info("StreamPage aboutToDisappear - cleaning up");

    this.lifecycleManager.unregisterAppStateListener();
    this.lifecycleManager.unregisterDisplayChangeListener();

    this.lifecycleManager.stopBackgroundTask();

    this.viewModel.dispose();

    this.touchInputHandler.dispose();

    InputInterceptorService.getInstance().stop();
    this.inputHandler.stopInputKitInterceptor();
    this.inputHandler.stopMouseInterceptor();
    this.stopMouseKeepAlive();

    GyroAssistService.getInstance().dispose();

    this.gamepadManager.setListener(null);
    this.gamepadManager.resetSession();

    this.customKeyManager?.reset();

    this.imeManager.hide();
    this.windowManager?.restoreWindow();

    try {
      pointer.setPointerVisibleSync(true);
    } catch (_) {}
  }

  onBackPress(): boolean {
    this.inputHandler.releaseAllKeys();

    if (this.viewModel.isConnecting) {
      return false;
    }

    if (this.showVirtualKeyboard) {
      this.showVirtualKeyboard = false;
      return true;
    }

    if (this.customKeyEditMode) {
      this.customKeyEditMode = false;
      return true;
    }

    if (this.showKeyboardPanel && Date.now() - this.imeManager.readyTime > 500) {
      this.imeManager.hide();
      return true;
    }

    if (this.viewModel.isConnected) {
      this.showStreamMenu();
      return true;
    }

    return false;
  }

  private buildGameMenuCallbacks(): GameMenuCallbacks {
    return {
      onDismiss: () => {
        this.resumeInterceptors();
      },
      onDisconnect: () => {
        this.stopStreaming();
      },
      onQuitGame: () => {
        this.quitGameAndReturn();
      },
      onTouchModeChanged: (mode: string) => {
        this.setTouchMode(mode);
      },
      onOpenShortcutEditor: () => {
        this.gameMenuDialogController?.close();
        setTimeout(() => this.showShortcutEditor(), 300);
      },
      onEditShortcut: (shortcut) => {
        this.gameMenuDialogController?.close();
        setTimeout(() => this.showShortcutEditor(shortcut), 300);
      },
      onDeleteShortcut: (shortcut) => {
        promptAction.showToast({ message: `快捷键 "${shortcut.name}" 已删除` });
      },
      onSendSuperCmd: (cmdId: string) => {
        this.sendSuperCmd(cmdId);
      },
      onForceUsbDriver: () => {
        this.forceUsbDriverMode();
      },
      onToggleKeyboard: () => {
        if (this.useVirtualKeyboard) {
          this.showVirtualKeyboard = !this.showVirtualKeyboard;
        } else {
          this.pendingShowIME = true;
        }
      },
      onToggleCustomKeys: () => {
        this.showCustomKeys = !this.showCustomKeys;
        if (this.showCustomKeys) {
          setTimeout(() => {
            this.customKeyHitReady += 1;
          }, 100);
        }
      },
      onEditCustomKeys: () => {
        this.showCustomKeys = true;
        this.customKeyEditMode = true;
        setTimeout(() => {
          this.customKeyHitReady += 1;
        }, 100);
      },
      onExportCustomKeys: () => {
        this.customKeyManager?.exportProfile();
      },
      onImportCustomKeys: () => {
        this.customKeyManager?.importProfile();
      },
      onToggleMouseEmulation: () => {
        this.gamepadManager.toggleMouseEmulation();
        const active = this.gamepadManager.isMouseEmulationActive();
        promptAction.showToast({
          message: active ? "手柄鼠标模拟已开启" : "手柄鼠标模拟已关闭",
          duration: 2000,
        });
      },
      onControllerOpacityChange: (opacity: number) => {
        this.controllerOpacityValue = opacity;
        VirtualControllerOverlay.saveOpacity(opacity);
      },
      onControllerScaleChange: (scale: number) => {
        this.controllerScaleValue = scale;
        VirtualControllerOverlay.saveScale(scale);
      },
      onTouchPassthroughChange: (enabled: boolean) => {
        this.touchPassthrough = enabled;
      },
      onClose: () => {
        this.gameMenuDialogController?.close();
        if (this.pendingShowIME) {
          this.pendingShowIME = false;
          setTimeout(() => this.imeManager.show(), 300);
        }
      },
      onUnlockOverlay: () => {
        this.viewModel.overlayState.config.isLocked = false;
        this.viewModel.overlayState.configVersion++;
        AppStorage.setOrCreate("perf_overlay_locked", false);
        PreferencesUtil.put(SettingsKeys.PERF_OVERLAY_LOCKED, false);
        promptAction.showToast({ message: "已解锁覆盖层", duration: 1500 });
        this.gameMenuDialogController?.close();
      },
      onToggleWindowMode: async () => {
        await this.windowManager?.toggleWindowMode();
        this.recalculateXComponentSize();
      },
      onTogglePanZoom: () => {
        this.isTouchOverrideEnabled = !this.isTouchOverrideEnabled;
        promptAction.showToast({
          message: this.isTouchOverrideEnabled
            ? "画面缩放已开启，双指捏合缩放画面"
            : "画面缩放已关闭",
          duration: 2000,
        });
      },
      onResetPanZoom: () => {
        this.panZoomHandler.reset();
        promptAction.showToast({ message: "缩放已重置", duration: 1500 });
      },
      onSwitchCustomKeyProfile: async (name: string) => {
        this.customKeyManager?.reset();
        const profile = await CustomKeyStore.switchProfile(name);
        if (profile) {
          this.customKeyProfileVersion++;
          if (this.appId > 0) {
            CustomKeyStore.setGameProfile(this.appId, profile.name);
          }
        }
      },
    };
  }

  showStreamMenu(): void {
    if (!this.menuManager) return;

    this.inputKitWasActive = this.inputHandler.isInputKitInterceptorActive();
    this.inputHandler.stopInputKitInterceptor();
    this.inputHandler.stopMouseInterceptor();
    this.stopMouseKeepAlive();

    this.gameMenuDialogController = new CustomDialogController({
      builder: GameMenuDialog({
        viewModel: this.viewModel,
        superCmds: this.cmdList,
        isUsbDriverMode: !this.gamepadManager.isUsingGameControllerKit(),
        hasUsbGamepad: this.gamepadManager.hasUsbGamepad(),
        isMouseEmulationActive: this.gamepadManager.isMouseEmulationActive(),
        hasConnectedGamepad: this.gamepadManager.getConnectedGamepads().length > 0,
        isFullscreen: this.windowManager?.isFullscreen ?? true,
        controllerOpacity: this.controllerOpacityValue,
        controllerScale: this.controllerScaleValue,
        touchPassthrough: this.touchPassthrough,
        showCustomKeys: this.showCustomKeys,
        isPanZoomActive: this.isTouchOverrideEnabled,
        callbacks: this.buildGameMenuCallbacks(),
      }),
      alignment: DialogAlignment.CenterEnd,
      customStyle: true,
      backgroundColor: Color.Transparent,
    });
    this.gameMenuDialogController.open();
  }

  private getXComponentWidthVp(): number {
    if (typeof this.xComponentWidth === "string") {
      return this.xComponentActualWidthVp > 0
        ? this.xComponentActualWidthVp
        : this.viewModel.displayInfo.screenWidth;
    }
    return this.xComponentWidth as number;
  }

  private getXComponentHeightVp(): number {
    if (typeof this.xComponentHeight === "string") {
      return this.xComponentActualHeightVp > 0
        ? this.xComponentActualHeightVp
        : this.viewModel.displayInfo.screenHeight;
    }
    return this.xComponentHeight as number;
  }

  private getAlignmentFromPosition(position: string): Alignment {
    switch (position) {
      case "左上":
        return Alignment.TopStart;
      case "上":
        return Alignment.Top;
      case "右上":
        return Alignment.TopEnd;
      case "左":
        return Alignment.Start;
      case "居中":
        return Alignment.Center;
      case "右":
        return Alignment.End;
      case "左下":
        return Alignment.BottomStart;
      case "下":
        return Alignment.Bottom;
      case "右下":
        return Alignment.BottomEnd;
      default:
        return Alignment.Center;
    }
  }

  private updateDisplayPosition(): void {
    this.xComponentAlignment = this.getAlignmentFromPosition(
      this.viewModel.displayInfo.screenPosition,
    );
    const baseWidth = this.getXComponentWidthVp();
    const baseHeight = this.getXComponentHeightVp();
    this.xComponentOffsetX = (baseWidth * this.viewModel.displayInfo.screenOffsetX) / 100;
    this.xComponentOffsetY = (baseHeight * this.viewModel.displayInfo.screenOffsetY) / 100;
  }

  private async recalculateXComponentSize(): Promise<void> {
    if (!this.windowManager) return;

    if (this.windowManager.isFullscreen) {
      const size = this.windowManager.calculateXComponentSize(
        this.viewModel.displayInfo.stretchVideo,
      );
      this.xComponentWidth = size.width;
      this.xComponentHeight = size.height;
    } else {
      this.xComponentWidth = "100%";
      this.xComponentHeight = "100%";
    }
    this.updateDisplayPosition();
  }

  private resumeMouseInterceptor(): void {
    if (!this.viewModel.isConnected) return;
    const monitorOk = this.inputHandler.startMouseInterceptor(
      this.getXComponentWidthVp(),
      this.getXComponentHeightVp(),
    );
    if (!monitorOk) {
      this.startMouseKeepAlive();
    }
  }

  private resumeInterceptors(): void {
    if (!this.viewModel.isConnected) return;
    if (this.inputKitWasActive) {
      this.inputKitWasActive = false;
      this.inputHandler.startInputKitInterceptor(
        this.getXComponentWidthVp(),
        this.getXComponentHeightVp(),
      );
    } else {
      this.resumeMouseInterceptor();
    }
  }

  private startMouseKeepAlive(): void {
    if (this.mouseDisplaySync) return;
    try {
      let deviceRefreshRate = 120;
      try {
        const displayInfo = display.getDefaultDisplaySync();
        deviceRefreshRate = Math.max(Math.round(displayInfo.refreshRate || 120), 60);
      } catch (_) {}

      this.mouseDisplaySync = displaySync.create();
      this.mouseDisplaySync.setExpectedFrameRateRange({
        min: 60,
        max: deviceRefreshRate,
        expected: deviceRefreshRate,
      });
      this.mouseDisplaySync.start();
      console.info(`StreamPage: DisplaySync 已启动（请求 60-${deviceRefreshRate}Hz 高刷新率）`);
    } catch (e) {
      console.warn("StreamPage: DisplaySync 创建失败:", JSON.stringify(e));
      this.mouseDisplaySync = null;
    }
  }

  private stopMouseKeepAlive(): void {
    if (this.mouseDisplaySync) {
      try {
        this.mouseDisplaySync.stop();
      } catch (_) {}
      this.mouseDisplaySync = null;
      console.info("StreamPage: DisplaySync 已停止");
    }
  }

  showShortcutEditor(editingShortcut?: Shortcut): void {
    this.shortcutEditorController = new CustomDialogController({
      builder: ShortcutEditorDialog({
        editingShortcut: editingShortcut,
        callbacks: {
          onSave: async (data: ShortcutEditData) => {
            if (editingShortcut) {
              await this.shortcutManager.updateShortcut(
                editingShortcut.id,
                data.name,
                data.keys,
                data.icon,
                data.color,
                data.keySequence,
              );
              promptAction.showToast({ message: `快捷键 "${data.name}" 已更新` });
            } else {
              await this.shortcutManager.addShortcut(
                data.name,
                data.keys,
                data.icon,
                data.color,
                data.keySequence,
              );
              promptAction.showToast({ message: `快捷键 "${data.name}" 已添加` });
            }
            this.resumeInterceptors();
          },
          onCancel: () => {
            this.resumeInterceptors();
          },
        },
      }),
      alignment: DialogAlignment.Center,
      customStyle: true,
      backgroundColor: Color.Transparent,
    });
    this.shortcutEditorController.open();
  }

  async cycleCustomKeyProfile(): Promise<void> {
    this.customKeyManager?.reset();
    const profile = await CustomKeyStore.cycleNextProfile();
    if (profile) {
      this.customKeyProfileVersion++;
      if (this.appId > 0) {
        CustomKeyStore.setGameProfile(this.appId, profile.name);
      }
      promptAction.showToast({ message: `已切换到: ${profile.name}`, duration: 1500 });
    } else {
      promptAction.showToast({ message: "仅有一个配置", duration: 1500 });
    }
  }

  showTouchModeMenu(): void {
    if (!this.menuManager) return;

    this.optionPickerDialogConfig = this.menuManager.getTouchModeMenuConfig();
    this.optionPickerDialogController = new CustomDialogController({
      builder: OptionPickerDialog({
        config: this.optionPickerDialogConfig,
      }),
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      backgroundColor: Color.Transparent,
    });
    this.optionPickerDialogController.open();
  }

  private async configureStreamWindow(): Promise<void> {
    this.windowManager?.setStreamResolution(
      this.viewModel.displayInfo.streamWidth,
      this.viewModel.displayInfo.streamHeight,
    );

    await this.windowManager?.configureWindow();

    await this.windowManager?.configureOrientation();

    const screenSize = await this.windowManager?.updateScreenSize();
    if (screenSize) {
      this.viewModel.displayInfo.screenWidth = screenSize.width;
      this.viewModel.displayInfo.screenHeight = screenSize.height;
    }

    const xComponentSize = this.windowManager?.calculateXComponentSize(
      this.viewModel.displayInfo.stretchVideo,
    );
    if (xComponentSize) {
      this.xComponentWidth = xComponentSize.width;
      this.xComponentHeight = xComponentSize.height;
      console.info(`StreamPage: XComponent 尺寸 = ${JSON.stringify(xComponentSize)}`);
    }

    this.updateDisplayPosition();
  }

  private async launchStream(): Promise<void> {
    const surfaceId = this.xComponentController.getXComponentSurfaceId();

    const streamConfig = this.viewModel.streamConfig;
    if (streamConfig && streamConfig.fps > 60) {
      try {
        const frameNode = this.getUIContext().getFrameNodeById("streamSurface");
        if (frameNode) {
          MoonBridge.setXComponentFrameRate(frameNode, streamConfig.fps);
          console.info(`XComponent 帧率已设置为 ${streamConfig.fps} fps`);
        }
      } catch (e) {
        console.warn(`设置 XComponent 帧率失败: ${e}`);
      }
    }

    await this.viewModel.startStreaming(
      this.computerId,
      this.appId,
      surfaceId,
      this.context,
      this.displayGuid,
      this.useVdd,
    );
  }

  async startStreaming(): Promise<void> {
    try {
      await this.viewModel.loadSettings();
      this.lifecycleManager.setLatencyToastEnabled(
        await PreferencesUtil.get<boolean>(SettingsKeys.LATENCY_TOAST, false),
      );
      this.lifecycleManager.setDisableWarnings(
        await PreferencesUtil.get<boolean>(SettingsKeys.DISABLE_WARNINGS, false),
      );
      this.enableBackgroundTask = await PreferencesUtil.get<boolean>(
        SettingsKeys.ENABLE_BACKGROUND_TASK,
        true,
      );
      this.lifecycleManager.setEnableBackgroundTask(this.enableBackgroundTask);
      this.useVirtualKeyboard = await PreferencesUtil.get<boolean>(
        SettingsKeys.ENABLE_ONSCREEN_KEYBOARD,
        false,
      );
      this.controllerScaleValue = await VirtualControllerOverlay.loadScale();
      this.controllerOpacityValue = await VirtualControllerOverlay.loadOpacity();
      await this.gamepadManager.reloadSettings();

      const escMenuKey = await PreferencesUtil.get<string>(SettingsKeys.ESC_MENU_KEY, "ESC");
      this.inputHandler.setMenuKey(escMenuKey);

      await this.customKeyManager?.init();

      await this.configureStreamWindow();

      const streamConfig = this.viewModel.streamConfig;
      if (streamConfig) {
        await this.windowManager?.setHdrBrightness(
          streamConfig.hdr,
          streamConfig.hdrHighBrightness,
        );
      }

      const touchModeStr = this.viewModel.touchMode as string;
      this.touchInputHandler.setMode(touchModeStr as TouchInputMode);
      if (streamConfig) {
        this.touchInputHandler.setDoubleTapTimeThreshold(streamConfig.doubleTapTimeThreshold);
      }

      this.viewModel.setConnectionTerminatedCallback((errorCode: number) => {
        this.lifecycleManager.handleConnectionTerminated(errorCode);
      });

      this.viewModel.setResolutionChangedCallback((width: number, height: number) => {
        this.lifecycleManager.handleServerResolutionChanged(width, height);
      });

      await this.launchStream();

      if (this.enableBackgroundTask) {
        await this.lifecycleManager.startBackgroundTask(this.context, this.appName || undefined);
      }

      if (this.viewModel.inputSettings?.enableKeyInterceptor) {
        this.inputHandler.startKeyInterceptor();
      }

      if (this.viewModel.inputSettings?.enableInputKitTouch) {
        // Use Input Kit interceptor for touch + mouse + keyboard.
        // Do NOT also start the mouse event monitor to avoid conflicts.
        this.inputHandler.startInputKitInterceptor(
          this.getXComponentWidthVp(),
          this.getXComponentHeightVp(),
        );
      }

      const monitorOk = this.viewModel.inputSettings?.enableInputKitTouch
        ? false // Skip regular mouse monitor when Input Kit interceptor is active
        : this.inputHandler.startMouseInterceptor(
            this.getXComponentWidthVp(),
            this.getXComponentHeightVp(),
          );
      if (!monitorOk) {
        this.startMouseKeepAlive();
      }

      this.initializeGyroAssist();

      if (!this.viewModel.showLocalCursor) {
        try {
          pointer.setPointerVisibleSync(false);
          console.info("StreamPage: 已隐藏本地系统鼠标光标");
        } catch (e) {
          console.warn("StreamPage: 隐藏鼠标光标失败:", JSON.stringify(e));
        }
      } else {
        console.info("StreamPage: 本地光标模式已启用，保持系统光标可见");
      }
    } catch (err) {
      console.error("开始串流失败:", err);
    }
  }

  private async exitStreamAndReturn(): Promise<void> {
    await this.windowManager?.restoreWindow();
    await new Promise<void>((resolve) => setTimeout(resolve, 150));
    router.back();
  }

  async stopStreaming(): Promise<void> {
    this.lifecycleManager.showLatencyToastIfEnabled();
    await this.lifecycleManager.stopBackgroundTask();
    this.inputHandler.resetState();
    this.stopMouseKeepAlive();
    try {
      pointer.setPointerVisibleSync(true);
    } catch (_) {}
    await this.exitStreamAndReturn();
    this.viewModel.stopStreaming();
  }

  async quitGameAndReturn(): Promise<void> {
    this.lifecycleManager.showLatencyToastIfEnabled();
    await this.lifecycleManager.stopBackgroundTask();

    if (this.viewModel.streamConfig?.lockScreenAfterDisconnect) {
      this.viewModel.getSession()?.sendKeys([0x5b, 0x4c]); // VK_LWIN + VK_L
      await new Promise<void>((resolve) => setTimeout(resolve, 500));
    }

    await this.exitStreamAndReturn();
    this.viewModel
      .quitGame()
      .then(() => {})
      .catch((_err: Error) => {});
  }

  async reconnectStreaming(): Promise<void> {
    console.info("[StreamPage] 开始重连串流...");
    try {
      await this.viewModel.stopStreaming();
      console.info("[StreamPage] 旧会话已停止，开始重新连接...");

      await this.configureStreamWindow();

      await this.launchStream();
      console.info("[StreamPage] 重连串流成功");

      promptAction.showToast({ message: "已重新连接" });
    } catch (err) {
      console.error("[StreamPage] 重连串流失败:", err);
      promptAction.showToast({ message: "重连失败，请手动重试" });
    }
  }

  async sendSuperCmd(cmdId: string): Promise<void> {
    try {
      const success = await this.viewModel.sendSuperCmd(cmdId);
      if (success) {
        promptAction.showToast({ message: "指令已发送" });
      } else {
        promptAction.showToast({ message: "指令发送失败" });
      }
    } catch (err) {
      promptAction.showToast({ message: `指令发送失败: ${(err as Error).message}` });
    }
  }

  sendShortcut(shortcut: Shortcut): void {
    const session = this.viewModel.getSession();
    if (!session) return;
    sendShortcutKeys(
      (keys: number[]) => session.sendKeys(keys),
      shortcut.keys,
      shortcut.keySequence,
    );
  }

  getTouchModeName(): string {
    switch (this.viewModel.touchMode) {
      case "trackpad":
        return "触控板模式";
      case "direct":
        return "多点触控模式";
      case "mouse":
        return "鼠标模式";
      default:
        return this.viewModel.touchMode;
    }
  }

  handleTouch(event: TouchEvent): void {
    if (!this.viewModel.isConnected) {
      return;
    }
    if (this.viewModel.showController && !this.touchPassthrough) {
      return;
    }
    this.touchInputHandler.handleTouchEvent(event);
  }

  setTouchMode(mode: string): void {
    this.viewModel.setTouchMode(mode as TouchMode);
    this.touchInputHandler.setMode(mode as TouchInputMode);
    console.info(`StreamPage: 触摸模式切换为 ${mode}`);
  }

  async forceUsbDriverMode(): Promise<void> {
    try {
      const success = await this.gamepadManager.forceUsbDriverMode();
      if (success) {
        const modeDesc = this.gamepadManager.getInputModeDescription();
        promptAction.showToast({
          message: `已切换到: ${modeDesc}`,
          duration: 3000,
        });
        console.info(`StreamPage: 已切换输入模式 -> ${modeDesc}`);
      } else {
        promptAction.showToast({
          message: "切换失败，请重试",
          duration: 2000,
        });
      }
    } catch (err) {
      console.error("强制 USB 驱动模式切换失败:", err);
      promptAction.showToast({
        message: "切换失败: " + (err as Error).message,
        duration: 2000,
      });
    }
  }

  build() {
    Stack() {
      Stack() {
        XComponent({
          id: "streamSurface",
          type: XComponentType.SURFACE,
          controller: this.xComponentController,
        })
          .onLoad(() => {
            console.info("XComponent 加载完成");
            this.startStreaming();
          })
          .onDestroy(() => {
            console.info("XComponent 销毁");
          })
          .width(this.xComponentWidth)
          .height(this.xComponentHeight)
          .offset({ x: this.xComponentOffsetX, y: this.xComponentOffsetY })
          .hitTestBehavior(
            this.viewModel.showController && !this.touchPassthrough
              ? HitTestMode.None
              : HitTestMode.Default,
          )
          .onTouch((event: TouchEvent) => {
            if (event.source === SourceType.Mouse) return;
            if (this.isTouchOverrideEnabled) {
              this.panZoomHandler.handleTouchEvent(event);
              return;
            }
            this.handleTouch(event);
          })
          .onMouse((event: MouseEvent) => {
            this.inputHandler.handleMouseEvent(event);
          })
          .onAxisEvent((event: AxisEvent) => {
            this.inputHandler.handleAxisEvent(event);
          })
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            const w = newArea.width as number;
            const h = newArea.height as number;
            if (w > 0 && h > 0) {
              this.xComponentActualWidthVp = w;
              this.xComponentActualHeightVp = h;
              this.inputHandler.updateXComponentActualSize(w, h);
            }
            const globalPos = newArea.globalPosition;
            if (globalPos) {
              const screenX = globalPos.x as number;
              const screenY = globalPos.y as number;
              this.inputHandler.updateXComponentScreenPosition(screenX, screenY);
            }
          })
      }
      .width("100%")
      .height("100%")
      .alignContent(this.xComponentAlignment)
      .clip(true)
      .scale({
        x: this.videoScale,
        y: this.videoScale,
        centerX: 0,
        centerY: 0,
      })
      .translate({
        x: this.videoTranslateX,
        y: this.videoTranslateY,
      })

      if (this.viewModel.isConnecting) {
        this.ConnectingOverlay();
      }

      if (this.viewModel.hasError) {
        Column() {
          this.ErrorOverlay()
        }
        .width("100%")
        .alignItems(HorizontalAlign.Center)
        .position({ bottom: 48 })
        .hitTestBehavior(HitTestMode.Transparent);
      }

      if (this.viewModel.isConnected && this.viewModel.connectionPoor) {
        Column() {
          this.ConnectionWarningOverlay()
        }
        .width("100%")
        .alignItems(HorizontalAlign.Center)
        .position({ bottom: 48 })
        .hitTestBehavior(HitTestMode.None);
      }

      if (this.viewModel.isConnected && this.viewModel.showOverlay) {
        PerformanceOverlay({
          viewModel: this.viewModel,
          screenWidth: this.viewModel.displayInfo.screenWidth,
          screenHeight: this.viewModel.displayInfo.screenHeight,
        });
      }

      if (this.viewModel.isConnected && this.viewModel.showController) {
        VirtualControllerOverlay({
          touchPassthrough: $touchPassthrough,
          controllerScale: $controllerScaleValue,
          controllerOpacity: $controllerOpacityValue,
          onlyL3R3: this.viewModel.inputSettings?.onlyL3R3 ?? false,
          showGuideButton: this.viewModel.inputSettings?.showGuideButton ?? true,
          vibrateOsc: this.viewModel.inputSettings?.vibrateOsc ?? true,
          halfHeightPortrait: this.viewModel.inputSettings?.halfHeightOscPortrait ?? true,
          onInput: (input) => {
            this.viewModel.sendInput(input);
          },
        });
      }

      if (this.showCustomKeys && this.viewModel.isConnected) {
        Column() {
          CustomKeyOverlay({
            editMode: $customKeyEditMode,
            profileVersion: this.customKeyProfileVersion,
            onKeyAction: (action: KeyAction, isDown: boolean): void => {
              this.customKeyManager?.handleAction(action, isDown);
            },
            onAnalogStickMovement: (stick: string, x: number, y: number): void => {
              this.customKeyManager?.handleAnalogStickMovement(stick, x, y);
            },
            onAnalogStickClick: (stick: string): void => {
              this.customKeyManager?.handleAnalogStickClick(stick);
            },
            onDPadDirectionChange: (direction: number): void => {
              this.customKeyManager?.handleDPadDirectionChange(direction);
            },
            onEditModeChanged: (editing: boolean): void => {
              this.customKeyEditMode = editing;
            },
            onProfileSwitched: (): void => {
              this.customKeyProfileVersion++;
              if (this.appId > 0) {
                CustomKeyStore.getActiveProfileName().then((name) => {
                  CustomKeyStore.setGameProfile(this.appId, name);
                });
              }
            },
          })
        }
        .width("100%")
        .height("100%")
        .hitTestBehavior(this.customKeyEditMode ? HitTestMode.Default : HitTestMode.Transparent)
        .opacity(this.customKeyHitReady > 0 ? 1 : 0.99);
      }

      if (this.showKeyboardPanel) {
        this.KeyboardInputPanel();
      }

      if (this.showVirtualKeyboard && this.viewModel.isConnected) {
        VirtualKeyboard({
          onVirtualKeyEvent: (vk: number, isDown: boolean): void => {
            const session = this.viewModel.getSession();
            if (session) {
              session.sendKeyboardInput(vk, isDown ? 0x03 : 0x04);
            }
          },
          onClose: (): void => {
            this.showVirtualKeyboard = false;
          },
        }).width("100%");
      }
    }
    .width("100%")
    .height("100%")
    .backgroundColor(Color.Black)
    .focusable(true)
    .defaultFocus(true)
    .onKeyEvent((event: KeyEvent) => {
      return this.inputHandler.handleKeyEvent(event);
    });
  }

  // ==================== UI Builders ====================

  @Builder
  KeyboardInputPanel() {
    Column({ space: 0 }) {
      Scroll() {
        Row({ space: 6 }) {
          Text("⌨")
            .fontSize(17)
            .fontColor("#D0FFFFFF")
          Button("主机键盘")
            .fontSize(11)
            .fontColor("#FFFFFF")
            .backgroundColor("#3B82F6")
            .height(26)
            .borderRadius(13)
            .padding({ left: 10, right: 10 })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .onClick(() => {
              this.viewModel
                .getSession()
                ?.sendKeys([VirtualKey.VK_LWIN, VirtualKey.VK_CONTROL, VirtualKey.VK_O]);
              this.imeManager.hide();
            })
          Button("虚拟键盘")
            .fontSize(11)
            .fontColor("#FFFFFF")
            .backgroundColor("#8B5CF6")
            .height(26)
            .borderRadius(13)
            .padding({ left: 10, right: 10 })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .onClick(() => {
              this.imeManager.hide();
              this.showVirtualKeyboard = true;
            })
          Divider()
            .vertical(true)
            .height(16)
            .color("#33FFFFFF")
            .strokeWidth(1)
          ForEach(
            this.shortcutManager.getShortcuts(),
            (shortcut: Shortcut) => {
              Row() {
                if (shortcut.icon) {
                  Text(shortcut.icon).fontSize(11).margin({ right: 3 });
                }
                Text(shortcut.name)
                  .fontSize(11)
                  .fontColor("#F0FFFFFF")
              }
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(`#50${(shortcut.color || "#9DABB2").replace("#", "")}`)
              .border({ width: 1, color: `#80${(shortcut.color || "#9DABB2").replace("#", "")}` })
              .borderRadius(13)
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
              .onClick(() => {
                this.sendShortcut(shortcut);
              });
            },
            (shortcut: Shortcut) => shortcut.id,
          )

          if (this.cmdList.length > 0) {
            Divider().vertical(true).height(16).color("#33FFFFFF").strokeWidth(1);

            ForEach(
              this.cmdList,
              (cmd: SuperCmd) => {
                Row() {
                  Text("⚡")
                    .fontSize(11)
                    .margin({ right: 3 })
                  Text(cmd.name)
                    .fontSize(11)
                    .fontColor("#F0FFFFFF")
                }
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor("#50D97706")
                .border({ width: 1, color: "#80D97706" })
                .borderRadius(13)
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                .onClick(() => {
                  this.sendSuperCmd(cmd.id);
                });
              },
              (cmd: SuperCmd) => cmd.id,
            );
          }
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .align(Alignment.Start)
      .padding({ left: 14, right: 16 })
      .fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(20) })
    }
    .direction(Direction.Ltr)
    .width("100%")
    .height(40)
    .backgroundColor("#CC1A1A2E")
    .backdropBlur(40)
    .borderRadius({ topLeft: 16, topRight: 16 })
    .shadow({ radius: 12, color: "#40000000", offsetY: -2 })
    .position({ left: 0, bottom: this.keyboardHeight });

    Text("✕")
      .fontSize(13)
      .fontColor("#99FFFFFF")
      .width(24)
      .height(24)
      .textAlign(TextAlign.Center)
      .borderRadius(12)
      .backgroundColor("#661A1A2E")
      .backdropBlur(20)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.85 })
      .onClick(() => {
        this.imeManager.hide();
      })
      .position({ right: 8, bottom: this.keyboardHeight + 44 });
  }

  @Builder
  ConnectionWarningOverlay() {
    Row({ space: 8 }) {
      Text("⚠")
        .fontSize(16)
        .fontColor("#FFFFB74D")
      Text(
        this.viewModel.streamConfig && this.viewModel.streamConfig.bitrate > 5000
          ? "网速慢，请尝试降低码率或使用有线连接"
          : "网络连接不稳定",
      )
        .fontSize(13)
        .fontColor("#EEFFFFFF")
    }
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .borderRadius(20)
    .backgroundColor("#B01A1A2E")
    .backdropBlur(30)
    .border({ width: 1, color: "#18FFFFFF" })
    .shadow({ radius: 12, color: "#40000000", offsetY: 4 })
    .hitTestBehavior(HitTestMode.None)
    .transition(TransitionEffect.OPACITY.animation({ duration: 300 }));
  }

  @Builder
  ConnectingOverlay() {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color(Color.White)
      Text(this.viewModel.connectionStageText || "正在连接...")
        .fontSize(14)
        .fontColor("#B0FFFFFF")
        .margin({ top: 16 })
        .textAlign(TextAlign.Center)
        .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
    }
    .width("100%")
    .height("100%")
    .backgroundColor("#CC000000")
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  ErrorOverlay() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text("✕")
          .fontSize(16)
          .fontColor("#FFEF5350")
        Text(this.viewModel.errorMessage)
          .fontSize(13)
          .fontColor("#EEFFFFFF")
          .constraintSize({ maxWidth: 280 })
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Text("返回")
        .fontSize(12)
        .fontColor("#EEFFFFFF")
        .padding({ left: 20, right: 20, top: 6, bottom: 6 })
        .borderRadius(14)
        .backgroundColor("#30FFFFFF")
        .onClick(() => {
          router.back();
        })
    }
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .borderRadius(20)
    .backgroundColor("#B01A1A2E")
    .backdropBlur(30)
    .border({ width: 1, color: "#18FFFFFF" })
    .shadow({ radius: 12, color: "#40000000", offsetY: 4 })
    .transition(TransitionEffect.OPACITY.animation({ duration: 300 }));
  }
}
