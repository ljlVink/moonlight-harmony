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

import { usbManager } from '@kit.BasicServicesKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { commonEventManager } from '@kit.BasicServicesKit';
import { AbstractController } from './AbstractController';
import { UsbDriverListener, UsbDriverStateListener } from './UsbDriverListener';
import { Xbox360Controller } from './Xbox360Controller';
import { XboxOneController } from './XboxOneController';
import { Dualshock4Controller } from './Dualshock4Controller';
import { DualSenseController } from './DualSenseController';
import { SwitchProController } from './SwitchProController';
import { NativeHidController } from './NativeHidController';
import { SettingsService } from '../../service/SettingsService';
import nativeLib from 'libmoonlight_nativelib.so';

interface NativeUsbHelper {
  reattachKernelDriver(fd: number, interfaceNumber: number): number;
}

interface NativeLibWithUsbHelper {
  UsbHelper?: NativeUsbHelper;
}

const usbHelper = (nativeLib as NativeLibWithUsbHelper).UsbHelper;

const TAG = '[USB-SERVICE]';

const USB_DEVICE_ATTACHED = 'usual.event.hardware.usb.action.USB_DEVICE_ATTACHED';
const USB_DEVICE_DETACHED = 'usual.event.hardware.usb.action.USB_DEVICE_DETACHED';

export class UsbDriverService implements UsbDriverListener {
  private static instance: UsbDriverService;
  
  private started: boolean = false;
  private controllers: AbstractController[] = [];
  private listener: UsbDriverListener | null = null;
  private stateListener: UsbDriverStateListener | null = null;
  private nextDeviceId: number = 1000;
  
  private processedDevices: Set<string> = new Set();
  
  private usbSubscriber: commonEventManager.CommonEventSubscriber | null = null;
  
  private rescanTimerId: number | null = null;
  private static readonly RESCAN_INTERVAL_MS: number = 5000;
  private ddkEnabled: boolean = false;
  private resetTimerId: number | null = null;
  
  private constructor() {
    console.info(`${TAG} 创建 USB 驱动服务实例`);
  }
  
  static getInstance(): UsbDriverService {
    if (!UsbDriverService.instance) {
      UsbDriverService.instance = new UsbDriverService();
    }
    return UsbDriverService.instance;
  }
  
  setListener(listener: UsbDriverListener | null): void {
    this.listener = listener;
    
    if (listener) {
      for (const controller of this.controllers) {
        if (controller.isReady()) {
          listener.deviceAdded(controller);
        }
      }
    }
  }
  
  setStateListener(stateListener: UsbDriverStateListener | null): void {
    this.stateListener = stateListener;
  }

  setControllerProtocolType(controllerId: number, protocolType: number): boolean {
    const controller = this.controllers.find(c => c.getControllerId() === controllerId);
    if (controller && controller instanceof NativeHidController) {
      controller.setForceProtocolType(protocolType);
      return true;
    }
    console.warn(`${TAG} 未找到控制器 ID=${controllerId} 或不支持协议切换`);
    return false;
  }
  
  async rescanDevices(): Promise<void> {
    console.info(`${TAG} 手动触发设备重新扫描`);
    this.processedDevices.clear();
    await this.enumerateDevices();
  }
  
  async start(): Promise<void> {
    if (this.started) {
      console.info(`${TAG} 服务已启动`);
      return;
    }
    
    console.info(`${TAG} 启动 USB 驱动服务`);
    this.started = true;
    
    if (this.resetTimerId !== null) {
      clearTimeout(this.resetTimerId);
      this.resetTimerId = null;
      console.info(`${TAG} 已取消待执行的内核驱动重绑定`);
    }
    
    await this.subscribeUsbEvents();
    
    await this.enumerateDevices();
    
    this.startRescanTimer();
  }
  
  private startRescanTimer(): void {
    if (this.rescanTimerId !== null) {
      return;
    }
    
    console.info(`${TAG} 启动设备重新扫描定时器，间隔 ${UsbDriverService.RESCAN_INTERVAL_MS}ms`);
    this.rescanTimerId = setInterval(() => {
      this.checkAndRescanDevices();
    }, UsbDriverService.RESCAN_INTERVAL_MS);
  }
  
  private stopRescanTimer(): void {
    if (this.rescanTimerId !== null) {
      clearInterval(this.rescanTimerId);
      this.rescanTimerId = null;
      console.info(`${TAG} 停止设备重新扫描定时器`);
    }
  }
  
  private async checkAndRescanDevices(): Promise<void> {
    try {
      const currentDevices = usbManager.getDevices();
      
      for (const device of currentDevices) {
        const deviceKey = `${device.vendorId}:${device.productId}:${device.busNum}:${device.devAddress}`;
        
        if (this.processedDevices.has(deviceKey)) {
          const controller = this.controllers.find(c => c.getDeviceKey() === deviceKey);
          
          const shouldReenumerate = !controller || !controller.isConnected();
          
          if (shouldReenumerate) {
            console.info(`${TAG} 检测到设备存在但控制器已断开，准备重新枚举: ${deviceKey}`);
            this.processedDevices.delete(deviceKey);
          }
        }
      }
      
      const hasUnprocessedDevices = currentDevices.some(device => {
        const deviceKey = `${device.vendorId}:${device.productId}:${device.busNum}:${device.devAddress}`;
        return !this.processedDevices.has(deviceKey);
      });
      
      if (hasUnprocessedDevices) {
        console.info(`${TAG} 检测到未处理的设备，执行重新枚举`);
        await this.enumerateDevices();
      }
    } catch (err) {
      console.error(`${TAG} 检查设备状态失败:`, err);
    }
  }
  
  private async subscribeUsbEvents(): Promise<void> {
    try {
      const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
        events: [USB_DEVICE_ATTACHED, USB_DEVICE_DETACHED]
      };
      
      this.usbSubscriber = await commonEventManager.createSubscriber(subscribeInfo);
      
      commonEventManager.subscribe(this.usbSubscriber, (err, data) => {
        if (err) {
          console.error(`${TAG} USB 事件接收错误:`, err);
          return;
        }
        
        console.info(`${TAG} 收到 USB 事件: ${data.event}`);
        
        if (data.event === USB_DEVICE_ATTACHED) {
          console.info(`${TAG} USB 设备已插入，延迟 500ms 后枚举设备`);
          setTimeout(() => {
            this.enumerateDevices();
          }, 500);
        } else if (data.event === USB_DEVICE_DETACHED) {
          console.info(`${TAG} USB 设备已拔出，检查控制器状态`);
          this.checkDetachedControllers();
        }
      });
      
      console.info(`${TAG} 已订阅 USB 设备插拔事件`);
    } catch (err) {
      console.error(`${TAG} 订阅 USB 事件失败:`, err);
    }
  }
  
  private unsubscribeUsbEvents(): void {
    if (this.usbSubscriber) {
      try {
        commonEventManager.unsubscribe(this.usbSubscriber);
        console.info(`${TAG} 已取消订阅 USB 事件`);
      } catch (err) {
        console.error(`${TAG} 取消订阅 USB 事件失败:`, err);
      }
      this.usbSubscriber = null;
    }
  }
  
  private checkDetachedControllers(): void {
    try {
      const currentDevices = usbManager.getDevices();
      const currentDeviceKeys = new Set<string>();
      
      for (const device of currentDevices) {
        const key = `${device.vendorId}:${device.productId}:${device.busNum}:${device.devAddress}`;
        currentDeviceKeys.add(key);
      }
      
      const controllersToRemove: AbstractController[] = [];
      for (const controller of this.controllers) {
        const deviceKey = controller.getDeviceKey();
        if (!currentDeviceKeys.has(deviceKey)) {
          console.info(`${TAG} 检测到控制器已断开: ${deviceKey}`);
          controllersToRemove.push(controller);
        }
      }
      
      for (const controller of controllersToRemove) {
        controller.stop();
      }
    } catch (err) {
      console.error(`${TAG} 检查断开设备失败:`, err);
    }
  }
  
  stop(): void {
    if (!this.started) {
      return;
    }
    
    const controllerCount = this.controllers.length;
    console.info(`${TAG} 停止 USB 驱动服务，需释放 ${controllerCount} 个控制器`);
    this.started = false;
    
    this.stopRescanTimer();
    
    this.unsubscribeUsbEvents();
    
    const releasedDeviceKeys = new Set(this.processedDevices);
    
    let stoppedCount = 0;
    while (this.controllers.length > 0) {
      const controller = this.controllers.shift();
      if (controller) {
        console.info(`${TAG} 释放控制器: ${controller.getName()} (VID=0x${controller.getVendorId().toString(16)}, PID=0x${controller.getProductId().toString(16)})`);
        controller.stop();
        stoppedCount++;
      }
    }
    
    this.processedDevices.clear();
    console.info(`${TAG} USB 驱动服务已停止，已释放 ${stoppedCount} 个控制器的 USB 独占`);
    
    if (stoppedCount > 0 && !this.ddkEnabled) {
      this.resetTimerId = setTimeout(() => {
        this.resetTimerId = null;
        this.resetReleasedUsbDevices(releasedDeviceKeys);
      }, 300);
    } else if (this.ddkEnabled) {
      console.info(`${TAG} DDK 模式，跳过内核 HID 驱动重绑定`);
    }
    
    this.ddkEnabled = false;
  }
  
  /**
   * 
   */
  private resetReleasedUsbDevices(releasedKeys: Set<string>): void {
    if (this.started) {
      console.info(`${TAG} 服务已重新启动，跳过 USB 设备内核驱动重绑定`);
      return;
    }
    if (!usbHelper) {
      console.warn(`${TAG} UsbHelper native 模块不可用，无法重绑定内核驱动`);
      return;
    }
    
    try {
      const devices: usbManager.USBDevice[] = usbManager.getDevices();
      let resetCount = 0;
      
      for (let i = 0; i < devices.length; i++) {
        const device = devices[i];
        const key = `${device.vendorId}:${device.productId}:${device.busNum}:${device.devAddress}`;
        
        if (!releasedKeys.has(key)) continue;
        if (!this.deviceHasHidInterface(device)) continue;
        
        try {
          if (!usbManager.hasRight(device.name)) {
            console.warn(`${TAG} 设备重置跳过（无权限）: ${device.name}`);
            continue;
          }
          
          const pipe = usbManager.connectDevice(device);
          
          const fd = usbManager.getFileDescriptor(pipe);
          
          if (fd >= 0 && device.configs) {
            for (let ci = 0; ci < device.configs.length; ci++) {
              const config = device.configs[ci];
              if (!config.interfaces) continue;
              for (let ii = 0; ii < config.interfaces.length; ii++) {
                const iface = config.interfaces[ii];
                if (iface.clazz === 3) { // USB_CLASS_HID
                  usbHelper.reattachKernelDriver(fd, iface.id);
                }
              }
            }
          }
          
          usbManager.closePipe(pipe);
          resetCount++;
          console.info(`${TAG} USB 设备内核驱动重绑定完成: ${device.name}`);
        } catch (e) {
          console.warn(`${TAG} USB 设备重置失败 (${device.name}):`, e);
        }
      }
      
      if (resetCount > 0) {
        console.info(`${TAG} 已尝试重绑定 ${resetCount} 个 USB 设备的内核 HID 驱动`);
      }
    } catch (e) {
      console.warn(`${TAG} resetReleasedUsbDevices 异常:`, e);
    }
  }
  
  private deviceHasHidInterface(device: usbManager.USBDevice): boolean {
    if (!device.configs) return false;
    for (let ci = 0; ci < device.configs.length; ci++) {
      const config = device.configs[ci];
      if (!config.interfaces) continue;
      for (let ii = 0; ii < config.interfaces.length; ii++) {
        if (config.interfaces[ii].clazz === 3) return true; // USB_CLASS_HID
      }
    }
    return false;
  }
  
  private async enumerateDevices(): Promise<void> {
    try {
      const devices: usbManager.USBDevice[] = usbManager.getDevices();
      console.info(`${TAG} 发现 ${devices.length} 个 USB 设备`);
      
      for (let i: number = 0; i < devices.length; i++) {
        const device: usbManager.USBDevice = devices[i];
        await this.handleUsbDevice(device);
      }
    } catch (err) {
      console.error(`${TAG} 枚举设备失败:`, err);
    }
  }
  
  private async handleUsbDevice(device: usbManager.USBDevice): Promise<void> {
    const deviceKey = `${device.vendorId}:${device.productId}:${device.busNum}:${device.devAddress}`;
    
    if (this.processedDevices.has(deviceKey)) {
      return;
    }
    
    const existingController = this.controllers.find(
      c => c.getDeviceKey() === deviceKey
    );
    
    if (existingController) {
      if (existingController.isConnected()) {
        console.info(`${TAG} 设备已有活跃控制器，跳过: ${deviceKey}`);
        return;
      } else {
        console.info(`${TAG} 检测到旧控制器已断开，移除后重新创建: ${deviceKey}`);
        existingController.stop();
      }
    }
    
    if (!this.shouldClaimDevice(device)) {
      return;
    }
    
    console.info(`${TAG} 检测到可驱动的设备: ${device.name} (VID=0x${device.vendorId.toString(16)}, PID=0x${device.productId.toString(16)})`);
    
    const hasPermission = usbManager.hasRight(device.name);
    
    if (!hasPermission) {
      console.info(`${TAG} 请求 USB 设备权限: ${device.name}`);
      
      if (this.stateListener) {
        this.stateListener.onUsbPermissionPromptStarting();
      }
      
      try {
        const granted = await usbManager.requestRight(device.name);
        
        if (this.stateListener) {
          this.stateListener.onUsbPermissionPromptCompleted();
        }
        
        if (!granted) {
          console.warn(`${TAG} 用户拒绝了 USB 权限: ${device.name}`);
          this.processedDevices.add(deviceKey);
          return;
        }
      } catch (err) {
        console.error(`${TAG} 请求权限失败:`, err);
        if (this.stateListener) {
          this.stateListener.onUsbPermissionPromptCompleted();
        }
        return;
      }
    }
    
    if (!this.started) {
      console.info(`${TAG} 服务已停止，放弃处理设备: ${device.name}`);
      return;
    }
    
    let pipe: usbManager.USBDevicePipe;
    try {
      pipe = usbManager.connectDevice(device);
      console.info(`${TAG} 成功连接设备: ${device.name}`);
    } catch (err) {
      console.error(`${TAG} 连接设备失败:`, err);
      return;
    }
    
    let controller: AbstractController | null = null;
    let driverName: string = '';
    
    if (XboxOneController.canClaimDevice(device)) {
      driverName = 'XboxOneController';
      controller = new XboxOneController(device, pipe, this.nextDeviceId++, this);
    } else if (Xbox360Controller.canClaimDevice(device)) {
      driverName = 'Xbox360Controller';
      controller = new Xbox360Controller(device, pipe, this.nextDeviceId++, this);
    } else if (SwitchProController.canClaimDevice(device)) {
      driverName = 'SwitchProController';
      controller = new SwitchProController(device, pipe, this.nextDeviceId++, this);
    } else if (DualSenseController.canClaimDevice(device)) {
      driverName = 'DualSenseController';
      controller = new DualSenseController(device, pipe, this.nextDeviceId++, this);
    } else if (Dualshock4Controller.canClaimDevice(device)) {
      driverName = 'Dualshock4Controller';
      controller = new Dualshock4Controller(device, pipe, this.nextDeviceId++, this);
    } else if (NativeHidController.canClaimDevice(device)) {
      driverName = 'NativeHidController';
      controller = new NativeHidController(device, pipe, this.nextDeviceId++, this);
    }
    
    if (controller) {
      controller.setDeviceLocation(device.busNum, device.devAddress, device.serial || '');
      
      const inputSettings = await SettingsService.getInstance().getInputSettings();
      if (inputSettings.ignoreDeviceDisconnect) {
        controller.setIgnoreDisconnect(true);
        console.info(`${TAG} 设备 ${device.name} 已启用忽略断开信号`);
      }

      console.info(`${TAG} DDK 高速轮询设置: ${inputSettings.ddkHighSpeedPolling}`);
      if (inputSettings.ddkHighSpeedPolling) {
        this.ddkEnabled = true;
        controller.setDdkPollingEnabled(true);
        console.info(`${TAG} 设备 ${device.name} 已启用 DDK 高速轮询`);
      }
      
      console.info(`${TAG} 使用驱动 [${driverName}] 处理设备: ${device.name}, Key=${controller.getDeviceKey()}`);
    } else {
      console.warn(`${TAG} 无法为设备创建控制器: ${device.name}`);
      usbManager.closePipe(pipe);
      return;
    }
    
    this.processedDevices.add(deviceKey);
    this.controllers.push(controller);
    
    if (!controller.start()) {
      console.error(`${TAG} 启动控制器失败`);
      this.controllers.pop();
      this.processedDevices.delete(deviceKey);
      usbManager.closePipe(pipe);
      return;
    }
    
    console.info(`${TAG} 控制器已启动: ID=${controller.getControllerId()}, Key=${deviceKey}`);
  }
  
  private shouldClaimDevice(device: usbManager.USBDevice): boolean {
    return XboxOneController.canClaimDevice(device) ||
           Xbox360Controller.canClaimDevice(device) ||
           SwitchProController.canClaimDevice(device) ||
           DualSenseController.canClaimDevice(device) ||
           Dualshock4Controller.canClaimDevice(device) ||
           NativeHidController.canClaimDevice(device);
  }
  
  async refreshDevices(): Promise<void> {
    if (!this.started) {
      return;
    }
    
    console.info(`${TAG} 刷新 USB 设备列表`);
    await this.enumerateDevices();
  }
  
  getControllerCount(): number {
    return this.controllers.length;
  }
  
  getControllers(): AbstractController[] {
    return [...this.controllers];
  }
  
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
    if (this.listener) {
      this.listener.reportControllerState(
        controllerId,
        buttonFlags,
        leftStickX,
        leftStickY,
        rightStickX,
        rightStickY,
        leftTrigger,
        rightTrigger
      );
    }
  }
  
  reportControllerMotion(
    controllerId: number,
    motionType: number,
    x: number,
    y: number,
    z: number
  ): void {
    if (this.listener) {
      this.listener.reportControllerMotion(controllerId, motionType, x, y, z);
    }
  }

  reportTouchpadInput(
    controllerId: number,
    active: boolean,
    x: number,
    y: number
  ): void {
    if (this.listener) {
      this.listener.reportTouchpadInput(controllerId, active, x, y);
    }
  }
  
  deviceRemoved(controller: AbstractController): void {
    const index = this.controllers.indexOf(controller);
    if (index >= 0) {
      this.controllers.splice(index, 1);
    }
    
    const deviceKey = controller.getDeviceKey();
    if (this.processedDevices.has(deviceKey)) {
      this.processedDevices.delete(deviceKey);
    }
    
    console.info(`${TAG} 控制器已移除: ID=${controller.getControllerId()}, Key=${deviceKey}`);
    
    if (this.listener) {
      this.listener.deviceRemoved(controller);
    }
  }
  
  deviceAdded(controller: AbstractController): void {
    console.info(`${TAG} 控制器已添加: ID=${controller.getControllerId()}, Key=${controller.getDeviceKey()}`);
    
    if (this.listener) {
      this.listener.deviceAdded(controller);
    }
  }
}
