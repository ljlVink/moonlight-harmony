/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */


export class MicrophoneConfig {
  /**
  static readonly SAMPLE_RATE: number = 48000;
  /**
  static readonly CHANNELS: number = 1;
  
  /**
  static readonly FRAME_SIZE_MS: number = 20;
  /**
  static readonly SAMPLES_PER_FRAME: number = MicrophoneConfig.SAMPLE_RATE * MicrophoneConfig.FRAME_SIZE_MS / 1000;
  /**
  static readonly BYTES_PER_FRAME: number = MicrophoneConfig.SAMPLES_PER_FRAME * MicrophoneConfig.CHANNELS * 2;
  
  /**
  static readonly CAPTURE_BUFFER_SIZE_MS: number = 40;
  /**
  static readonly CAPTURE_BUFFER_SIZE: number = 
    MicrophoneConfig.SAMPLE_RATE * MicrophoneConfig.CAPTURE_BUFFER_SIZE_MS / 1000 * MicrophoneConfig.CHANNELS * 2;
  
  /**
  static readonly MAX_QUEUE_SIZE: number = 5;
  /**
  static readonly FRAME_INTERVAL_MS: number = 20;
  /**
  static readonly SENDER_THREAD_SLEEP_MS: number = 5;
  
  private static opusBitrateKbps: number = 64;
  
  static getOpusBitrate(): number {
    return MicrophoneConfig.opusBitrateKbps * 1000;
  }
  
  static getOpusBitrateKbps(): number {
    return MicrophoneConfig.opusBitrateKbps;
  }
  
  static setOpusBitrate(bitrateKbps: number): void {
    MicrophoneConfig.opusBitrateKbps = bitrateKbps;
  }
  
  static getConfigSummary(): string {
    return `麦克风配置:
采样率: ${MicrophoneConfig.SAMPLE_RATE} Hz
声道数: ${MicrophoneConfig.CHANNELS}
Opus 比特率: ${MicrophoneConfig.opusBitrateKbps} Kbps
帧大小: ${MicrophoneConfig.FRAME_SIZE_MS} ms (${MicrophoneConfig.SAMPLES_PER_FRAME} samples)`;
  }
}

export enum MicrophoneState {
  /**
  STOPPED = 'stopped',
  /**
  INITIALIZING = 'initializing',
  /**
  CAPTURING = 'capturing',
  /**
  PAUSED = 'paused',
  /**
  ERROR = 'error'
}

export enum MicrophoneEventType {
  /**
  STATE_CHANGED = 'stateChanged',
  /**
  HOST_REQUESTED = 'hostRequested',
  /**
  ERROR = 'error',
  /**
  DATA_SENT = 'dataSent'
}

export interface MicrophoneEvent {
  type: MicrophoneEventType;
  state?: MicrophoneState;
  error?: string;
  data?: object;
}

export interface MicrophoneStateListener {
  onMicrophoneStateChanged(state: MicrophoneState): void;
  onMicrophoneError(error: string): void;
}
