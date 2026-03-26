/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { inputDevice } from '@kit.InputKit';
import { UsbDriverService, UsbDriverListener, AbstractController, ButtonFlags } from './usbdriver/index';
import { 
  gameControllerService, 
  AxisType, 
  GameControllerDeviceInfo 
} from './GameControllerService';
import { SettingsService, SettingsKeys } from './SettingsService';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { DeviceSensorService, LI_MOTION_TYPE_ACCEL, LI_MOTION_TYPE_GYRO } from './DeviceSensorService';
import { MoonBridge } from './MoonBridge';
import { MouseEmulationService, MouseEmulationCallback } from './MouseEmulationService';
import { GamepadVibrationService } from './GamepadVibrationService';
import {
  GamepadState, GamepadInfo, GamepadInputListener, DeviceBusType,
  MoonlightButton, GCButton2313Action, GCButton2313ActionCallback,
  MoonlightControllerType, VendorId, ProductId,
  AXIS_MAX, TRIGGER_MAX, SPECIAL_KEYCODE_MIN, SPECIAL_KEYCODE_MAX,
  buttonMap, gcButtonMap, GAMEPAD_NAME_KEYWORDS, NON_GAMEPAD_KEYWORDS, isNonGamepadByName,
  hasStrongNonGamepadKeyword
} from './GamepadTypes';

export {
  GamepadState, GamepadInfo, GamepadInputListener, DeviceBusType,
  MoonlightButton, GCButton2313Action, GCButton2313ActionCallback,
  MoonlightControllerType
} from './GamepadTypes';
export { MouseEmulationCallback } from './MouseEmulationService';

/**
 * 
 */
export class GamepadManager implements UsbDriverListener {
  private static instance: GamepadManager;
  private static readonly DEBUG = false;
  private static readonly MAX_CONTROLLERS = 4;
  
  private listener: GamepadInputListener | null = null;
  
  private connectedDevices = new Map<number, string>();
  private deviceStates = new Map<number, GamepadState>();
  private deviceInfoMap = new Map<number, GamepadInfo>();
  
  private usbDriverService: UsbDriverService;
  
  private useGameControllerKit = false;
  /**
  private useUsbDriverMode = false;
  private modeInitialized = false;
  private gcDeviceIdToSlot = new Map<string, number>();
  private gcDeviceStates = new Map<string, GamepadState>();
  private gcPhysicalAddressToDeviceId = new Map<string, string>();
  private gcDeviceInfoCache = new Map<string, GameControllerDeviceInfo>();
  
  private deviceKeyToSlot = new Map<string, number>();
  private slotOccupied = [false, false, false, false];
  private controllerIdToDeviceKey = new Map<number, string>();
  private usbDeviceKeyToId = new Map<string, number>();
  
  private deviceSensorService: DeviceSensorService;
  private sensorFallbackEnabled = false;
  private gamepadMotionSensorsEnabled = true;
  private usingDeviceSensorFallback = false;
  
  private sensorDataCallback: ((controllerNumber: number, motionType: number, x: number, y: number, z: number) => void) | null = null;

  private touchpadMouseEnabled: boolean = false;
  private touchpadLastX: number = -1;
  private touchpadLastY: number = -1;
  private touchpadMouseCallback: ((deltaX: number, deltaY: number) => void) | null = null;
  private static readonly TOUCHPAD_SENSITIVITY: number = 0.5;

  private gcButton2313Action: GCButton2313Action = 'guide';
  private gcButton2313ActionCallback: GCButton2313ActionCallback | null = null;
  
  /**
  private mouseEmulationService: MouseEmulationService;
  /**
  private vibrationService: GamepadVibrationService;
  
  private gcDpadAxisActive = new Set<string>();
  /**
  private dpadAxisActive = new Set<number>();

  /**
  private gcAxisFlushPending = new Set<number>();
  private gcAxisFlushTimerId: number = -1;
  
  /**
  private startKeyDownTime: number = 0;
  /**
  private static readonly START_LONG_PRESS_MS = 750;
  /**
  private enableStartKeyMenu = true;
  /**
  private showGameMenuCallback: (() => void) | null = null;

  /**
  private stickDeadzone: number = 0.07;
  /**
  private static readonly TRIGGER_DEADZONE: number = 0.13;

  private handleStartLongPress(isPressed: boolean): boolean {
    if (isPressed) {
      this.startKeyDownTime = Date.now();
    } else if (this.startKeyDownTime > 0) {
      const pressDuration = Date.now() - this.startKeyDownTime;
      this.startKeyDownTime = 0;
      if (pressDuration > GamepadManager.START_LONG_PRESS_MS && this.enableStartKeyMenu) {
        this.showGameMenuCallback?.();
        return true;
      }
    }
    return false;
  }
  
  private constructor() {
    this.usbDriverService = UsbDriverService.getInstance();
    this.deviceSensorService = DeviceSensorService.getInstance();
    this.mouseEmulationService = new MouseEmulationService();
    this.vibrationService = new GamepadVibrationService(this.usbDriverService, this.deviceKeyToSlot);
    this.loadGCButtonMappingSettings();
    this.loadSensorSettings();
    this.loadUsbDriverSetting();
    this.loadStartKeyMenuSetting();
    this.loadTouchpadMouseSetting();
    this.loadDeadzoneSetting();
  }

  /**
   * 
   * 
   */
  private loadUsbDriverSetting(): void {
    Promise.all([
      PreferencesUtil.get<boolean>(SettingsKeys.USB_DRIVER_ENABLED, false),
      PreferencesUtil.get<boolean>(SettingsKeys.FORCE_USB_DRIVER_ONLY, false)
    ]).then((results: boolean[]) => {
      const usbEnabled = results[0];
      const forceUsbOnly = results[1];
      
      if (forceUsbOnly) {
        console.info('[GAMEPAD] 强制 USB 驱动模式：跳过 GCK，USB 驱动接管全部输入');
        this.useGameControllerKit = false;
        this.useUsbDriverMode = true;
        this.initializeDeviceListener();
        this.initializeUsbDriver();
      } else {
        this.initializeGameControllerKit();
        
        if (usbEnabled && this.useGameControllerKit) {
          console.info('[GAMEPAD] 混合模式：GCK(输入) + USB驱动(震动/高级功能)');
          this.useUsbDriverMode = true;
          this.initializeUsbDriver();
        } else if (usbEnabled && !this.useGameControllerKit) {
          console.info('[GAMEPAD] GCK 不可用，回退到纯 USB 驱动 + InputKit 模式');
          this.useUsbDriverMode = true;
          this.initializeDeviceListener();
          this.initializeUsbDriver();
        } else if (!this.useGameControllerKit) {
          console.info('[GAMEPAD] GCK 不可用，使用 InputKit 传统模式');
          this.initializeDeviceListener();
        }
      }

      this.modeInitialized = true;
      console.info(`[GAMEPAD] 最终输入模式: ${this.getInputModeDescription()}`);
      this.notifyListenerOfExistingDevices();
    }).catch(() => {
      this.initializeGameControllerKit();
      if (!this.useGameControllerKit) {
        this.initializeDeviceListener();
      }
      this.modeInitialized = true;
      this.notifyListenerOfExistingDevices();
    });
  }

  private async loadStartKeyMenuSetting(): Promise<void> {
    try {
      this.enableStartKeyMenu = await PreferencesUtil.get<boolean>(SettingsKeys.ENABLE_START_KEY_MENU, true);
    } catch (e) {
      this.enableStartKeyMenu = true;
    }
  }

  setShowGameMenuCallback(callback: (() => void) | null): void {
    this.showGameMenuCallback = callback;
  }
  
  static getInstance(): GamepadManager {
    if (!GamepadManager.instance) {
      GamepadManager.instance = new GamepadManager();
    }
    return GamepadManager.instance;
  }

  private async loadGCButtonMappingSettings(): Promise<void> {
    try {
      const action = await PreferencesUtil.get<string>(SettingsKeys.GC_BUTTON_HOME_MAPPING, 'guide');
      this.updateGCButton2313Action(action as GCButton2313Action);
    } catch (e) {
      this.updateGCButton2313Action('guide');
    }
  }

  setGCButton2313ActionCallback(callback: GCButton2313ActionCallback | null): void {
    this.gcButton2313ActionCallback = callback;
  }

  updateGCButton2313Action(action: GCButton2313Action): void {
    this.gcButton2313Action = action;

    switch (action) {
      case 'guide':
        gcButtonMap.set(2313, MoonlightButton.SPECIAL);
        break;
      case 'select':
        gcButtonMap.set(2313, MoonlightButton.BACK);
        break;
      default:
        gcButtonMap.delete(2313);
        break;
    }
  }

  private handleGCButton2313Action(): boolean {
    switch (this.gcButton2313Action) {
      case 'toggle_mouse':
        this.toggleMouseEmulation();
        this.gcButton2313ActionCallback?.onToggleMouse?.();
        return true;
      case 'toggle_perf':
        this.gcButton2313ActionCallback?.onTogglePerf?.();
        return true;
      case 'show_menu':
        this.gcButton2313ActionCallback?.onShowMenu?.();
        return true;
      case 'none':
        return true;
      default:
        return false;
    }
  }
  
  private initializeGameControllerKit(): void {
    if (!gameControllerService.isAvailable()) {
      console.info('[GAMEPAD] Game Controller Kit 不可用，使用传统输入方案');
      this.fallbackToLegacyInput();
      return;
    }
    
    console.info('[GAMEPAD] Game Controller Kit 可用，初始化中...');
    
    if (!gameControllerService.init()) {
      console.warn('[GAMEPAD] Game Controller Kit 初始化失败，回退到传统方案');
      this.fallbackToLegacyInput();
      return;
    }
    
    this.useGameControllerKit = true;
    
    if (this.connectedDevices.size > 0) {
      console.info(`[GAMEPAD] 清理 ${this.connectedDevices.size} 个竞争期间注册的传统设备`);
      this.connectedDevices.forEach((name, deviceId) => {
        this.listener?.onGamepadDisconnected(deviceId);
      });
      this.connectedDevices.clear();
      this.deviceStates.clear();
      this.deviceInfoMap.clear();
      this.dpadAxisActive.clear();
    }
    
    this.setupGCCallbacks();
    gameControllerService.startMonitor();
    console.info('[GAMEPAD] Game Controller Kit 初始化成功');
  }
  
  private setupGCCallbacks(): void {
    gameControllerService.setDeviceCallback((deviceId, isConnected, info) => {
      this.handleGCDeviceChange(deviceId, isConnected, info);
    });
    
    gameControllerService.setButtonCallback((deviceId, buttonCode, isPressed) => {
      this.handleGCButtonEvent(deviceId, buttonCode, isPressed);
    });
    
    gameControllerService.setAxisCallback((deviceId, axisType, x, y) => {
      this.handleGCAxisEvent(deviceId, axisType, x, y);
    });
  }
  
  private fallbackToLegacyInput(): void {
    this.useGameControllerKit = false;
  }
  
  async forceUsbDriverMode(): Promise<boolean> {
    console.info('[GAMEPAD] 用户请求强制切换到 USB 驱动模式');
    
    if (!this.useGameControllerKit) {
      console.info('[GAMEPAD] 当前已是 USB 驱动模式');
      return true;
    }
    
    try {
      gameControllerService.stopMonitor();
      gameControllerService.setDeviceCallback(null);
      gameControllerService.setButtonCallback(null);
      gameControllerService.setAxisCallback(null);
      
      this.gcDeviceIdToSlot.forEach((slot, deviceId) => {
        if (this.listener) {
          this.listener.onGamepadDisconnected(slot);
        }
        this.slotOccupied[slot] = false;
      });
      this.gcDeviceIdToSlot.clear();
      this.gcDeviceStates.clear();
      this.gcDpadAxisActive.clear();
      this.gcAxisFlushPending.clear();
      this.gcPhysicalAddressToDeviceId.clear();
      this.gcDeviceInfoCache.clear();
      
      console.info('[GAMEPAD] Game Controller Kit 已停止');
    } catch (err) {
      console.error('[GAMEPAD] 停止 Game Controller Kit 失败:', err);
    }
    
    const wasHybridMode = this.useUsbDriverMode;
    if (wasHybridMode) {
      this.usbDeviceKeyToId.clear();
      this.controllerIdToDeviceKey.clear();
    }
    
    this.useGameControllerKit = false;
    this.useUsbDriverMode = true;
    this.initializeDeviceListener();
    
    if (!wasHybridMode) {
      this.initializeUsbDriver();
    }
    
    Promise.all([
      PreferencesUtil.put(SettingsKeys.USB_DRIVER_ENABLED, true),
      PreferencesUtil.put(SettingsKeys.FORCE_USB_DRIVER_ONLY, true)
    ]).catch((err: Error) => {
      console.error('[GAMEPAD] 持久化 USB 驱动设置失败:', err);
    });
    
    console.info('[GAMEPAD] 已切换到纯 USB 驱动模式（已保存设置）');
    return true;
  }
  
  isUsingGameControllerKit(): boolean {
    return this.useGameControllerKit;
  }

  hasActiveGcGamepad(): boolean {
    return this.useGameControllerKit && this.gcDeviceIdToSlot.size > 0;
  }

  /**
  setMouseEmulationCallback(callback: MouseEmulationCallback | null): void {
    this.mouseEmulationService.setCallback(callback);
  }

  /**
  toggleMouseEmulation(): void {
    this.mouseEmulationService.toggle();
  }

  /**
  isMouseEmulationActive(): boolean {
    return this.mouseEmulationService.isActive();
  }

  /**
   * 
   */
  async reloadSettings(): Promise<void> {
    await Promise.all([
      this.loadStartKeyMenuSetting(),
      this.loadGCButtonMappingSettings(),
      this.loadSensorSettings(),
      this.loadDeadzoneSetting()
    ]);
  }

  private interceptForMouseEmulation(slot: number, state: GamepadState): boolean {
    return this.mouseEmulationService.intercept(state, () => {
      if (this.listener) {
        this.listener.onGamepadInput(slot, this.createEmptyState());
      }
    });
  }

  /**
   * 
   */
  reattachInputCallbacks(): void {
    console.info('[GAMEPAD] 重新挂载输入回调');

    if (this.useGameControllerKit) {
      this.setupGCCallbacks();
      gameControllerService.startMonitor();
      console.info('[GAMEPAD] GC Kit 回调已恢复');
      
      if (this.useUsbDriverMode) {
        this.usbDriverService.setListener(this);
        this.usbDriverService.start();
        console.info('[GAMEPAD] USB 驱动 listener 已恢复（混合模式-震动）');
      }
    } else {
      this.usbDriverService.setListener(this);
      this.usbDriverService.start();
      console.info('[GAMEPAD] USB 驱动 listener 已恢复并重启');
    }
  }
  
  getInputModeDescription(): string {
    if (this.useGameControllerKit && this.useUsbDriverMode) {
      return 'Game Controller Kit + USB 驱动 (混合模式)';
    } else if (this.useGameControllerKit) {
      return 'Game Controller Kit (系统统一输入)';
    } else {
      return 'USB 驱动 (直接设备控制)';
    }
  }
  
  private async initializeUsbDriver(): Promise<void> {
    try {
      console.info('[GAMEPAD] 初始化 USB 驱动服务...');
      this.usbDriverService.setListener(this);
      await this.usbDriverService.start();
      console.info('[GAMEPAD] USB 驱动服务已启动');
    } catch (err) {
      console.error('[GAMEPAD] USB 驱动服务启动失败:', err);
    }
  }
  
  setDeviceVibrate(enabled: boolean, strength: number, mode: string): void {
    this.vibrationService.setSettings(enabled, strength, mode);
  }

  setListener(listener: GamepadInputListener | null): void {
    this.listener = listener;
    
    if (listener) {
      if (!this.modeInitialized) {
        console.info('GamepadManager: 设置监听器（输入模式初始化中，稍后通知已连接设备）');
        return;
      }
      this.notifyListenerOfExistingDevices();
    }
  }
  
  private notifyListenerOfExistingDevices(): void {
    const listener = this.listener;
    if (!listener) return;
    
    if (this.useGameControllerKit) {
        console.info(`GamepadManager: 设置监听器 (Game Controller Kit 模式)`);
        
        this.listener = null;
        this.ensureGCKitCallbacks();
        this.listener = listener;
        
        const devices = gameControllerService.getAllDevices();
        const notifiedSlots = new Set<number>();
        for (const device of devices) {
          const deviceNameLower = (device.name || '').toLowerCase();
          if (isNonGamepadByName(deviceNameLower)) {
            console.info(`GamepadManager: 跳过非手柄设备: ${device.name}`);
            continue;
          }
          const slot = this.getSlotForGCDevice(device.deviceId);
          if (notifiedSlots.has(slot)) {
            console.info(`GamepadManager: 跳过重复槽位手柄: ${device.name} (Slot: ${slot})`);
            continue;
          }
          notifiedSlots.add(slot);
          const ctrlType = MoonlightControllerType.fromDeviceName(device.name);
          console.info(`GamepadManager: 通知已连接手柄: ${device.name} (Slot: ${slot}, Type: ${ctrlType})`);
          listener.onGamepadConnected(slot, device.name, ctrlType);
        }
      } else {
        console.info(`GamepadManager: 设置监听器，已连接设备数: ${this.connectedDevices.size}`);
        this.connectedDevices.forEach((name, deviceId) => {
          const info = this.deviceInfoMap.get(deviceId);
          const ctrlType = info?.vendor ? MoonlightControllerType.fromVendorProduct(info.vendor, info.product ?? 0) : MoonlightControllerType.fromDeviceName(name);
          const slot = this.getControllerSlot(deviceId);
          console.info(`GamepadManager: 通知已连接手柄: ${name} (ID: ${deviceId}, Slot: ${slot}, Type: ${ctrlType})`);
          listener.onGamepadConnected(slot, name, ctrlType);
        });
        
        this.scanConnectedDevices();
        
        this.usbDriverService.refreshDevices();
      }
  }
  
  private ensureGCKitCallbacks(): void {
    if (!gameControllerService.init()) {
      console.warn('[GAMEPAD] GC Kit 初始化失败');
      return;
    }
    
    console.info('[GAMEPAD] 重新设置 Game Controller Kit 回调');
    this.setupGCCallbacks();
    
    gameControllerService.startMonitor();
    
    this.rescanGCKitDevices();
    if (this.gcDeviceIdToSlot.size === 0) {
      gameControllerService.pauseInputMonitor();
      console.info('[GAMEPAD] 初始扫描无手柄，暂停输入监听（设备监听保持活跃）');
    }
  }
  
  private rescanGCKitDevices(): void {
    const devices = gameControllerService.getAllDevices();
    console.info(`[GAMEPAD] 扫描 GC Kit 设备: 发现 ${devices.length} 个`);
    
    for (const device of devices) {
      if (!this.gcDeviceIdToSlot.has(device.deviceId)) {
        console.info(`[GAMEPAD] 补充注册 GC Kit 设备: ${device.name} (${device.deviceId})`);
        this.handleGCDeviceChange(device.deviceId, true, device);
      }
    }
  }
  
  private initializeDeviceListener(): void {
    inputDevice.on('change', (data) => {
      console.info(`[GAMEPAD] 系统输入设备变化: type=${data.type}, deviceId=${data.deviceId}`);
      if (data.type === 'add') {
        this.handleDeviceAdded(data.deviceId);
        this.usbDriverService.refreshDevices();
        if (this.useGameControllerKit && this.gcDeviceIdToSlot.size === 0) {
          gameControllerService.refreshDeviceCache();
          gameControllerService.resumeInputMonitor();
          this.rescanGCKitDevices();
        }
      } else if (data.type === 'remove') {
        this.handleDeviceRemoved(data.deviceId);
        this.checkUsbControllerStatus();
      }
    });
    
    this.scanConnectedDevices();
  }
  
  private checkUsbControllerStatus(): void {
    const controllers = this.usbDriverService.getControllers();
    for (const controller of controllers) {
      if (!controller.isConnected()) {
        console.info(`[GAMEPAD] USB 控制器已断开: ID=${controller.getControllerId()}`);
        controller.stop();
      }
    }
  }
  
  private async scanConnectedDevices(): Promise<void> {
    try {
      const deviceIds = await inputDevice.getDeviceIds();
      
      console.info(`[GAMEPAD] ============ 开始扫描输入设备 ============`);
      console.info(`[GAMEPAD] 发现 ${deviceIds.length} 个输入设备`);
      
      for (const deviceId of deviceIds) {
        try {
          const info = await inputDevice.getDeviceInfo(deviceId);
          console.info(`[GAMEPAD] 设备[${deviceId}]: "${info.name}"`);
          console.info(`[GAMEPAD]   - sources: ${JSON.stringify(info.sources)}`);
          console.info(`[GAMEPAD]   - bus: ${info.bus}, vendor: 0x${info.vendor?.toString(16) || '0'}, product: 0x${info.product?.toString(16) || '0'}`);
        } catch (e) {
          console.error(`[GAMEPAD] 获取设备 ${deviceId} 信息失败`, e);
        }
        
        await this.checkAndRegisterDevice(deviceId);
      }
      
      console.info(`[GAMEPAD] ============ 扫描完成，注册了 ${this.connectedDevices.size} 个手柄 ============`);
    } catch (err) {
      console.error('[GAMEPAD] 扫描设备失败', err);
    }
  }
  
  private async checkAndRegisterDevice(deviceId: number): Promise<void> {
    try {
      const deviceInfo = await inputDevice.getDeviceInfo(deviceId);
      const deviceNameLower = deviceInfo.name.toLowerCase();
      const isUsbInForceUsbMode =
        !this.useGameControllerKit &&
        this.useUsbDriverMode &&
        deviceInfo.bus === DeviceBusType.BUS_USB;
      
      if (isUsbInForceUsbMode) {
        console.info(`[GAMEPAD] 强制 USB 模式下跳过 InputKit USB 设备注册: "${deviceInfo.name}" (ID: ${deviceId})`);
        return;
      }
      
      if (this.isNonGamepadDevice(deviceNameLower, deviceInfo.sources)) {
        GamepadManager.DEBUG && console.info(`[GAMEPAD] 跳过非手柄设备: "${deviceInfo.name}"`);
        return;
      }
      
      const hasJoystickSource = deviceInfo.sources.some(s => s === 'joystick');
      const nameIndicatesGamepad = GAMEPAD_NAME_KEYWORDS.some(kw => deviceNameLower.includes(kw));
      
      if (!hasJoystickSource && !nameIndicatesGamepad) {
        GamepadManager.DEBUG && console.info(`[GAMEPAD] 跳过未识别设备: "${deviceInfo.name}"`);
        return;
      }
      
      this.registerGamepad(deviceId, deviceInfo, hasJoystickSource, nameIndicatesGamepad);
    } catch (err) {
      console.error(`[GAMEPAD] 获取设备信息失败 ${deviceId}`, err);
    }
  }
  
  private isNonGamepadDevice(nameLower: string, sources: inputDevice.SourceType[]): boolean {
    const hasGamepadKeyword = GAMEPAD_NAME_KEYWORDS.some(kw => nameLower.includes(kw));
    if (hasGamepadKeyword) return false;
    if (isNonGamepadByName(nameLower)) return true;
    const hasNonGamepadSource = sources.includes('keyboard' as inputDevice.SourceType) ||
                                 sources.includes('mouse' as inputDevice.SourceType);
    return hasNonGamepadSource;
  }
  
  private registerGamepad(
    deviceId: number, 
    deviceInfo: inputDevice.InputDeviceData,
    hasJoystickSource: boolean,
    nameIndicatesGamepad: boolean
  ): void {
    if (this.connectedDevices.has(deviceId)) {
      GamepadManager.DEBUG && console.info(`[GAMEPAD] 设备 ${deviceId} 已注册，跳过重复注册`);
      return;
    }

    const bus = deviceInfo.bus;
    const isUsb = bus === DeviceBusType.BUS_USB;
    const isBluetooth = bus === DeviceBusType.BUS_BLUETOOTH;
    
    this.connectedDevices.set(deviceId, deviceInfo.name);
    this.deviceStates.set(deviceId, this.createEmptyState());
    
    const gamepadInfo: GamepadInfo = {
      id: deviceId,
      name: deviceInfo.name,
      bus, vendor: deviceInfo.vendor, product: deviceInfo.product,
      isUsb, isBluetooth
    };
    this.deviceInfoMap.set(deviceId, gamepadInfo);
    
    const deviceKey = `inputkit_${deviceId}`;
    const slot = this.allocateSlotForDevice(deviceKey);
    if (slot >= 0) {
      this.controllerIdToDeviceKey.set(deviceId, deviceKey);
    }
    
    const connectionType = isBluetooth ? '蓝牙' : (isUsb ? 'USB' : `其他(${bus})`);
    const effectiveSlot = slot >= 0 ? slot : 0;
    console.info(`[GAMEPAD] ★ 注册手柄: "${deviceInfo.name}" (ID: ${deviceId}, Slot: ${effectiveSlot}, ${connectionType})`);
    GamepadManager.DEBUG && console.info(`[GAMEPAD]   检测: joystick源=${hasJoystickSource}, 名称匹配=${nameIndicatesGamepad}`);
    
    const ctrlType = deviceInfo.vendor ? MoonlightControllerType.fromVendorProduct(deviceInfo.vendor, deviceInfo.product ?? 0) : MoonlightControllerType.fromDeviceName(deviceInfo.name);
    this.listener?.onGamepadConnected(effectiveSlot, deviceInfo.name, ctrlType);
  }
  
  private handleDeviceAdded(deviceId: number): void {
    this.checkAndRegisterDevice(deviceId);
  }
  
  private async handleDeviceRemoved(deviceId: number): Promise<void> {
    const inputSettings = await SettingsService.getInstance().getInputSettings();
    if (inputSettings.ignoreDeviceDisconnect) {
      console.info(`[GAMEPAD] 忽略设备断开信号: deviceId=${deviceId} (用户已启用忽略断开设置)`);
      return;
    }
    
    if (this.connectedDevices.has(deviceId)) {
      const name = this.connectedDevices.get(deviceId) || 'Unknown';
      const info = this.deviceInfoMap.get(deviceId);
      const connectionType = info?.isBluetooth ? '蓝牙' : (info?.isUsb ? 'USB' : '未知');
      
      const slot = this.getControllerSlot(deviceId);
      
      this.connectedDevices.delete(deviceId);
      this.deviceStates.delete(deviceId);
      this.deviceInfoMap.delete(deviceId);
      this.dpadAxisActive.delete(deviceId);
      
      const deviceKey = this.controllerIdToDeviceKey.get(deviceId);
      if (deviceKey) {
        this.releaseSlotForDevice(deviceKey);
        this.controllerIdToDeviceKey.delete(deviceId);
      }
      
      console.info(`GamepadManager: 移除手柄 ${name} (ID: ${deviceId}, Slot: ${slot}, 连接类型: ${connectionType})`);
      
      if (this.listener) {
        this.listener.onGamepadDisconnected(slot);
      }
    }
  }
  
  private createEmptyState(): GamepadState {
    return {
      buttons: 0,
      leftStickX: 0,
      leftStickY: 0,
      rightStickX: 0,
      rightStickY: 0,
      leftTrigger: 0,
      rightTrigger: 0
    };
  }
  
  private updateButtonState(state: GamepadState, buttonFlag: number, isPressed: boolean): void {
    if (isPressed) {
      state.buttons |= buttonFlag;
    } else {
      state.buttons &= ~buttonFlag;
    }
  }
  
  private copyState(state: GamepadState): GamepadState {
    return {
      buttons: state.buttons,
      leftStickX: state.leftStickX,
      leftStickY: state.leftStickY,
      rightStickX: state.rightStickX,
      rightStickY: state.rightStickY,
      leftTrigger: state.leftTrigger,
      rightTrigger: state.rightTrigger
    };
  }

  private allocateSlot(deviceKey: string, keyToSlotMap: Map<string, number>, logPrefix: string): number {
    const existingSlot = keyToSlotMap.get(deviceKey);
    if (existingSlot !== undefined) {
      return existingSlot;
    }
    
    for (let i = 0; i < GamepadManager.MAX_CONTROLLERS; i++) {
      if (!this.slotOccupied[i]) {
        this.slotOccupied[i] = true;
        keyToSlotMap.set(deviceKey, i);
        console.info(`[${logPrefix}] 为设备分配槽位: Key=${deviceKey}, Slot=${i}`);
        return i;
      }
    }
    
    console.warn(`[${logPrefix}] 所有槽位已满，无法分配: Key=${deviceKey}`);
    return -1;
  }
  
  private releaseSlot(deviceKey: string, keyToSlotMap: Map<string, number>, logPrefix: string): void {
    const slot = keyToSlotMap.get(deviceKey);
    if (slot !== undefined) {
      this.slotOccupied[slot] = false;
      keyToSlotMap.delete(deviceKey);
      console.info(`[${logPrefix}] 释放设备槽位: Key=${deviceKey}, Slot=${slot}`);
    }
  }
  
  private isSpecialKeyCode(keyCode: number): boolean {
    return keyCode >= SPECIAL_KEYCODE_MIN && keyCode <= SPECIAL_KEYCODE_MAX;
  }
  
  private allocateSlotForGCDevice(deviceId: string): number {
    return this.allocateSlot(deviceId, this.gcDeviceIdToSlot, 'GAMEPAD-GC');
  }
  
  private releaseSlotForGCDevice(deviceId: string): void {
    this.releaseSlot(deviceId, this.gcDeviceIdToSlot, 'GAMEPAD-GC');
  }
  
  private getSlotForGCDevice(deviceId: string): number {
    return this.gcDeviceIdToSlot.get(deviceId) ?? 0;
  }
  
  private getGCDeviceInfoCached(deviceId: string): GameControllerDeviceInfo | null {
    return this.gcDeviceInfoCache.get(deviceId) ?? null;
  }
  
  private handleGCDeviceChange(deviceId: string, isConnected: boolean, info: GameControllerDeviceInfo): void {
    console.info(`[GAMEPAD-GC] 设备状态变化: deviceId=${deviceId}, isConnected=${isConnected}, name=${info?.name}, physAddr=${info?.physicalAddress || 'N/A'}`);
    
    if (isConnected) {
      if (this.gcDeviceIdToSlot.has(deviceId)) {
        console.info(`[GAMEPAD-GC] 设备已注册，跳过: deviceId=${deviceId}, slot=${this.gcDeviceIdToSlot.get(deviceId)}`);
        return;
      }

      const deviceNameLower = (info?.name || '').toLowerCase();
      if (isNonGamepadByName(deviceNameLower)) {
        console.info(`[GAMEPAD-GC] 跳过非手柄设备: "${info?.name}"`);
        return;
      }

      if (hasStrongNonGamepadKeyword(deviceNameLower)) {
        console.info(`[GAMEPAD-GC] 名称含非手柄关键词，验证设备源类型: "${info?.name}"`);
        this.verifyAndRegisterGCDevice(deviceId, info);
        return;
      }

      const physAddr = info?.physicalAddress || '';
      if (physAddr && physAddr.length > 0) {
        const existingDeviceId = this.gcPhysicalAddressToDeviceId.get(physAddr);
        if (existingDeviceId && existingDeviceId !== deviceId) {
          console.info(`[GAMEPAD-GC] 跳过重复设备(物理地址): deviceId=${deviceId} -> 已有设备 ${existingDeviceId} (physAddr=${physAddr})`);
          const existSlot = this.gcDeviceIdToSlot.get(existingDeviceId);
          if (existSlot !== undefined) {
            this.gcDeviceIdToSlot.set(deviceId, existSlot);
            this.gcDeviceStates.set(deviceId, this.gcDeviceStates.get(existingDeviceId) || this.createEmptyState());
          }
          return;
        }
        this.gcPhysicalAddressToDeviceId.set(physAddr, deviceId);
      }

      {
        const slotEntries = Array.from(this.gcDeviceIdToSlot.entries());
        for (let i = 0; i < slotEntries.length; i++) {
          const existId = slotEntries[i][0];
          const existSlot = slotEntries[i][1];
          if (existId === deviceId) continue;
          const existInfo = this.getGCDeviceInfoCached(existId);
          if (existInfo && existInfo.name === info?.name && existInfo.product === info?.product) {
            const existPhysAddr = existInfo.physicalAddress || '';
            if (physAddr.length > 0 && existPhysAddr.length > 0 && physAddr !== existPhysAddr) {
              continue;
            }
            console.info(`[GAMEPAD-GC] 跳过重复设备(名称+产品ID): deviceId=${deviceId} -> 已有设备 ${existId} (name=${info?.name}, product=${info?.product})`);
            this.gcDeviceIdToSlot.set(deviceId, existSlot);
            this.gcDeviceStates.set(deviceId, this.gcDeviceStates.get(existId) || this.createEmptyState());
            return;
          }
        }
      }

      const hadNoGcDevices = this.gcDeviceIdToSlot.size === 0;

      const slot = this.allocateSlotForGCDevice(deviceId);
      if (slot < 0) {
        console.warn(`[GAMEPAD-GC] 无法分配槽位，忽略设备: ${info?.name}`);
        return;
      }
      
      if (info) {
        this.gcDeviceInfoCache.set(deviceId, info);
      }
      
      this.gcDeviceStates.set(deviceId, this.createEmptyState());
      
      if (this.listener) {
        const ctrlType = MoonlightControllerType.fromDeviceName(info?.name || '');
        console.info(`[GAMEPAD-GC] 通知手柄连接: slot=${slot}, name=${info?.name || `Controller ${slot}`}, type=${ctrlType}`);
        this.listener.onGamepadConnected(slot, info?.name || `Controller ${slot}`, ctrlType);
      }

      if (hadNoGcDevices) {
        gameControllerService.resumeInputMonitor();
        console.info('[GAMEPAD] 检测到手柄连接，恢复输入监听');
      }
    } else {
      const slot = this.getSlotForGCDevice(deviceId);
      
      const addrEntries = Array.from(this.gcPhysicalAddressToDeviceId.entries());
      for (let i = 0; i < addrEntries.length; i++) {
        const addr = addrEntries[i][0];
        const id = addrEntries[i][1];
        if (id === deviceId) {
          this.gcPhysicalAddressToDeviceId.delete(addr);
          break;
        }
      }
      
      let isSharedSlotDevice = false;
      const slotEntries2 = Array.from(this.gcDeviceIdToSlot.entries());
      for (let i = 0; i < slotEntries2.length; i++) {
        const otherId = slotEntries2[i][0];
        const otherSlot = slotEntries2[i][1];
        if (otherId !== deviceId && otherSlot === slot) {
          isSharedSlotDevice = true;
          break;
        }
      }
      
      this.gcDeviceStates.delete(deviceId);
      this.gcDeviceInfoCache.delete(deviceId);
      this.gcDpadAxisActive.delete(deviceId);
      this.gcAxisFlushPending.delete(slot);
      this.gcDeviceIdToSlot.delete(deviceId);
      
      if (isSharedSlotDevice) {
        console.info(`[GAMEPAD-GC] 副本设备断开: deviceId=${deviceId}, 主设备仍在，不通知断开`);
        return;
      }
      
      this.releaseSlotForGCDevice(deviceId);
      if (this.listener) {
        this.listener.onGamepadDisconnected(slot);
      }

      if (this.gcDeviceIdToSlot.size === 0) {
        gameControllerService.pauseInputMonitor();
        console.info('[GAMEPAD] 无手柄连接，暂停输入监听（设备监听保持活跃）');
      }
    }
  }
  
  /**
   *
   */
  private async verifyAndRegisterGCDevice(deviceId: string, info: GameControllerDeviceInfo): Promise<void> {
    try {
      const deviceIds = await inputDevice.getDeviceIds();
      let hasJoystickSource = false;

      for (const id of deviceIds) {
        const devInfo = await inputDevice.getDeviceInfo(id);
        const nameMatch = devInfo.name === info?.name;
        const productMatch = info?.product !== undefined &&
          devInfo.product === info.product;

        if (nameMatch || productMatch) {
          hasJoystickSource = devInfo.sources.some(
            (s: inputDevice.SourceType) => s === 'joystick'
          );
          if (hasJoystickSource) break;
        }
      }

      if (hasJoystickSource) {
        console.info(`[GAMEPAD-GC] 设备 "${info?.name}" 验证通过（有 joystick 源），继续注册`);
        this.continueGCDeviceRegistration(deviceId, info);
      } else {
        console.info(`[GAMEPAD-GC] 设备 "${info?.name}" 无 joystick 源，跳过（不是手柄）`);
      }
    } catch (err) {
      console.warn(`[GAMEPAD-GC] 验证设备 "${info?.name}" 失败，跳过: ${err}`);
    }
  }

  private continueGCDeviceRegistration(deviceId: string, info: GameControllerDeviceInfo): void {
    if (this.gcDeviceIdToSlot.has(deviceId)) {
      return;
    }

    const hadNoGcDevices = this.gcDeviceIdToSlot.size === 0;

    const slot = this.allocateSlotForGCDevice(deviceId);
    if (slot < 0) {
      console.warn(`[GAMEPAD-GC] 无法分配槽位，忽略设备: ${info?.name}`);
      return;
    }

    if (info) {
      this.gcDeviceInfoCache.set(deviceId, info);
    }

    this.gcDeviceStates.set(deviceId, this.createEmptyState());

    if (this.listener) {
      const ctrlType = MoonlightControllerType.fromDeviceName(info?.name || '');
      console.info(`[GAMEPAD-GC] 通知手柄连接(验证后): slot=${slot}, name=${info?.name || `Controller ${slot}`}, type=${ctrlType}`);
      this.listener.onGamepadConnected(slot, info?.name || `Controller ${slot}`, ctrlType);
    }

    if (hadNoGcDevices) {
      gameControllerService.resumeInputMonitor();
      console.info('[GAMEPAD] 检测到手柄连接，恢复输入监听');
    }
  }

  private handleGCButtonEvent(deviceId: string, buttonCode: number, isPressed: boolean): void {
    let state = this.gcDeviceStates.get(deviceId);
    if (!state) {
      state = this.createEmptyState();
      this.gcDeviceStates.set(deviceId, state);
    }
    
    if (buttonCode === 2312 && this.handleStartLongPress(isPressed)) {
      return;
    }
    
    const buttonFlag = gcButtonMap.get(buttonCode);
    if (buttonFlag !== undefined) {
      if ((buttonFlag & MoonlightButton.DPAD_MASK) !== 0 && this.gcDpadAxisActive.has(deviceId)) {
        return;
      }
      this.updateButtonState(state, buttonFlag, isPressed);
      this.notifyGCStateChange(this.getSlotForGCDevice(deviceId), state);
    } else {
      GamepadManager.DEBUG && console.info(`[GAMEPAD-GC] 未映射的按键: buttonCode=${buttonCode}`);
    }
  }
  
  /**
  private gcAxisFirstEventLogged = new Set<string>();

  private handleGCAxisEvent(deviceId: string, axisType: number, x: number, y: number): void {
    if (!this.gcAxisFirstEventLogged.has(deviceId)) {
      this.gcAxisFirstEventLogged.add(deviceId);
      const registered = this.gcDeviceIdToSlot.has(deviceId);
      const slot = this.getSlotForGCDevice(deviceId);
      console.info(`[GAMEPAD-GC] 首次轴事件: deviceId=${deviceId}, axisType=${axisType}, registered=${registered}, slot=${slot}, listener=${!!this.listener}`);
    }
    let state = this.gcDeviceStates.get(deviceId);
    if (!state) {
      state = this.createEmptyState();
      this.gcDeviceStates.set(deviceId, state);
    }
    
    const clampStick = (v: number) => Math.max(-AXIS_MAX, Math.min(AXIS_MAX, Math.floor(v)));
    const clampTrigger = (v: number) => Math.max(0, Math.min(TRIGGER_MAX, Math.floor(v)));

    switch (axisType) {
      case AxisType.LEFT_THUMBSTICK: {
        const dz = this.applyStickDeadzone(x, y);
        state.leftStickX = clampStick(dz[0] * AXIS_MAX);
        state.leftStickY = clampStick(-dz[1] * AXIS_MAX);
        break;
      }
      case AxisType.RIGHT_THUMBSTICK: {
        const dz = this.applyStickDeadzone(x, y);
        state.rightStickX = clampStick(dz[0] * AXIS_MAX);
        state.rightStickY = clampStick(-dz[1] * AXIS_MAX);
        break;
      }
        
      case AxisType.DPAD:
        this.gcDpadAxisActive.add(deviceId);
        state.buttons &= ~MoonlightButton.DPAD_MASK;
        if (y < -0.5) state.buttons |= MoonlightButton.UP;
        if (y > 0.5) state.buttons |= MoonlightButton.DOWN;
        if (x < -0.5) state.buttons |= MoonlightButton.LEFT;
        if (x > 0.5) state.buttons |= MoonlightButton.RIGHT;
        break;
        
      case AxisType.LEFT_TRIGGER:
        state.leftTrigger = clampTrigger(this.applyTriggerDeadzone(x) * TRIGGER_MAX);
        break;
        
      case AxisType.RIGHT_TRIGGER:
        state.rightTrigger = clampTrigger(this.applyTriggerDeadzone(x) * TRIGGER_MAX);
        break;
    }
    
    const slot = this.getSlotForGCDevice(deviceId);
    this.gcAxisFlushPending.add(slot);
    this.scheduleGCAxisFlush();
  }

  /**
  private scheduleGCAxisFlush(): void {
    if (this.gcAxisFlushTimerId !== -1) {
      return;
    }
    this.gcAxisFlushTimerId = setTimeout(() => {
      this.gcAxisFlushTimerId = -1;
      this.flushGCAxisPending();
    }, 0);
  }

  private flushGCAxisPending(): void {
    if (this.gcAxisFlushPending.size === 0 || !this.listener) {
      if (this.gcAxisFlushPending.size > 0 && !this.listener) {
        console.warn(`[GAMEPAD-GC] 轴事件丢弃: listener 为空, pending slots=${this.gcAxisFlushPending.size}`);
      }
      this.gcAxisFlushPending.clear();
      return;
    }
    const flushedSlots = new Set<number>();
    this.gcDeviceIdToSlot.forEach((slot: number, deviceId: string) => {
      if (!this.gcAxisFlushPending.has(slot) || flushedSlots.has(slot)) {
        return;
      }
      const state = this.gcDeviceStates.get(deviceId);
      if (state) {
        flushedSlots.add(slot);
        this.notifyGCStateChange(slot, state);
      }
    });
    this.gcAxisFlushPending.clear();
  }
  
  private notifyGCStateChange(slot: number, state: GamepadState): void {
    const copy = this.copyState(state);
    if (this.interceptForMouseEmulation(slot, copy)) {
      return;
    }
    if (this.listener) {
      this.listener.onGamepadInput(slot, copy);
    }
  }
  
  /**
   * 
   * 
   */
  handleKeyEvent(deviceId: number, keyCode: number, isPressed: boolean): void {
    if (!this.modeInitialized) return;
    
    GamepadManager.DEBUG && console.info(`[GAMEPAD-KEY] handleKeyEvent: deviceId=${deviceId}, keyCode=${keyCode}, isPressed=${isPressed}`);
    
    if (keyCode === 2313) {
      if (isPressed && this.handleGCButton2313Action()) {
        return;
      }
      if (this.useGameControllerKit) {
        const mappedButton = gcButtonMap.get(2313);
        if (mappedButton !== undefined) {
          const firstDeviceId = this.gcDeviceStates.keys().next().value as string;
          if (firstDeviceId) {
            const state = this.gcDeviceStates.get(firstDeviceId);
            if (state) {
              this.updateButtonState(state, mappedButton, isPressed);
              this.notifyGCStateChange(this.getSlotForGCDevice(firstDeviceId), state);
            }
          }
        }
        return;
      }
    }

    if ((keyCode === 108 || keyCode === 2312) && this.handleStartLongPress(isPressed)) {
      return;
    }
    
    if (this.useGameControllerKit) {
      return;
    }
    
    const isSpecialKey = this.isSpecialKeyCode(keyCode);
    const resolvedDeviceId = this.resolveDeviceIdForKeyEvent(deviceId, keyCode, isSpecialKey);
    if (resolvedDeviceId === -1) return;
    
    const state = this.deviceStates.get(resolvedDeviceId);
    if (!state) {
      console.warn(`[GAMEPAD-KEY] 无法获取设备 ${resolvedDeviceId} 的状态`);
      return;
    }
    
    const buttonFlag = buttonMap.get(keyCode);
    if (buttonFlag !== undefined) {
      if ((buttonFlag & MoonlightButton.DPAD_MASK) !== 0 && this.dpadAxisActive.has(resolvedDeviceId)) {
        GamepadManager.DEBUG && console.info(`[GAMEPAD-KEY] D-pad通道去重: keyCode=${keyCode} (Axis通道已处理)`);
        return;
      }
      GamepadManager.DEBUG && console.info(`[GAMEPAD-KEY] 映射按键: keyCode=${keyCode} -> 0x${buttonFlag.toString(16)}`);
      this.updateButtonState(state, buttonFlag, isPressed);
      this.notifyStateChange(resolvedDeviceId, state);
    } else {
      GamepadManager.DEBUG && console.info(`[GAMEPAD-KEY] 未映射的按键: keyCode=${keyCode}`);
    }
  }
  
  private resolveDeviceIdForKeyEvent(deviceId: number, keyCode: number, isSpecialKey: boolean): number {
    if (this.connectedDevices.has(deviceId)) {
      return deviceId;
    }
    
    if (isSpecialKey) {
      const existingDevices = Array.from(this.connectedDevices.keys());
      if (existingDevices.length > 0) {
        GamepadManager.DEBUG && console.info(`[GAMEPAD-KEY] 特殊按键 ${keyCode} 路由到设备 ${existingDevices[0]}`);
        return existingDevices[0];
      }
      console.warn(`[GAMEPAD-KEY] 特殊按键 ${keyCode} 无可用设备处理`);
      return -1;
    }
    
    if (!this.deviceStates.has(deviceId)) {
      this.deviceStates.set(deviceId, this.createEmptyState());
      this.connectedDevices.set(deviceId, `Unknown Controller ${deviceId}`);
      const deviceKey = `inputkit_${deviceId}`;
      const slot = this.allocateSlotForDevice(deviceKey);
      if (slot >= 0) {
        this.controllerIdToDeviceKey.set(deviceId, deviceKey);
      }
      const effectiveSlot = slot >= 0 ? slot : 0;
      console.info(`[GAMEPAD-KEY] 动态注册设备 ${deviceId} -> Slot ${effectiveSlot}`);
      this.listener?.onGamepadConnected(effectiveSlot, `Controller ${effectiveSlot}`, MoonlightControllerType.XBOX);
    }
    return deviceId;
  }
  
  handleAxisEvent(deviceId: number, axisCode: number, value: number): void {
    if (!this.connectedDevices.has(deviceId)) return;
    
    const state = this.deviceStates.get(deviceId);
    if (!state) return;
    
    switch (axisCode) {
      case 0: {
        const dz = this.applyStickDeadzone(value, state.leftStickY / AXIS_MAX);
        state.leftStickX = Math.max(-AXIS_MAX, Math.min(AXIS_MAX, Math.floor(dz[0] * AXIS_MAX)));
        state.leftStickY = Math.max(-AXIS_MAX, Math.min(AXIS_MAX, Math.floor(dz[1] * AXIS_MAX)));
        break;
      }
      case 1: {
        const dz = this.applyStickDeadzone(state.leftStickX / AXIS_MAX, value);
        state.leftStickX = Math.max(-AXIS_MAX, Math.min(AXIS_MAX, Math.floor(dz[0] * AXIS_MAX)));
        state.leftStickY = Math.max(-AXIS_MAX, Math.min(AXIS_MAX, Math.floor(dz[1] * AXIS_MAX)));
        break;
      }
      case 2: {
        const dz = this.applyStickDeadzone(value, state.rightStickY / AXIS_MAX);
        state.rightStickX = Math.max(-AXIS_MAX, Math.min(AXIS_MAX, Math.floor(dz[0] * AXIS_MAX)));
        state.rightStickY = Math.max(-AXIS_MAX, Math.min(AXIS_MAX, Math.floor(dz[1] * AXIS_MAX)));
        break;
      }
      case 5: {
        const dz = this.applyStickDeadzone(state.rightStickX / AXIS_MAX, value);
        state.rightStickX = Math.max(-AXIS_MAX, Math.min(AXIS_MAX, Math.floor(dz[0] * AXIS_MAX)));
        state.rightStickY = Math.max(-AXIS_MAX, Math.min(AXIS_MAX, Math.floor(dz[1] * AXIS_MAX)));
        break;
      }
      case 17: // ABS_HAT0X - D-Pad X
        this.dpadAxisActive.add(deviceId);
        this.updateDpadHorizontal(state, value);
        break;
      case 18: // ABS_HAT0Y - D-Pad Y
        this.dpadAxisActive.add(deviceId);
        this.updateDpadVertical(state, value);
        break;
      case 9: {
        const normalized = this.applyTriggerDeadzone((value + 1) / 2);
        state.rightTrigger = Math.max(0, Math.min(TRIGGER_MAX, Math.floor(normalized * TRIGGER_MAX)));
        break;
      }
      case 10: {
        const normalized = this.applyTriggerDeadzone((value + 1) / 2);
        state.leftTrigger = Math.max(0, Math.min(TRIGGER_MAX, Math.floor(normalized * TRIGGER_MAX)));
        break;
      }
    }
    
    this.notifyStateChange(deviceId, state);
  }
  
  private updateDpadHorizontal(state: GamepadState, value: number): void {
    if (value < 0) {
      state.buttons |= MoonlightButton.LEFT;
      state.buttons &= ~MoonlightButton.RIGHT;
    } else if (value > 0) {
      state.buttons |= MoonlightButton.RIGHT;
      state.buttons &= ~MoonlightButton.LEFT;
    } else {
      state.buttons &= ~(MoonlightButton.LEFT | MoonlightButton.RIGHT);
    }
  }
  
  private updateDpadVertical(state: GamepadState, value: number): void {
    if (value < 0) {
      state.buttons |= MoonlightButton.UP;
      state.buttons &= ~MoonlightButton.DOWN;
    } else if (value > 0) {
      state.buttons |= MoonlightButton.DOWN;
      state.buttons &= ~MoonlightButton.UP;
    } else {
      state.buttons &= ~(MoonlightButton.UP | MoonlightButton.DOWN);
    }
  }
  
  private allocateSlotForDevice(deviceKey: string): number {
    return this.allocateSlot(deviceKey, this.deviceKeyToSlot, 'GAMEPAD');
  }
  
  private releaseSlotForDevice(deviceKey: string): void {
    this.releaseSlot(deviceKey, this.deviceKeyToSlot, 'GAMEPAD');
  }
  
  getControllerSlot(controllerId: number): number {
    const deviceKey = this.controllerIdToDeviceKey.get(controllerId);
    if (deviceKey) {
      const slot = this.deviceKeyToSlot.get(deviceKey);
      if (slot !== undefined) return slot;
    }
    return 0;
  }
  
  private notifyStateChange(deviceId: number, state: GamepadState): void {
    const slot = this.getControllerSlot(deviceId);
    const copy = this.copyState(state);
    if (this.interceptForMouseEmulation(slot, copy)) {
      return;
    }
    this.listener?.onGamepadInput(slot, copy);
  }

  hasUsbGamepad(): boolean {
    return this.usbDriverService.getControllerCount() > 0;
  }

  getConnectedGamepads(): GamepadInfo[] {
    if (this.useGameControllerKit) {
      const devices = gameControllerService.getAllDevices();
      const slotSeen = new Set<number>();
      const result: GamepadInfo[] = [];
      for (const d of devices) {
        const slot = this.getSlotForGCDevice(d.deviceId);
        if (slotSeen.has(slot)) continue;
        slotSeen.add(slot);
        const info: GamepadInfo = {
          id: slot,
          name: d.name,
          isUsb: false,
          isBluetooth: false
        };
        result.push(info);
      }
      return result;
    }
    return Array.from(this.deviceInfoMap.values());
  }
  
  resetSession(): void {
    console.info('[GAMEPAD] 重置会话状态');
    
    this.mouseEmulationService.cleanup();
    this.vibrationService.stopAll();

    this.touchpadLastX = -1;
    this.touchpadLastY = -1;

    if (this.gcAxisFlushTimerId !== -1) {
      clearTimeout(this.gcAxisFlushTimerId);
      this.gcAxisFlushTimerId = -1;
    }
    this.gcAxisFlushPending.clear();

    this.slotOccupied = [false, false, false, false];
    this.deviceKeyToSlot.clear();
    this.gcDeviceIdToSlot.clear();
    this.gcPhysicalAddressToDeviceId.clear();
    this.gcDeviceInfoCache.clear();
    this.controllerIdToDeviceKey.clear();
    this.usbDeviceKeyToId.clear();
    
    this.connectedDevices.clear();
    this.deviceStates.clear();
    this.deviceInfoMap.clear();
    this.dpadAxisActive.clear();
    
    this.gcDeviceStates.forEach((state, _deviceId) => {
      state.buttons = 0;
      state.leftStickX = 0;
      state.leftStickY = 0;
      state.rightStickX = 0;
      state.rightStickY = 0;
      state.leftTrigger = 0;
      state.rightTrigger = 0;
    });
    
    console.info('[GAMEPAD] 会话状态已重置');
  }
  
  cleanup(): void {
    this.mouseEmulationService.cleanup();
    this.vibrationService.stopAll();

    if (this.gcAxisFlushTimerId !== -1) {
      clearTimeout(this.gcAxisFlushTimerId);
      this.gcAxisFlushTimerId = -1;
    }
    this.gcAxisFlushPending.clear();

    if (this.useGameControllerKit) {
      gameControllerService.stopMonitor();
      gameControllerService.setDeviceCallback(null);
      gameControllerService.setButtonCallback(null);
      gameControllerService.setAxisCallback(null);
      gameControllerService.uninit();
      this.gcDeviceStates.clear();
      this.gcDeviceIdToSlot.clear();
      this.gcPhysicalAddressToDeviceId.clear();
      this.gcDeviceInfoCache.clear();
      this.gcDpadAxisActive.clear();
    }
    
    try {
      inputDevice.off('change');
    } catch (err) {
      // ignore
    }
    
    this.usbDriverService.stop();
    
    this.connectedDevices.clear();
    this.deviceStates.clear();
    this.deviceInfoMap.clear();
    this.dpadAxisActive.clear();
    this.usbDeviceKeyToId.clear();
    this.deviceKeyToSlot.clear();
    this.controllerIdToDeviceKey.clear();
    this.slotOccupied = [false, false, false, false];
    this.listener = null;
  }
  
  /**
   * 
   */
  reportControllerState(
    controllerId: number,
    buttonFlags: number,
    leftStickX: number,
    leftStickY: number,
    rightStickX: number,
    rightStickY: number,
    leftTrigger: number,
    rightTrigger: number
  ): void {
    if (this.useGameControllerKit) {
      return;
    }
    
    let state = this.deviceStates.get(controllerId);
    if (!state) {
      state = this.createEmptyState();
      this.deviceStates.set(controllerId, state);
    }
    
    const clampAxis = (v: number) => Math.max(-AXIS_MAX, Math.min(AXIS_MAX, Math.floor(v * AXIS_MAX)));
    
    const lDz = this.applyStickDeadzone(leftStickX, leftStickY);
    const rDz = this.applyStickDeadzone(rightStickX, rightStickY);
    
    state.buttons = buttonFlags;
    state.leftStickX = clampAxis(lDz[0]);
    state.leftStickY = clampAxis(-lDz[1]);
    state.rightStickX = clampAxis(rDz[0]);
    state.rightStickY = clampAxis(-rDz[1]);
    state.leftTrigger = Math.max(0, Math.min(TRIGGER_MAX, Math.floor(this.applyTriggerDeadzone(leftTrigger) * TRIGGER_MAX)));
    state.rightTrigger = Math.max(0, Math.min(TRIGGER_MAX, Math.floor(this.applyTriggerDeadzone(rightTrigger) * TRIGGER_MAX)));
    
    this.notifyStateChange(controllerId, state);
  }
  
  reportControllerMotion(
    controllerId: number,
    motionType: number,
    x: number,
    y: number,
    z: number
  ): void {
    const slot = this.getControllerSlot(controllerId);
    if (this.sensorDataCallback) {
      this.sensorDataCallback(slot, motionType, x, y, z);
    }
  }

  reportTouchpadInput(
    controllerId: number,
    active: boolean,
    x: number,
    y: number
  ): void {
    if (!this.touchpadMouseEnabled || !this.touchpadMouseCallback) {
      return;
    }

    if (active) {
      if (this.touchpadLastX >= 0 && this.touchpadLastY >= 0) {
        const deltaX = (x - this.touchpadLastX) * GamepadManager.TOUCHPAD_SENSITIVITY;
        const deltaY = (y - this.touchpadLastY) * GamepadManager.TOUCHPAD_SENSITIVITY;
        if (deltaX !== 0 || deltaY !== 0) {
          this.touchpadMouseCallback(Math.round(deltaX), Math.round(deltaY));
        }
      }
      this.touchpadLastX = x;
      this.touchpadLastY = y;
    } else {
      this.touchpadLastX = -1;
      this.touchpadLastY = -1;
    }
  }

  setTouchpadMouseCallback(callback: ((deltaX: number, deltaY: number) => void) | null): void {
    this.touchpadMouseCallback = callback;
  }

  async loadTouchpadMouseSetting(): Promise<void> {
    this.touchpadMouseEnabled = await PreferencesUtil.get<boolean>(SettingsKeys.GAMEPAD_TOUCHPAD_MOUSE, false);
    console.info(`[GAMEPAD] 触摸板鼠标模拟: ${this.touchpadMouseEnabled}`);
  }

  private async loadDeadzoneSetting(): Promise<void> {
    const percentage = await PreferencesUtil.get<number>(SettingsKeys.DEADZONE, 7);
    this.stickDeadzone = Math.max(1, percentage) / 100.0;
    console.info(`[GAMEPAD] 摇杆死区: ${percentage}% (radius=${this.stickDeadzone})`);
  }

  private applyStickDeadzone(x: number, y: number): number[] {
    const magnitude = Math.sqrt(x * x + y * y);
    if (magnitude <= this.stickDeadzone) {
      return [0, 0];
    }
    return [x, y];
  }

  private applyTriggerDeadzone(value: number): number {
    return value <= GamepadManager.TRIGGER_DEADZONE ? 0 : value;
  }

  private async loadSensorSettings(): Promise<void> {
    try {
      const results = await Promise.all([
        PreferencesUtil.get<boolean>(SettingsKeys.GAMEPAD_MOTION_SENSORS, true),
        PreferencesUtil.get<boolean>(SettingsKeys.GAMEPAD_MOTION_FALLBACK, false)
      ]);
      this.gamepadMotionSensorsEnabled = results[0];
      this.sensorFallbackEnabled = results[1];
      console.info(`[GAMEPAD] 设备传感器回退设置: ${results[1]}`);
    } catch (e) {
      this.gamepadMotionSensorsEnabled = true;
      this.sensorFallbackEnabled = false;
    }
  }

  setSensorDataCallback(callback: ((controllerNumber: number, motionType: number, x: number, y: number, z: number) => void) | null): void {
    this.sensorDataCallback = callback;

    if (callback) {
      this.deviceSensorService.setDataCallback((controllerNumber, motionType, x, y, z) => {
        if (this.sensorDataCallback) {
          this.sensorDataCallback(controllerNumber, motionType, x, y, z);
        }
      });
    } else {
      this.deviceSensorService.setDataCallback(null);
      this.deviceSensorService.disableAll();
      this.usingDeviceSensorFallback = false;
    }
  }

  /**
   * 
   * 
   */
  handleSetMotionEventState(controllerNumber: number, motionType: number, reportRateHz: number): void {
    console.info(`[GAMEPAD] 主机请求传感器: ctrl=${controllerNumber}, type=${motionType}, rate=${reportRateHz}Hz`);

    if (!this.gamepadMotionSensorsEnabled) {
      console.info('[GAMEPAD] 传感器功能已被用户禁用');
      return;
    }

    if (!this.sensorFallbackEnabled) {
      console.info('[GAMEPAD] 设备传感器回退未启用');
      return;
    }

    if (controllerNumber !== 0) {
      console.info(`[GAMEPAD] 仅控制器 0 支持设备传感器回退 (当前: ${controllerNumber})`);
      return;
    }

    if (motionType === LI_MOTION_TYPE_GYRO && !this.deviceSensorService.hasGyroscope()) {
      console.warn('[GAMEPAD] 设备没有陀螺仪');
      return;
    }
    if (motionType === LI_MOTION_TYPE_ACCEL && !this.deviceSensorService.hasAccelerometer()) {
      console.warn('[GAMEPAD] 设备没有加速度计');
      return;
    }

    this.deviceSensorService.setControllerNumber(controllerNumber);

    this.deviceSensorService.setMotionEventState(motionType, reportRateHz);

    this.usingDeviceSensorFallback = reportRateHz > 0;
    console.info(`[GAMEPAD] 设备传感器回退: ${this.usingDeviceSensorFallback ? '启用' : '禁用'}`);
  }

  getSensorCapabilities(): number {
    if (!this.gamepadMotionSensorsEnabled) {
      return 0;
    }

    let capabilities = 0;

    if (this.sensorFallbackEnabled) {
      if (this.deviceSensorService.hasAccelerometer()) {
        capabilities |= 0x10;  // LI_CCAP_ACCEL
      }
      if (this.deviceSensorService.hasGyroscope()) {
        capabilities |= 0x20;  // LI_CCAP_GYRO
      }
    }

    return capabilities;
  }

  stopAllSensors(): void {
    this.deviceSensorService.disableAll();
    this.usingDeviceSensorFallback = false;
    this.sensorDataCallback = null;
    console.info('[GAMEPAD] 所有传感器已停止');
  }
  
  deviceRemoved(controller: AbstractController): void {
    const controllerId = controller.getControllerId();
    const deviceKey = controller.getDeviceKey();
    console.info(`[GAMEPAD-USB] 设备移除: ID=${controllerId}, Key=${deviceKey}`);

    if (this.useGameControllerKit) {
      this.usbDeviceKeyToId.delete(deviceKey);
      this.controllerIdToDeviceKey.delete(controllerId);
      console.info(`[GAMEPAD-USB] 混合模式: 清理震动路由记录`);
      return;
    }

    if (!this.connectedDevices.has(controllerId)) return;
    
    const slot = this.getControllerSlot(controllerId);
    
    this.connectedDevices.delete(controllerId);
    this.deviceStates.delete(controllerId);
    this.deviceInfoMap.delete(controllerId);
    this.usbDeviceKeyToId.delete(deviceKey);
    this.controllerIdToDeviceKey.delete(controllerId);
    this.releaseSlotForDevice(deviceKey);
    this.dpadAxisActive.delete(controllerId);

    this.listener?.onGamepadDisconnected(slot);
  }
  
  deviceAdded(controller: AbstractController): void {
    const controllerId = controller.getControllerId();
    const vendorId = controller.getVendorId();
    const productId = controller.getProductId();
    const deviceKey = controller.getDeviceKey();
    
    if (this.useGameControllerKit) {
      const name = this.getControllerFriendlyName(vendorId, productId);
      this.usbDeviceKeyToId.set(deviceKey, controllerId);
      this.controllerIdToDeviceKey.set(controllerId, deviceKey);
      console.info(`[GAMEPAD-USB] 混合模式: 记录 USB 设备用于震动: ${name} (ID=${controllerId})`);
      return;
    }
    
    if (this.connectedDevices.has(controllerId)) {
      GamepadManager.DEBUG && console.info(`[GAMEPAD-USB] 控制器 ID=${controllerId} 已存在，跳过`);
      return;
    }
    
    this.handleDeviceReconnect(deviceKey, controllerId);
    
    const name = this.getControllerFriendlyName(vendorId, productId);
    
    const slot = this.allocateSlotForDevice(deviceKey);
    if (slot < 0) {
      console.warn(`[GAMEPAD-USB] 无法分配槽位，设备被忽略: ${name}`);
      return;
    }
    
    this.registerUsbDevice(controllerId, deviceKey, name, vendorId, productId);
    const ddkTag = controller.isDdkPolling() ? ' [DDK]' : '';
    console.info(`[GAMEPAD-USB] 设备添加: ${name}${ddkTag} (ID=${controllerId}, Slot=${slot})`);
    
    const ctrlType = MoonlightControllerType.fromVendorProduct(vendorId, productId);
    this.listener?.onGamepadConnected(slot, `${name}${ddkTag}`, ctrlType);
  }
  
  private handleDeviceReconnect(deviceKey: string, newControllerId: number): void {
    const existingControllerId = this.usbDeviceKeyToId.get(deviceKey);
    if (existingControllerId !== undefined && existingControllerId !== newControllerId) {
      console.info(`[GAMEPAD-USB] 设备重连: Key=${deviceKey}, 旧ID=${existingControllerId}, 新ID=${newControllerId}`);
      this.connectedDevices.delete(existingControllerId);
      this.deviceStates.delete(existingControllerId);
      this.deviceInfoMap.delete(existingControllerId);
      this.controllerIdToDeviceKey.delete(existingControllerId);
    }
  }
  
  private getControllerFriendlyName(vendorId: number, productId: number): string {
    if (vendorId === VendorId.MICROSOFT) {
      return 'Xbox Controller';
    }
    if (vendorId === VendorId.SONY) {
      if (productId === ProductId.DUALSENSE || productId === ProductId.DUALSENSE_EDGE) {
        return 'DualSense Controller';
      }
      return 'DualShock 4 Controller';
    }
    if (vendorId === VendorId.NINTENDO) {
      if (productId === ProductId.SWITCH_PRO) {
        return 'Switch Pro Controller';
      }
      return 'Nintendo Joy-Con';
    }
    return `USB Controller (VID:0x${vendorId.toString(16)}, PID:0x${productId.toString(16)})`;
  }
  
  private registerUsbDevice(
    controllerId: number, 
    deviceKey: string, 
    name: string, 
    vendorId: number, 
    productId: number
  ): void {
    this.connectedDevices.set(controllerId, name);
    this.deviceStates.set(controllerId, this.createEmptyState());
    this.usbDeviceKeyToId.set(deviceKey, controllerId);
    this.controllerIdToDeviceKey.set(controllerId, deviceKey);
    
    this.deviceInfoMap.set(controllerId, {
      id: controllerId,
      name, vendor: vendorId, product: productId,
      isUsb: true, bus: DeviceBusType.BUS_USB
    });
  }
  

  /**
  handleRumble(controllerNumber: number, lowFreqMotor: number, highFreqMotor: number): void {
    this.vibrationService.handleRumble(controllerNumber, lowFreqMotor, highFreqMotor);
  }

  /**
  handleRumbleTriggers(controllerNumber: number, leftTrigger: number, rightTrigger: number): void {
    this.vibrationService.handleRumbleTriggers(controllerNumber, leftTrigger, rightTrigger);
  }

  /**
  rumbleUsbControllers(controllerNumber: number, lowFreqMotor: number, highFreqMotor: number): void {
    this.vibrationService.rumbleUsbControllersOnly(controllerNumber, lowFreqMotor, highFreqMotor);
  }

  /**
  hasUsbControllers(): boolean {
    return this.vibrationService.hasUsbControllers();
  }

  /**
  stopAllVibration(): void {
    this.vibrationService.stopAll();
  }
}
