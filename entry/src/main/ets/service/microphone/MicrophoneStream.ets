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
import { MoonBridge, MoonBridgeClass } from "../MoonBridge";
import { MicrophoneConfig, MicrophoneState, MicrophoneStateListener } from "./MicrophoneConfig";

const TAG = "[MicStream]";

/**
 *
 */
export class MicrophoneStream {
  private moonBridge: MoonBridgeClass;
  private running: boolean = false;
  private paused: boolean = false;
  private hostRequested: boolean = false;

  private stateListener: MicrophoneStateListener | null = null;

  private statsTimerId: number = -1;
  private lastLogTime: number = 0;

  constructor(moonBridge: MoonBridgeClass) {
    this.moonBridge = moonBridge;
    console.info(TAG, "初始化麦克风流");
  }

  setStateListener(listener: MicrophoneStateListener): void {
    this.stateListener = listener;
  }

  isMicrophoneAvailable(): boolean {
    return this.moonBridge.isMicrophoneRequested();
  }

  isRunning(): boolean {
    return this.running && !this.paused;
  }

  async start(): Promise<boolean> {
    if (this.running) {
      console.info(TAG, "麦克风流已在运行");
      return true;
    }

    if (!this.moonBridge.isMicrophoneRequested()) {
      console.info(TAG, "主机未请求麦克风");
      return false;
    }

    this.hostRequested = true;

    if (this.moonBridge.isMicrophoneEncryptionEnabled()) {
      console.info(TAG, "麦克风加密已启用");
    }

    return this.startMicrophoneCapture();
  }

  private async startMicrophoneCapture(): Promise<boolean> {
    if (this.running) {
      return true;
    }

    try {
      const micPort = this.moonBridge.getMicPortNumber();
      if (micPort === 0) {
        console.warn(TAG, "未获取到麦克风端口");
      } else {
        console.info(TAG, `使用麦克风端口: ${micPort}`);
      }

      const bitrate = MicrophoneConfig.getOpusBitrate();
      console.info(
        TAG,
        `启动 native 麦克风: rate=${MicrophoneConfig.SAMPLE_RATE} ch=${MicrophoneConfig.CHANNELS} bitrate=${bitrate}`,
      );

      const ret = this.moonBridge.nativeMicStart(
        MicrophoneConfig.SAMPLE_RATE,
        MicrophoneConfig.CHANNELS,
        bitrate,
      );

      if (ret !== 0) {
        console.error(TAG, `启动 native 麦克风失败: ${ret}`);
        this.notifyError("启动低时延麦克风采集失败");
        return false;
      }

      this.running = true;
      this.paused = false;
      this.lastLogTime = Date.now();

      this.startStatsTimer();

      this.notifyStateChanged(MicrophoneState.CAPTURING);
      console.info(TAG, "麦克风流已启动（native 低时延模式）");

      return true;
    } catch (error) {
      console.error(TAG, `启动麦克风捕获失败: ${error}`);
      this.moonBridge.nativeMicStop();
      this.notifyError(`启动麦克风捕获失败: ${error}`);
      return false;
    }
  }

  async pause(): Promise<void> {
    if (!this.running || this.paused) {
      return;
    }

    this.paused = true;
    this.moonBridge.nativeMicPause();

    this.notifyStateChanged(MicrophoneState.PAUSED);
    console.info(TAG, "麦克风流已暂停");
  }

  async resume(): Promise<void> {
    if (!this.running || !this.paused) {
      return;
    }

    this.moonBridge.nativeMicResume();
    this.paused = false;
    this.notifyStateChanged(MicrophoneState.CAPTURING);
    console.info(TAG, "麦克风流已恢复");
  }

  async toggle(): Promise<boolean> {
    if (!this.running) {
      return this.start();
    }

    if (this.paused) {
      await this.resume();
    } else {
      await this.pause();
    }

    return !this.paused;
  }

  async stop(): Promise<void> {
    if (!this.running) {
      return;
    }

    console.info(TAG, "停止麦克风流");

    this.running = false;
    this.paused = false;

    this.stopStatsTimer();

    this.moonBridge.nativeMicStop();

    this.notifyStateChanged(MicrophoneState.STOPPED);
    console.info(TAG, "麦克风流已停止");
  }

  private async cleanup(): Promise<void> {
    this.moonBridge.nativeMicStop();
    this.stopStatsTimer();
    this.running = false;
    this.paused = false;
  }

  private startStatsTimer(): void {
    this.stopStatsTimer();
    this.statsTimerId = setInterval(() => {
      if (!this.running) {
        this.stopStatsTimer();
        return;
      }
      try {
        const stats = this.moonBridge.nativeMicGetStats();
        if (stats) {
          console.info(
            TAG,
            `麦克风统计: 已采集=${stats.captured}, 已编码=${stats.encoded}, ` +
              `已发送=${stats.sent}, 丢弃=${stats.dropped}, ` +
              `速率=${(stats.sent / 10).toFixed(1)} pps`,
          );
        }
      } catch (e) {
        console.warn(TAG, `获取麦克风统计失败: ${e}`);
      }
    }, 10000);
  }

  private stopStatsTimer(): void {
    if (this.statsTimerId !== -1) {
      clearInterval(this.statsTimerId);
      this.statsTimerId = -1;
    }
  }

  private notifyStateChanged(state: MicrophoneState): void {
    if (this.stateListener) {
      this.stateListener.onMicrophoneStateChanged(state);
    }
  }

  private notifyError(error: string): void {
    if (this.stateListener) {
      this.stateListener.onMicrophoneError(error);
    }
  }
}
