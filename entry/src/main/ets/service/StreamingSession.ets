/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { StreamConfig, HdrMode, getSurroundAudioInfo } from '../model/StreamConfig';
import { InputEvent, InputType, ControllerButtonEvent, ControllerAxisEvent, ControllerButton } from '../model/InputEvent';
import { ComputerManager } from './ComputerManager';
import { ComputerInfo, selectBestAddress } from '../model/ComputerInfo';
import { NvHttp, LaunchConfig } from './NvHttp';
import { CryptoUtil } from '../utils/CryptoUtil';
import { common, abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import { GamepadManager } from './GamepadManager';
import { MoonlightButton } from './GamepadTypes';
import { MicrophoneStream } from './microphone/MicrophoneStream';
import { AudioVibrationService } from './AudioVibrationService';
import {
  MoonBridge,
  CONTROLLER_TYPE_UNKNOWN,
  CONTROLLER_TYPE_XBOX,
  CONTROLLER_TYPE_PS,
  LI_CCAP_ANALOG_TRIGGERS,
  LI_CCAP_RUMBLE,
  LI_CCAP_ACCEL,
  LI_CCAP_GYRO,
  MODIFIER_SHIFT,
  MODIFIER_CTRL,
  MODIFIER_ALT,
  MODIFIER_META,
  VK_SHIFT,
  VK_CONTROL,
  VK_MENU,
  VK_LWIN,
  KEY_ACTION_DOWN,
  KEY_ACTION_UP
} from './MoonBridge';
import nativeLib from 'libmoonlight_nativelib.so';

// =============================================================================
// =============================================================================

export interface StreamStats {
  fps: number;
  renderedFps: number;
  bitrate: number;         // Kbps
  latency: number;
  hostLatency: number;
  networkLatency: number;
  packetLoss: number;      // %
  decodedFrames: number;
  droppedFrames: number;
  globalAvgDecodeLatency: number;
  globalAvgHostLatency: number;
  globalAvgFps: number;
  droppedByL1: number;     // L1: sync drain-to-latest
  droppedByL2: number;
  droppedByL3: number;
  droppedByL4: number;
  droppedByL5: number;
}

export interface DecoderCapabilities {
  supportsH264: boolean;
  supportsHEVC: boolean;
  supportsAV1: boolean;
  maxWidth: number;
  maxHeight: number;
  maxFps: number;
  supportsLowLatency: boolean;
  supports4K60: boolean;
  supports4K120: boolean;
  supports1080p120: boolean;
  maxInstances: number;
}

/**
export type HdrStateCallback = (isHdr: boolean) => void;

/**
export type CodecStateCallback = (codec: string) => void;

/**
export type ResolutionChangedCallback = (width: number, height: number) => void;

// =============================================================================
// =============================================================================

interface NativeModule {
  init(callbacks: StreamCallbacks): void;
  startConnection(
    address: string, appVersion: string, gfeVersion: string, rtspSessionUrl: string,
    serverCodecModeSupportFlags: number, width: number, height: number, fps: number,
    bitrate: number, packetSize: number, streamingRemotely: number,
    audioConfiguration: number, supportedVideoFormats: number, clientRefreshRateX100: number,
    riAesKey: ArrayBuffer, riAesIv: ArrayBuffer, videoCapabilities: number,
    colorSpace: number, colorRange: number, hdrMode: number,
    enableMic: boolean, controlOnly: boolean
  ): number;
  stopConnection(): void;
  interruptConnection(): void;
  resumeDecoder(): void;
  setVideoSurface(surfaceId: string): boolean;
  releaseVideoSurface(): void;
  getVideoStats(): VideoStats;
  getDecoderCapabilities(): DecoderCapabilities;
  setDecoderBufferCount(count: number): void;
  setDecoderSyncMode(enabled: boolean): void;
  isDecoderSyncMode(): boolean;
  setVsyncEnabled(enabled: boolean): void;
  isVsyncEnabled(): boolean;
  setVrrEnabled(enabled: boolean): void;
  setSpatialAudioEnabled(enabled: boolean): void;
  isSpatialAudioEnabled(): boolean;
  setAudioVolume(volume: number): boolean;
  setPerformanceModeEnabled(enabled: boolean): void;
  getPerformanceModeEnabled(): boolean;
  setBassVibrationConfig(enabled: boolean, sensitivity: number, sceneMode?: number): void;
  getEstimatedRttInfo(): number;
  sendMouseMove(deltaX: number, deltaY: number): void;
  sendMouseButton(buttonEvent: number, mouseButton: number): void;
  sendKeyboardInput(keyCode: number, keyAction: number, modifiers: number, flags: number): void;
  sendUtf8Text(text: string): void;
  sendMultiControllerInput(
    controllerNumber: number, activeGamepadMask: number, buttonFlags: number,
    leftTrigger: number, rightTrigger: number, leftStickX: number, leftStickY: number,
    rightStickX: number, rightStickY: number
  ): void;
  sendControllerArrivalEvent(
    controllerNumber: number, activeGamepadMask: number, type: number,
    supportedButtonFlags: number, capabilities: number
  ): number;
  sendControllerMotionEvent(
    controllerNumber: number, motionType: number, x: number, y: number, z: number
  ): number;
}

interface StreamCallbacks {
  drSetup?: (videoFormat: number, width: number, height: number, redrawRate: number) => void;
  drStart?: () => void;
  drStop?: () => void;
  drCleanup?: () => void;
  drSubmitDecodeUnit?: (data: ArrayBuffer, frameNumber: number, frameType: number) => void;
  arInit?: (audioConfiguration: number, sampleRate: number, samplesPerFrame: number) => void;
  arStart?: () => void;
  arStop?: () => void;
  arCleanup?: () => void;
  arPlaySample?: (samples: Int16Array) => void;
  stageStarting?: (stage: number) => void;
  stageComplete?: (stage: number) => void;
  stageFailed?: (stage: number, errorCode: number) => void;
  connectionStarted?: () => void;
  connectionTerminated?: (errorCode: number) => void;
  connectionStatusUpdate?: (connectionStatus: number) => void;
  setHdrMode?: (enabled: boolean) => void;
  rumble?: (controllerNumber: number, lowFreqMotor: number, highFreqMotor: number) => void;
  rumbleTriggers?: (controllerNumber: number, leftTrigger: number, rightTrigger: number) => void;
  setMotionEventState?: (controllerNumber: number, motionType: number, reportRateHz: number) => void;
  setControllerLED?: (controllerNumber: number, r: number, g: number, b: number) => void;
  resolutionChanged?: (width: number, height: number) => void;
  bassEnergy?: (intensity: number, lowFreqRatio: number) => void;
}

interface VideoStats {
  framesDecoded: number;
  framesDropped: number;
  avgDecodeTimeMs: number;
  fps: number;
  renderedFps: number;
  bitrate: number;
  hostLatency: number;
  totalDecodeTimeMs: number;
  validDecodeFrames: number;
  totalHostLatencyMs: number;
  framesWithHostLatency: number;
  globalAvgFps: number;
  framesLost: number;
  totalFrames: number;
  droppedByL1: number;
  droppedByL2: number;
  droppedByL3: number;
  droppedByL4: number;
  droppedByL5: number;
  droppedByQueueOverflow: number;
  droppedByTimeout: number;
}

interface ControllerState {
  buttonFlags: number;
  leftTrigger: number;
  rightTrigger: number;
  leftStickX: number;
  leftStickY: number;
  rightStickX: number;
  rightStickY: number;
}

// =============================================================================
// =============================================================================

/**
const nativeModuleRef = nativeLib as NativeModule;

/**
const VIDEO_FORMAT_MASK_10BIT = 0xAA00;
const VIDEO_FORMAT_MASK_H264 = 0x000F;
const VIDEO_FORMAT_MASK_H265 = 0x0F00;
const VIDEO_FORMAT_MASK_AV1 = 0xF000;

/**
const STAGE_NAMES: Record<number, string> = {
  1: '正在初始化平台...',
  2: '正在解析服务器地址...',
  3: '正在建立 RTSP 连接...',
  4: '正在初始化控制通道...',
  5: '正在初始化视频通道...',
  6: '正在初始化音频通道...',
  7: '正在初始化输入通道...',
  8: '正在启动控制流...',
  9: '正在启动视频流...',
  10: '正在启动音频流...',
  11: '正在启动输入流...'
};

/**
const STANDARD_BUTTON_FLAGS =
  MoonlightButton.A | MoonlightButton.B | MoonlightButton.X | MoonlightButton.Y |
  MoonlightButton.UP | MoonlightButton.DOWN | MoonlightButton.LEFT | MoonlightButton.RIGHT |
  MoonlightButton.LB | MoonlightButton.RB |
  MoonlightButton.LS | MoonlightButton.RS |
  MoonlightButton.START | MoonlightButton.BACK | MoonlightButton.SPECIAL;

// =============================================================================
// StreamingSession
// =============================================================================

/**
 *
 */
export class StreamingSession {

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  static getDecoderCapabilities(): DecoderCapabilities {
    return nativeModuleRef.getDecoderCapabilities();
  }

  /**
   * @returns [minBrightness, maxBrightness, maxAverageBrightness] (nits)
   */
  private static getBrightnessRange(): number[] {
    let minBrightness = 2;
    let maxBrightness = 500;
    let maxAverageBrightness = 200;

    try {
      const brightnessInfo = display.getBrightnessInfo(0);
      console.info(`[Brightness] sdrNits=${brightnessInfo.sdrNits}, ` +
        `currentHeadroom=${brightnessInfo.currentHeadroom}, maxHeadroom=${brightnessInfo.maxHeadroom}`);

      if (brightnessInfo.sdrNits > 0) {
        maxBrightness = brightnessInfo.sdrNits * brightnessInfo.maxHeadroom;
        maxAverageBrightness = brightnessInfo.sdrNits;
      }
    } catch (err) {
      console.warn(`[Brightness] getBrightnessInfo 不可用，使用默认值: ${err}`);
    }

    console.info(`[Brightness] min=${minBrightness}, max=${maxBrightness}, avg=${maxAverageBrightness} nits`);
    return [minBrightness, maxBrightness, maxAverageBrightness];
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  private nativeModule: NativeModule;
  private computerId: string = '';
  private appId: number = 0;
  private config: StreamConfig | null = null;
  private surfaceId: string = '';
  private isRunning: boolean = false;
  /**
  private userInitiatedStop: boolean = false;
  private computer: ComputerInfo | null = null;
  private nvHttp: NvHttp | null = null;
  private riKey: ArrayBuffer | null = null;
  private riKeyId: number = 0;
  private displayGuid: string = '';
  private useVdd: boolean = false;

  private serverAppVersion: string = '';
  private serverGfeVersion: string = '';
  private serverCodecModeSupport: number = 0;
  private rtspSessionUrl: string = '';

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  private hdrStateCallback: HdrStateCallback | null = null;
  private codecStateCallback: CodecStateCallback | null = null;
  private connectionTerminatedCallback: ((errorCode: number) => void) | null = null;
  private resolutionChangedCallback: ResolutionChangedCallback | null = null;
  private stageProgressCallback: ((stage: number, stageName: string) => void) | null = null;
  private connectionStatusCallback: ((connectionStatus: number) => void) | null = null;

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  private virtualControllerArrived: boolean = false;
  private physicalControllerArrived = new Set<number>();
  private activeGamepadMask: number = 0;
  private controllerState: ControllerState = {
    buttonFlags: 0,
    leftTrigger: 0,
    rightTrigger: 0,
    leftStickX: 0,
    leftStickY: 0,
    rightStickX: 0,
    rightStickY: 0
  };

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  private stats: StreamStats = {
    fps: 0, renderedFps: 0, bitrate: 0, latency: 0,
    hostLatency: 0, networkLatency: 0, packetLoss: 0,
    decodedFrames: 0, droppedFrames: 0,
    globalAvgDecodeLatency: 0, globalAvgHostLatency: 0, globalAvgFps: 0,
    droppedByL1: 0, droppedByL2: 0, droppedByL3: 0, droppedByL4: 0, droppedByL5: 0
  };
  private lastValidStats: StreamStats | null = null;

  private prevSnapshotLost: number = 0;
  private prevSnapshotTotal: number = 0;
  private activeSnapshotLost: number = 0;
  private activeSnapshotTotal: number = 0;
  private lastWindowFlipTime: number = 0;

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  private audioVibrationService: AudioVibrationService = new AudioVibrationService();
  private microphoneStream: MicrophoneStream | null = null;
  private abilityContext: common.UIAbilityContext | undefined = undefined;

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  constructor() {
    this.nativeModule = nativeLib as NativeModule;
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  setHdrStateCallback(callback: HdrStateCallback | null): void {
    this.hdrStateCallback = callback;
  }

  setCodecStateCallback(callback: CodecStateCallback | null): void {
    this.codecStateCallback = callback;
  }

  setConnectionTerminatedCallback(callback: ((errorCode: number) => void) | null): void {
    this.connectionTerminatedCallback = callback;
  }

  setResolutionChangedCallback(callback: ResolutionChangedCallback | null): void {
    this.resolutionChangedCallback = callback;
  }

  setStageProgressCallback(callback: ((stage: number, stageName: string) => void) | null): void {
    this.stageProgressCallback = callback;
  }

  setConnectionStatusCallback(callback: ((connectionStatus: number) => void) | null): void {
    this.connectionStatusCallback = callback;
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  async start(
    computerId: string,
    appId: number,
    config: StreamConfig,
    surfaceId: string,
    context?: common.UIAbilityContext,
    displayGuid?: string,
    useVdd?: boolean
  ): Promise<void> {
    this.computerId = computerId;
    this.appId = appId;
    this.config = config;
    this.surfaceId = surfaceId;
    this.displayGuid = displayGuid || '';
    this.useVdd = useVdd || false;
    this.abilityContext = context;

    console.info(`开始串流: computer=${computerId}, app=${appId}`);
    console.info(`配置: ${config.width}x${config.height}@${config.fps}fps, ${config.bitrate}kbps, ${config.codec}`);
    console.info(`HDR: hdr=${config.hdr}, hdrMode=${config.hdrMode}, colorRange=${config.colorRange}`);
    if (this.displayGuid || this.useVdd) {
      console.info(`显示器: displayGuid=${this.displayGuid}, useVdd=${this.useVdd}`);
    }

    try {
      await this.resolveComputer(computerId, context);
      await this.fetchServerInfo();
      this.generateInputKey();
      await this.initializeNative();
      this.applyPreConnectionSettings(config);
      await this.setupVideoSurface();

      if (this.stageProgressCallback) {
        this.stageProgressCallback(0, '正在启动应用...');
      }
      const cachedCurrentGame = await this.getCachedCurrentGame();
      await this.launchApp(cachedCurrentGame);
      await this.connectToServer();
      this.applyPostConnectionSettings(config);

      this.isRunning = true;
    } catch (err) {
      await this.cleanup();
      throw new Error(`串流会话启动失败: ${(err as Error).message}`);
    }
  }

  async stop(): Promise<void> {
    console.info('停止串流');
    this.userInitiatedStop = true;
    this.isRunning = false;
    this.resetControllerState();
    GamepadManager.getInstance().stopAllSensors();
    this.audioVibrationService.stop();
    await this.cleanup();
  }

  async quitApp(): Promise<boolean> {
    console.info('退出远程应用');
    this.userInitiatedStop = true;
    let quitSuccess = false;

    if (this.nvHttp) {
      try {
        quitSuccess = await this.nvHttp.quitApp();
        console.info(quitSuccess ? '远程应用已退出' : '退出远程应用失败');
      } catch (err) {
        console.error('退出远程应用出错:', err);
      }
    }

    this.isRunning = false;
    await this.cleanup();
    return quitSuccess;
  }

  resumeDecoder(): void {
    if (!this.isRunning) {
      console.warn('[StreamingSession] 串流已停止，无需恢复解码器');
      return;
    }
    try {
      (nativeLib as NativeModule).resumeDecoder();
      console.info('[StreamingSession] 解码器恢复命令已发送');
    } catch (err) {
      console.error('[StreamingSession] 恢复解码器失败:', err);
    }
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  getEffectiveConfig(): StreamConfig | null {
    return this.config;
  }

  getCurrentBitrate(): number {
    return this.config?.bitrate || 0;
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  async setBitrate(bitrate: number): Promise<boolean> {
    if (!this.nvHttp) return false;
    try {
      const success = await this.nvHttp.setBitrate(bitrate);
      if (success && this.config) this.config.bitrate = bitrate;
      return success;
    } catch {
      return false;
    }
  }

  async sendSuperCmd(cmdId: string): Promise<boolean> {
    if (!this.nvHttp) return false;
    try {
      return await this.nvHttp.sendSuperCmd(cmdId);
    } catch {
      return false;
    }
  }

  async rotateDisplay(angle: number, displayName?: string): Promise<boolean> {
    if (!this.nvHttp) {
      console.warn('StreamingSession: rotateDisplay 失败 - nvHttp 未初始化');
      return false;
    }
    try {
      return await this.nvHttp.rotateDisplay(angle, displayName);
    } catch (err) {
      console.warn(`StreamingSession: rotateDisplay 失败: ${err}`);
      return false;
    }
  }

  setAudioVolume(volume: number): boolean {
    return this.nativeModule.setAudioVolume(volume);
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  /**
   * @param keyAction 0x03=KEY_DOWN, 0x04=KEY_UP
   * @param modifiers SHIFT=0x01, CTRL=0x02, ALT=0x04, META=0x08
   */
  sendKeyboardInput(keyCode: number, keyAction: number, modifiers: number = 0): void {
    if (!this.isRunning) return;
    this.nativeModule.sendKeyboardInput(keyCode, keyAction, modifiers, 0);
  }

  sendKeys(keyCodes: number[]): void {
    if (!this.isRunning || keyCodes.length === 0) return;

    let modifier = 0;
    for (const key of keyCodes) {
      this.nativeModule.sendKeyboardInput(key, KEY_ACTION_DOWN, modifier, 0);
      modifier |= StreamingSession.getModifierForKey(key);
    }

    setTimeout(() => {
      for (let i = keyCodes.length - 1; i >= 0; i--) {
        modifier &= ~StreamingSession.getModifierForKey(keyCodes[i]);
        this.nativeModule.sendKeyboardInput(keyCodes[i], KEY_ACTION_UP, modifier, 0);
      }
    }, 25);
  }

  sendUtf8Text(text: string): void {
    if (!this.isRunning || text.length === 0) return;
    this.nativeModule.sendUtf8Text(text);
  }

  /**
   *
   */
  sendVirtualControllerInput(
    buttonFlags: number, leftTrigger: number, rightTrigger: number,
    leftStickX: number, leftStickY: number,
    rightStickX: number, rightStickY: number,
  ): void {
    if (!this.isRunning) return;
    const controllerIndex = 0;
    this.ensureVirtualControllerArrival(controllerIndex);
    this.nativeModule.sendMultiControllerInput(
      controllerIndex, this.activeGamepadMask,
      buttonFlags, leftTrigger, rightTrigger,
      leftStickX, leftStickY, rightStickX, rightStickY
    );
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  sendInput(input: InputEvent): void {
    if (!this.isRunning) return;

    if (input.type === InputType.CONTROLLER_BUTTON) {
      this.handleControllerButton(input as ControllerButtonEvent);
    } else if (input.type === InputType.CONTROLLER_AXIS) {
      this.handleControllerAxis(input as ControllerAxisEvent);
    }
  }

  sendGamepadState(
    controllerIndex: number,
    buttons: number,
    leftStickX: number, leftStickY: number,
    rightStickX: number, rightStickY: number,
    leftTrigger: number, rightTrigger: number,
    controllerType: number = CONTROLLER_TYPE_XBOX
  ): void {
    if (!this.isRunning) return;

    if (controllerIndex < 0 || controllerIndex > 3) {
      console.warn(`[Gamepad] controllerIndex 越界: ${controllerIndex}, 钳位到 0`);
      controllerIndex = 0;
    }

    this.ensurePhysicalControllerArrival(controllerIndex, controllerType);
    this.nativeModule.sendMultiControllerInput(
      controllerIndex, this.activeGamepadMask,
      buttons, leftTrigger, rightTrigger,
      leftStickX, leftStickY, rightStickX, rightStickY
    );
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  getStats(): StreamStats {
    try {
      const vs = this.nativeModule.getVideoStats();
      this.stats.decodedFrames = vs.framesDecoded;
      this.stats.droppedFrames = vs.framesDropped;
      this.stats.fps = vs.fps || 0;
      this.stats.renderedFps = vs.renderedFps || 0;
      this.stats.bitrate = vs.bitrate || 0;
      this.stats.latency = vs.avgDecodeTimeMs || 0;
      this.stats.hostLatency = vs.hostLatency || 0;

      const totalFrames = vs.totalFrames || 0;
      const framesLost = vs.framesLost || 0;
      const now = Date.now();
      if (this.lastWindowFlipTime === 0) {
        this.lastWindowFlipTime = now;
        this.activeSnapshotLost = framesLost;
        this.activeSnapshotTotal = totalFrames;
        this.prevSnapshotLost = framesLost;
        this.prevSnapshotTotal = totalFrames;
      } else if (now - this.lastWindowFlipTime >= 1000) {
        this.prevSnapshotLost = this.activeSnapshotLost;
        this.prevSnapshotTotal = this.activeSnapshotTotal;
        this.activeSnapshotLost = framesLost;
        this.activeSnapshotTotal = totalFrames;
        this.lastWindowFlipTime = now;
      }
      const windowLost = framesLost - this.prevSnapshotLost;
      const windowTotal = totalFrames - this.prevSnapshotTotal;
      this.stats.packetLoss = windowTotal > 0 ? (windowLost / windowTotal * 100) : 0;

      this.stats.droppedByL1 = vs.droppedByL1 || 0;
      this.stats.droppedByL2 = vs.droppedByL2 || 0;
      this.stats.droppedByL3 = vs.droppedByL3 || 0;
      this.stats.droppedByL4 = vs.droppedByL4 || 0;
      this.stats.droppedByL5 = vs.droppedByL5 || 0;

      if ((vs.validDecodeFrames || 0) > 0) {
        this.stats.globalAvgDecodeLatency = (vs.totalDecodeTimeMs || 0) / vs.validDecodeFrames;
      }
      if ((vs.framesWithHostLatency || 0) > 0) {
        this.stats.globalAvgHostLatency = (vs.totalHostLatencyMs || 0) / vs.framesWithHostLatency;
      }
      if (vs.globalAvgFps > 0) {
        this.stats.globalAvgFps = vs.globalAvgFps;
      }

      const rttInfo = this.nativeModule.getEstimatedRttInfo();
      if (rttInfo >= 0) {
        this.stats.networkLatency = Math.floor(rttInfo / 0x100000000);
      }
    } catch (_) { /* ignore */ }

    const copy: StreamStats = {
      fps: this.stats.fps,
      renderedFps: this.stats.renderedFps,
      bitrate: this.stats.bitrate,
      latency: this.stats.latency,
      hostLatency: this.stats.hostLatency,
      networkLatency: this.stats.networkLatency,
      packetLoss: this.stats.packetLoss,
      decodedFrames: this.stats.decodedFrames,
      droppedFrames: this.stats.droppedFrames,
      globalAvgDecodeLatency: this.stats.globalAvgDecodeLatency,
      globalAvgHostLatency: this.stats.globalAvgHostLatency,
      globalAvgFps: this.stats.globalAvgFps,
      droppedByL1: this.stats.droppedByL1,
      droppedByL2: this.stats.droppedByL2,
      droppedByL3: this.stats.droppedByL3,
      droppedByL4: this.stats.droppedByL4,
      droppedByL5: this.stats.droppedByL5,
    };
    copy.fps = Math.round(copy.fps);
    copy.renderedFps = Math.round(copy.renderedFps);
    copy.bitrate = Math.round(copy.bitrate);

    if (copy.renderedFps > 0 || copy.latency > 0) {
      this.lastValidStats = copy;
    }
    return copy;
  }

  getSummaryStats(): StreamStats {
    const current = this.getStats();
    if (current.renderedFps > 0 || current.latency > 0) return current;
    return this.lastValidStats || current;
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  private async resolveComputer(computerId: string, context?: common.UIAbilityContext): Promise<void> {
    const computerManager = ComputerManager.getInstance();
    const computerResult = computerManager.getComputer(computerId);
    if (!computerResult) throw new Error(`找不到电脑: ${computerId}`);
    this.computer = computerResult;
    this.nvHttp = new NvHttp(
      selectBestAddress(this.computer), this.computer.serverCert, context, this.computer.httpPort
    );
  }

  private async fetchServerInfo(): Promise<void> {
    if (!this.nvHttp) throw new Error('nvHttp 未初始化');
    const serverInfo = await this.nvHttp.getServerInfo();
    this.serverAppVersion = serverInfo.appVersion || '';
    this.serverGfeVersion = serverInfo.gfeVersion || '';
    this.serverCodecModeSupport = serverInfo.serverCodecModeSupport || 0;
    console.info(`服务器版本: app=${this.serverAppVersion}, gfe=${this.serverGfeVersion}, ` +
      `codecSupport=${this.serverCodecModeSupport}`);

    if (this.stageProgressCallback) {
      this.stageProgressCallback(0, '正在初始化...');
    }
  }

  private async getCachedCurrentGame(): Promise<number> {
    if (!this.nvHttp) return 0;
    const serverInfo = await this.nvHttp.getServerInfo();
    return serverInfo.currentGame || 0;
  }

  private generateInputKey(): void {
    this.riKey = CryptoUtil.generateAesKey();
    this.riKeyId = CryptoUtil.generateRandomUint32();
  }

  private applyPreConnectionSettings(config: StreamConfig): void {
    this.nativeModule.setSpatialAudioEnabled(config.enableSpatializer);
    if (config.enableSpatializer) {
      console.info('空间音频已启用');
    }
    if (config.performanceMode) {
      this.nativeModule.setPerformanceModeEnabled(true);
      console.info('性能模式已启用');
    }
    this.audioVibrationService.setSettings(
      config.enableAudioVibration, config.audioVibrationStrength, config.vibrationMode,
      config.audioVibrationSceneMode
    );
  }

  private applyPostConnectionSettings(config: StreamConfig): void {
    const sceneMode = this.audioVibrationService.getSceneModeInt();
    this.nativeModule.setBassVibrationConfig(config.enableAudioVibration, 1.0, sceneMode);
    if (config.enableAudioVibration) {
      console.info(`音频振动已启用, 强度=${config.audioVibrationStrength}, 模式=${config.vibrationMode}, 场景=${config.audioVibrationSceneMode}`);
    }
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  private async initializeNative(): Promise<void> {
    console.info('初始化 Native 模块');

    const callbacks: StreamCallbacks = {
      drSetup: (videoFormat: number, width: number, height: number, redrawRate: number): void => {
        const actualCodec = StreamingSession.detectCodec(videoFormat);
        const actualHdr = (videoFormat & VIDEO_FORMAT_MASK_10BIT) !== 0;
        console.info(`视频设置: format=0x${videoFormat.toString(16)}, ${width}x${height}@${redrawRate}, ` +
          `codec=${actualCodec}, HDR=${actualHdr}`);

        if (this.config && this.config.hdr !== actualHdr) {
          console.info(`HDR 状态更新: ${this.config.hdr} -> ${actualHdr}`);
          this.config.hdr = actualHdr;
        }
        if (this.codecStateCallback) this.codecStateCallback(actualCodec);
        if (this.hdrStateCallback) this.hdrStateCallback(actualHdr);
      },
      drStart: (): void => { console.info('视频解码器启动'); },
      drStop: (): void => { console.info('视频解码器停止'); },
      drCleanup: (): void => { console.info('视频解码器清理'); },
      arInit: (audioConfiguration: number, sampleRate: number, samplesPerFrame: number): void => {
        console.info(`音频初始化: config=${audioConfiguration}, rate=${sampleRate}, samples=${samplesPerFrame}`);
      },
      arStart: (): void => { console.info('音频渲染器启动'); },
      arStop: (): void => { console.info('音频渲染器停止'); },
      arCleanup: (): void => { console.info('音频渲染器清理'); },
      stageStarting: (stage: number): void => {
        const name = STAGE_NAMES[stage] || `阶段 ${stage}`;
        console.info(`连接阶段开始: ${stage} (${name})`);
        if (this.stageProgressCallback) this.stageProgressCallback(stage, name);
      },
      stageComplete: (stage: number): void => { console.info(`连接阶段完成: ${stage}`); },
      stageFailed: (stage: number, errorCode: number): void => {
        const name = STAGE_NAMES[stage] || `阶段 ${stage}`;
        console.error(`连接阶段失败: stage=${stage} (${name}), error=${errorCode}`);
      },
      connectionStarted: (): void => {
        console.info('连接已建立');
        this.isRunning = true;
        this.startMicrophoneIfNeeded();
      },
      connectionTerminated: (errorCode: number): void => {
        console.info(`连接已终止: ${errorCode}, userInitiated=${this.userInitiatedStop}`);
        this.isRunning = false;
        GamepadManager.getInstance().stopAllSensors();
        GamepadManager.getInstance().stopAllVibration();
        this.audioVibrationService.stop();
        this.stopMicrophone();
        if (!this.userInitiatedStop && this.connectionTerminatedCallback) {
          this.connectionTerminatedCallback(errorCode);
        }
      },
      connectionStatusUpdate: (status: number): void => {
        console.info(`连接状态更新: ${status}`);
        if (this.connectionStatusCallback) {
          this.connectionStatusCallback(status);
        }
      },
      setHdrMode: (enabled: boolean): void => {
        console.info(`HDR 模式变化通知: ${enabled}`);
        if (this.config && this.config.hdr !== enabled) {
          this.config.hdr = enabled;
        }
        if (this.hdrStateCallback) this.hdrStateCallback(enabled);
      },
      rumble: (cn: number, low: number, high: number): void => {
        GamepadManager.getInstance().handleRumble(cn, low, high);
      },
      rumbleTriggers: (cn: number, lt: number, rt: number): void => {
        GamepadManager.getInstance().handleRumbleTriggers(cn, lt, rt);
      },
      setMotionEventState: (cn: number, motionType: number, rateHz: number): void => {
        console.info(`传感器状态: controller=${cn}, type=${motionType}, rate=${rateHz}`);
        GamepadManager.getInstance().handleSetMotionEventState(cn, motionType, rateHz);
      },
      setControllerLED: (cn: number, r: number, g: number, b: number): void => {
        console.info(`LED: controller=${cn}, rgb=(${r},${g},${b})`);
      },
      resolutionChanged: (width: number, height: number): void => {
        console.info(`分辨率变化: ${width}x${height}`);
        if (this.resolutionChangedCallback) this.resolutionChangedCallback(width, height);
      },
      bassEnergy: (intensity: number, lowFreqRatio: number): void => {
        this.audioVibrationService.handleBassEnergy(intensity, lowFreqRatio);
      }
    };

    GamepadManager.getInstance().setSensorDataCallback(
      (cn: number, motionType: number, x: number, y: number, z: number): void => {
        if (this.isRunning) this.nativeModule.sendControllerMotionEvent(cn, motionType, x, y, z);
      }
    );

    this.nativeModule.init(callbacks);
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  private async setupVideoSurface(): Promise<void> {
    console.info(`设置视频 Surface: ${this.surfaceId}`);
    if (!this.nativeModule.setVideoSurface(this.surfaceId)) {
      throw new Error('设置视频 Surface 失败');
    }
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  private async launchApp(cachedCurrentGame: number = 0): Promise<void> {
    if (!this.nvHttp || !this.config || !this.riKey) {
      throw new Error('启动应用前提条件不满足');
    }

    console.info(`启动应用: appId=${this.appId}`);

    const riKeyHex = Array.from(new Uint8Array(this.riKey))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    let effectiveHdr = this.config.hdr;
    if (effectiveHdr) {
      try {
        const caps = StreamingSession.getDecoderCapabilities();
        if (!caps.supportsHEVC && !caps.supportsAV1) {
          console.warn('设备不支持 HEVC/AV1，自动禁用 HDR');
          effectiveHdr = false;
        }
      } catch {
        console.warn('获取解码器能力失败，禁用 HDR');
        effectiveHdr = false;
      }
    }
    if (this.config.hdr !== effectiveHdr) {
      console.info(`HDR 状态已调整: ${this.config.hdr} -> ${effectiveHdr}`);
      this.config.hdr = effectiveHdr;
    }

    const brightnessRange = StreamingSession.getBrightnessRange();

    const launchConfig: LaunchConfig = {
      appId: this.appId,
      width: this.config.width,
      height: this.config.height,
      fps: this.config.fps,
      bitrate: this.config.bitrate,
      sops: this.config.sops,
      localAudio: this.config.playLocalAudio,
      riKey: riKeyHex,
      riKeyId: this.riKeyId,
      audioConfig: getSurroundAudioInfo(this.config.audioConfig).toString(),
      enableHdr: effectiveHdr,
      hdrMode: effectiveHdr ? this.config.hdrMode : HdrMode.SDR,
      displayGuid: this.displayGuid,
      minBrightness: brightnessRange[0],
      maxBrightness: brightnessRange[1],
      maxAverageBrightness: brightnessRange[2],
      screenCombinationMode: this.config.screenCombinationMode,
    };

    try {
      if (cachedCurrentGame !== 0) {
        if (cachedCurrentGame === this.appId) {
          console.info('同一应用正在运行，尝试恢复会话...');
          try {
            this.rtspSessionUrl = await this.nvHttp.resumeApp(launchConfig);
            console.info(`恢复会话成功, sessionUrl=${this.rtspSessionUrl}`);
            return;
          } catch (resumeErr) {
            console.warn(`恢复失败: ${(resumeErr as Error).message}，尝试重新启动...`);
          }
        }

        console.info('正在退出当前运行的应用...');
        if (!(await this.nvHttp.quitApp())) {
          throw new Error('无法退出当前运行的应用，请在 PC 上手动退出');
        }
      }

      this.rtspSessionUrl = await this.nvHttp.launchApp(this.appId, launchConfig);
      console.info(`应用启动成功, sessionUrl=${this.rtspSessionUrl}`);
    } catch (err) {
      throw new Error(`启动应用失败: ${(err as Error).message}`);
    }
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  private async connectToServer(): Promise<void> {
    if (!this.config || !this.computer || !this.riKey) {
      throw new Error('配置未设置');
    }

    let supportedVideoFormats = 0x0001; // H.264
    let actualCodec: 'H.264' | 'HEVC' = this.config.codec;

    try {
      const caps = StreamingSession.getDecoderCapabilities();
      console.info(`解码器: H264=${caps.supportsH264}, HEVC=${caps.supportsHEVC}, AV1=${caps.supportsAV1}, ` +
        `max=${caps.maxWidth}x${caps.maxHeight}@${caps.maxFps}`);

      if (caps.supportsHEVC) {
        supportedVideoFormats |= 0x0100;
        if (this.config.hdr) supportedVideoFormats |= 0x0200;
      }
      if (caps.supportsAV1) {
        supportedVideoFormats |= 0x1000;
        if (this.config.hdr) supportedVideoFormats |= 0x2000;
      }
      if (this.config.codec === 'HEVC' && !caps.supportsHEVC) {
        console.warn('设备不支持 HEVC，降级到 H.264');
        actualCodec = 'H.264';
      }
    } catch (err) {
      console.warn(`获取解码器能力失败: ${(err as Error).message}`);
      actualCodec = 'H.264';
      supportedVideoFormats = 0x0001;
    }

    console.info(`编解码器: ${actualCodec}, formats=0x${supportedVideoFormats.toString(16)}`);

    const riAesIv = new ArrayBuffer(16);
    new DataView(riAesIv).setUint32(0, this.riKeyId, false);

    this.nativeModule.setDecoderBufferCount(this.config.decoderBufferCount);
    this.nativeModule.setDecoderSyncMode(this.config.enableSyncDecode);
    this.nativeModule.setVsyncEnabled(this.config.enableVsync);
    this.nativeModule.setVrrEnabled(this.config.enableVrr);

    console.info(`解码器: buffers=${this.config.decoderBufferCount}, sync=${this.config.enableSyncDecode}, ` +
      `vsync=${this.config.enableVsync}, vrr=${this.config.enableVrr}`);

    const result = this.nativeModule.startConnection(
      this.computer.address,
      this.serverAppVersion,
      this.serverGfeVersion,
      this.rtspSessionUrl,
      this.serverCodecModeSupport,
      this.config.width, this.config.height, this.config.fps,
      this.config.bitrate,
      1392, // packetSize (will be capped by moonlight-common-c for remote)
      2,    // streamingRemotely: STREAM_CFG_AUTO - let moonlight-common-c auto-detect
      this.config.audioConfig,
      supportedVideoFormats,
      this.config.clientRefreshRateX100,
      this.riKey, riAesIv,
      0x01 | 0x02, // videoCapabilities: DIRECT_SUBMIT | RFI_AVC
      this.config.hdr ? 2 : 1, // colorSpace: REC_2020 / REC_709
      this.config.colorRange,
      this.config.hdr ? this.config.hdrMode : HdrMode.SDR,
      this.config.microphoneEnabled,
      false // controlOnly
    );

    if (result !== 0) {
      throw new Error(`连接失败，错误码: ${result}`);
    }
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  private handleControllerButton(event: ControllerButtonEvent): void {
    const buttonValue = event.button as number;
    if (event.isPressed) {
      this.controllerState.buttonFlags |= buttonValue;
    } else {
      this.controllerState.buttonFlags &= ~buttonValue;
    }
    this.sendControllerState(event.controllerIndex);
  }

  private handleControllerAxis(event: ControllerAxisEvent): void {
    switch (event.axis) {
      case 0: this.controllerState.leftStickX = event.value; break;
      case 1: this.controllerState.leftStickY = event.value; break;
      case 2: this.controllerState.rightStickX = event.value; break;
      case 3: this.controllerState.rightStickY = event.value; break;
      case 4:
        this.controllerState.leftTrigger = StreamingSession.normalizeTrigger(event.value);
        break;
      case 5:
        this.controllerState.rightTrigger = StreamingSession.normalizeTrigger(event.value);
        break;
    }
    this.sendControllerState(event.controllerIndex);
  }

  private sendControllerState(controllerIndex: number): void {
    this.ensureVirtualControllerArrival(controllerIndex);
    const s = this.controllerState;
    this.nativeModule.sendMultiControllerInput(
      controllerIndex, this.activeGamepadMask,
      s.buttonFlags, s.leftTrigger, s.rightTrigger,
      s.leftStickX, s.leftStickY, s.rightStickX, s.rightStickY
    );
  }

  private ensureVirtualControllerArrival(controllerIndex: number): void {
    if (this.virtualControllerArrived) return;

    this.activeGamepadMask |= (1 << controllerIndex);
    const ret = this.nativeModule.sendControllerArrivalEvent(
      controllerIndex, this.activeGamepadMask,
      CONTROLLER_TYPE_XBOX, STANDARD_BUTTON_FLAGS,
      LI_CCAP_ANALOG_TRIGGERS | LI_CCAP_RUMBLE
    );

    if (ret >= 0) {
      this.virtualControllerArrived = true;
      console.info(`[VirtualCtrl] arrival sent, index=${controllerIndex}, mask=0x${this.activeGamepadMask.toString(16)}`);
    } else {
      console.warn(`[VirtualCtrl] arrival failed (ret=${ret}), will retry`);
    }
  }

  private ensurePhysicalControllerArrival(controllerIndex: number, controllerType: number = CONTROLLER_TYPE_XBOX): void {
    if (this.physicalControllerArrived.has(controllerIndex)) return;

    let capabilities = LI_CCAP_ANALOG_TRIGGERS | LI_CCAP_RUMBLE;
    capabilities |= GamepadManager.getInstance().getSensorCapabilities();

    let reportedType = controllerType;
    if ((capabilities & (LI_CCAP_ACCEL | LI_CCAP_GYRO)) && controllerType !== CONTROLLER_TYPE_PS) {
      reportedType = CONTROLLER_TYPE_UNKNOWN;
    }

    this.activeGamepadMask |= (1 << controllerIndex);
    const ret = this.nativeModule.sendControllerArrivalEvent(
      controllerIndex, this.activeGamepadMask,
      reportedType, STANDARD_BUTTON_FLAGS, capabilities
    );

    if (ret >= 0) {
      this.physicalControllerArrived.add(controllerIndex);
      console.info(`[Gamepad] arrival: index=${controllerIndex}, type=${reportedType}(orig=${controllerType}), ` +
        `caps=0x${capabilities.toString(16)}, mask=0x${this.activeGamepadMask.toString(16)}`);
    }
  }

  private resetControllerState(): void {
    this.virtualControllerArrived = false;
    this.physicalControllerArrived.clear();
    this.activeGamepadMask = 0;
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  private startMicrophoneIfNeeded(): void {
    if (!this.config?.microphoneEnabled) return;
    if (!MoonBridge.isMicrophoneRequested()) {
      console.info('主机未请求麦克风');
      return;
    }

    console.info('启动麦克风...');
    this.ensureMicPermissionAndStart();
  }

  private async ensureMicPermissionAndStart(): Promise<void> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      const tokenId = bundleInfo.appInfo.accessTokenId;
      const permission: Permissions = 'ohos.permission.MICROPHONE';

      let granted = atManager.checkAccessTokenSync(tokenId, permission)
        === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;

      if (!granted && this.abilityContext) {
        console.info('请求麦克风权限...');
        const result = await atManager.requestPermissionsFromUser(
          this.abilityContext, [permission]
        );
        granted = result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      }

      if (!granted) {
        console.error('麦克风权限被拒绝');
        return;
      }

      this.microphoneStream = new MicrophoneStream(MoonBridge);
      const success = await this.microphoneStream.start();
      if (!success) {
        console.error('麦克风启动失败');
        this.microphoneStream = null;
      }
    } catch (error) {
      console.error(`麦克风启动异常: ${(error as Error).message}`);
      this.microphoneStream = null;
    }
  }

  private stopMicrophone(): void {
    if (!this.microphoneStream) return;
    console.info('停止麦克风...');
    this.microphoneStream.stop().catch((error: Error) => {
      console.warn(`停止麦克风出错: ${error.message}`);
    });
    this.microphoneStream = null;
  }

  async toggleMicrophone(): Promise<boolean> {
    if (!this.microphoneStream) return false;
    return this.microphoneStream.toggle();
  }

  isMicrophoneActive(): boolean {
    return this.microphoneStream?.isRunning() ?? false;
  }

  isMicrophoneEnabled(): boolean {
    return this.config?.microphoneEnabled ?? false;
  }

  hasMicrophoneStream(): boolean {
    return this.microphoneStream !== null;
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  private async cleanup(): Promise<void> {
    console.info('清理串流资源');
    this.stopMicrophone();
    this.nativeModule.setPerformanceModeEnabled(false);
    try {
      this.nativeModule.stopConnection();
      this.nativeModule.releaseVideoSurface();
    } catch (err) {
      console.error('清理资源失败:', err);
    }
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  private static detectCodec(videoFormat: number): string {
    if ((videoFormat & VIDEO_FORMAT_MASK_AV1) !== 0) return 'AV1';
    if ((videoFormat & VIDEO_FORMAT_MASK_H265) !== 0) return 'HEVC';
    if ((videoFormat & VIDEO_FORMAT_MASK_H264) !== 0) return 'H.264';
    return 'HEVC';
  }

  private static normalizeTrigger(value: number): number {
    if (value >= 0 && value <= 255) return value;
    return Math.floor((value + 32768) / 256);
  }

  private static getModifierForKey(key: number): number {
    switch (key) {
      case VK_SHIFT: return MODIFIER_SHIFT;
      case VK_CONTROL: return MODIFIER_CTRL;
      case VK_MENU: return MODIFIER_ALT;
      case VK_LWIN: return MODIFIER_META;
      default: return 0;
    }
  }
}
