/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { audio } from '@kit.AudioKit';
import { MicrophoneConfig, MicrophoneState } from './MicrophoneConfig';

const TAG = '[MicCapturer]';

export interface MicrophoneDataCallback {
  onMicrophoneData(data: ArrayBuffer, length: number): void;
}

export class MicrophoneCapturer {
  private audioCapturer: audio.AudioCapturer | null = null;
  private dataCallback: MicrophoneDataCallback | null = null;
  private running: boolean = false;
  private state: MicrophoneState = MicrophoneState.STOPPED;
  
  private frameBuffer: ArrayBuffer;
  private frameBufferView: Uint8Array;
  private frameBufferPos: number = 0;
  
  private frameCount: number = 0;
  private lastLogTime: number = 0;
  
  constructor(callback: MicrophoneDataCallback) {
    this.dataCallback = callback;
    this.frameBuffer = new ArrayBuffer(MicrophoneConfig.BYTES_PER_FRAME);
    this.frameBufferView = new Uint8Array(this.frameBuffer);
  }
  
  getState(): MicrophoneState {
    return this.state;
  }
  
  isRunning(): boolean {
    return this.running;
  }
  
  async start(): Promise<boolean> {
    if (this.running) {
      console.info(TAG, '麦克风捕获已在运行');
      return true;
    }
    
    this.state = MicrophoneState.INITIALIZING;
    
    try {
      const audioStreamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_48000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };
      
      const audioCapturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_VOICE_COMMUNICATION,
        capturerFlags: 0
      };
      
      const audioCapturerOptions: audio.AudioCapturerOptions = {
        streamInfo: audioStreamInfo,
        capturerInfo: audioCapturerInfo
      };
      
      console.info(TAG, `创建 AudioCapturer: 采样率=${MicrophoneConfig.SAMPLE_RATE}, 通道=${MicrophoneConfig.CHANNELS}`);
      
      this.audioCapturer = await audio.createAudioCapturer(audioCapturerOptions);
      
      if (!this.audioCapturer) {
        console.error(TAG, '创建 AudioCapturer 失败');
        this.state = MicrophoneState.ERROR;
        return false;
      }
      
      this.audioCapturer.on('readData', (buffer: ArrayBuffer) => {
        this.processAudioData(buffer);
      });
      
      this.audioCapturer.on('stateChange', (state: audio.AudioState) => {
        console.info(TAG, `AudioCapturer 状态变化: ${state}`);
      });
      
      await this.audioCapturer.start();
      
      this.running = true;
      this.state = MicrophoneState.CAPTURING;
      this.frameCount = 0;
      this.lastLogTime = Date.now();
      
      console.info(TAG, '麦克风捕获已启动');
      return true;
      
    } catch (error) {
      console.error(TAG, `启动麦克风捕获失败: ${error}`);
      this.state = MicrophoneState.ERROR;
      await this.release();
      return false;
    }
  }
  
  private processAudioData(buffer: ArrayBuffer): void {
    if (!this.running || !this.dataCallback) {
      return;
    }
    
    const data = new Uint8Array(buffer);
    let dataOffset = 0;
    let remainingBytes = data.length;
    
    while (remainingBytes > 0) {
      const bytesNeeded = MicrophoneConfig.BYTES_PER_FRAME - this.frameBufferPos;
      const bytesToCopy = Math.min(remainingBytes, bytesNeeded);
      
      this.frameBufferView.set(
        data.subarray(dataOffset, dataOffset + bytesToCopy),
        this.frameBufferPos
      );
      this.frameBufferPos += bytesToCopy;
      dataOffset += bytesToCopy;
      remainingBytes -= bytesToCopy;
      
      if (this.frameBufferPos >= MicrophoneConfig.BYTES_PER_FRAME) {
        this.dataCallback.onMicrophoneData(
          this.frameBuffer.slice(0),
          MicrophoneConfig.BYTES_PER_FRAME
        );
        
        this.frameBufferPos = 0;
        this.frameCount++;
        
        const now = Date.now();
        if (now - this.lastLogTime >= 5000) {
          const elapsed = (now - this.lastLogTime) / 1000;
          const fps = this.frameCount / elapsed;
          console.info(TAG, `麦克风统计: ${this.frameCount} 帧, ${fps.toFixed(1)} fps`);
          this.frameCount = 0;
          this.lastLogTime = now;
        }
      }
    }
  }
  
  async pause(): Promise<void> {
    if (this.audioCapturer && this.state === MicrophoneState.CAPTURING) {
      try {
        await this.audioCapturer.stop();
        this.state = MicrophoneState.PAUSED;
        console.info(TAG, '麦克风捕获已暂停');
      } catch (error) {
        console.error(TAG, `暂停麦克风捕获失败: ${error}`);
      }
    }
  }
  
  async resume(): Promise<void> {
    if (this.audioCapturer && this.state === MicrophoneState.PAUSED) {
      try {
        await this.audioCapturer.start();
        this.state = MicrophoneState.CAPTURING;
        console.info(TAG, '麦克风捕获已恢复');
      } catch (error) {
        console.error(TAG, `恢复麦克风捕获失败: ${error}`);
      }
    }
  }
  
  async stop(): Promise<void> {
    this.running = false;
    
    if (this.audioCapturer) {
      try {
        await this.audioCapturer.stop();
      } catch (error) {
        console.warn(TAG, `停止 AudioCapturer 时出错: ${error}`);
      }
    }
    
    this.state = MicrophoneState.STOPPED;
    this.frameBufferPos = 0;
    console.info(TAG, '麦克风捕获已停止');
  }
  
  async release(): Promise<void> {
    await this.stop();
    
    if (this.audioCapturer) {
      try {
        await this.audioCapturer.release();
      } catch (error) {
        console.warn(TAG, `释放 AudioCapturer 时出错: ${error}`);
      }
      this.audioCapturer = null;
    }
    
    this.dataCallback = null;
    console.info(TAG, '麦克风捕获器已释放');
  }
}
