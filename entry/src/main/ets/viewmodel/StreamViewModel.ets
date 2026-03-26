/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { StreamConfig } from "../model/StreamConfig";
import {
  DisplaySettings,
  InputSettings,
  SettingsKeys,
  SettingsService,
} from "../service/SettingsService";
import { StreamingSession } from "../service/StreamingSession";
import { InputEvent } from "../model/InputEvent";
import {
  calculateSnapPosition,
  getDefaultOverlayConfig,
  OverlayConfig,
  SnapPosition,
} from "../components/PerformanceOverlayManager";
import { PreferencesUtil } from "../utils/PreferencesUtil";
import { GamepadManager } from "../service/GamepadManager";
import { CONN_STATUS_POOR, CONTROLLER_TYPE_XBOX } from "../service/MoonBridge";
import { common } from "@kit.AbilityKit";
import { inputDevice } from "@kit.InputKit";

export enum StreamConnectionState {
  IDLE = "idle",
  CONNECTING = "connecting",
  CONNECTED = "connected",
  ERROR = "error",
  DISCONNECTED = "disconnected",
}

export enum TouchMode {
  TRACKPAD = "trackpad",
  DIRECT = "direct",
  MOUSE = "mouse",
}

@Observed
export class PerformanceStats {
  fps: number = 0;
  renderedFps: number = 0;
  bitrate: number = 0;
  latency: number = 0;
  packetLoss: number = 0;
  decodedFrames: number = 0;
  droppedFrames: number = 0;
  networkLatency: number = 0;
  hostLatency: number = 0;
  globalAvgDecodeLatency: number = 0;
  globalAvgHostLatency: number = 0;
  globalAvgFps: number = 0;
  batteryLevel: number = 100;
  isCharging: boolean = false;
  droppedByL1: number = 0;
  droppedByL2: number = 0;
  droppedByL3: number = 0;
  droppedByL4: number = 0;
  droppedByL5: number = 0;
}

@Observed
export class DisplayInfo {
  screenWidth: number = 1920;
  screenHeight: number = 1080;
  streamWidth: number = 1920;
  streamHeight: number = 1080;
  xComponentWidth: Length = "100%";
  xComponentHeight: Length = "100%";
  stretchVideo: boolean = false;
  screenPosition: string = "居中";
  screenOffsetX: number = 0;
  screenOffsetY: number = 0;
}

@Observed
export class OverlayState {
  config: OverlayConfig = getDefaultOverlayConfig();
  configVersion: number = 0;
  x: number = 0;
  y: number = 8;
  opacity: number = 1.0;
  scale: number = 1.0;
  width: number = 200;
  height: number = 200;
  isDragging: boolean = false;
  dragStartX: number = 0;
  dragStartY: number = 0;
  moveDistance: number = 0;
  clickStartTime: number = 0;
  lastClickTime: number = 0;
}

@Observed
export class StreamViewModel {
  connectionState: StreamConnectionState = StreamConnectionState.IDLE;
  errorMessage: string = "";

  connectionProgress: number = 0;
  connectionStageText: string = "";

  performanceStats: PerformanceStats = new PerformanceStats();

  displayInfo: DisplayInfo = new DisplayInfo();

  overlayState: OverlayState = new OverlayState();

  showLocalCursor: boolean = false;

  streamConfig: StreamConfig | null = null;
  inputSettings: InputSettings | null = null;
  displaySettings: DisplaySettings | null = null;

  touchMode: TouchMode = TouchMode.TRACKPAD;

  actualHdr: boolean = false;

  actualCodec: string = "";

  showOverlay: boolean = false;
  showController: boolean = false;

  connectionPoor: boolean = false;

  private settingsService: SettingsService = SettingsService.getInstance();
  private streamingSession: StreamingSession | null = null;

  private connectionTerminatedCallback: ((errorCode: number) => void) | null = null;
  private resolutionChangedCallback: ((width: number, height: number) => void) | null = null;
  private connectionStatusCallback: ((connectionStatus: number) => void) | null = null;

  get isConnecting(): boolean {
    return this.connectionState === StreamConnectionState.CONNECTING;
  }

  get isConnected(): boolean {
    return this.connectionState === StreamConnectionState.CONNECTED;
  }

  get hasError(): boolean {
    return this.connectionState === StreamConnectionState.ERROR;
  }

  setConnectionTerminatedCallback(callback: ((errorCode: number) => void) | null): void {
    this.connectionTerminatedCallback = callback;
  }

  setResolutionChangedCallback(callback: ((width: number, height: number) => void) | null): void {
    this.resolutionChangedCallback = callback;
  }

  setConnectionStatusCallback(callback: ((connectionStatus: number) => void) | null): void {
    this.connectionStatusCallback = callback;
  }

  async loadSettings(): Promise<void> {
    this.streamConfig = await this.settingsService.getStreamConfig();
    this.inputSettings = await this.settingsService.getInputSettings();
    this.displaySettings = await this.settingsService.getDisplaySettings();

    this.showOverlay = this.displaySettings.enablePerfOverlay;
    this.showController = this.inputSettings.enableOnscreenControls;
    this.displayInfo.stretchVideo = this.displaySettings.stretchVideo;
    this.displayInfo.screenPosition = this.displaySettings.screenPosition;
    this.displayInfo.screenOffsetX = this.displaySettings.screenOffsetX;
    this.displayInfo.screenOffsetY = this.displaySettings.screenOffsetY;

    this.overlayState.config.isVertical = this.displaySettings.perfOverlayOrientation === "垂直";
    this.overlayState.config.isLocked = this.displaySettings.perfOverlayLocked || false;

    if (this.displaySettings.perfOverlayItems) {
      this.overlayState.config.enabledItems = new Set(this.displaySettings.perfOverlayItems);
    }

    this.overlayState.config.position = this.parseOverlayPosition(
      this.displaySettings.perfOverlayPosition,
    );

    if (this.displaySettings.perfOverlayBgOpacity !== undefined) {
      this.overlayState.config.bgOpacity = this.displaySettings.perfOverlayBgOpacity;
    }

    this.displayInfo.streamWidth = this.streamConfig.width;
    this.displayInfo.streamHeight = this.streamConfig.height;

    this.showLocalCursor = this.inputSettings.showLocalCursor ?? false;

    const lastTouchMode = await PreferencesUtil.get<string>(SettingsKeys.LAST_TOUCH_MODE, "");
    if (
      lastTouchMode &&
      (lastTouchMode === "trackpad" || lastTouchMode === "direct" || lastTouchMode === "mouse")
    ) {
      this.touchMode = lastTouchMode as TouchMode;
    } else if (this.inputSettings.touchscreenTrackpad) {
      this.touchMode = TouchMode.TRACKPAD;
    } else {
      const hasKeyboardOrMouse = await this.detectKeyboardOrMouse();
      this.touchMode = hasKeyboardOrMouse ? TouchMode.TRACKPAD : TouchMode.DIRECT;
    }

    console.info(
      `StreamViewModel: 配置加载完成 - ${this.streamConfig.width}x${this.streamConfig.height}@${this.streamConfig.fps}fps`,
    );
    console.info(`StreamViewModel: 触摸模式=${this.touchMode}`);
    console.info(
      `StreamViewModel: 性能覆盖层=${this.showOverlay}, 虚拟控制器=${this.showController}`,
    );

    const deviceVibrateEnabled =
      this.streamConfig.enableVibration && this.streamConfig.vibrateFallbackStrength > 0;
    GamepadManager.getInstance().setDeviceVibrate(
      deviceVibrateEnabled,
      this.streamConfig.vibrateFallbackStrength,
      this.streamConfig.vibrationMode,
    );
  }

  async startStreaming(
    computerId: string,
    appId: number,
    surfaceId: string,
    context: common.UIAbilityContext,
    displayGuid?: string,
    useVdd?: boolean,
  ): Promise<void> {
    this.connectionState = StreamConnectionState.CONNECTING;
    this.connectionProgress = 0;
    this.connectionStageText = "";
    this.errorMessage = "";

    try {
      await this.loadSettings();

      this.actualHdr = this.streamConfig?.hdr || false;

      this.actualCodec = this.streamConfig?.codec || "HEVC";

      this.streamingSession = new StreamingSession();

      this.streamingSession.setHdrStateCallback((isHdr: boolean) => {
        console.info(`StreamViewModel: HDR 状态回调 actualHdr=${isHdr}`);
        this.actualHdr = isHdr;
      });

      this.streamingSession.setCodecStateCallback((codec: string) => {
        console.info(`StreamViewModel: 编解码器状态回调 actualCodec=${codec}`);
        this.actualCodec = codec;
      });

      this.streamingSession.setConnectionTerminatedCallback((errorCode: number) => {
        console.info(`StreamViewModel: 连接终止回调 errorCode=${errorCode}`);
        this.connectionState = StreamConnectionState.DISCONNECTED;
        if (this.connectionTerminatedCallback) {
          this.connectionTerminatedCallback(errorCode);
        }
      });

      this.streamingSession.setResolutionChangedCallback((width: number, height: number) => {
        console.info(`StreamViewModel: 服务端分辨率变化 ${width}x${height}`);
        this.displayInfo.streamWidth = width;
        this.displayInfo.streamHeight = height;
        this.setServerInitiatedRotation(true);
        if (this.resolutionChangedCallback) {
          this.resolutionChangedCallback(width, height);
        }
      });

      this.streamingSession.setConnectionStatusCallback((connectionStatus: number) => {
        this.connectionPoor = connectionStatus === CONN_STATUS_POOR;
        if (this.connectionStatusCallback) {
          this.connectionStatusCallback(connectionStatus);
        }
      });

      this.streamingSession.setStageProgressCallback((stage: number, stageName: string) => {
        const nativeProgress = 0.35 + (stage / 12) * 0.65;
        this.connectionProgress = Math.min(nativeProgress, 1.0);
        this.connectionStageText = stageName;
      });

      this.connectionProgress = 0.05;
      this.connectionStageText = "正在获取服务器信息...";

      await this.streamingSession.start(
        computerId,
        appId,
        this.streamConfig!,
        surfaceId,
        context,
        displayGuid,
        useVdd,
      );

      const effectiveConfig = this.streamingSession.getEffectiveConfig();
      if (effectiveConfig) {
        if (this.streamConfig!.hdr !== effectiveConfig.hdr) {
          console.info(
            `StreamViewModel: HDR 状态同步 ${this.streamConfig!.hdr} -> ${effectiveConfig.hdr}`,
          );
          this.streamConfig!.hdr = effectiveConfig.hdr;
        }
        if (this.streamConfig!.codec !== effectiveConfig.codec) {
          console.info(
            `StreamViewModel: Codec 状态同步 ${this.streamConfig!.codec} -> ${effectiveConfig.codec}`,
          );
          this.streamConfig!.codec = effectiveConfig.codec;
        }
      }

      this.connectionProgress = 1.0;
      this.connectionStageText = "已连接";
      this.connectionState = StreamConnectionState.CONNECTED;
    } catch (err) {
      this.connectionState = StreamConnectionState.ERROR;
      const error = err as Error;
      this.errorMessage = `连接失败: ${error.message}`;
      throw error;
    }
  }

  async stopStreaming(): Promise<void> {
    this.resetRotationState();

    if (this.streamingSession) {
      await this.streamingSession.stop();
      this.streamingSession = null;
    }

    this.connectionState = StreamConnectionState.DISCONNECTED;
  }

  sendInput(input: InputEvent): void {
    this.streamingSession?.sendInput(input);
  }

  sendGamepadState(
    controllerIndex: number,
    buttons: number,
    leftStickX: number,
    leftStickY: number,
    rightStickX: number,
    rightStickY: number,
    leftTrigger: number,
    rightTrigger: number,
    controllerType: number = CONTROLLER_TYPE_XBOX,
  ): void {
    this.streamingSession?.sendGamepadState(
      controllerIndex,
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

  getSession(): StreamingSession | null {
    return this.streamingSession;
  }

  private parseOverlayPosition(positionStr: string): SnapPosition {
    switch (positionStr) {
      case "顶部":
        return SnapPosition.TOP_CENTER;
      case "底部":
        return SnapPosition.BOTTOM_CENTER;
      case "左上角":
        return SnapPosition.TOP_LEFT;
      case "右上角":
        return SnapPosition.TOP_RIGHT;
      case "左下角":
        return SnapPosition.BOTTOM_LEFT;
      case "右下角":
        return SnapPosition.BOTTOM_RIGHT;
      case "左侧":
        return SnapPosition.CENTER_LEFT;
      case "居中":
        return SnapPosition.CENTER;
      case "右侧":
        return SnapPosition.CENTER_RIGHT;
      default:
        return SnapPosition.TOP_RIGHT;
    }
  }

  initOverlayPosition(): void {
    const snapPos = calculateSnapPosition(
      this.overlayState.config.position,
      this.displayInfo.screenWidth,
      this.displayInfo.screenHeight,
      this.overlayState.width,
      this.overlayState.height,
    );
    this.overlayState.x = snapPos.x;
    this.overlayState.y = snapPos.y;

    console.info(
      `StreamViewModel: 覆盖层初始位置 (${this.overlayState.x}, ${this.overlayState.y})`,
    );
  }

  setTouchMode(mode: TouchMode): void {
    this.touchMode = mode;
    PreferencesUtil.put(SettingsKeys.LAST_TOUCH_MODE, mode as string).catch((err: Error) => {
      console.warn(`StreamViewModel: 保存触摸模式失败: ${err.message}`);
    });
    console.info(`StreamViewModel: 触摸模式切换为 ${mode}`);
  }

  private async detectKeyboardOrMouse(): Promise<boolean> {
    try {
      const deviceIds = await inputDevice.getDeviceIds();
      for (const id of deviceIds) {
        const info = await inputDevice.getDeviceInfo(id);
        const sources: inputDevice.SourceType[] = info.sources;
        if (
          sources.includes("keyboard" as inputDevice.SourceType) ||
          sources.includes("mouse" as inputDevice.SourceType)
        ) {
          return true;
        }
      }
    } catch (e) {
      console.warn(`StreamViewModel: 检测输入设备失败: ${JSON.stringify(e)}`);
    }
    return false;
  }

  toggleOverlay(): void {
    this.showOverlay = !this.showOverlay;
    console.info(`StreamViewModel: 性能覆盖层 ${this.showOverlay ? "显示" : "隐藏"}`);
  }

  toggleController(): void {
    this.showController = !this.showController;
    console.info(`StreamViewModel: 虚拟控制器 ${this.showController ? "显示" : "隐藏"}`);
  }

  toggleOverlayLayout(): void {
    this.overlayState.config.isVertical = !this.overlayState.config.isVertical;
  }

  async quitGame(): Promise<void> {
    try {
      if (this.streamingSession) {
        const success = await this.streamingSession.quitApp();
        if (success) {
          console.info("远程游戏已退出");
        } else {
          console.warn("退出远程游戏失败，但已断开连接");
        }
        this.streamingSession = null;
      }
    } catch (err) {
      console.error("退出游戏失败:", err);
    }

    this.connectionState = StreamConnectionState.DISCONNECTED;
  }

  async setBitrate(bitrateKbps: number): Promise<boolean> {
    if (!this.streamingSession) {
      return false;
    }

    const success = await this.streamingSession.setBitrate(bitrateKbps);
    if (success && this.streamConfig) {
      this.streamConfig.bitrate = bitrateKbps;
    }
    return success;
  }

  async sendSuperCmd(cmdId: string): Promise<boolean> {
    if (!this.streamingSession) {
      return false;
    }
    return await this.streamingSession.sendSuperCmd(cmdId);
  }

  private lastRotation: number = -1;
  private isServerInitiatedRotation: boolean = false;
  private pendingRotationTimeoutId: number = -1;
  private static readonly ROTATION_DEBOUNCE_MS: number = 3000;

  setServerInitiatedRotation(value: boolean): void {
    this.isServerInitiatedRotation = value;
    if (value) {
      console.info("StreamViewModel: 标记为服务器触发的旋转");
    }
  }

  handleRotationChange(isLandscape: boolean): void {
    if (!this.displaySettings?.rotableScreen) {
      console.info("StreamViewModel: 屏幕旋转同步未启用");
      return;
    }

    if (this.isServerInitiatedRotation) {
      console.info("StreamViewModel: 跳过服务器触发的旋转");
      this.isServerInitiatedRotation = false;
      return;
    }

    if (!this.isConnected || !this.streamingSession) {
      console.warn("StreamViewModel: handleRotationChange - 连接未就绪");
      return;
    }

    const currentOrientation = isLandscape ? 1 : 0;

    if (this.lastRotation === -1) {
      this.lastRotation = currentOrientation;
      console.info(`StreamViewModel: 初始化旋转方向=${currentOrientation}`);
      return;
    }

    if (currentOrientation === this.lastRotation) {
      return;
    }

    this.lastRotation = currentOrientation;
    const angle = isLandscape ? 0 : 90;

    console.info(`StreamViewModel: 检测到旋转变化 isLandscape=${isLandscape}, angle=${angle}`);

    if (this.pendingRotationTimeoutId !== -1) {
      clearTimeout(this.pendingRotationTimeoutId);
    }

    this.pendingRotationTimeoutId = setTimeout(async () => {
      console.info(`StreamViewModel: 通知服务器旋转，angle=${angle}`);

      try {
        const success = await this.streamingSession?.rotateDisplay(angle);
        if (success) {
          console.info(`StreamViewModel: 服务器旋转成功，角度=${angle}`);
        } else {
          console.warn("StreamViewModel: 服务器旋转失败");
        }
      } catch (err) {
        console.error(`StreamViewModel: 旋转请求异常: ${err}`);
      }

      this.pendingRotationTimeoutId = -1;
    }, StreamViewModel.ROTATION_DEBOUNCE_MS) as number;
  }

  checkAndSyncOrientation(
    serverWidth: number,
    serverHeight: number,
    clientIsLandscape: boolean,
  ): void {
    if (!this.displaySettings?.rotableScreen) {
      return;
    }

    const serverIsLandscape = serverWidth > serverHeight;

    console.info(
      `StreamViewModel: checkAndSyncOrientation - 客户端=${clientIsLandscape ? "横屏" : "竖屏"}, ` +
        `服务端=${serverWidth}x${serverHeight}(${serverIsLandscape ? "横屏" : "竖屏"})`,
    );

    if (clientIsLandscape !== serverIsLandscape) {
      console.info("StreamViewModel: 方向不匹配，通知服务器同步");
      this.handleRotationChange(clientIsLandscape);
    } else {
      console.info("StreamViewModel: 方向匹配");
      if (this.lastRotation === -1) {
        this.lastRotation = clientIsLandscape ? 1 : 0;
      }
    }
  }

  private resetRotationState(): void {
    this.lastRotation = -1;
    this.isServerInitiatedRotation = false;
    if (this.pendingRotationTimeoutId !== -1) {
      clearTimeout(this.pendingRotationTimeoutId);
      this.pendingRotationTimeoutId = -1;
    }
  }

  getCurrentBitrate(): number {
    return this.streamingSession?.getCurrentBitrate() || this.streamConfig?.bitrate || 0;
  }

  resumeFromBackground(): void {
    console.info("[StreamViewModel] 从后台恢复串流");

    if (!this.streamingSession) {
      console.warn("[StreamViewModel] 没有活跃的串流会话，无需恢复");
      return;
    }

    try {
      this.streamingSession.resumeDecoder();
      console.info("[StreamViewModel] 解码器恢复成功");
    } catch (err) {
      console.error("[StreamViewModel] 恢复解码器失败:", err);
    }
  }

  dispose(): void {
    this.resetRotationState();
    if (this.streamingSession) {
      this.streamingSession.stop();
      this.streamingSession = null;
    }
  }
}
