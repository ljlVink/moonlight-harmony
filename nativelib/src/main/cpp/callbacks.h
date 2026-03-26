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
 * @file callbacks.h
 * 
 */

#ifndef MOONLIGHT_CALLBACKS_H
#define MOONLIGHT_CALLBACKS_H

#include <napi/native_api.h>
#include <js_native_api.h>
#include <js_native_api_types.h>

#ifdef __cplusplus
extern "C" {
#endif




/**
 * 
 */
void Callbacks_Init(napi_env env, napi_value callbacks);

void Callbacks_Cleanup(void);




typedef struct {
    napi_threadsafe_function tsfn_setup;
    napi_threadsafe_function tsfn_start;
    napi_threadsafe_function tsfn_stop;
    napi_threadsafe_function tsfn_cleanup;
    napi_threadsafe_function tsfn_submitDecodeUnit;
} VideoDecoderCallbacks;

typedef struct {
    napi_threadsafe_function tsfn_init;
    napi_threadsafe_function tsfn_start;
    napi_threadsafe_function tsfn_stop;
    napi_threadsafe_function tsfn_cleanup;
    napi_threadsafe_function tsfn_playSample;
    napi_threadsafe_function tsfn_bassEnergy;
} AudioRendererCallbacks;

typedef struct {
    napi_threadsafe_function tsfn_stageStarting;
    napi_threadsafe_function tsfn_stageComplete;
    napi_threadsafe_function tsfn_stageFailed;
    napi_threadsafe_function tsfn_connectionStarted;
    napi_threadsafe_function tsfn_connectionTerminated;
    napi_threadsafe_function tsfn_rumble;
    napi_threadsafe_function tsfn_connectionStatusUpdate;
    napi_threadsafe_function tsfn_setHdrMode;
    napi_threadsafe_function tsfn_rumbleTriggers;
    napi_threadsafe_function tsfn_setMotionEventState;
    napi_threadsafe_function tsfn_setControllerLED;
    napi_threadsafe_function tsfn_resolutionChanged;
} ConnectionListenerCallbacks;




extern VideoDecoderCallbacks g_videoCallbacks;
extern AudioRendererCallbacks g_audioCallbacks;
extern ConnectionListenerCallbacks g_connCallbacks;




int BridgeDrSetup(int videoFormat, int width, int height, int redrawRate, void* context, int drFlags);
void BridgeDrStart(void);
void BridgeDrStop(void);
void BridgeDrCleanup(void);
int BridgeDrSubmitDecodeUnit(void* decodeUnit);

int BridgeArInit(int audioConfiguration, void* opusConfig, void* context, int flags);
void BridgeArStart(void);
void BridgeArStop(void);
void BridgeArCleanup(void);
void BridgeArDecodeAndPlaySample(char* sampleData, int sampleLength);

void BridgeClStageStarting(int stage);
void BridgeClStageComplete(int stage);
void BridgeClStageFailed(int stage, int errorCode);
void BridgeClConnectionStarted(void);
void BridgeClConnectionTerminated(int errorCode);
void BridgeClRumble(unsigned short controllerNumber, unsigned short lowFreqMotor, unsigned short highFreqMotor);
void BridgeClConnectionStatusUpdate(int connectionStatus);
void BridgeClSetHdrMode(int enabled, void* hdrMetadata);
void BridgeClRumbleTriggers(unsigned short controllerNumber, unsigned short leftTrigger, unsigned short rightTrigger);
void BridgeClSetMotionEventState(unsigned short controllerNumber, unsigned char motionType, unsigned short reportRateHz);
void BridgeClSetControllerLED(unsigned short controllerNumber, unsigned char r, unsigned char g, unsigned char b);
void BridgeClResolutionChanged(unsigned int width, unsigned int height);
void BridgeClLogMessage(const char* format, ...);

#ifdef __cplusplus
}
#endif

#endif // MOONLIGHT_CALLBACKS_H
