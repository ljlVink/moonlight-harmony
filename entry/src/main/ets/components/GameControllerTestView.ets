/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */



import { gameControllerService, GameControllerService, ButtonCode } from '../service/GameControllerService';
import { GamepadManager } from '../service/GamepadManager';
import { UsbDriverService } from '../service/usbdriver';
import { gcButtonMap, AXIS_MAX, TRIGGER_MAX } from '../service/GamepadTypes';
import { AppColors } from '../common/Theme';


interface ButtonIndicatorParams {
  name: string;
  buttons: number;
  flag: number;
}


class ControllerInputState {
  buttons: number = 0;
  leftStickX: number = 0;
  leftStickY: number = 0;
  rightStickX: number = 0;
  rightStickY: number = 0;
  leftTrigger: number = 0;
  rightTrigger: number = 0;
}


class GCDeviceInfo {
  deviceId: string = '';
  name: string = '';
  productId: number = 0;
}


class ButtonEventLog {
  timestamp: string;
  deviceId: string;
  buttonCode: number;
  buttonName: string;
  isPressed: boolean;
  
  constructor(deviceId: string, buttonCode: number, isPressed: boolean) {
    this.timestamp = new Date().toLocaleTimeString();
    this.deviceId = deviceId;
    this.buttonCode = buttonCode;
    this.buttonName = ButtonEventLog.getButtonName(buttonCode);
    this.isPressed = isPressed;
  }
  
  static getButtonName(code: number): string {
    // Button name mapping based on actual testing
    switch (code) {
      case 2301: return 'A';
      case 2302: return 'B';
      case 2303: return 'C';
      case 2304: return 'X';
      case 2305: return 'Y';
      case 2306: return 'Z';
      case 2307: return 'L1';
      case 2308: return 'R1';
      case 2309: return 'LT (Button)';
      case 2310: return 'RT (Button)';
      case 2311: return 'Select';
      case 2312: return 'Start';
      case 2313: return 'Home/Mode (Customizable)';
      case 2314: return 'L3';
      case 2315: return 'R3';
      // D-Pad
      case 2012: return 'D-Up';
      case 2013: return 'D-Down';
      case 2014: return 'D-Left';
      case 2015: return 'D-Right';
      default: return `Unknown(${code})`;
    }
  }
}

@Component
export struct GameControllerTestView {
  @State isMonitoring: boolean = false;
  @State isAvailable: boolean = false;
  @State connectedDevices: GCDeviceInfo[] = [];

  @State displayButtons: number = 0;
  @State displayLSX: number = 0;
  @State displayLSY: number = 0;
  @State displayRSX: number = 0;
  @State displayRSY: number = 0;
  @State displayLT: number = 0;
  @State displayRT: number = 0;
  @State hasInput: boolean = false;
  @State logMessages: string[] = [];
  @State buttonEventLogs: ButtonEventLog[] = [];
  @State rawButtonEvents: string[] = [];
  @State keyEventLogs: string[] = [];
  

  onKeyEventRef?: (handler: (event: KeyEvent) => boolean) => void;


  private internalState: ControllerInputState = new ControllerInputState();
  private stateDirty: boolean = false;
  private internalLogs: string[] = [];
  private logsDirty: boolean = false;
  private internalRawButtonEvents: string[] = [];
  private internalButtonEventLogs: ButtonEventLog[] = [];
  private buttonEventsDirty: boolean = false;
  private internalKeyEventLogs: string[] = [];
  private keyEventsDirty: boolean = false;
  private uiRefreshTimer: number = -1;

  aboutToAppear(): void {
    this.addLog('Game Controller Kit test view initialized');
    this.checkAvailability();
    this.startUiRefreshTimer();
    

    if (this.onKeyEventRef) {
      this.onKeyEventRef((event: KeyEvent) => this.handleKeyEvent(event));
    }
  }

  aboutToDisappear(): void {
    this.stopUiRefreshTimer();
    this.stopMonitoring();
  }


  private startUiRefreshTimer(): void {
    this.uiRefreshTimer = setInterval(() => {

      if (this.stateDirty) {
        const s = this.internalState;
        this.displayButtons = s.buttons;
        this.displayLSX = s.leftStickX;
        this.displayLSY = s.leftStickY;
        this.displayRSX = s.rightStickX;
        this.displayRSY = s.rightStickY;
        this.displayLT = s.leftTrigger;
        this.displayRT = s.rightTrigger;
        this.hasInput = true;
        this.stateDirty = false;
      }

      if (this.logsDirty) {
        this.logMessages = [...this.internalLogs];
        this.logsDirty = false;
      }

      if (this.buttonEventsDirty) {
        this.rawButtonEvents = [...this.internalRawButtonEvents];
        this.buttonEventLogs = [...this.internalButtonEventLogs];
        this.buttonEventsDirty = false;
      }

      if (this.keyEventsDirty) {
        this.keyEventLogs = [...this.internalKeyEventLogs];
        this.keyEventsDirty = false;
      }
    }, 33);
  }

  private stopUiRefreshTimer(): void {
    if (this.uiRefreshTimer !== -1) {
      clearInterval(this.uiRefreshTimer);
      this.uiRefreshTimer = -1;
    }
  }
  
  /**
   * Handle KeyEvent (API 15+ supports 2311-2315 gamepad buttons)
   * Note: GC Kit does not support 2313 (Mode), can only be captured via KeyEvent
   */
  private handleKeyEvent(event: KeyEvent): boolean {
    const keyCode = event.keyCode;
    // KeyType.Down = 0, KeyType.Up = 1
    const isPressed = event.type === 0;
    const timestamp = new Date().toLocaleTimeString();
    
    // Record all 2300+ range keys (gamepad related)
    if (keyCode >= 2300 && keyCode <= 2320) {
      const buttonName = ButtonEventLog.getButtonName(keyCode);
      const logEntry = `[${timestamp}] KeyEvent: code=${keyCode} (${buttonName}) ${isPressed ? 'Down' : 'Up'}`;
      this.internalKeyEventLogs = [logEntry, ...this.internalKeyEventLogs.slice(0, 29)];
      this.keyEventsDirty = true;
      this.addLog(`KeyEvent: ${keyCode} (${buttonName}) ${isPressed ? 'Down' : 'Up'}`);
      
      // Specifically mark 2313
      if (keyCode === 2313) {
        this.addLog(`⭐ Received 2313 (Mode) key! GC Kit does not support this key, captured via KeyEvent`);
      }
      
      return true;  // Handled
    }
    
    return false;  // Not handled
  }
  
  private checkAvailability(): void {
    this.isAvailable = gameControllerService.isAvailable();
    this.addLog(`Game Controller Kit availability: ${this.isAvailable ? 'Available' : 'Unavailable'}`);
    
    if (this.isAvailable) {
      this.addLog('Can test Bluetooth/System gamepad input');
    } else {
      this.addLog('Warning: Game Controller Kit unavailable, may require API 21+');
    }
  }

  addLog(message: string): void {
    const timestamp = new Date().toLocaleTimeString();
    this.internalLogs = [`[${timestamp}] ${message}`, ...this.internalLogs.slice(0, 99)];
    this.logsDirty = true;
  }
  
  private addButtonEventLog(deviceId: string, buttonCode: number, isPressed: boolean): void {
    const log = new ButtonEventLog(deviceId, buttonCode, isPressed);
    this.internalButtonEventLogs = [log, ...this.internalButtonEventLogs.slice(0, 49)];
    this.internalRawButtonEvents = [`[${log.timestamp}] ${isPressed ? 'Down' : 'Up'} buttonCode=${buttonCode} (${log.buttonName})`,
                            ...this.internalRawButtonEvents.slice(0, 29)];
    this.buttonEventsDirty = true;
  }
  
  private startMonitoring(): void {
    if (!this.isAvailable) {
      this.addLog('Error: Game Controller Kit unavailable');
      return;
    }
    
    if (this.isMonitoring) {
      this.addLog('Already monitoring');
      return;
    }

    // Release USB driver exclusive access first to avoid GC Kit missing devices
    // (e.g., currently in forced USB mode, or just switched from USB test page)
    try {
      UsbDriverService.getInstance().stop();
      this.addLog('Released USB driver exclusive access, waiting for GC Kit to re-detect devices...');
    } catch (err) {
      this.addLog(`Failed to release USB driver exclusive access (can ignore): ${err}`);
    }
    
    // Initialize
    if (!gameControllerService.init()) {
      this.addLog('Error: Initialization failed');
      return;
    }
    
    // Temporarily take over callbacks (override GamepadManager's callbacks for testing)
    gameControllerService.setDeviceCallback((deviceId, isConnected, info) => {
      this.onDeviceChanged(deviceId, isConnected, info);
    });
    
    gameControllerService.setButtonCallback((deviceId, buttonCode, isPressed) => {
      this.onButtonEvent(deviceId, buttonCode, isPressed);
    });
    
    gameControllerService.setAxisCallback((deviceId, axisType, x, y) => {
      this.handleAxisEvent(deviceId, axisType, x, y);
    });
    
    // Start monitoring (returns true if already monitoring)
    if (!gameControllerService.startMonitor()) {
      this.addLog('Error: Failed to start monitoring');
      return;
    }
    
    this.isMonitoring = true;
    this.addLog('Started monitoring Game Controller Kit events');
    
    // Immediately read current devices from cache (may be empty)
    const cachedCount = gameControllerService.getDeviceCount();
    this.addLog(`Current GCK cached device count: ${cachedCount}`);
    this.refreshConnectedDevices();
    
    // After USB driver releases device, UsbDriverService will rebind kernel HID driver
    // via native ioctl (USBDEVFS_CONNECT) after 300ms.
    // GCK needs extra time to detect the rebound device.
    // Multiple delayed refreshes to cover different device re-enumeration timings.
    const refreshDelays = [1000, 2000, 4000, 7000];
    for (const delay of refreshDelays) {
      setTimeout(() => {
        if (this.isMonitoring) {
          const newCount = gameControllerService.refreshDeviceCache();
          const totalCount = gameControllerService.getDeviceCount();
          if (newCount > 0) {
            this.addLog(`Refresh(${delay}ms): Found ${newCount} new devices, total ${totalCount}`);
            this.refreshConnectedDevices();
          } else if (newCount < 0) {
            this.addLog(`Refresh(${delay}ms): Query failed`);
          }
          
          // Last refresh: if still no devices, suggest re-plugging
          if (delay === 7000 && totalCount === 0) {
            this.addLog('⚠ No gamepad device detected. If USB driver test was used before, may need to re-plug the gamepad.');
          }
        }
      }, delay);
    }
  }
  
  /**
   * Stop monitoring Game Controller Kit events
   */
  private stopMonitoring(): void {
    if (!this.isMonitoring) {
      return;
    }
    
    // Don't call stopMonitor() to avoid stopping global monitoring affecting GamepadManager
    // Just restore GamepadManager's callbacks
    this.restoreGamepadManagerCallbacks();
    
    this.isMonitoring = false;
    this.addLog('Stopped monitoring (GamepadManager callbacks restored)');
  }
  
  /**
   * Restore GamepadManager callbacks to avoid losing gamepad input after test page exit
   */
  private restoreGamepadManagerCallbacks(): void {
    try {
      GamepadManager.getInstance().reattachInputCallbacks();
    } catch (err) {
      console.error('[GameControllerTest] Failed to restore GamepadManager callbacks:', err);
    }
  }
  
  private refreshConnectedDevices(): void {
    const devices = gameControllerService.getAllDevices();
    this.connectedDevices = [];

    // Deduplicate by physicalAddress: keep only first interface for devices with multiple HID interfaces
    const seenPhysicalAddresses = new Set<string>();
    const seenNameProduct = new Set<string>();

    for (const device of devices) {
      // Primary dedup: physicalAddress
      if (device.physicalAddress && device.physicalAddress.length > 0) {
        if (seenPhysicalAddresses.has(device.physicalAddress)) {
          this.addLog(`Skipped duplicate interface: ${device.name} (physical address: ${device.physicalAddress})`);
          continue;
        }
        seenPhysicalAddresses.add(device.physicalAddress);
      } else {
        // Backup dedup: name + product
        const key = `${device.name}::${device.product}`;
        if (seenNameProduct.has(key)) {
          this.addLog(`Skipped duplicate interface: ${device.name} (name+product dedup)`);
          continue;
        }
        seenNameProduct.add(key);
      }

      const info = new GCDeviceInfo();
      info.deviceId = device.deviceId;
      info.name = device.name;
      info.productId = device.product;
      this.connectedDevices.push(info);
      this.addLog(`Found device: ${device.name} (ID: ${device.deviceId})`);
    }
    
    if (this.connectedDevices.length === 0) {
      this.addLog('No connected gamepad devices found');
    }
  }
  
  private onDeviceChanged(deviceId: string, isConnected: boolean, info: object | null): void {
    if (isConnected) {
      this.addLog(`Device connected: ${deviceId}`);
      this.refreshConnectedDevices();
    } else {
      this.addLog(`Device disconnected: ${deviceId}`);
      this.connectedDevices = this.connectedDevices.filter(d => d.deviceId !== deviceId);
      // Reset state
      this.internalState = new ControllerInputState();
      this.stateDirty = true;
    }
  }
  
  private onButtonEvent(deviceId: string, buttonCode: number, isPressed: boolean): void {
    // Record raw event (write to buffer, synced by timer)
    this.addButtonEventLog(deviceId, buttonCode, isPressed);
    
    // Update internal buffer state
    const state = this.internalState;
    
    const flag = this.buttonCodeToFlag(buttonCode);
    if (flag !== 0) {
      if (isPressed) {
        state.buttons |= flag;
      } else {
        state.buttons &= ~flag;
      }
      // Mark dirty for timer to sync to @State
      this.stateDirty = true;
    }
  }
  
  private buttonCodeToFlag(code: number): number {
    return gcButtonMap.get(code) ?? 0;
  }
  
  private handleAxisEvent(deviceId: string, axisType: number, x: number, y: number): void {
    const state = this.internalState;
    
    // AxisType: 0=Left Stick, 1=Right Stick, 2=D-Pad, 3=Left Trigger, 4=Right Trigger
    switch (axisType) {
      case 0: // Left Stick
        state.leftStickX = Math.floor(x * AXIS_MAX);
        state.leftStickY = Math.floor(-y * AXIS_MAX);
        break;
      case 1: // Right Stick
        state.rightStickX = Math.floor(x * AXIS_MAX);
        state.rightStickY = Math.floor(-y * AXIS_MAX);
        break;
      case 3: // Left Trigger
        state.leftTrigger = Math.floor(x * TRIGGER_MAX);
        break;
      case 4: // Right Trigger
        state.rightTrigger = Math.floor(x * TRIGGER_MAX);
        break;
    }
    
    this.stateDirty = true;
  }

  private formatStickValue(value: number): string {
    const percent = Math.round((value / AXIS_MAX) * 100);
    if (percent > 0) {
      return `+${percent}%`;
    }
    return `${percent}%`;
  }

  private isButtonPressed(buttons: number, flag: number): boolean {
    return (buttons & flag) !== 0;
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        // Status title
        Row({ space: 8 }) {
          Circle()
            .width(12)
            .height(12)
            .fill(this.isAvailable ? (this.isMonitoring ? AppColors.Success : AppColors.Warning) : AppColors.Error)
          Text(this.isAvailable ? (this.isMonitoring ? 'Monitoring' : 'Ready') : 'Unavailable')
            .fontSize(14)
            .fontColor(AppColors.TextPrimary)
        }
        
        // Control buttons
        Row({ space: 12 }) {
          Button(this.isMonitoring ? 'Stop Monitoring' : 'Start Monitoring')
            .onClick(() => {
              if (this.isMonitoring) {
                this.stopMonitoring();
              } else {
                this.startMonitoring();
              }
            })
            .backgroundColor(this.isMonitoring ? AppColors.Error : AppColors.Success)
            .fontColor(AppColors.TextOnPrimary)
            .fontSize(14)
            .height(40)
            .padding({ left: 20, right: 20 })
            .borderRadius(20)
            .enabled(this.isAvailable)

          Button('Refresh Devices')
            .onClick(() => {
              // First query system device list to update cache, then read from cache
              const newCount = gameControllerService.refreshDeviceCache();
              if (newCount > 0) {
                this.addLog(`Manual refresh: Found ${newCount} new devices`);
              }
              this.refreshConnectedDevices();
            })
            .backgroundColor(AppColors.Primary)
            .fontColor(AppColors.TextOnPrimary)
            .fontSize(14)
            .height(40)
            .padding({ left: 20, right: 20 })
            .borderRadius(20)
            .enabled(this.isMonitoring)
        }

        // Connected devices
        Column({ space: 8 }) {
          Text(`Connected Devices (${this.connectedDevices.length})`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .width('100%')

          if (this.connectedDevices.length === 0) {
            Text('No gamepad device detected\nPlease ensure Bluetooth gamepad is paired and connected'))
              .fontSize(13)
              .fontColor(AppColors.TextSecondary)
              .textAlign(TextAlign.Center)
              .padding(16)
          } else {
            ForEach(this.connectedDevices, (device: GCDeviceInfo) => {
              Row({ space: 8 }) {
                Text('🎮')
                  .fontSize(20)
                Column({ space: 2 }) {
                  Text(device.name)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TextPrimary)
                  Text(`ID: ${device.deviceId}`)
                    .fontSize(11)
                    .fontColor(AppColors.TextTertiary)
                  if (device.productId !== 0) {
                    Text(`PID:0x${device.productId.toString(16).toUpperCase()}`)
                      .fontSize(10)
                      .fontColor(AppColors.TextTertiary)
                  }
                }
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(12)
              .backgroundColor(AppColors.SurfaceTransparent)
              .borderRadius(8)
            })
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor(AppColors.Surface)
        .borderRadius(12)

        // Raw button events (important diagnostic info)
        Column({ space: 8 }) {
          Row() {
            Text('🔑 原始按键事件')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TextPrimary)
            Blank()
            Text('Press gamepad button to view code',)
              .fontSize(11)
              .fontColor(AppColors.TextTertiary)
          }
          .width('100%')

          if (this.rawButtonEvents.length === 0) {
            Text('Waiting for button input...\nPress any button on gamepad')
              .fontSize(13)
              .fontColor(AppColors.TextSecondary)
              .textAlign(TextAlign.Center)
              .padding(16)
          } else {
            ForEach(this.rawButtonEvents.slice(0, 10), (event: string, index: number) => {
              Text(event)
                .fontSize(12)
                .fontColor(index === 0 ? AppColors.Primary : AppColors.TextSecondary)
                .fontFamily('monospace')
                .width('100%')
                .padding({ top: 4, bottom: 4 })
            })
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor(AppColors.Surface)
        .borderRadius(12)

        // Button state visualization
        if (this.hasInput) {
          this.buildButtonsDisplay()
        }

        // Logs
        Column({ space: 8 }) {
          Text('📋 日志')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .width('100%')

          ForEach(this.logMessages.slice(0, 20), (log: string) => {
            Text(log)
              .fontSize(11)
              .fontColor(AppColors.TextSecondary)
              .width('100%')
              .padding({ top: 2, bottom: 2 })
          })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(AppColors.Surface)
        .borderRadius(12)
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Background)
  }
  
  // Get first device state (now using pure primitive @State variables)
  
  @Builder
  buildButtonsDisplay() {
    Column({ space: 8 }) {
      Text('🎮 按键状态')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .width('100%')

      // Button grid
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        this.buildButtonIndicator({ name: 'A', buttons: this.displayButtons, flag: 0x1000 })
        this.buildButtonIndicator({ name: 'B', buttons: this.displayButtons, flag: 0x2000 })
        this.buildButtonIndicator({ name: 'X', buttons: this.displayButtons, flag: 0x4000 })
        this.buildButtonIndicator({ name: 'Y', buttons: this.displayButtons, flag: 0x8000 })
        this.buildButtonIndicator({ name: 'LB', buttons: this.displayButtons, flag: 0x0100 })
        this.buildButtonIndicator({ name: 'RB', buttons: this.displayButtons, flag: 0x0200 })
        this.buildButtonIndicator({ name: 'LS', buttons: this.displayButtons, flag: 0x0040 })
        this.buildButtonIndicator({ name: 'RS', buttons: this.displayButtons, flag: 0x0080 })
        this.buildButtonIndicator({ name: 'Start', buttons: this.displayButtons, flag: 0x0010 })
        this.buildButtonIndicator({ name: 'Back', buttons: this.displayButtons, flag: 0x0020 })
        this.buildButtonIndicator({ name: 'Home', buttons: this.displayButtons, flag: 0x0400 })
        this.buildButtonIndicator({ name: '↑', buttons: this.displayButtons, flag: 0x0001 })
        this.buildButtonIndicator({ name: '↓', buttons: this.displayButtons, flag: 0x0002 })
        this.buildButtonIndicator({ name: '←', buttons: this.displayButtons, flag: 0x0004 })
        this.buildButtonIndicator({ name: '→', buttons: this.displayButtons, flag: 0x0008 })
      }
      .width('100%')

      // Sticks and triggers
      Row({ space: 16 }) {
        Column({ space: 4 }) {
          Text('Left Stick'))
            .fontSize(11)
            .fontColor(AppColors.TextSecondary)
          Text(`X: ${this.formatStickValue(this.displayLSX)}`)
            .fontSize(12)
            .fontColor(AppColors.TextPrimary)
          Text(`Y: ${this.formatStickValue(this.displayLSY)}`)
            .fontSize(12)
            .fontColor(AppColors.TextPrimary)
        }
        
        Column({ space: 4 }) {
          Text('Right Stick'))
            .fontSize(11)
            .fontColor(AppColors.TextSecondary)
          Text(`X: ${this.formatStickValue(this.displayRSX)}`)
            .fontSize(12)
            .fontColor(AppColors.TextPrimary)
          Text(`Y: ${this.formatStickValue(this.displayRSY)}`)
            .fontSize(12)
            .fontColor(AppColors.TextPrimary)
        }
        
        Column({ space: 4 }) {
          Text('Triggers'))
            .fontSize(11)
            .fontColor(AppColors.TextSecondary)
          Text(`LT: ${this.displayLT}`)
            .fontSize(12)
            .fontColor(AppColors.TextPrimary)
          Text(`RT: ${this.displayRT}`)
            .fontSize(12)
            .fontColor(AppColors.TextPrimary)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.Surface)
    .borderRadius(12)
  }
  
  @Builder
  buildButtonIndicator($$: ButtonIndicatorParams) {
    Text($$.name)
      .fontSize(12)
      .fontColor(($$.buttons & $$.flag) !== 0 ? AppColors.TextOnPrimary : AppColors.TextSecondary)
      .backgroundColor(($$.buttons & $$.flag) !== 0 ? AppColors.Success : AppColors.SurfaceDark)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(4)
      .margin(4)
  }
}
