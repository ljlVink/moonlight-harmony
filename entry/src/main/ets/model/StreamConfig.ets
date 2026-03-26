/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

export interface StreamConfig {
  width: number;
  height: number;
  fps: number;
  clientRefreshRateX100: number;
  bitrate: number;
  codec: 'H.264' | 'HEVC';
  hdr: boolean;
  hdrMode: HdrMode;
  hdrHighBrightness: boolean;
  stretchVideo: boolean;

  audioEnabled: boolean;
  microphoneEnabled: boolean;
  micBitrate: number;
  audioConfig: AudioConfiguration;
  enableSpatializer: boolean;

  sops: boolean;
  playLocalAudio: boolean;
  screenCombinationMode: ScreenCombinationMode;
  lockScreenAfterDisconnect: boolean;

  multiController: boolean;
  attachedGamepadMask: number;
  enableVibration: boolean;
  vibrationMode: string;
  vibrateFallbackStrength: number;
  enableAudioVibration: boolean;
  audioVibrationStrength: number;
  audioVibrationSceneMode: string;
  deadzone: number;
  flipFaceButtons: boolean;

  showLocalCursor: boolean;
  touchscreenTrackpad: boolean;
  enableDoubleClickDrag: boolean;
  doubleTapTimeThreshold: number;

  enableEnhancedTouch: boolean;
  enhancedTouchOnRight: boolean;
  enhancedTouchZoneDivider: number;
  pointerVelocityFactor: number;
  longPressFlatRegion: number;

  packetSize: number;
  encryptionFlags: number;
  colorRange: ColorRange;
  decoderBufferCount: number;
  enableSyncDecode: boolean;
  enableVrr: boolean;
  enableVsync: boolean;
  enableStun: boolean;
  performanceMode: boolean;

  remote: RemoteConfig;

  showPerfOverlay: boolean;
  perfOverlayOrientation: PerfOverlayOrientation;
  perfOverlayPosition: PerfOverlayPosition;
  showOnscreenControls: boolean;
  onscreenControlsOpacity: number;
  enableEscMenu: boolean;
}

export enum AudioConfiguration {
  STEREO = 0x000302CA,
  SURROUND_51 = 0x003F06CA,
  SURROUND_71 = 0x063F08CA
}

export function getSurroundAudioInfo(audioConfig: AudioConfiguration): number {
  const channelCount = (audioConfig >> 8) & 0xFF;
  const channelMask = (audioConfig >> 16) & 0xFFFF;
  return (channelMask << 16) | channelCount;
}

export enum ColorRange {
  LIMITED = 0,
  FULL = 1
}

export enum HdrMode {
  SDR = 0,
  HDR10 = 1,
  HLG = 2
}

export enum RemoteConfig {
  LOCAL = 0,
  REMOTE = 1,
  AUTO = 2
}

export enum ScreenCombinationMode {
  HOST_DEFAULT = -1,
  NO_OPERATION = 0,
  ENSURE_ACTIVE = 1,
  ENSURE_PRIMARY = 2,
  ENSURE_ONLY_DISPLAY = 3,
}

export enum PerfOverlayOrientation {
  HORIZONTAL = 0,
  VERTICAL = 1
}

export enum PerfOverlayPosition {
  TOP = 0,
  BOTTOM = 1,
  TOP_LEFT = 2,
  TOP_RIGHT = 3,
  BOTTOM_LEFT = 4,
  BOTTOM_RIGHT = 5
}

export interface ResolutionPreset {
  name: string;
  width: number;
  height: number;
}

export function getDefaultStreamConfig(): StreamConfig {
  const defaultBitrate = getRecommendedBitrate(1920, 1080, 60);

  return {
    width: 1920,
    height: 1080,
    fps: 60,
    clientRefreshRateX100: 6000,
    bitrate: defaultBitrate,
    codec: 'H.264',
    hdr: false,
    hdrMode: HdrMode.SDR,
    hdrHighBrightness: false,
    stretchVideo: false,

    audioEnabled: true,
    microphoneEnabled: false,
    micBitrate: 64,
    audioConfig: AudioConfiguration.STEREO,
    enableSpatializer: false,

    sops: true,
    playLocalAudio: false,
    screenCombinationMode: ScreenCombinationMode.HOST_DEFAULT,
    lockScreenAfterDisconnect: false,

    multiController: true,
    attachedGamepadMask: 0,
    enableVibration: true,
    vibrationMode: 'auto',
    vibrateFallbackStrength: 100,
    enableAudioVibration: false,
    audioVibrationStrength: 60,
    audioVibrationSceneMode: 'game',
    deadzone: 7,
    flipFaceButtons: false,

    showLocalCursor: false,
    touchscreenTrackpad: false,
    enableDoubleClickDrag: false,
    doubleTapTimeThreshold: 125,

    enableEnhancedTouch: true,
    enhancedTouchOnRight: false,
    enhancedTouchZoneDivider: 50,
    pointerVelocityFactor: 100,
    longPressFlatRegion: 0,

    packetSize: 1024,
    encryptionFlags: 0,
    colorRange: ColorRange.LIMITED,
    decoderBufferCount: 0,
    enableSyncDecode: false,
    enableVrr: false,
    enableVsync: false,
    enableStun: false,
    performanceMode: false,

    remote: RemoteConfig.AUTO,

    showPerfOverlay: false,
    perfOverlayOrientation: PerfOverlayOrientation.VERTICAL,
    perfOverlayPosition: PerfOverlayPosition.TOP,
    showOnscreenControls: false,
    onscreenControlsOpacity: 90,
    enableEscMenu: true
  };
}

export function getResolutionPresets(): ResolutionPreset[] {
  const presets: ResolutionPreset[] = [
    { name: '720p', width: 1280, height: 720 } as ResolutionPreset,
    { name: '1080p', width: 1920, height: 1080 } as ResolutionPreset,
    { name: '1440p', width: 2560, height: 1440 } as ResolutionPreset,
    { name: '4K', width: 3840, height: 2160 } as ResolutionPreset
  ];
  return presets;
}

export function getRecommendedBitrate(width: number, height: number, fps: number): number {
  const frameRateFactor = (fps <= 60 ? fps : (Math.sqrt(fps / 60) * 60)) / 30;

  const pixels = width * height;

  const pixelVals = [
    640 * 360,
    854 * 480,
    1280 * 720,
    1920 * 1080,
    2560 * 1440,
    3840 * 2160,
    -1
  ];
  const factorVals = [1, 2, 5, 10, 20, 40, -1];

  let resolutionFactor = factorVals[0];
  for (let i = 0; i < pixelVals.length; i++) {
    if (pixels === pixelVals[i]) {
      resolutionFactor = factorVals[i];
      break;
    } else if (pixels < pixelVals[i]) {
      if (i === 0) {
        resolutionFactor = factorVals[i];
      } else {
        resolutionFactor =
          ((pixels - pixelVals[i - 1]) / (pixelVals[i] - pixelVals[i - 1])) *
          (factorVals[i] - factorVals[i - 1]) + factorVals[i - 1];
      }
      break;
    } else if (pixelVals[i] === -1) {
      resolutionFactor = factorVals[i - 1];
      break;
    }
  }

  return Math.round(resolutionFactor * frameRateFactor) * 1000;
}
