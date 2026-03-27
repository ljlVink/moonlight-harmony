/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { PreferencesUtil } from "../utils/PreferencesUtil";
import { display } from "@kit.ArkUI";
import {
  AudioConfiguration,
  ColorRange,
  getRecommendedBitrate,
  HdrMode,
  PerfOverlayOrientation,
  PerfOverlayPosition,
  RemoteConfig,
  ScreenCombinationMode,
  StreamConfig,
} from "../model/StreamConfig";

export class SettingsKeys {
  static readonly RESOLUTION: string = "settings_resolution";
  static readonly CUSTOM_RESOLUTIONS: string = "settings_custom_resolutions";
  static readonly FPS: string = "settings_fps";
  static readonly CUSTOM_FPS: string = "settings_custom_fps";
  static readonly BITRATE: string = "settings_bitrate";
  static readonly HOST_SCALE: string = "settings_host_scale";
  static readonly ENABLE_HDR: string = "settings_enable_hdr";
  static readonly HDR_MODE: string = "settings_hdr_mode"; // 'HDR10' or 'HLG'
  static readonly ENABLE_HDR_HIGH_BRIGHTNESS: string = "settings_enable_hdr_high_brightness";
  static readonly VIDEO_FORMAT: string = "settings_video_format";
  static readonly STRETCH_VIDEO: string = "settings_stretch_video";
  static readonly FULL_RANGE: string = "settings_full_range";
  static readonly REVERSE_RESOLUTION: string = "settings_reverse_resolution";
  static readonly ROTABLE_SCREEN: string = "settings_rotable_screen";
  static readonly SCREEN_POSITION: string = "settings_screen_position";
  static readonly SCREEN_OFFSET_X: string = "settings_screen_offset_x";
  static readonly SCREEN_OFFSET_Y: string = "settings_screen_offset_y";

  static readonly AUDIO_CONFIG: string = "settings_audio_config";
  static readonly ENABLE_LOCAL_AUDIO: string = "settings_enable_local_audio";
  static readonly ENABLE_SPATIALIZER: string = "settings_enable_spatializer";
  static readonly CONTROL_ONLY: string = "settings_control_only";
  static readonly ENABLE_MIC: string = "settings_enable_mic";
  static readonly MIC_BITRATE: string = "settings_mic_bitrate";

  static readonly ENABLE_VIBRATION: string = "settings_enable_vibration";
  static readonly VIBRATION_MODE: string = "settings_vibration_mode";
  static readonly VIBRATE_FALLBACK_STRENGTH: string = "settings_vibrate_fallback_strength";
  static readonly ENABLE_AUDIO_VIBRATION: string = "settings_enable_audio_vibration";
  static readonly AUDIO_VIBRATION_STRENGTH: string = "settings_audio_vibration_strength";
  static readonly AUDIO_VIBRATION_SCENE_MODE: string = "settings_audio_vibration_scene_mode";
  static readonly MULTI_CONTROLLER: string = "settings_multi_controller";
  static readonly FLIP_FACE_BUTTONS: string = "settings_flip_face_buttons";
  static readonly DEADZONE: string = "settings_deadzone";
  static readonly GAMEPAD_MOTION_SENSORS: string = "settings_gamepad_motion_sensors";
  static readonly GAMEPAD_MOTION_FALLBACK: string = "settings_gamepad_motion_fallback";
  static readonly GAMEPAD_TOUCHPAD_MOUSE: string = "settings_gamepad_touchpad_mouse";

  static readonly GYRO_ASSIST_ENABLED: string = "settings_gyro_assist_enabled";
  static readonly GYRO_SENSITIVITY: string = "settings_gyro_sensitivity";
  static readonly GYRO_INVERT_X: string = "settings_gyro_invert_x";
  static readonly GYRO_INVERT_Y: string = "settings_gyro_invert_y";
  static readonly GYRO_ACTIVATION_KEY: string = "settings_gyro_activation_key";
  static readonly SHOW_GYRO_CARD: string = "settings_show_gyro_card";

  static readonly ENABLE_START_KEY_MENU: string = "settings_enable_start_key_menu";
  static readonly IGNORE_DEVICE_DISCONNECT: string = "settings_ignore_device_disconnect";
  static readonly GC_BUTTON_HOME_MAPPING: string = "settings_gc_button_home_mapping";
  static readonly ENABLE_KEY_INTERCEPTOR: string = "settings_enable_key_interceptor";
  static readonly ENABLE_INPUT_KIT_TOUCH: string = "settings_enable_input_kit_touch";
  static readonly USB_DRIVER_ENABLED: string = "settings_usb_driver_enabled";
  static readonly FORCE_USB_DRIVER_ONLY: string = "settings_force_usb_driver_only";
  static readonly DDK_HIGH_SPEED_POLLING: string = "settings_ddk_high_speed_polling";

  static readonly ENABLE_ONSCREEN_CONTROLS: string = "settings_enable_onscreen_controls";
  static readonly ENABLE_ONSCREEN_KEYBOARD: string = "settings_enable_onscreen_keyboard";
  static readonly ONLY_L3_R3: string = "settings_only_l3_r3";
  static readonly SHOW_GUIDE_BUTTON: string = "settings_show_guide_button";
  static readonly HALF_HEIGHT_OSC_PORTRAIT: string = "settings_half_height_osc_portrait";
  static readonly OSC_OPACITY: string = "settings_osc_opacity";
  static readonly VIBRATE_OSC: string = "settings_vibrate_osc";

  static readonly SHOW_LOCAL_CURSOR: string = "settings_show_local_cursor";
  static readonly TOUCHSCREEN_TRACKPAD: string = "settings_touchscreen_trackpad";
  static readonly ENABLE_DOUBLE_CLICK_DRAG: string = "settings_enable_double_click_drag";
  static readonly DOUBLE_TAP_TIME_THRESHOLD: string = "settings_double_tap_time_threshold";
  static readonly MOUSE_NAV_BUTTONS: string = "settings_mouse_nav_buttons";
  static readonly GAME_MOUSE_MODE: string = "settings_game_mouse_mode";
  static readonly LAST_TOUCH_MODE: string = "settings_last_touch_mode";

  static readonly ENABLE_ENHANCED_TOUCH: string = "settings_enable_enhanced_touch";
  static readonly ENHANCED_TOUCH_ON_RIGHT: string = "settings_enhanced_touch_on_right";
  static readonly ENHANCED_TOUCH_ZONE_DIVIDER: string = "settings_enhanced_touch_zone_divider";
  static readonly POINTER_VELOCITY_FACTOR: string = "settings_pointer_velocity_factor";
  static readonly LONG_PRESS_FLAT_REGION: string = "settings_long_press_flat_region";

  static readonly ENABLE_SOPS: string = "settings_enable_sops";
  static readonly SCREEN_COMBINATION_MODE: string = "settings_screen_combination_mode";
  static readonly LOCK_SCREEN_AFTER_DISCONNECT: string = "settings_lock_screen_after_disconnect";

  static readonly DECODER_BUFFER_COUNT: string = "settings_decoder_buffer_count";
  static readonly ENABLE_SYNC_DECODE: string = "settings_enable_sync_decode";
  static readonly ENABLE_VRR: string = "settings_enable_vrr";
  static readonly ENABLE_VSYNC: string = "settings_enable_vsync";
  static readonly ENABLE_PERF_OVERLAY: string = "settings_enable_perf_overlay";
  static readonly PERF_OVERLAY_ORIENTATION: string = "settings_perf_overlay_orientation";
  static readonly PERF_OVERLAY_POSITION: string = "settings_perf_overlay_position";
  static readonly PERF_OVERLAY_LOCKED: string = "settings_perf_overlay_locked";
  static readonly PERF_OVERLAY_ITEMS: string = "settings_perf_overlay_items";
  static readonly PERF_OVERLAY_BG_OPACITY: string = "settings_perf_overlay_bg_opacity";
  static readonly PERF_OVERLAY_GUIDE_SHOWN: string = "settings_perf_overlay_guide_shown";
  static readonly LATENCY_TOAST: string = "settings_latency_toast";
  static readonly DISABLE_WARNINGS: string = "settings_disable_warnings";
  static readonly ENABLE_STUN: string = "settings_enable_stun";
  static readonly ENABLE_ESC_MENU: string = "settings_enable_esc_menu";
  static readonly ESC_MENU_KEY: string = "settings_esc_menu_key";
  static readonly ENABLE_BACKGROUND_TASK: string = "settings_enable_background_task";

  static readonly SMALL_ICON_MODE: string = "settings_small_icon_mode";
  static readonly RESUME_STREAM: string = "settings_resume_stream";

  static readonly DEVELOPER_MODE: string = "settings_developer_mode";
  static readonly DEV_KEY_ACTIVATED: string = "settings_dev_key_activated";

  static readonly PERFORMANCE_MODE: string = "settings_performance_mode";
}

export interface InputSettings {
  enableVibration: boolean;
  vibrationMode: string;
  vibrateFallbackStrength: number;
  enableAudioVibration: boolean;
  audioVibrationStrength: number;
  audioVibrationSceneMode: string;
  multiController: boolean;
  flipFaceButtons: boolean;
  deadzone: number;
  gamepadMotionSensors: boolean;
  gamepadMotionFallback: boolean;
  gamepadTouchpadMouse: boolean;
  enableStartKeyMenu: boolean;
  ignoreDeviceDisconnect: boolean;
  enableKeyInterceptor: boolean;
  enableInputKitTouch: boolean;
  usbDriverEnabled: boolean;
  forceUsbDriverOnly: boolean;
  ddkHighSpeedPolling: boolean;

  gyroAssistEnabled: boolean;
  gyroSensitivity: number;
  gyroInvertX: boolean;
  gyroInvertY: boolean;
  gyroActivationKey: number;
  showGyroCard: boolean;

  enableOnscreenControls: boolean;
  enableOnscreenKeyboard: boolean;
  onlyL3R3: boolean;
  showGuideButton: boolean;
  halfHeightOscPortrait: boolean;
  oscOpacity: number;
  vibrateOsc: boolean;

  showLocalCursor: boolean;
  touchscreenTrackpad: boolean;
  enableDoubleClickDrag: boolean;
  doubleTapTimeThreshold: number;
  mouseNavButtons: boolean;
  gameMouseMode: boolean;

  enableEnhancedTouch: boolean;
  enhancedTouchOnRight: boolean;
  enhancedTouchZoneDivider: number;
  pointerVelocityFactor: number;
  longPressFlatRegion: number;
}

export interface HostSettings {
  enableSops: boolean;
  screenCombinationMode: string;
  lockScreenAfterDisconnect: boolean;
}

export interface DisplaySettings {
  stretchVideo: boolean;
  reverseResolution: boolean;
  rotableScreen: boolean;
  enableHdrHighBrightness: boolean;
  screenPosition: string;
  screenOffsetX: number;
  screenOffsetY: number;
  enablePerfOverlay: boolean;
  perfOverlayOrientation: string;
  perfOverlayPosition: string;
  perfOverlayLocked?: boolean;
  perfOverlayItems?: string[];
  perfOverlayBgOpacity?: number;
}

export interface AdvancedSettings {
  decoderBufferCount: number;
  enableSyncDecode: boolean;
  enableVrr: boolean;
  latencyToast: boolean;
  disableWarnings: boolean;
  enableStun: boolean;
  enableEscMenu: boolean;
  escMenuKey: string;
  performanceMode: boolean;
}

export interface AudioSettings {
  audioConfig: string;
  enableLocalAudio: boolean;
  enableSpatializer: boolean;
  controlOnly: boolean;
  enableMic: boolean;
  micBitrate: number;
}

interface Resolution {
  width: number;
  height: number;
}

export class SettingsService {
  private static instance: SettingsService | null = null;

  private constructor() {}

  static getInstance(): SettingsService {
    if (!SettingsService.instance) {
      SettingsService.instance = new SettingsService();
    }
    return SettingsService.instance;
  }

  private parseResolution(resolutionStr: string): Resolution {
    if (resolutionStr === "native") {
      try {
        const displayInfo = display.getDefaultDisplaySync();
        const w = displayInfo.width;
        const h = displayInfo.height;
        return w >= h
          ? ({ width: w, height: h } as Resolution)
          : ({ width: h, height: w } as Resolution);
      } catch (_e) {
        return { width: 1920, height: 1080 } as Resolution;
      }
    }
    switch (resolutionStr) {
      case "720p":
        return { width: 1280, height: 720 } as Resolution;
      case "1080p":
        return { width: 1920, height: 1080 } as Resolution;
      case "1440p":
        return { width: 2560, height: 1440 } as Resolution;
      case "4K":
        return { width: 3840, height: 2160 } as Resolution;
      case "360p":
        return { width: 640, height: 360 } as Resolution;
      case "480p":
        return { width: 854, height: 480 } as Resolution;
    }

    const match = resolutionStr.match(/^(\d+)x(\d+)$/);
    if (match) {
      const width = parseInt(match[1]);
      const height = parseInt(match[2]);
      if (width >= 320 && width <= 7680 && height >= 240 && height <= 4320) {
        return { width, height } as Resolution;
      }
    }

    return { width: 1920, height: 1080 } as Resolution;
  }

  private parseFps(fpsStr: string): number {
    if (fpsStr.startsWith("自定义:")) {
      const customFps = parseInt(fpsStr.split(":")[1]);
      return isNaN(customFps) ? 60 : customFps;
    }

    switch (fpsStr) {
      case "30 FPS":
        return 30;
      case "60 FPS":
        return 60;
      case "90 FPS":
        return 90;
      case "119.88 FPS":
        return 120;
      case "120 FPS":
        return 120;
      case "144 FPS":
        return 144;
      default: {
        const parsed = parseInt(fpsStr);
        return isNaN(parsed) ? 60 : parsed;
      }
    }
  }

  private parseClientRefreshRateX100(fpsStr: string): number {
    if (fpsStr.startsWith("自定义:")) {
      const customFps = parseInt(fpsStr.split(":")[1]);
      return isNaN(customFps) ? 6000 : customFps * 100;
    }

    switch (fpsStr) {
      case "30 FPS":
        return 3000;
      case "60 FPS":
        return 6000;
      case "90 FPS":
        return 9000;
      case "119.88 FPS":
        return 11988;
      case "120 FPS":
        return 12000;
      case "144 FPS":
        return 14400;
      default: {
        const parsed = parseInt(fpsStr);
        return isNaN(parsed) ? 6000 : parsed * 100;
      }
    }
  }

  private parseAudioConfig(configStr: string): AudioConfiguration {
    switch (configStr) {
      case "立体声":
        return AudioConfiguration.STEREO;
      case "5.1 环绕声":
        return AudioConfiguration.SURROUND_51;
      case "7.1 环绕声":
        return AudioConfiguration.SURROUND_71;
      default:
        return AudioConfiguration.STEREO;
    }
  }

  private parseVideoFormat(formatStr: string): "H.264" | "HEVC" {
    switch (formatStr) {
      case "自动":
      case "HEVC (H.265)":
        return "HEVC";
      case "H.264":
        return "H.264";
      default:
        return "HEVC";
    }
  }

  private parseScreenCombinationMode(modeStr: string): ScreenCombinationMode {
    switch (modeStr) {
      case "主机默认":
        return ScreenCombinationMode.HOST_DEFAULT;
      case "不修改":
        return ScreenCombinationMode.NO_OPERATION;
      case "确保开启":
        return ScreenCombinationMode.ENSURE_ACTIVE;
      case "设为主屏":
        return ScreenCombinationMode.ENSURE_PRIMARY;
      case "仅此屏幕":
        return ScreenCombinationMode.ENSURE_ONLY_DISPLAY;
      default:
        return ScreenCombinationMode.HOST_DEFAULT;
    }
  }

  private parsePerfOverlayOrientation(orientationStr: string): PerfOverlayOrientation {
    switch (orientationStr) {
      case "水平":
        return PerfOverlayOrientation.HORIZONTAL;
      case "垂直":
        return PerfOverlayOrientation.VERTICAL;
      default:
        return PerfOverlayOrientation.HORIZONTAL;
    }
  }

  private parsePerfOverlayPosition(positionStr: string): PerfOverlayPosition {
    switch (positionStr) {
      case "顶部":
        return PerfOverlayPosition.TOP;
      case "底部":
        return PerfOverlayPosition.BOTTOM;
      case "左上角":
        return PerfOverlayPosition.TOP_LEFT;
      case "右上角":
        return PerfOverlayPosition.TOP_RIGHT;
      case "左下角":
        return PerfOverlayPosition.BOTTOM_LEFT;
      case "右下角":
        return PerfOverlayPosition.BOTTOM_RIGHT;
      default:
        return PerfOverlayPosition.TOP;
    }
  }

  private async getBoolean(key: string, defaultValue: boolean): Promise<boolean> {
    const value = await PreferencesUtil.get<string | boolean>(key, defaultValue.toString());
    if (typeof value === "boolean") {
      return value;
    }
    return value === "true";
  }

  private async getNumber(key: string, defaultValue: number): Promise<number> {
    const value = await PreferencesUtil.get<number | string>(key, defaultValue.toString());
    if (typeof value === "number") {
      return value;
    }
    return parseInt(value) || defaultValue;
  }

  private async getString(key: string, defaultValue: string): Promise<string> {
    return await PreferencesUtil.get<string>(key, defaultValue);
  }

  async getStreamConfig(): Promise<StreamConfig> {
    const resolutionStr = await this.getString(SettingsKeys.RESOLUTION, "1080p");
    const fpsStr = await this.getString(SettingsKeys.FPS, "60 FPS");
    const bitrateRaw = await this.getNumber(SettingsKeys.BITRATE, 0);
    const hostScale = await this.getNumber(SettingsKeys.HOST_SCALE, 100);
    const enableHdr = await this.getBoolean(SettingsKeys.ENABLE_HDR, false);
    const hdrModeStr = await this.getString(SettingsKeys.HDR_MODE, "HDR10");
    const videoFormatStr = await this.getString(SettingsKeys.VIDEO_FORMAT, "自动");
    const fullRange = await this.getBoolean(SettingsKeys.FULL_RANGE, false);
    const reverseResolution = await this.getBoolean(SettingsKeys.REVERSE_RESOLUTION, false);

    let resolution: Resolution = this.parseResolution(resolutionStr);
    const fps = this.parseFps(fpsStr);

    if (hostScale !== 100) {
      const scaledWidth = Math.round((resolution.width * hostScale) / 100);
      const scaledHeight = Math.round((resolution.height * hostScale) / 100);
      resolution = { width: scaledWidth, height: scaledHeight } as Resolution;
    }

    if (reverseResolution) {
      const temp = resolution.width;
      resolution.width = resolution.height;
      resolution.height = temp;
    }

    let bitrate = bitrateRaw * 1000;
    if (bitrateRaw <= 0) {
      bitrate = getRecommendedBitrate(resolution.width, resolution.height, fps);
    }

    const audioConfigStr = await this.getString(SettingsKeys.AUDIO_CONFIG, "立体声");
    const enableLocalAudio = await this.getBoolean(SettingsKeys.ENABLE_LOCAL_AUDIO, false);
    const developerMode = await this.getBoolean(SettingsKeys.DEVELOPER_MODE, false);
    const enableMic = developerMode && (await this.getBoolean(SettingsKeys.ENABLE_MIC, false));
    const micBitrate = await this.getNumber(SettingsKeys.MIC_BITRATE, 64);
    const controlOnly = await this.getBoolean(SettingsKeys.CONTROL_ONLY, false);
    const enableSpatializer = await this.getBoolean(SettingsKeys.ENABLE_SPATIALIZER, false);

    const enableSops = await this.getBoolean(SettingsKeys.ENABLE_SOPS, true);
    const multiController = await this.getBoolean(SettingsKeys.MULTI_CONTROLLER, true);
    const lockScreenAfterDisconnect = await this.getBoolean(
      SettingsKeys.LOCK_SCREEN_AFTER_DISCONNECT,
      false,
    );
    const screenCombinationModeStr = await this.getString(
      SettingsKeys.SCREEN_COMBINATION_MODE,
      "主机默认",
    );

    const enableVibration = await this.getBoolean(SettingsKeys.ENABLE_VIBRATION, true);
    const vibrationMode = await this.getString(SettingsKeys.VIBRATION_MODE, "自动");
    const vibrateFallbackStrength = await this.getNumber(
      SettingsKeys.VIBRATE_FALLBACK_STRENGTH,
      100,
    );
    const enableAudioVibration = await this.getBoolean(SettingsKeys.ENABLE_AUDIO_VIBRATION, false);
    const audioVibrationStrength = await this.getNumber(SettingsKeys.AUDIO_VIBRATION_STRENGTH, 60);
    const audioVibrationSceneMode = await this.getString(
      SettingsKeys.AUDIO_VIBRATION_SCENE_MODE,
      "游戏/电影",
    );
    const deadzone = await this.getNumber(SettingsKeys.DEADZONE, 7);
    const flipFaceButtons = await this.getBoolean(SettingsKeys.FLIP_FACE_BUTTONS, false);

    const showLocalCursor = await this.getBoolean(SettingsKeys.SHOW_LOCAL_CURSOR, false);
    const touchscreenTrackpad = await this.getBoolean(SettingsKeys.TOUCHSCREEN_TRACKPAD, false);
    const enableDoubleClickDrag = await this.getBoolean(
      SettingsKeys.ENABLE_DOUBLE_CLICK_DRAG,
      false,
    );
    const doubleTapTimeThreshold = await this.getNumber(
      SettingsKeys.DOUBLE_TAP_TIME_THRESHOLD,
      125,
    );

    const enableEnhancedTouch = await this.getBoolean(SettingsKeys.ENABLE_ENHANCED_TOUCH, true);
    const enhancedTouchOnRight = await this.getBoolean(SettingsKeys.ENHANCED_TOUCH_ON_RIGHT, false);
    const enhancedTouchZoneDivider = await this.getNumber(
      SettingsKeys.ENHANCED_TOUCH_ZONE_DIVIDER,
      50,
    );
    const pointerVelocityFactor = await this.getNumber(SettingsKeys.POINTER_VELOCITY_FACTOR, 100);
    const longPressFlatRegion = await this.getNumber(SettingsKeys.LONG_PRESS_FLAT_REGION, 0);

    const decoderBufferCount = await this.getNumber(SettingsKeys.DECODER_BUFFER_COUNT, 0);
    const enableSyncDecode = await this.getBoolean(SettingsKeys.ENABLE_SYNC_DECODE, false);
    const enableVrr = await this.getBoolean(SettingsKeys.ENABLE_VRR, false);
    const enableVsync = await this.getBoolean(SettingsKeys.ENABLE_VSYNC, false);
    const enableStun = await this.getBoolean(SettingsKeys.ENABLE_STUN, false);
    const stretchVideo = await this.getBoolean(SettingsKeys.STRETCH_VIDEO, false);
    const hdrHighBrightness = await this.getBoolean(SettingsKeys.ENABLE_HDR_HIGH_BRIGHTNESS, false);

    const enablePerfOverlay = await this.getBoolean(SettingsKeys.ENABLE_PERF_OVERLAY, false);
    const perfOverlayOrientationStr = await this.getString(
      SettingsKeys.PERF_OVERLAY_ORIENTATION,
      "垂直",
    );
    const perfOverlayPositionStr = await this.getString(
      SettingsKeys.PERF_OVERLAY_POSITION,
      "右上角",
    );
    const enableOnscreenControls = await this.getBoolean(
      SettingsKeys.ENABLE_ONSCREEN_CONTROLS,
      false,
    );
    const oscOpacity = await this.getNumber(SettingsKeys.OSC_OPACITY, 90);
    const enableEscMenu = await this.getBoolean(SettingsKeys.ENABLE_ESC_MENU, true);

    const config: StreamConfig = {
      width: resolution.width,
      height: resolution.height,
      fps: fps,
      clientRefreshRateX100: this.parseClientRefreshRateX100(fpsStr),
      bitrate: bitrate,
      codec: this.parseVideoFormat(videoFormatStr),
      hdr: enableHdr,
      hdrMode: hdrModeStr === "HLG" ? HdrMode.HLG : HdrMode.HDR10,
      hdrHighBrightness: hdrHighBrightness,
      stretchVideo: stretchVideo,

      audioEnabled: !controlOnly,
      microphoneEnabled: enableMic,
      micBitrate: micBitrate,
      audioConfig: this.parseAudioConfig(audioConfigStr),
      enableSpatializer: enableSpatializer,

      sops: enableSops,
      playLocalAudio: enableLocalAudio,
      screenCombinationMode: this.parseScreenCombinationMode(screenCombinationModeStr),
      lockScreenAfterDisconnect: lockScreenAfterDisconnect,

      multiController: multiController,
      attachedGamepadMask: 0,
      enableVibration: enableVibration,
      vibrationMode: vibrationMode,
      vibrateFallbackStrength: vibrateFallbackStrength,
      enableAudioVibration: enableAudioVibration,
      audioVibrationStrength: audioVibrationStrength,
      audioVibrationSceneMode: audioVibrationSceneMode,
      deadzone: deadzone,
      flipFaceButtons: flipFaceButtons,

      showLocalCursor: showLocalCursor,
      touchscreenTrackpad: touchscreenTrackpad,
      enableDoubleClickDrag: enableDoubleClickDrag,
      doubleTapTimeThreshold: doubleTapTimeThreshold,

      enableEnhancedTouch: enableEnhancedTouch,
      enhancedTouchOnRight: enhancedTouchOnRight,
      enhancedTouchZoneDivider: enhancedTouchZoneDivider,
      pointerVelocityFactor: pointerVelocityFactor,
      longPressFlatRegion: longPressFlatRegion,

      packetSize: 1024,
      encryptionFlags: 0,
      colorRange: fullRange ? ColorRange.FULL : ColorRange.LIMITED,
      decoderBufferCount: decoderBufferCount,
      enableSyncDecode: enableSyncDecode,
      enableVrr: enableVrr,
      enableVsync: enableVsync,
      enableStun: enableStun,
      performanceMode: await this.getBoolean(SettingsKeys.PERFORMANCE_MODE, false),

      remote: RemoteConfig.AUTO,

      showPerfOverlay: enablePerfOverlay,
      perfOverlayOrientation: this.parsePerfOverlayOrientation(perfOverlayOrientationStr),
      perfOverlayPosition: this.parsePerfOverlayPosition(perfOverlayPositionStr),
      showOnscreenControls: enableOnscreenControls,
      onscreenControlsOpacity: oscOpacity,
      enableEscMenu: enableEscMenu,
    };

    return config;
  }

  async getInputSettings(): Promise<InputSettings> {
    return {
      enableVibration: await this.getBoolean(SettingsKeys.ENABLE_VIBRATION, true),
      vibrationMode: await this.getString(SettingsKeys.VIBRATION_MODE, "自动"),
      vibrateFallbackStrength: await this.getNumber(SettingsKeys.VIBRATE_FALLBACK_STRENGTH, 100),
      enableAudioVibration: await this.getBoolean(SettingsKeys.ENABLE_AUDIO_VIBRATION, false),
      audioVibrationStrength: await this.getNumber(SettingsKeys.AUDIO_VIBRATION_STRENGTH, 60),
      audioVibrationSceneMode: await this.getString(
        SettingsKeys.AUDIO_VIBRATION_SCENE_MODE,
        "游戏/电影",
      ),
      multiController: await this.getBoolean(SettingsKeys.MULTI_CONTROLLER, true),
      flipFaceButtons: await this.getBoolean(SettingsKeys.FLIP_FACE_BUTTONS, false),
      deadzone: await this.getNumber(SettingsKeys.DEADZONE, 7),
      gamepadMotionSensors: await this.getBoolean(SettingsKeys.GAMEPAD_MOTION_SENSORS, true),
      gamepadMotionFallback: await this.getBoolean(SettingsKeys.GAMEPAD_MOTION_FALLBACK, false),
      gamepadTouchpadMouse: await this.getBoolean(SettingsKeys.GAMEPAD_TOUCHPAD_MOUSE, false),
      enableStartKeyMenu: await this.getBoolean(SettingsKeys.ENABLE_START_KEY_MENU, true),
      ignoreDeviceDisconnect: await this.getBoolean(SettingsKeys.IGNORE_DEVICE_DISCONNECT, false),
      enableKeyInterceptor: await this.getBoolean(SettingsKeys.ENABLE_KEY_INTERCEPTOR, false),
      enableInputKitTouch: await this.getBoolean(SettingsKeys.ENABLE_INPUT_KIT_TOUCH, false),
      usbDriverEnabled: await this.getBoolean(SettingsKeys.USB_DRIVER_ENABLED, false),
      forceUsbDriverOnly: await this.getBoolean(SettingsKeys.FORCE_USB_DRIVER_ONLY, false),
      ddkHighSpeedPolling: await this.getBoolean(SettingsKeys.DDK_HIGH_SPEED_POLLING, false),

      gyroAssistEnabled: await this.getBoolean(SettingsKeys.GYRO_ASSIST_ENABLED, false),
      gyroSensitivity: await this.getNumber(SettingsKeys.GYRO_SENSITIVITY, 1.0),
      gyroInvertX: await this.getBoolean(SettingsKeys.GYRO_INVERT_X, false),
      gyroInvertY: await this.getBoolean(SettingsKeys.GYRO_INVERT_Y, false),
      gyroActivationKey: await this.getNumber(SettingsKeys.GYRO_ACTIVATION_KEY, -1),
      showGyroCard: await this.getBoolean(SettingsKeys.SHOW_GYRO_CARD, true),

      enableOnscreenControls: await this.getBoolean(SettingsKeys.ENABLE_ONSCREEN_CONTROLS, false),
      enableOnscreenKeyboard: await this.getBoolean(SettingsKeys.ENABLE_ONSCREEN_KEYBOARD, false),
      onlyL3R3: await this.getBoolean(SettingsKeys.ONLY_L3_R3, false),
      showGuideButton: await this.getBoolean(SettingsKeys.SHOW_GUIDE_BUTTON, true),
      halfHeightOscPortrait: await this.getBoolean(SettingsKeys.HALF_HEIGHT_OSC_PORTRAIT, true),
      oscOpacity: await this.getNumber(SettingsKeys.OSC_OPACITY, 90),
      vibrateOsc: await this.getBoolean(SettingsKeys.VIBRATE_OSC, true),

      showLocalCursor: await this.getBoolean(SettingsKeys.SHOW_LOCAL_CURSOR, false),
      touchscreenTrackpad: await this.getBoolean(SettingsKeys.TOUCHSCREEN_TRACKPAD, false),
      enableDoubleClickDrag: await this.getBoolean(SettingsKeys.ENABLE_DOUBLE_CLICK_DRAG, false),
      doubleTapTimeThreshold: await this.getNumber(SettingsKeys.DOUBLE_TAP_TIME_THRESHOLD, 125),
      mouseNavButtons: await this.getBoolean(SettingsKeys.MOUSE_NAV_BUTTONS, false),
      gameMouseMode: await this.getBoolean(SettingsKeys.GAME_MOUSE_MODE, false),

      enableEnhancedTouch: await this.getBoolean(SettingsKeys.ENABLE_ENHANCED_TOUCH, true),
      enhancedTouchOnRight: await this.getBoolean(SettingsKeys.ENHANCED_TOUCH_ON_RIGHT, false),
      enhancedTouchZoneDivider: await this.getNumber(SettingsKeys.ENHANCED_TOUCH_ZONE_DIVIDER, 50),
      pointerVelocityFactor: await this.getNumber(SettingsKeys.POINTER_VELOCITY_FACTOR, 100),
      longPressFlatRegion: await this.getNumber(SettingsKeys.LONG_PRESS_FLAT_REGION, 0),
    };
  }

  async getHostSettings(): Promise<HostSettings> {
    return {
      enableSops: await this.getBoolean(SettingsKeys.ENABLE_SOPS, true),
      screenCombinationMode: await this.getString(SettingsKeys.SCREEN_COMBINATION_MODE, "主机默认"),
      lockScreenAfterDisconnect: await this.getBoolean(
        SettingsKeys.LOCK_SCREEN_AFTER_DISCONNECT,
        false,
      ),
    };
  }

  async getDisplaySettings(): Promise<DisplaySettings> {
    const itemsStr = await this.getString(
      SettingsKeys.PERF_OVERLAY_ITEMS,
      "resolution,decoder,render_fps,packet_loss,bitrate,network_latency,decode_latency",
    );
    const items = itemsStr.split(",").filter((item) => item.length > 0);

    return {
      stretchVideo: await this.getBoolean(SettingsKeys.STRETCH_VIDEO, false),
      reverseResolution: await this.getBoolean(SettingsKeys.REVERSE_RESOLUTION, false),
      rotableScreen: await this.getBoolean(SettingsKeys.ROTABLE_SCREEN, false),
      enableHdrHighBrightness: await this.getBoolean(
        SettingsKeys.ENABLE_HDR_HIGH_BRIGHTNESS,
        false,
      ),
      screenPosition: await this.getString(SettingsKeys.SCREEN_POSITION, "居中"),
      screenOffsetX: await this.getNumber(SettingsKeys.SCREEN_OFFSET_X, 0),
      screenOffsetY: await this.getNumber(SettingsKeys.SCREEN_OFFSET_Y, 0),
      enablePerfOverlay: await this.getBoolean(SettingsKeys.ENABLE_PERF_OVERLAY, false),
      perfOverlayOrientation: await this.getString(SettingsKeys.PERF_OVERLAY_ORIENTATION, "垂直"),
      perfOverlayPosition: await this.getString(SettingsKeys.PERF_OVERLAY_POSITION, "右上角"),
      perfOverlayLocked: await this.getBoolean(SettingsKeys.PERF_OVERLAY_LOCKED, false),
      perfOverlayItems: items,
      perfOverlayBgOpacity: await this.getNumber(SettingsKeys.PERF_OVERLAY_BG_OPACITY, 0.53),
    };
  }

  async getAdvancedSettings(): Promise<AdvancedSettings> {
    return {
      decoderBufferCount: await this.getNumber(SettingsKeys.DECODER_BUFFER_COUNT, 0),
      enableSyncDecode: await this.getBoolean(SettingsKeys.ENABLE_SYNC_DECODE, false),
      enableVrr: await this.getBoolean(SettingsKeys.ENABLE_VRR, false),
      latencyToast: await this.getBoolean(SettingsKeys.LATENCY_TOAST, false),
      disableWarnings: await this.getBoolean(SettingsKeys.DISABLE_WARNINGS, false),
      enableStun: await this.getBoolean(SettingsKeys.ENABLE_STUN, false),
      enableEscMenu: await this.getBoolean(SettingsKeys.ENABLE_ESC_MENU, true),
      escMenuKey: await this.getString(SettingsKeys.ESC_MENU_KEY, "ESC"),
      performanceMode: await this.getBoolean(SettingsKeys.PERFORMANCE_MODE, false),
    };
  }

  async getAudioSettings(): Promise<AudioSettings> {
    return {
      audioConfig: await this.getString(SettingsKeys.AUDIO_CONFIG, "立体声"),
      enableLocalAudio: await this.getBoolean(SettingsKeys.ENABLE_LOCAL_AUDIO, false),
      enableSpatializer: await this.getBoolean(SettingsKeys.ENABLE_SPATIALIZER, false),
      controlOnly: await this.getBoolean(SettingsKeys.CONTROL_ONLY, false),
      enableMic: await this.getBoolean(SettingsKeys.ENABLE_MIC, false),
      micBitrate: await this.getNumber(SettingsKeys.MIC_BITRATE, 64),
    };
  }

  async shouldShowPerfOverlay(): Promise<boolean> {
    return await this.getBoolean(SettingsKeys.ENABLE_PERF_OVERLAY, false);
  }

  async shouldShowOnscreenControls(): Promise<boolean> {
    return await this.getBoolean(SettingsKeys.ENABLE_ONSCREEN_CONTROLS, false);
  }

  async getOscOpacity(): Promise<number> {
    return await this.getNumber(SettingsKeys.OSC_OPACITY, 90);
  }

  async shouldResumeStream(): Promise<boolean> {
    return await this.getBoolean(SettingsKeys.RESUME_STREAM, false);
  }
}
