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
 * @file moonlight_bridge.h
 * 
 */

#ifndef MOONLIGHT_BRIDGE_H
#define MOONLIGHT_BRIDGE_H

#include <napi/native_api.h>
#include <js_native_api.h>
#include <js_native_api_types.h>

#ifdef __cplusplus
extern "C" {
#endif




napi_value MoonBridge_Init(napi_env env, napi_callback_info info);




napi_value MoonBridge_StartConnection(napi_env env, napi_callback_info info);

napi_value MoonBridge_StopConnection(napi_env env, napi_callback_info info);

napi_value MoonBridge_InterruptConnection(napi_env env, napi_callback_info info);

napi_value MoonBridge_ResumeDecoder(napi_env env, napi_callback_info info);




napi_value MoonBridge_SendMouseMove(napi_env env, napi_callback_info info);
napi_value MoonBridge_SendMousePosition(napi_env env, napi_callback_info info);
napi_value MoonBridge_SendMouseMoveAsMousePosition(napi_env env, napi_callback_info info);
napi_value MoonBridge_SendMouseButton(napi_env env, napi_callback_info info);
napi_value MoonBridge_SendMouseHighResScroll(napi_env env, napi_callback_info info);
napi_value MoonBridge_SendMouseHighResHScroll(napi_env env, napi_callback_info info);




napi_value MoonBridge_SendKeyboardInput(napi_env env, napi_callback_info info);
napi_value MoonBridge_SendUtf8Text(napi_env env, napi_callback_info info);




napi_value MoonBridge_SendMultiControllerInput(napi_env env, napi_callback_info info);
napi_value MoonBridge_SendControllerArrivalEvent(napi_env env, napi_callback_info info);
napi_value MoonBridge_SendControllerTouchEvent(napi_env env, napi_callback_info info);
napi_value MoonBridge_SendControllerMotionEvent(napi_env env, napi_callback_info info);
napi_value MoonBridge_SendControllerBatteryEvent(napi_env env, napi_callback_info info);




napi_value MoonBridge_SendTouchEvent(napi_env env, napi_callback_info info);
napi_value MoonBridge_SendPenEvent(napi_env env, napi_callback_info info);




napi_value MoonBridge_GetMicPortNumber(napi_env env, napi_callback_info info);
napi_value MoonBridge_IsMicrophoneRequested(napi_env env, napi_callback_info info);
napi_value MoonBridge_SendMicrophoneOpusData(napi_env env, napi_callback_info info);
napi_value MoonBridge_IsMicrophoneEncryptionEnabled(napi_env env, napi_callback_info info);




napi_value MoonBridge_OpusEncoderCreate(napi_env env, napi_callback_info info);
napi_value MoonBridge_OpusEncoderEncode(napi_env env, napi_callback_info info);
napi_value MoonBridge_OpusEncoderDestroy(napi_env env, napi_callback_info info);




napi_value MoonBridge_NativeMicStart(napi_env env, napi_callback_info info);
napi_value MoonBridge_NativeMicStop(napi_env env, napi_callback_info info);
napi_value MoonBridge_NativeMicPause(napi_env env, napi_callback_info info);
napi_value MoonBridge_NativeMicResume(napi_env env, napi_callback_info info);
napi_value MoonBridge_NativeMicGetStats(napi_env env, napi_callback_info info);




napi_value MoonBridge_GetStageName(napi_env env, napi_callback_info info);
napi_value MoonBridge_GetPendingAudioDuration(napi_env env, napi_callback_info info);
napi_value MoonBridge_GetPendingVideoFrames(napi_env env, napi_callback_info info);
napi_value MoonBridge_GetEstimatedRttInfo(napi_env env, napi_callback_info info);
napi_value MoonBridge_GetHostFeatureFlags(napi_env env, napi_callback_info info);
napi_value MoonBridge_GetLaunchUrlQueryParameters(napi_env env, napi_callback_info info);




napi_value MoonBridge_TestClientConnectivity(napi_env env, napi_callback_info info);
napi_value MoonBridge_GetPortFlagsFromStage(napi_env env, napi_callback_info info);
napi_value MoonBridge_GetPortFlagsFromTerminationErrorCode(napi_env env, napi_callback_info info);
napi_value MoonBridge_StringifyPortFlags(napi_env env, napi_callback_info info);
napi_value MoonBridge_FindExternalAddressIP4(napi_env env, napi_callback_info info);
napi_value MoonBridge_GuessControllerType(napi_env env, napi_callback_info info);
napi_value MoonBridge_GuessControllerHasPaddles(napi_env env, napi_callback_info info);
napi_value MoonBridge_GuessControllerHasShareButton(napi_env env, napi_callback_info info);




napi_value MoonBridge_SetVideoSurface(napi_env env, napi_callback_info info);

napi_value MoonBridge_ReleaseVideoSurface(napi_env env, napi_callback_info info);

/**
 * @return { framesDecoded, framesDropped, avgDecodeTimeMs }
 */
napi_value MoonBridge_GetVideoStats(napi_env env, napi_callback_info info);

/**
 * @return { supportsH264, supportsHEVC, supportsAV1, maxWidth, maxHeight, maxFps,
 *           supportsLowLatency, supports4K60, supports4K120, supports1080p120, maxInstances }
 */
napi_value MoonBridge_GetDecoderCapabilities(napi_env env, napi_callback_info info);

napi_value MoonBridge_SetDecoderBufferCount(napi_env env, napi_callback_info info);

napi_value MoonBridge_SetDecoderSyncMode(napi_env env, napi_callback_info info);

/**
 * @return boolean
 */
napi_value MoonBridge_IsDecoderSyncMode(napi_env env, napi_callback_info info);

/**
 * 
 * 
 */
napi_value MoonBridge_SetVrrEnabled(napi_env env, napi_callback_info info);

/**
 * @param enabled boolean
 */
napi_value MoonBridge_SetVsyncEnabled(napi_env env, napi_callback_info info);

/**
 * @return boolean
 */
napi_value MoonBridge_IsVsyncEnabled(napi_env env, napi_callback_info info);




/**
 * @param enabled boolean
 */
napi_value MoonBridge_SetSpatialAudioEnabled(napi_env env, napi_callback_info info);

/**
 * @return boolean
 */
napi_value MoonBridge_IsSpatialAudioEnabled(napi_env env, napi_callback_info info);

napi_value MoonBridge_SetAudioVolume(napi_env env, napi_callback_info info);




/**
 * @return boolean
 */
bool MoonBridge_IsPerformanceModeEnabled();

/**
 * @param enabled boolean
 */
napi_value MoonBridge_SetPerformanceModeEnabled(napi_env env, napi_callback_info info);

/**
 * @return boolean
 */
napi_value MoonBridge_GetPerformanceModeEnabled(napi_env env, napi_callback_info info);




napi_value MoonBridge_SetBassVibrationConfig(napi_env env, napi_callback_info info);




napi_value MoonBridge_SetXComponentFrameRate(napi_env env, napi_callback_info info);




#define BUTTON_ACTION_PRESS 0x07
#define BUTTON_ACTION_RELEASE 0x08

#define BUTTON_LEFT 0x01
#define BUTTON_MIDDLE 0x02
#define BUTTON_RIGHT 0x03
#define BUTTON_X1 0x04
#define BUTTON_X2 0x05

#define KEY_ACTION_DOWN 0x03
#define KEY_ACTION_UP 0x04

#define MODIFIER_SHIFT 0x01
#define MODIFIER_CTRL 0x02
#define MODIFIER_ALT 0x04
#define MODIFIER_META 0x08

#define LI_TOUCH_EVENT_HOVER 0x00
#define LI_TOUCH_EVENT_DOWN 0x01
#define LI_TOUCH_EVENT_UP 0x02
#define LI_TOUCH_EVENT_MOVE 0x03
#define LI_TOUCH_EVENT_CANCEL 0x04
#define LI_TOUCH_EVENT_BUTTON_ONLY 0x05
#define LI_TOUCH_EVENT_HOVER_LEAVE 0x06
#define LI_TOUCH_EVENT_CANCEL_ALL 0x07

#define A_FLAG 0x1000
#define B_FLAG 0x2000
#define X_FLAG 0x4000
#define Y_FLAG 0x8000
#define UP_FLAG 0x0001
#define DOWN_FLAG 0x0002
#define LEFT_FLAG 0x0004
#define RIGHT_FLAG 0x0008
#define LB_FLAG 0x0100
#define RB_FLAG 0x0200
#define PLAY_FLAG 0x0010
#define BACK_FLAG 0x0020
#define LS_CLK_FLAG 0x0040
#define RS_CLK_FLAG 0x0080
#define SPECIAL_FLAG 0x0400
#define PADDLE1_FLAG 0x010000
#define PADDLE2_FLAG 0x020000
#define PADDLE3_FLAG 0x040000
#define PADDLE4_FLAG 0x080000
#define TOUCHPAD_FLAG 0x100000
#define MISC_FLAG 0x200000

#define LI_CTYPE_UNKNOWN 0x00
#define LI_CTYPE_XBOX 0x01
#define LI_CTYPE_PS 0x02
#define LI_CTYPE_NINTENDO 0x03

#ifndef VIDEO_FORMAT_H264
#define VIDEO_FORMAT_H264 0x0001
#define VIDEO_FORMAT_H265 0x0100
#define VIDEO_FORMAT_H265_MAIN10 0x0200
#define VIDEO_FORMAT_AV1_MAIN8 0x1000
#define VIDEO_FORMAT_AV1_MAIN10 0x2000
#endif

#define CONN_STATUS_OKAY 0
#define CONN_STATUS_POOR 1

#define BUFFER_TYPE_PICDATA 0x00
#define BUFFER_TYPE_SPS 0x01
#define BUFFER_TYPE_PPS 0x02
#define BUFFER_TYPE_VPS 0x03

#define FRAME_TYPE_PFRAME 0x00
#define FRAME_TYPE_IDR 0x01

#define DR_OK 0
#define DR_NEED_IDR -1

#ifdef __cplusplus
}
#endif

#endif // MOONLIGHT_BRIDGE_H
