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
import { display, promptAction } from '@kit.ArkUI';
import { StreamViewModel } from '../viewmodel/StreamViewModel';
import { StreamWindowManager } from '../service/StreamWindowManager';
import { AppStateService, AppState } from '../service/AppStateService';
import { BackgroundStreamService, BroadcastControlCallbacks } from '../service/BackgroundStreamService';
import { common } from '@kit.AbilityKit';
import { MoonBridge, ML_TEST_RESULT_INCONCLUSIVE, CONNECTION_TEST_SERVER } from '../service/MoonBridge';

export interface LifecycleCallbacks {
  /**
  updateXComponentSize: (width: Length, height: Length) => void;
  /**
  stopStreaming: () => void;
  /**
  reconnectStreaming: () => void;
}

export class StreamLifecycleManager {
  private viewModel: StreamViewModel | null = null;
  private windowManager: StreamWindowManager | null = null;
  private callbacks: LifecycleCallbacks | null = null;

  private appStateService: AppStateService = AppStateService.getInstance();
  private appStateListener: ((state: AppState) => void) | null = null;
  private wasInBackground: boolean = false;
  private backgroundService: BackgroundStreamService = BackgroundStreamService.getInstance();
  private enableBackgroundTask: boolean = true;
  /**
  private pendingTerminationErrorCode: number | null = null;

  private displayChangeCallback: ((displayId: number) => void) | null = null;
  private lastDisplayOrientation: boolean | null = null;

  private latencyToastEnabled: boolean = false;
  /**
  private disableWarnings: boolean = false;

  initialize(viewModel: StreamViewModel, windowManager: StreamWindowManager | null,
    callbacks: LifecycleCallbacks): void {
    this.viewModel = viewModel;
    this.windowManager = windowManager;
    this.callbacks = callbacks;
  }

  setLatencyToastEnabled(enabled: boolean): void {
    this.latencyToastEnabled = enabled;
  }

  setDisableWarnings(disabled: boolean): void {
    this.disableWarnings = disabled;
  }

  setEnableBackgroundTask(enabled: boolean): void {
    this.enableBackgroundTask = enabled;
  }

  registerAppStateListener(): void {
    this.appStateListener = (state: AppState) => {
      if (state === AppState.BACKGROUND) {
        console.info('[StreamPage] 应用进入后台');
        this.wasInBackground = true;
      } else if (state === AppState.FOREGROUND && this.wasInBackground) {
        console.info('[StreamPage] 应用从后台恢复');
        this.wasInBackground = false;
        this.handleAppResume();
      }
    };
    this.appStateService.addListener(this.appStateListener);
  }

  unregisterAppStateListener(): void {
    if (this.appStateListener) {
      this.appStateService.removeListener(this.appStateListener);
      this.appStateListener = null;
    }
  }

  registerDisplayChangeListener(): void {
    try {
      this.displayChangeCallback = (displayId: number): void => {
        this.handleDisplayChange(displayId);
      };
      display.on('change', this.displayChangeCallback);
      console.info('[StreamPage] 已注册屏幕方向变化监听');
    } catch (err) {
      console.warn('[StreamPage] 注册屏幕方向监听失败:', err);
    }
  }

  unregisterDisplayChangeListener(): void {
    if (this.displayChangeCallback) {
      try {
        display.off('change', this.displayChangeCallback);
        console.info('[StreamPage] 已取消屏幕方向变化监听');
      } catch (err) {
        console.warn('[StreamPage] 取消屏幕方向监听失败:', err);
      }
      this.displayChangeCallback = null;
    }
  }

  private handleDisplayChange(displayId: number): void {
    if (!this.viewModel?.isConnected) {
      return;
    }

    try {
      const displayInfo = display.getDefaultDisplaySync();
      const isLandscape = displayInfo.width > displayInfo.height;

      if (this.lastDisplayOrientation !== null && this.lastDisplayOrientation === isLandscape) {
        return;
      }

      console.info(`[StreamPage] 屏幕方向变化: ${isLandscape ? '横屏' : '竖屏'}, displayId=${displayId}`);
      this.lastDisplayOrientation = isLandscape;

      this.viewModel?.handleRotationChange(isLandscape);

      this.updateScreenSizeAfterRotation();
    } catch (err) {
      console.warn('[StreamPage] 处理屏幕变化失败:', err);
    }
  }

  async updateScreenSizeAfterRotation(): Promise<void> {
    try {
      const screenSize = await this.windowManager?.updateScreenSize();
      if (screenSize) {
        if (this.viewModel) {
          this.viewModel.displayInfo.screenWidth = screenSize.width;
          this.viewModel.displayInfo.screenHeight = screenSize.height;
        }

        const xComponentSize = this.windowManager?.calculateXComponentSize(
          this.viewModel?.displayInfo.stretchVideo ?? false
        );
        if (xComponentSize) {
          this.callbacks?.updateXComponentSize(xComponentSize.width, xComponentSize.height);
        }
      }
    } catch (err) {
      console.warn('[StreamPage] 更新屏幕尺寸失败:', err);
    }
  }

  async handleServerResolutionChanged(width: number, height: number): Promise<void> {
    console.info(`[StreamPage] 服务端分辨率变化: ${width}x${height}`);

    this.windowManager?.setStreamResolution(width, height);

    await this.windowManager?.configureOrientation();

    const screenSize = await this.windowManager?.updateScreenSize();
    if (screenSize && this.viewModel) {
      this.viewModel.displayInfo.screenWidth = screenSize.width;
      this.viewModel.displayInfo.screenHeight = screenSize.height;
    }

    const xComponentSize = this.windowManager?.calculateXComponentSize(
      this.viewModel?.displayInfo.stretchVideo ?? false
    );
    if (xComponentSize) {
      this.callbacks?.updateXComponentSize(xComponentSize.width, xComponentSize.height);
      console.info(`[StreamPage] XComponent 尺寸更新: ${JSON.stringify(xComponentSize)}`);
    }
  }

  /**
   * @param context UIAbilityContext
   */
  async startBackgroundTask(context: common.UIAbilityContext, gameName?: string): Promise<void> {
    try {
      const broadcastCallbacks: BroadcastControlCallbacks = {
        onStop: () => {
          console.info('[StreamPage] 播控中心请求停止串流');
          if (this.callbacks) {
            this.callbacks.stopStreaming();
          }
        }
      } as BroadcastControlCallbacks;
      await this.backgroundService.start(context, gameName, broadcastCallbacks);
      console.info('[StreamPage] 后台保活已启动');
    } catch (err) {
      console.warn('[StreamPage] 启动后台保活失败（不影响串流）:', err);
    }
  }

  async stopBackgroundTask(): Promise<void> {
    try {
      await this.backgroundService.stop();
      console.info('[StreamPage] 后台保活已停止');
    } catch (err) {
      console.warn('[StreamPage] 停止后台保活失败:', err);
    }
  }

  private handleAppResume(): void {
    console.info(`[StreamPage] 处理应用恢复, 连接状态: ${this.viewModel?.connectionState}, ` +
      `后台保活: ${this.enableBackgroundTask}, 待处理断连: ${this.pendingTerminationErrorCode}`);

    if (this.pendingTerminationErrorCode !== null) {
      const errorCode = this.pendingTerminationErrorCode;
      this.pendingTerminationErrorCode = null;
      console.info(`[StreamPage] 后台期间连接断开 (errorCode=${errorCode})，尝试重连...`);
      this.callbacks?.reconnectStreaming();
      return;
    }

    if (this.enableBackgroundTask) {
      if (this.viewModel?.isConnected) {
        console.info('[StreamPage] 后台保活开启，尝试恢复串流...');
        this.viewModel.resumeFromBackground();
      }
    } else {
      console.info('[StreamPage] 后台保活关闭，触发重连...');
      this.callbacks?.reconnectStreaming();
    }
  }

  showLatencyToastIfEnabled(): void {
    console.info(`[StreamPage] showLatencyToast: enabled=${this.latencyToastEnabled}`);
    if (!this.latencyToastEnabled) {
      return;
    }

    const session = this.viewModel?.getSession();
    const stats = session ? session.getSummaryStats() : this.viewModel?.performanceStats;
    if (!stats) return;

    console.info(`[StreamPage] stats: net=${stats.networkLatency}, decode=${stats.latency}, host=${stats.hostLatency}, fps=${stats.renderedFps}`);
    const parts: string[] = [];

    if (stats.networkLatency > 0) {
      parts.push(`网络: ${stats.networkLatency}ms`);
    }
    const decodeLatency = stats.globalAvgDecodeLatency > 0 ? stats.globalAvgDecodeLatency : stats.latency;
    if (decodeLatency > 0) {
      parts.push(`解码: ${decodeLatency.toFixed(1)}ms`);
    }
    const hostLatency = stats.globalAvgHostLatency > 0 ? stats.globalAvgHostLatency : stats.hostLatency;
    if (hostLatency > 0) {
      parts.push(`主机: ${hostLatency.toFixed(1)}ms`);
    }
    const avgFps = stats.globalAvgFps > 0 ? Math.round(stats.globalAvgFps) : stats.renderedFps;
    if (avgFps > 0) {
      parts.push(`帧率: ${avgFps}fps`);
    }
    if (stats.droppedFrames > 0) {
      const dropDetails: string[] = [];
      if (stats.droppedByL1 > 0) dropDetails.push(`L1:${stats.droppedByL1}`);
      if (stats.droppedByL2 > 0) dropDetails.push(`L2:${stats.droppedByL2}`);
      if (stats.droppedByL3 > 0) dropDetails.push(`L3:${stats.droppedByL3}`);
      if (stats.droppedByL4 > 0) dropDetails.push(`L4:${stats.droppedByL4}`);
      if (stats.droppedByL5 > 0) dropDetails.push(`L5:${stats.droppedByL5}`);
      const detail = dropDetails.length > 0 ? ` (${dropDetails.join(' ')})` : '';
      parts.push(`丢帧: ${stats.droppedFrames}${detail}`);
    }

    const message = parts.length > 0 ? parts.join(' | ') : '串流已结束';
    promptAction.showToast({
      message: message,
      duration: 3500
    });
  }

  handleConnectionTerminated(errorCode: number): void {
    console.info(`StreamPage: 连接终止, errorCode=${errorCode}, inBackground=${this.wasInBackground}`);

    const ML_ERROR_GRACEFUL_TERMINATION = 0;
    const ML_ERROR_NO_VIDEO_TRAFFIC = -100;
    const ML_ERROR_NO_VIDEO_FRAME = -101;
    const ML_ERROR_UNEXPECTED_EARLY_TERMINATION = -102;
    const ML_ERROR_PROTECTED_CONTENT = -103;
    const ML_ERROR_FRAME_CONVERSION = -104;

    if (this.wasInBackground) {
      console.info(`[StreamPage] 后台期间连接断开，延迟处理 (errorCode=${errorCode})`);
      this.pendingTerminationErrorCode = errorCode;
      return;
    }

    if (errorCode === ML_ERROR_GRACEFUL_TERMINATION) {
      this.callbacks?.stopStreaming();
    } else if (this.disableWarnings) {
      this.callbacks?.stopStreaming();
    } else {
      const portFlags = MoonBridge.getPortFlagsFromTerminationErrorCode(errorCode);
      let portTestResult = ML_TEST_RESULT_INCONCLUSIVE;
      if (portFlags !== 0) {
        try {
          portTestResult = MoonBridge.testClientConnectivity(CONNECTION_TEST_SERVER, 443, portFlags);
        } catch (e) {
          console.warn(`端口诊断失败: ${e}`);
        }
      }

      let message: string;
      if (portTestResult !== ML_TEST_RESULT_INCONCLUSIVE && portTestResult !== 0) {
        message = '检测到端口被封锁，请检查防火墙或端口转发规则。';
      } else {
        switch (errorCode) {
          case ML_ERROR_NO_VIDEO_TRAFFIC:
            message = '未收到视频数据。请检查防火墙或端口转发规则（UDP 47998）。';
            break;
          case ML_ERROR_NO_VIDEO_FRAME:
            message = '未收到完整视频帧。网络可能不稳定或码率设置过高。';
            break;
          case ML_ERROR_UNEXPECTED_EARLY_TERMINATION:
          case ML_ERROR_PROTECTED_CONTENT:
            message = '串流意外终止。可能是受保护内容或编码器无法捕获视频。';
            break;
          case ML_ERROR_FRAME_CONVERSION:
            message = '帧转换错误。请尝试调整分辨率或关闭 HDR。';
            break;
          default:
            const errorHex = Math.abs(errorCode) > 1000 ? `0x${errorCode.toString(16)}` : errorCode.toString();
            message = `连接已断开 (错误码: ${errorHex})`;
            break;
        }
      }

      if (portFlags !== 0) {
        try {
          const portInfo = MoonBridge.stringifyPortFlags(portFlags, '\n');
          if (portInfo) {
            message += `\n\n请确保以下端口已开放:\n${portInfo}`;
          }
        } catch (e) {
          console.warn(`端口信息格式化失败: ${e}`);
        }
      }

      promptAction.showDialog({
        title: '连接已断开',
        message: message,
        buttons: [{ text: '确定', color: '#3B82F6' }]
      }).then(() => {
        this.callbacks?.stopStreaming();
      }).catch(() => {
        this.callbacks?.stopStreaming();
      });
    }
  }
}
