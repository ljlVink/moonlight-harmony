/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { common, abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import { MoonBridge, MoonBridgeClass } from '../MoonBridge';
import { MicrophoneConfig, MicrophoneState, MicrophoneStateListener } from './MicrophoneConfig';
import { MicrophoneStream } from './MicrophoneStream';

const TAG = '[MicManager]';

export class MicrophoneManager implements MicrophoneStateListener {
  private context: common.UIAbilityContext;
  private moonBridge: MoonBridgeClass;
  private microphoneStream: MicrophoneStream | null = null;
  private enableMic: boolean = false;
  
  private state: MicrophoneState = MicrophoneState.STOPPED;
  private hasPermission: boolean = false;
  
  private externalListener: MicrophoneStateListener | null = null;
  
  constructor(context: common.UIAbilityContext, moonBridge: MoonBridgeClass, enableMic: boolean) {
    this.context = context;
    this.moonBridge = moonBridge;
    this.enableMic = enableMic;
    console.info(TAG, `初始化麦克风管理器, enableMic=${enableMic}`);
  }
  
  setStateListener(listener: MicrophoneStateListener): void {
    this.externalListener = listener;
  }
  
  onMicrophoneStateChanged(state: MicrophoneState): void {
    this.state = state;
    if (this.externalListener) {
      this.externalListener.onMicrophoneStateChanged(state);
    }
  }
  
  onMicrophoneError(error: string): void {
    this.state = MicrophoneState.ERROR;
    if (this.externalListener) {
      this.externalListener.onMicrophoneError(error);
    }
  }
  
  getState(): MicrophoneState {
    return this.state;
  }
  
  async hasMicrophonePermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const tokenId = bundleInfo.appInfo.accessTokenId;
      
      const permission: Permissions = 'ohos.permission.MICROPHONE';
      const grantStatus = atManager.checkAccessTokenSync(tokenId, permission);
      
      this.hasPermission = grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      return this.hasPermission;
    } catch (error) {
      console.error(TAG, `检查麦克风权限失败: ${error}`);
      return false;
    }
  }
  
  async requestMicrophonePermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const permission: Permissions = 'ohos.permission.MICROPHONE';
      
      const result = await atManager.requestPermissionsFromUser(this.context, [permission]);
      
      if (result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        this.hasPermission = true;
        console.info(TAG, '麦克风权限已授予');
        return true;
      } else {
        console.warn(TAG, '麦克风权限被拒绝');
        return false;
      }
    } catch (error) {
      console.error(TAG, `请求麦克风权限失败: ${error}`);
      return false;
    }
  }
  
  async initializeMicrophoneStream(): Promise<boolean> {
    if (!this.enableMic) {
      console.info(TAG, '麦克风功能已禁用');
      return false;
    }
    
    if (this.microphoneStream !== null) {
      console.info(TAG, '麦克风流已存在');
      return true;
    }
    
    if (!await this.hasMicrophonePermission()) {
      console.warn(TAG, '需要麦克风权限');
      if (!await this.requestMicrophonePermission()) {
        return false;
      }
    }
    
    try {
      const settingsService = (await import('../SettingsService')).SettingsService.getInstance();
      const audioSettings = await settingsService.getAudioSettings();
      MicrophoneConfig.setOpusBitrate(audioSettings.micBitrate);

      this.microphoneStream = new MicrophoneStream(this.moonBridge);
      this.microphoneStream.setStateListener(this);

      if (!this.microphoneStream.isMicrophoneAvailable()) {
        console.info(TAG, '主机不支持麦克风功能');
        return true;
      }

      console.info(TAG, '麦克风流已初始化，等待用户启动');

      return true;

    } catch (error) {
      console.error(TAG, `初始化麦克风流失败: ${error}`);
      this.onMicrophoneError(`初始化失败: ${error}`);
      return false;
    }
  }
  
  isMicrophoneAvailable(): boolean {
    return this.microphoneStream?.isMicrophoneAvailable() || false;
  }
  
  isMicrophoneActive(): boolean {
    return this.microphoneStream?.isRunning() || false;
  }
  
  async toggleMicrophone(): Promise<boolean> {
    if (!this.microphoneStream) {
      if (!await this.initializeMicrophoneStream()) {
        return false;
      }
    }
    
    if (this.microphoneStream) {
      return this.microphoneStream.toggle();
    }
    
    return false;
  }
  
  async startMicrophone(): Promise<boolean> {
    if (!this.microphoneStream) {
      if (!await this.initializeMicrophoneStream()) {
        return false;
      }
    }
    
    if (this.microphoneStream) {
      await this.microphoneStream.resume();
      return true;
    }
    
    return false;
  }
  
  async stopMicrophone(): Promise<void> {
    if (this.microphoneStream) {
      await this.microphoneStream.pause();
    }
  }
  
  async cleanup(): Promise<void> {
    if (this.microphoneStream) {
      await this.microphoneStream.stop();
      this.microphoneStream = null;
    }
    
    this.state = MicrophoneState.STOPPED;
    console.info(TAG, '麦克风管理器已清理');
  }
}
