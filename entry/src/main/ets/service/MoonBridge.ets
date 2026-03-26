/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */



import nativeLib from 'libmoonlight_nativelib.so';




export const BUTTON_ACTION_PRESS = 0x07;
export const BUTTON_ACTION_RELEASE = 0x08;


export const BUTTON_LEFT = 0x01;
export const BUTTON_MIDDLE = 0x02;
export const BUTTON_RIGHT = 0x03;
export const BUTTON_X1 = 0x04;
export const BUTTON_X2 = 0x05;


export const KEY_ACTION_DOWN = 0x03;
export const KEY_ACTION_UP = 0x04;


export const MODIFIER_SHIFT = 0x01;
export const MODIFIER_CTRL = 0x02;
export const MODIFIER_ALT = 0x04;
export const MODIFIER_META = 0x08;


export const VK_SHIFT = 0x10;
export const VK_CONTROL = 0x11;
export const VK_MENU = 0x12;    // Alt
export const VK_LWIN = 0x5B;


export const TOUCH_EVENT_HOVER = 0x00;
export const TOUCH_EVENT_DOWN = 0x01;
export const TOUCH_EVENT_UP = 0x02;
export const TOUCH_EVENT_MOVE = 0x03;
export const TOUCH_EVENT_CANCEL = 0x04;
export const TOUCH_EVENT_BUTTON_ONLY = 0x05;
export const TOUCH_EVENT_HOVER_LEAVE = 0x06;
export const TOUCH_EVENT_CANCEL_ALL = 0x07;


export const LI_TOOL_TYPE_UNKNOWN = 0x00;
export const LI_TOOL_TYPE_PEN = 0x01;
export const LI_TOOL_TYPE_ERASER = 0x02;


export const LI_PEN_BUTTON_PRIMARY = 0x01;
export const LI_PEN_BUTTON_SECONDARY = 0x02;
export const LI_PEN_BUTTON_TERTIARY = 0x04;


export const LI_TILT_UNKNOWN = 0xFF;
export const LI_ROT_UNKNOWN = 0xFFFF;


export const LI_FF_PEN_TOUCH_EVENTS = 0x01;


export const A_FLAG = 0x1000;
export const B_FLAG = 0x2000;
export const X_FLAG = 0x4000;
export const Y_FLAG = 0x8000;
export const UP_FLAG = 0x0001;
export const DOWN_FLAG = 0x0002;
export const LEFT_FLAG = 0x0004;
export const RIGHT_FLAG = 0x0008;
export const LB_FLAG = 0x0100;
export const RB_FLAG = 0x0200;
export const PLAY_FLAG = 0x0010;
export const BACK_FLAG = 0x0020;
export const LS_CLK_FLAG = 0x0040;
export const RS_CLK_FLAG = 0x0080;
export const SPECIAL_FLAG = 0x0400;
export const PADDLE1_FLAG = 0x010000;
export const PADDLE2_FLAG = 0x020000;
export const PADDLE3_FLAG = 0x040000;
export const PADDLE4_FLAG = 0x080000;
export const TOUCHPAD_FLAG = 0x100000;
export const MISC_FLAG = 0x200000;


export const CONTROLLER_TYPE_UNKNOWN = 0x00;
export const CONTROLLER_TYPE_XBOX = 0x01;
export const CONTROLLER_TYPE_PS = 0x02;
export const CONTROLLER_TYPE_NINTENDO = 0x03;


export const LI_CCAP_ANALOG_TRIGGERS = 0x01;
export const LI_CCAP_RUMBLE = 0x02;
export const LI_CCAP_TRIGGER_RUMBLE = 0x04;
export const LI_CCAP_TOUCHPAD = 0x08;
export const LI_CCAP_ACCEL = 0x10;
export const LI_CCAP_GYRO = 0x20;
export const LI_CCAP_BATTERY_STATE = 0x40;
export const LI_CCAP_RGB_LED = 0x80;


export const LI_MOTION_TYPE_ACCEL = 0x01;
export const LI_MOTION_TYPE_GYRO = 0x02;


export const VIDEO_FORMAT_H264 = 0x0001;
export const VIDEO_FORMAT_H265 = 0x0100;
export const VIDEO_FORMAT_H265_MAIN10 = 0x0200;
export const VIDEO_FORMAT_AV1_MAIN8 = 0x1000;
export const VIDEO_FORMAT_AV1_MAIN10 = 0x2000;


export interface RttInfo {
  rtt: number;
  variance: number;
}


export interface NativeMicStats {
  running: boolean;
  paused: boolean;
  captured: number;
  encoded: number;
  sent: number;
  dropped: number;
}


export const AUDIO_CONFIGURATION_STEREO = 0;
export const AUDIO_CONFIGURATION_51_SURROUND = 1;
export const AUDIO_CONFIGURATION_71_SURROUND = 2;


export const STAGE_NONE = 0;
export const STAGE_PLATFORM_INIT = 1;
export const STAGE_NAME_RESOLUTION = 2;
export const STAGE_RTSP_HANDSHAKE = 3;
export const STAGE_CONTROL_STREAM_INIT = 4;
export const STAGE_VIDEO_STREAM_INIT = 5;
export const STAGE_AUDIO_STREAM_INIT = 6;
export const STAGE_INPUT_STREAM_INIT = 7;
export const STAGE_CONTROL_STREAM_START = 8;
export const STAGE_VIDEO_STREAM_START = 9;
export const STAGE_AUDIO_STREAM_START = 10;
export const STAGE_INPUT_STREAM_START = 11;
export const STAGE_MAX = 12;


export const CONN_STATUS_OKAY = 0;
export const CONN_STATUS_POOR = 1;


export const ML_TEST_RESULT_INCONCLUSIVE = 0xFFFFFFFF;


export const CONNECTION_TEST_SERVER = 'android.conntest.moonlight-stream.org';


export const CAPABILITY_DIRECT_SUBMIT = 0x01;
export const CAPABILITY_REFERENCE_FRAME_INVALIDATION_AVC = 0x02;
export const CAPABILITY_REFERENCE_FRAME_INVALIDATION_HEVC = 0x04;
export const CAPABILITY_REFERENCE_FRAME_INVALIDATION_AV1 = 0x08;
export const CAPABILITY_SLICES_PER_FRAME = 0x10;


export const BUFFER_TYPE_PICDATA = 0x00;
export const BUFFER_TYPE_SPS = 0x01;
export const BUFFER_TYPE_PPS = 0x02;
export const BUFFER_TYPE_VPS = 0x03;


export const FRAME_TYPE_PFRAME = 0x00;
export const FRAME_TYPE_IDR = 0x01;



export interface VideoDecoderCallbacks {

  drSetup?: (videoFormat: number, width: number, height: number, redrawRate: number) => number;

  drStart?: () => void;

  drStop?: () => void;

  drCleanup?: () => void;

  drSubmitDecodeUnit?: (data: ArrayBuffer, frameNumber: number, frameType: number) => number;
}

export interface AudioRendererCallbacks {

  arInit?: (audioConfiguration: number, sampleRate: number, samplesPerFrame: number) => number;

  arStart?: () => void;

  arStop?: () => void;

  arCleanup?: () => void;

  arPlaySample?: (samples: Int16Array) => void;
}

export interface ConnectionListenerCallbacks {

  stageStarting?: (stage: number) => void;

  stageComplete?: (stage: number) => void;

  stageFailed?: (stage: number, errorCode: number) => void;

  connectionStarted?: () => void;

  connectionTerminated?: (errorCode: number) => void;

  rumble?: (controllerNumber: number, lowFreqMotor: number, highFreqMotor: number) => void;

  connectionStatusUpdate?: (connectionStatus: number) => void;

  resolutionChanged?: (width: number, height: number) => void;
}

export interface MoonBridgeCallbacks extends VideoDecoderCallbacks, AudioRendererCallbacks, ConnectionListenerCallbacks {
}




export const HDR_MODE_SDR = 0;
export const HDR_MODE_HDR10 = 1;
export const HDR_MODE_HLG = 2;

export interface StreamConfiguration {
  address: string;
  appVersion: string;
  gfeVersion?: string;
  rtspSessionUrl?: string;
  serverCodecModeSupport: number;
  width: number;
  height: number;
  fps: number;
  bitrate: number;
  packetSize: number;
  streamingRemotely: number;
  audioConfiguration: number;
  supportedVideoFormats: number;
  clientRefreshRateX100: number;
  riAesKey: ArrayBuffer;
  riAesIv: ArrayBuffer;
  videoCapabilities: number;
  colorSpace: number;
  colorRange: number;
  hdrMode?: number;
  enableMic?: boolean;
  controlOnly?: boolean;
}



class MoonBridgeClass {
  private callbacks: MoonBridgeCallbacks | null = null;


  init(callbacks: MoonBridgeCallbacks): boolean {
    this.callbacks = callbacks;
    return nativeLib.init(callbacks);
  }


  startConnection(config: StreamConfiguration): number {
    return nativeLib.startConnection(
      config.address,
      config.appVersion,
      config.gfeVersion || '',
      config.rtspSessionUrl || '',
      config.serverCodecModeSupport,
      config.width,
      config.height,
      config.fps,
      config.bitrate,
      config.packetSize,
      config.streamingRemotely,
      config.audioConfiguration,
      config.supportedVideoFormats,
      config.clientRefreshRateX100,
      config.riAesKey,
      config.riAesIv,
      config.videoCapabilities,
      config.colorSpace,
      config.colorRange,
      config.hdrMode || HDR_MODE_SDR,
      config.enableMic || false,
      config.controlOnly || false
    );
  }


  stopConnection(): void {
    nativeLib.stopConnection();
  }


  interruptConnection(): void {
    nativeLib.interruptConnection();
  }



  sendMouseMove(deltaX: number, deltaY: number): void {
    nativeLib.sendMouseMove(deltaX, deltaY);
  }

  sendMousePosition(x: number, y: number, referenceWidth: number, referenceHeight: number): void {
    nativeLib.sendMousePosition(x, y, referenceWidth, referenceHeight);
  }

  sendMouseMoveAsMousePosition(deltaX: number, deltaY: number, referenceWidth: number, referenceHeight: number): void {
    nativeLib.sendMouseMoveAsMousePosition(deltaX, deltaY, referenceWidth, referenceHeight);
  }

  sendMouseButton(buttonEvent: number, mouseButton: number): void {
    nativeLib.sendMouseButton(buttonEvent, mouseButton);
  }

  sendMouseHighResScroll(scrollAmount: number): void {
    nativeLib.sendMouseHighResScroll(scrollAmount);
  }

  sendMouseHighResHScroll(scrollAmount: number): void {
    nativeLib.sendMouseHighResHScroll(scrollAmount);
  }



  sendKeyboardInput(keyCode: number, keyAction: number, modifiers: number, flags: number): void {
    nativeLib.sendKeyboardInput(keyCode, keyAction, modifiers, flags);
  }

  sendUtf8Text(text: string): void {
    nativeLib.sendUtf8Text(text);
  }



  sendMultiControllerInput(
    controllerNumber: number,
    activeGamepadMask: number,
    buttonFlags: number,
    leftTrigger: number,
    rightTrigger: number,
    leftStickX: number,
    leftStickY: number,
    rightStickX: number,
    rightStickY: number
  ): void {
    nativeLib.sendMultiControllerInput(
      controllerNumber,
      activeGamepadMask,
      buttonFlags,
      leftTrigger,
      rightTrigger,
      leftStickX,
      leftStickY,
      rightStickX,
      rightStickY
    );
  }

  sendControllerArrivalEvent(
    controllerNumber: number,
    activeGamepadMask: number,
    type: number,
    supportedButtonFlags: number,
    capabilities: number
  ): number {
    return nativeLib.sendControllerArrivalEvent(
      controllerNumber,
      activeGamepadMask,
      type,
      supportedButtonFlags,
      capabilities
    );
  }

  sendControllerTouchEvent(
    controllerNumber: number,
    eventType: number,
    pointerId: number,
    x: number,
    y: number,
    pressure: number
  ): number {
    return nativeLib.sendControllerTouchEvent(controllerNumber, eventType, pointerId, x, y, pressure);
  }

  sendControllerMotionEvent(
    controllerNumber: number,
    motionType: number,
    x: number,
    y: number,
    z: number
  ): number {
    return nativeLib.sendControllerMotionEvent(controllerNumber, motionType, x, y, z);
  }

  sendControllerBatteryEvent(
    controllerNumber: number,
    batteryState: number,
    batteryPercentage: number
  ): number {
    return nativeLib.sendControllerBatteryEvent(controllerNumber, batteryState, batteryPercentage);
  }



  sendTouchEvent(
    eventType: number,
    pointerId: number,
    x: number,
    y: number,
    pressureOrDistance: number,
    contactAreaMajor: number,
    contactAreaMinor: number,
    rotation: number
  ): number {
    return nativeLib.sendTouchEvent(
      eventType,
      pointerId,
      x,
      y,
      pressureOrDistance,
      contactAreaMajor,
      contactAreaMinor,
      rotation
    );
  }

  sendPenEvent(
    eventType: number,
    toolType: number,
    penButtons: number,
    x: number,
    y: number,
    pressureOrDistance: number,
    contactAreaMajor: number,
    contactAreaMinor: number,
    rotation: number,
    tilt: number
  ): number {
    return nativeLib.sendPenEvent(
      eventType,
      toolType,
      penButtons,
      x,
      y,
      pressureOrDistance,
      contactAreaMajor,
      contactAreaMinor,
      rotation,
      tilt
    );
  }



  getMicPortNumber(): number {
    return nativeLib.getMicPortNumber();
  }

  isMicrophoneRequested(): boolean {
    return nativeLib.isMicrophoneRequested();
  }

  sendMicrophoneOpusData(opusData: ArrayBuffer): number {
    return nativeLib.sendMicrophoneOpusData(opusData);
  }

  isMicrophoneEncryptionEnabled(): boolean {
    return nativeLib.isMicrophoneEncryptionEnabled();
  }




  opusEncoderCreate(sampleRate: number = 48000, channels: number = 1, bitrate: number = 64000): number {
    return nativeLib.opusEncoderCreate(sampleRate, channels, bitrate);
  }


  opusEncoderEncode(handle: number, pcmData: ArrayBuffer): ArrayBuffer | undefined {
    return nativeLib.opusEncoderEncode(handle, pcmData);
  }


  opusEncoderDestroy(handle: number): void {
    nativeLib.opusEncoderDestroy(handle);
  }




  nativeMicStart(sampleRate: number = 48000, channels: number = 1, bitrate: number = 64000): number {
    return nativeLib.nativeMicStart(sampleRate, channels, bitrate);
  }


  nativeMicStop(): void {
    nativeLib.nativeMicStop();
  }


  nativeMicPause(): void {
    nativeLib.nativeMicPause();
  }


  nativeMicResume(): void {
    nativeLib.nativeMicResume();
  }


  nativeMicGetStats(): NativeMicStats {
    return nativeLib.nativeMicGetStats();
  }




  setXComponentFrameRate(frameNode: object, fps: number): void {
    nativeLib.setXComponentFrameRate(frameNode, fps);
  }




  setPerformanceModeEnabled(enabled: boolean): void {
    nativeLib.setPerformanceModeEnabled(enabled);
  }


  getPerformanceModeEnabled(): boolean {
    return nativeLib.getPerformanceModeEnabled();
  }



  getStageName(stage: number): string {
    return nativeLib.getStageName(stage);
  }

  getPendingAudioDuration(): number {
    return nativeLib.getPendingAudioDuration();
  }

  getPendingVideoFrames(): number {
    return nativeLib.getPendingVideoFrames();
  }

  getEstimatedRttInfo(): RttInfo | null {
    const combined: number = nativeLib.getEstimatedRttInfo();
    if (combined < 0) {
      return null;
    }
    const rtt = Number(BigInt(combined) >> 32n);
    const variance = combined & 0xFFFFFFFF;
    const result: RttInfo = { rtt: rtt, variance: variance };
    return result;
  }

  getHostFeatureFlags(): number {
    return nativeLib.getHostFeatureFlags();
  }

  getLaunchUrlQueryParameters(): string | null {
    return nativeLib.getLaunchUrlQueryParameters();
  }



  testClientConnectivity(testServerHostName: string, referencePort: number, testFlags: number): number {
    return nativeLib.testClientConnectivity(testServerHostName, referencePort, testFlags);
  }

  getPortFlagsFromStage(stage: number): number {
    return nativeLib.getPortFlagsFromStage(stage);
  }

  getPortFlagsFromTerminationErrorCode(errorCode: number): number {
    return nativeLib.getPortFlagsFromTerminationErrorCode(errorCode);
  }

  stringifyPortFlags(portFlags: number, separator: string): string {
    return nativeLib.stringifyPortFlags(portFlags, separator);
  }

  findExternalAddressIP4(stunHostName: string, stunPort: number): string | null {
    return nativeLib.findExternalAddressIP4(stunHostName, stunPort);
  }

  guessControllerType(vendorId: number, productId: number): number {
    return nativeLib.guessControllerType(vendorId, productId);
  }

  guessControllerHasPaddles(vendorId: number, productId: number): boolean {
    return nativeLib.guessControllerHasPaddles(vendorId, productId);
  }

  guessControllerHasShareButton(vendorId: number, productId: number): boolean {
    return nativeLib.guessControllerHasShareButton(vendorId, productId);
  }
}


export { MoonBridgeClass };
export const MoonBridge = new MoonBridgeClass();
export default MoonBridge;
