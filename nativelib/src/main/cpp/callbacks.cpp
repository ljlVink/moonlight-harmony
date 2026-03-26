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
 * @file callbacks.cpp
 * @brief moonlight-common-c callback handling implementation
 */

#include "callbacks.h"
#include "opus_libopus.h"
#include "video_decoder.h"
#include "audio_renderer.h"
#include "bass_energy_analyzer.h"
#include <hilog/log.h>
#include <cstring>

// External function: update mic encoder packet loss rate (defined in moonlight_bridge.cpp)
extern void MicCapturerUpdatePacketLossPercent(int percent);
#include <cstdarg>
#include <mutex>
#include <qos/qos.h>
#include <sched.h>
#include <unistd.h>
#include <fstream>
#include <vector>

extern "C" {
#include "moonlight-common-c/src/Limelight.h"
}

#define LOG_TAG "MoonlightCallbacks"


// Global variables


static napi_env g_env = nullptr;
static std::mutex g_mutex;

// Callback instances
VideoDecoderCallbacks g_videoCallbacks = {0};
AudioRendererCallbacks g_audioCallbacks = {0};
ConnectionListenerCallbacks g_connCallbacks = {0};

// Opus configuration
static OPUS_MULTISTREAM_CONFIGURATION g_opusConfig;
static short* g_decodedAudioBuffer = nullptr;

// Bass energy analyzer (extern for moonlight_bridge.cpp access)
BassEnergyAnalyzer g_bassAnalyzer;


// Helper functions


/**
 * Create thread-safe function
 */
static napi_status CreateThreadsafeFunction(
    napi_env env,
    napi_value callback,
    const char* name,
    napi_threadsafe_function_call_js call_js,
    napi_threadsafe_function* result
) {
    napi_value resourceName;
    napi_create_string_utf8(env, name, NAPI_AUTO_LENGTH, &resourceName);
    
    return napi_create_threadsafe_function(
        env,
        callback,
        nullptr,
        resourceName,
        0,  // max_queue_size (0 = unlimited)
        1,  // initial_thread_count
        nullptr,
        nullptr,
        nullptr,
        call_js,
        result
    );
}


// Callback JS call functions


// Generic parameter passing structure
typedef struct {
    int intParams[4];
    double doubleParams[2];
    void* ptrParam;
    int ptrSize;
} CallbackData;

static void CallJs_StageStarting(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[1];
        napi_create_int32(env, cbData->intParams[0], &argv[0]);
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 1, argv, nullptr);
    }
    delete cbData;
}

static void CallJs_StageComplete(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[1];
        napi_create_int32(env, cbData->intParams[0], &argv[0]);
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 1, argv, nullptr);
    }
    delete cbData;
}

static void CallJs_StageFailed(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[2];
        napi_create_int32(env, cbData->intParams[0], &argv[0]);
        napi_create_int32(env, cbData->intParams[1], &argv[1]);
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 2, argv, nullptr);
    }
    delete cbData;
}

static void CallJs_ConnectionStarted(napi_env env, napi_value js_callback, void* context, void* data) {
    if (env != nullptr && js_callback != nullptr) {
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 0, nullptr, nullptr);
    }
}

static void CallJs_ConnectionTerminated(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[1];
        napi_create_int32(env, cbData->intParams[0], &argv[0]);
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 1, argv, nullptr);
    }
    delete cbData;
}

static void CallJs_Rumble(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[3];
        napi_create_int32(env, cbData->intParams[0], &argv[0]);
        napi_create_int32(env, cbData->intParams[1], &argv[1]);
        napi_create_int32(env, cbData->intParams[2], &argv[2]);
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 3, argv, nullptr);
    }
    delete cbData;
}

static void CallJs_ConnectionStatusUpdate(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[1];
        napi_create_int32(env, cbData->intParams[0], &argv[0]);
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 1, argv, nullptr);
    }
    delete cbData;
}

static void CallJs_SetHdrMode(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[1];
        napi_get_boolean(env, cbData->intParams[0] != 0, &argv[0]);
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 1, argv, nullptr);
    }
    delete cbData;
}

static void CallJs_SetMotionEventState(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[3];
        napi_create_int32(env, cbData->intParams[0], &argv[0]); // controllerNumber
        napi_create_int32(env, cbData->intParams[1], &argv[1]); // motionType
        napi_create_int32(env, cbData->intParams[2], &argv[2]); // reportRateHz
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 3, argv, nullptr);
    }
    delete cbData;
}

static void CallJs_SetControllerLED(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[4];
        napi_create_int32(env, cbData->intParams[0], &argv[0]); // controllerNumber
        napi_create_int32(env, cbData->intParams[1], &argv[1]); // r
        napi_create_int32(env, cbData->intParams[2], &argv[2]); // g
        napi_create_int32(env, cbData->intParams[3], &argv[3]); // b
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 4, argv, nullptr);
    }
    delete cbData;
}

static void CallJs_RumbleTriggers(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[3];
        napi_create_int32(env, cbData->intParams[0], &argv[0]); // controllerNumber
        napi_create_int32(env, cbData->intParams[1], &argv[1]); // leftTrigger
        napi_create_int32(env, cbData->intParams[2], &argv[2]); // rightTrigger
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 3, argv, nullptr);
    }
    delete cbData;
}

static void CallJs_ResolutionChanged(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[2];
        napi_create_uint32(env, cbData->intParams[0], &argv[0]);
        napi_create_uint32(env, cbData->intParams[1], &argv[1]);
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 2, argv, nullptr);
    }
    delete cbData;
}

static void CallJs_DrSetup(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[4];
        napi_create_int32(env, cbData->intParams[0], &argv[0]); // videoFormat
        napi_create_int32(env, cbData->intParams[1], &argv[1]); // width
        napi_create_int32(env, cbData->intParams[2], &argv[2]); // height
        napi_create_int32(env, cbData->intParams[3], &argv[3]); // redrawRate
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 4, argv, nullptr);
    }
    delete cbData;
}

static void CallJs_DrSubmitDecodeUnit(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr && cbData->ptrParam != nullptr) {
        napi_value argv[3];
        
        void* bufferData;
        napi_create_arraybuffer(env, cbData->ptrSize, &bufferData, &argv[0]);
        memcpy(bufferData, cbData->ptrParam, cbData->ptrSize);
        
        napi_create_int32(env, cbData->intParams[0], &argv[1]); // frameNumber
        napi_create_int32(env, cbData->intParams[1], &argv[2]); // frameType
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 3, argv, nullptr);
        
        free(cbData->ptrParam);
    }
    delete cbData;
}

static void CallJs_ArInit(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[3];
        napi_create_int32(env, cbData->intParams[0], &argv[0]); // audioConfiguration
        napi_create_int32(env, cbData->intParams[1], &argv[1]); // sampleRate
        napi_create_int32(env, cbData->intParams[2], &argv[2]); // samplesPerFrame
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 3, argv, nullptr);
    }
    delete cbData;
}

static void CallJs_ArPlaySample(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr && cbData->ptrParam != nullptr) {
        napi_value argv[1];
        
        void* bufferData;
        napi_value arrayBuffer;
        napi_create_arraybuffer(env, cbData->ptrSize, &bufferData, &arrayBuffer);
        memcpy(bufferData, cbData->ptrParam, cbData->ptrSize);
        
        napi_create_typedarray(env, napi_int16_array, cbData->ptrSize / 2, arrayBuffer, 0, &argv[0]);
        
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 1, argv, nullptr);
        
        free(cbData->ptrParam);
    }
    delete cbData;
}

static void CallJs_Void(napi_env env, napi_value js_callback, void* context, void* data) {
    if (env != nullptr && js_callback != nullptr) {
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 0, nullptr, nullptr);
    }
}

static void CallJs_BassEnergy(napi_env env, napi_value js_callback, void* context, void* data) {
    CallbackData* cbData = (CallbackData*)data;
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[2];
        napi_create_int32(env, cbData->intParams[0], &argv[0]); // intensity (0-100)
        napi_create_int32(env, cbData->intParams[1], &argv[1]); // lowFreqRatio (0-100)

        napi_value undefined;
        napi_get_undefined(env, &undefined);
        napi_call_function(env, undefined, js_callback, 2, argv, nullptr);
    }
    delete cbData;
}


// Callback initialization


void Callbacks_Init(napi_env env, napi_value callbacks) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_env = env;
    
    napi_value callback;
    
    // Video decoder callbacks
    if (napi_get_named_property(env, callbacks, "drSetup", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "drSetup", CallJs_DrSetup, &g_videoCallbacks.tsfn_setup);
    }
    if (napi_get_named_property(env, callbacks, "drStart", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "drStart", CallJs_Void, &g_videoCallbacks.tsfn_start);
    }
    if (napi_get_named_property(env, callbacks, "drStop", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "drStop", CallJs_Void, &g_videoCallbacks.tsfn_stop);
    }
    if (napi_get_named_property(env, callbacks, "drCleanup", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "drCleanup", CallJs_Void, &g_videoCallbacks.tsfn_cleanup);
    }
    if (napi_get_named_property(env, callbacks, "drSubmitDecodeUnit", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "drSubmitDecodeUnit", CallJs_DrSubmitDecodeUnit, &g_videoCallbacks.tsfn_submitDecodeUnit);
    }
    
    // Audio renderer callbacks
    if (napi_get_named_property(env, callbacks, "arInit", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "arInit", CallJs_ArInit, &g_audioCallbacks.tsfn_init);
    }
    if (napi_get_named_property(env, callbacks, "arStart", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "arStart", CallJs_Void, &g_audioCallbacks.tsfn_start);
    }
    if (napi_get_named_property(env, callbacks, "arStop", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "arStop", CallJs_Void, &g_audioCallbacks.tsfn_stop);
    }
    if (napi_get_named_property(env, callbacks, "arCleanup", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "arCleanup", CallJs_Void, &g_audioCallbacks.tsfn_cleanup);
    }
    if (napi_get_named_property(env, callbacks, "arPlaySample", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "arPlaySample", CallJs_ArPlaySample, &g_audioCallbacks.tsfn_playSample);
    }
    if (napi_get_named_property(env, callbacks, "bassEnergy", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "bassEnergy", CallJs_BassEnergy, &g_audioCallbacks.tsfn_bassEnergy);
    }
    
    // Connection listener callbacks
    if (napi_get_named_property(env, callbacks, "stageStarting", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "stageStarting", CallJs_StageStarting, &g_connCallbacks.tsfn_stageStarting);
    }
    if (napi_get_named_property(env, callbacks, "stageComplete", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "stageComplete", CallJs_StageComplete, &g_connCallbacks.tsfn_stageComplete);
    }
    if (napi_get_named_property(env, callbacks, "stageFailed", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "stageFailed", CallJs_StageFailed, &g_connCallbacks.tsfn_stageFailed);
    }
    if (napi_get_named_property(env, callbacks, "connectionStarted", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "connectionStarted", CallJs_ConnectionStarted, &g_connCallbacks.tsfn_connectionStarted);
    }
    if (napi_get_named_property(env, callbacks, "connectionTerminated", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "connectionTerminated", CallJs_ConnectionTerminated, &g_connCallbacks.tsfn_connectionTerminated);
    }
    if (napi_get_named_property(env, callbacks, "rumble", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "rumble", CallJs_Rumble, &g_connCallbacks.tsfn_rumble);
    }
    if (napi_get_named_property(env, callbacks, "connectionStatusUpdate", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "connectionStatusUpdate", CallJs_ConnectionStatusUpdate, &g_connCallbacks.tsfn_connectionStatusUpdate);
    }
    if (napi_get_named_property(env, callbacks, "setHdrMode", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "setHdrMode", CallJs_SetHdrMode, &g_connCallbacks.tsfn_setHdrMode);
    }
    if (napi_get_named_property(env, callbacks, "setMotionEventState", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "setMotionEventState", CallJs_SetMotionEventState, &g_connCallbacks.tsfn_setMotionEventState);
    }
    if (napi_get_named_property(env, callbacks, "setControllerLED", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "setControllerLED", CallJs_SetControllerLED, &g_connCallbacks.tsfn_setControllerLED);
    }
    if (napi_get_named_property(env, callbacks, "rumbleTriggers", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "rumbleTriggers", CallJs_RumbleTriggers, &g_connCallbacks.tsfn_rumbleTriggers);
    }
    if (napi_get_named_property(env, callbacks, "resolutionChanged", &callback) == napi_ok) {
        CreateThreadsafeFunction(env, callback, "resolutionChanged", CallJs_ResolutionChanged, &g_connCallbacks.tsfn_resolutionChanged);
    }
    
    OH_LOG_INFO(LOG_APP, "Callbacks initialized");
}

void Callbacks_Cleanup(void) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    // Release thread-safe functions
    if (g_videoCallbacks.tsfn_setup) napi_release_threadsafe_function(g_videoCallbacks.tsfn_setup, napi_tsfn_release);
    if (g_videoCallbacks.tsfn_start) napi_release_threadsafe_function(g_videoCallbacks.tsfn_start, napi_tsfn_release);
    if (g_videoCallbacks.tsfn_stop) napi_release_threadsafe_function(g_videoCallbacks.tsfn_stop, napi_tsfn_release);
    if (g_videoCallbacks.tsfn_cleanup) napi_release_threadsafe_function(g_videoCallbacks.tsfn_cleanup, napi_tsfn_release);
    if (g_videoCallbacks.tsfn_submitDecodeUnit) napi_release_threadsafe_function(g_videoCallbacks.tsfn_submitDecodeUnit, napi_tsfn_release);
    
    if (g_audioCallbacks.tsfn_init) napi_release_threadsafe_function(g_audioCallbacks.tsfn_init, napi_tsfn_release);
    if (g_audioCallbacks.tsfn_start) napi_release_threadsafe_function(g_audioCallbacks.tsfn_start, napi_tsfn_release);
    if (g_audioCallbacks.tsfn_stop) napi_release_threadsafe_function(g_audioCallbacks.tsfn_stop, napi_tsfn_release);
    if (g_audioCallbacks.tsfn_cleanup) napi_release_threadsafe_function(g_audioCallbacks.tsfn_cleanup, napi_tsfn_release);
    if (g_audioCallbacks.tsfn_playSample) napi_release_threadsafe_function(g_audioCallbacks.tsfn_playSample, napi_tsfn_release);
    if (g_audioCallbacks.tsfn_bassEnergy) napi_release_threadsafe_function(g_audioCallbacks.tsfn_bassEnergy, napi_tsfn_release);
    
    if (g_connCallbacks.tsfn_stageStarting) napi_release_threadsafe_function(g_connCallbacks.tsfn_stageStarting, napi_tsfn_release);
    if (g_connCallbacks.tsfn_stageComplete) napi_release_threadsafe_function(g_connCallbacks.tsfn_stageComplete, napi_tsfn_release);
    if (g_connCallbacks.tsfn_stageFailed) napi_release_threadsafe_function(g_connCallbacks.tsfn_stageFailed, napi_tsfn_release);
    if (g_connCallbacks.tsfn_connectionStarted) napi_release_threadsafe_function(g_connCallbacks.tsfn_connectionStarted, napi_tsfn_release);
    if (g_connCallbacks.tsfn_connectionTerminated) napi_release_threadsafe_function(g_connCallbacks.tsfn_connectionTerminated, napi_tsfn_release);
    if (g_connCallbacks.tsfn_rumble) napi_release_threadsafe_function(g_connCallbacks.tsfn_rumble, napi_tsfn_release);
    if (g_connCallbacks.tsfn_connectionStatusUpdate) napi_release_threadsafe_function(g_connCallbacks.tsfn_connectionStatusUpdate, napi_tsfn_release);
    if (g_connCallbacks.tsfn_setHdrMode) napi_release_threadsafe_function(g_connCallbacks.tsfn_setHdrMode, napi_tsfn_release);
    if (g_connCallbacks.tsfn_setMotionEventState) napi_release_threadsafe_function(g_connCallbacks.tsfn_setMotionEventState, napi_tsfn_release);
    if (g_connCallbacks.tsfn_setControllerLED) napi_release_threadsafe_function(g_connCallbacks.tsfn_setControllerLED, napi_tsfn_release);
    if (g_connCallbacks.tsfn_rumbleTriggers) napi_release_threadsafe_function(g_connCallbacks.tsfn_rumbleTriggers, napi_tsfn_release);
    if (g_connCallbacks.tsfn_resolutionChanged) napi_release_threadsafe_function(g_connCallbacks.tsfn_resolutionChanged, napi_tsfn_release);
    
    memset(&g_videoCallbacks, 0, sizeof(g_videoCallbacks));
    memset(&g_audioCallbacks, 0, sizeof(g_audioCallbacks));
    memset(&g_connCallbacks, 0, sizeof(g_connCallbacks));
    
    // Clean up AVCodec Opus decoder
    MoonlightOpusDecoder::Cleanup();
    
    if (g_decodedAudioBuffer) {
        free(g_decodedAudioBuffer);
        g_decodedAudioBuffer = nullptr;
    }
    
    g_env = nullptr;
    
    OH_LOG_INFO(LOG_APP, "Callbacks cleaned up");
}


// moonlight-common-c callback bridge implementation


// Video decoder config parameters (saved for decoder creation)
static int g_videoFormat = 0;
static int g_videoWidth = 0;
static int g_videoHeight = 0;
static int g_videoFps = 0;

// Video decoder callback
int BridgeDrSetup(int videoFormat, int width, int height, int redrawRate, void* context, int drFlags) {
    OH_LOG_INFO(LOG_APP, "BridgeDrSetup: format=0x%{public}x, %{public}dx%{public}d@%{public}d, drFlags=0x%{public}x", 
                videoFormat, width, height, redrawRate, drFlags);
    
    // Clean up previous decoder resources (if any)
    VideoDecoderInstance::Cleanup();
    
    // Save video parameters
    g_videoFormat = videoFormat;
    g_videoWidth = width;
    g_videoHeight = height;
    g_videoFps = redrawRate;
    
    // Initialize video decoder (creates decoder immediately if Surface is set)
    int ret = VideoDecoderInstance::Setup(videoFormat, width, height, redrawRate);
    if (ret != 0) {
        OH_LOG_ERROR(LOG_APP, "VideoDecoderInstance::Setup failed: %{public}d", ret);
    }
    
    // Notify ArkTS layer to set video parameters
    if (g_videoCallbacks.tsfn_setup) {
        CallbackData* data = new CallbackData();
        data->intParams[0] = videoFormat;
        data->intParams[1] = width;
        data->intParams[2] = height;
        data->intParams[3] = redrawRate;
        napi_call_threadsafe_function(g_videoCallbacks.tsfn_setup, data, napi_tsfn_blocking);
    }
    
    OH_LOG_INFO(LOG_APP, "BridgeDrSetup completed with ret=%{public}d", ret);
    return ret;
}

void BridgeDrStart(void) {
    OH_LOG_INFO(LOG_APP, "BridgeDrStart: starting video decoder...");
    
    // Start video decoder (actually creates decoder at this point)
    int ret = VideoDecoderInstance::Start();
    if (ret != 0) {
        OH_LOG_ERROR(LOG_APP, "VideoDecoderInstance::Start failed: %{public}d", ret);
        // BridgeDrStart returns void, cannot return error
        // But decoder will fail at SubmitDecodeUnit
    } else {
        OH_LOG_INFO(LOG_APP, "BridgeDrStart: video decoder started successfully");
    }
    
    if (g_videoCallbacks.tsfn_start) {
        napi_call_threadsafe_function(g_videoCallbacks.tsfn_start, nullptr, napi_tsfn_blocking);
    }
    
    OH_LOG_INFO(LOG_APP, "BridgeDrStart: completed");
}

void BridgeDrStop(void) {
    OH_LOG_INFO(LOG_APP, "BridgeDrStop");
    
    // Stop video decoder
    VideoDecoderInstance::Stop();
    
    if (g_videoCallbacks.tsfn_stop) {
        napi_call_threadsafe_function(g_videoCallbacks.tsfn_stop, nullptr, napi_tsfn_blocking);
    }
}

void BridgeDrCleanup(void) {
    OH_LOG_INFO(LOG_APP, "BridgeDrCleanup");
    
    // Clean up video decoder
    VideoDecoderInstance::Cleanup();
    
    if (g_videoCallbacks.tsfn_cleanup) {
        napi_call_threadsafe_function(g_videoCallbacks.tsfn_cleanup, nullptr, napi_tsfn_blocking);
    }
}

int BridgeDrSubmitDecodeUnit(void* decodeUnitPtr) {
    PDECODE_UNIT decodeUnit = (PDECODE_UNIT)decodeUnitPtr;
    
    // Calculate total size and segment count
    int totalSize = 0;
    int segmentCount = 0;
    PLENTRY entry = decodeUnit->bufferList;
    while (entry != nullptr) {
        totalSize += entry->length;
        segmentCount++;
        entry = entry->next;
    }
    
    // Build scatter-gather segment array (stack allocated, avoid dynamic memory)
    // Typical frame consists of SPS/PPS/VPS + NAL, few segments (usually < 16)
    constexpr int kMaxStackSegments = 32;
    BufferSegment stackSegments[kMaxStackSegments];
    BufferSegment* segments = stackSegments;
    
    // Fall back to heap allocation in extreme cases where segment count exceeds limit
    bool heapAllocated = false;
    if (segmentCount > kMaxStackSegments) {
        segments = new BufferSegment[segmentCount];
        heapAllocated = true;
    }
    
    int i = 0;
    entry = decodeUnit->bufferList;
    while (entry != nullptr) {
        segments[i].data = reinterpret_cast<const uint8_t*>(entry->data);
        segments[i].length = entry->length;
        i++;
        entry = entry->next;
    }
    
    // Submit directly to hardware decoder (scatter-gather zero-copy: list data directly to AVBuffer)
    int result = VideoDecoderInstance::SubmitDecodeUnitScatter(
        segments,
        segmentCount,
        totalSize,
        decodeUnit->frameNumber, 
        decodeUnit->frameType,
        decodeUnit->frameHostProcessingLatency
    );
    
    if (heapAllocated) {
        delete[] segments;
    }
    
    // Note: No longer notify ArkTS layer via tsfn_submitDecodeUnit
    // Previously allocated CallbackData (ptrParam=nullptr) per frame and dispatched to JS thread,
    // but CallJs_DrSubmitDecodeUnit just deleted it when ptrParam==null,
    // causing ~60Hz useless new/delete + event loop wake-up, accumulating GC pressure causing stuttering.
    // Video frames are now submitted directly to hardware decoder, no need to notify JS.
    
    return result == 0 ? DR_OK : DR_NEED_IDR;
}

// Audio renderer callback
int BridgeArInit(int audioConfiguration, void* opusConfigPtr, void* context, int flags) {
    POPUS_MULTISTREAM_CONFIGURATION opusConfig = (POPUS_MULTISTREAM_CONFIGURATION)opusConfigPtr;
    OH_LOG_INFO(LOG_APP, "BridgeArInit: config=%{public}d, sampleRate=%{public}d, channels=%{public}d", 
                audioConfiguration, opusConfig->sampleRate, opusConfig->channelCount);
    
    // Save configuration
    memcpy(&g_opusConfig, opusConfig, sizeof(g_opusConfig));
    
    // Use HarmonyOS AVCodec Opus decoder
    int err = MoonlightOpusDecoder::Init(opusConfig);
    if (err != 0) {
        OH_LOG_ERROR(LOG_APP, "Failed to create AVCodec Opus decoder: %{public}d", err);
        return -1;
    }
    
    // Allocate decode buffer
    g_decodedAudioBuffer = (short*)malloc(opusConfig->channelCount * opusConfig->samplesPerFrame * sizeof(short));
    
    // Initialize audio player
    err = AudioRendererInstance::Init(opusConfig->sampleRate, opusConfig->channelCount, opusConfig->samplesPerFrame);
    if (err != 0) {
        OH_LOG_ERROR(LOG_APP, "Failed to init audio renderer: %{public}d", err);
        // Continue execution, let ArkTS layer handle audio
    }
    
    // Initialize bass energy analyzer
    g_bassAnalyzer.Init(opusConfig->sampleRate, opusConfig->channelCount);
    OH_LOG_INFO(LOG_APP, "Bass energy analyzer initialized: rate=%{public}d, ch=%{public}d",
                opusConfig->sampleRate, opusConfig->channelCount);
    
    if (g_audioCallbacks.tsfn_init) {
        CallbackData* data = new CallbackData();
        data->intParams[0] = audioConfiguration;
        data->intParams[1] = opusConfig->sampleRate;
        data->intParams[2] = opusConfig->samplesPerFrame;
        napi_call_threadsafe_function(g_audioCallbacks.tsfn_init, data, napi_tsfn_blocking);
    }
    
    return 0;
}

void BridgeArStart(void) {
    OH_LOG_INFO(LOG_APP, "BridgeArStart");
    
    // Start audio player
    AudioRendererInstance::Start();
    
    if (g_audioCallbacks.tsfn_start) {
        napi_call_threadsafe_function(g_audioCallbacks.tsfn_start, nullptr, napi_tsfn_blocking);
    }
}

void BridgeArStop(void) {
    OH_LOG_INFO(LOG_APP, "BridgeArStop");
    
    // Stop audio player
    AudioRendererInstance::Stop();
    
    if (g_audioCallbacks.tsfn_stop) {
        napi_call_threadsafe_function(g_audioCallbacks.tsfn_stop, nullptr, napi_tsfn_blocking);
    }
}

void BridgeArCleanup(void) {
    OH_LOG_INFO(LOG_APP, "BridgeArCleanup");
    
    // Clean up audio player
    AudioRendererInstance::Cleanup();
    
    // Clean up AVCodec Opus decoder
    MoonlightOpusDecoder::Cleanup();
    
    if (g_decodedAudioBuffer) {
        free(g_decodedAudioBuffer);
        g_decodedAudioBuffer = nullptr;
    }
    
    if (g_audioCallbacks.tsfn_cleanup) {
        napi_call_threadsafe_function(g_audioCallbacks.tsfn_cleanup, nullptr, napi_tsfn_blocking);
    }
}

void BridgeArDecodeAndPlaySample(char* sampleData, int sampleLength) {
    static thread_local bool audioThreadSetup = false;
    if (!audioThreadSetup) {
        audioThreadSetup = true;
        
        int qosRet = OH_QoS_SetThreadQoS(QOS_USER_INTERACTIVE);
        if (qosRet == 0) {
            OH_LOG_INFO(LOG_APP, "AudioRecv thread QoS: USER_INTERACTIVE (highest)");
        } else {
            qosRet = OH_QoS_SetThreadQoS(QOS_USER_INITIATED);
            if (qosRet == 0) {
                OH_LOG_INFO(LOG_APP, "AudioRecv thread QoS: USER_INITIATED (fallback)");
            } else {
                OH_LOG_WARN(LOG_APP, "AudioRecv thread: failed to set QoS (ret=%{public}d)", qosRet);
            }
        }
        
        int numCpus = sysconf(_SC_NPROCESSORS_CONF);
        if (numCpus > 1) {
            long maxFreq = 0;
            std::vector<std::pair<int, long>> cpuFreqs;
            for (int i = 0; i < numCpus; i++) {
                char path[128];
                snprintf(path, sizeof(path),
                    "/sys/devices/system/cpu/cpu%d/cpufreq/cpuinfo_max_freq", i);
                std::ifstream ifs(path);
                long freq = 0;
                if (ifs >> freq) {
                    cpuFreqs.push_back({i, freq});
                    if (freq > maxFreq) maxFreq = freq;
                }
            }
            
            if (maxFreq > 0) {
                long threshold = maxFreq * 80 / 100;
                cpu_set_t cpuset;
                CPU_ZERO(&cpuset);
                int bigCount = 0;
                for (auto& [cpu, freq] : cpuFreqs) {
                    if (freq >= threshold) {
                        CPU_SET(cpu, &cpuset);
                        bigCount++;
                    }
                }
                if (bigCount > 0 && bigCount < numCpus) {
                    int ret = sched_setaffinity(0, sizeof(cpuset), &cpuset);
                    if (ret == 0) {
                        OH_LOG_INFO(LOG_APP, "AudioRecv thread bound to %{public}d big cores", bigCount);
                    }
                }
            }
        }
    }
    
    if (g_decodedAudioBuffer == nullptr) {
        return;
    }
    
    // Use HarmonyOS AVCodec Opus decoder
    int decodeLen = MoonlightOpusDecoder::Decode(
        (const unsigned char*)sampleData,
        sampleLength,
        g_decodedAudioBuffer,
        g_opusConfig.samplesPerFrame
    );
    
    if (decodeLen > 0) {
        AudioRendererInstance::PlaySamples(g_decodedAudioBuffer, decodeLen);
        
        int bassIntensity = 0;
        int bassLowFreqRatio = 50;
        if (g_bassAnalyzer.ProcessFrame(g_decodedAudioBuffer, decodeLen, bassIntensity, bassLowFreqRatio)) {
            if (g_audioCallbacks.tsfn_bassEnergy) {
                CallbackData* data = new CallbackData();
                data->intParams[0] = bassIntensity;
                data->intParams[1] = bassLowFreqRatio;
                napi_status st = napi_call_threadsafe_function(g_audioCallbacks.tsfn_bassEnergy, data, napi_tsfn_nonblocking);
                if (st != napi_ok) delete data;
            }
        }
    }
}

void BridgeClStageStarting(int stage) {
    OH_LOG_INFO(LOG_APP, "Stage starting: %{public}d", stage);
    if (g_connCallbacks.tsfn_stageStarting) {
        CallbackData* data = new CallbackData();
        data->intParams[0] = stage;
        napi_call_threadsafe_function(g_connCallbacks.tsfn_stageStarting, data, napi_tsfn_blocking);
    }
}

void BridgeClStageComplete(int stage) {
    OH_LOG_INFO(LOG_APP, "Stage complete: %{public}d", stage);
    if (g_connCallbacks.tsfn_stageComplete) {
        CallbackData* data = new CallbackData();
        data->intParams[0] = stage;
        napi_call_threadsafe_function(g_connCallbacks.tsfn_stageComplete, data, napi_tsfn_blocking);
    }
}

void BridgeClStageFailed(int stage, int errorCode) {
    OH_LOG_ERROR(LOG_APP, "Stage failed: %{public}d, error: %{public}d", stage, errorCode);
    if (g_connCallbacks.tsfn_stageFailed) {
        CallbackData* data = new CallbackData();
        data->intParams[0] = stage;
        data->intParams[1] = errorCode;
        napi_call_threadsafe_function(g_connCallbacks.tsfn_stageFailed, data, napi_tsfn_blocking);
    }
}

void BridgeClConnectionStarted(void) {
    OH_LOG_INFO(LOG_APP, "Connection started");
    if (g_connCallbacks.tsfn_connectionStarted) {
        napi_call_threadsafe_function(g_connCallbacks.tsfn_connectionStarted, nullptr, napi_tsfn_blocking);
    }
}

void BridgeClConnectionTerminated(int errorCode) {
    OH_LOG_INFO(LOG_APP, "Connection terminated: %{public}d", errorCode);
    if (g_connCallbacks.tsfn_connectionTerminated) {
        CallbackData* data = new CallbackData();
        data->intParams[0] = errorCode;
        napi_call_threadsafe_function(g_connCallbacks.tsfn_connectionTerminated, data, napi_tsfn_blocking);
    }
}

void BridgeClRumble(unsigned short controllerNumber, unsigned short lowFreqMotor, unsigned short highFreqMotor) {
    if (g_connCallbacks.tsfn_rumble) {
        CallbackData* data = new CallbackData();
        data->intParams[0] = controllerNumber;
        data->intParams[1] = lowFreqMotor;
        data->intParams[2] = highFreqMotor;
        napi_status st = napi_call_threadsafe_function(g_connCallbacks.tsfn_rumble, data, napi_tsfn_nonblocking);
        if (st != napi_ok) delete data;
    }
}

void BridgeClConnectionStatusUpdate(int connectionStatus) {
    OH_LOG_INFO(LOG_APP, "Connection status: %{public}d", connectionStatus);
    
    if (connectionStatus == 1) { // CONN_STATUS_POOR
        LiRequestIdrFrame();
        OH_LOG_WARN(LOG_APP, "Poor connection detected, proactively requesting IDR frame");
    }
    
    {
        int lossPercent = (connectionStatus == 1) ? 15 : 1;
        MicCapturerUpdatePacketLossPercent(lossPercent);
    }
    
    if (g_connCallbacks.tsfn_connectionStatusUpdate) {
        CallbackData* data = new CallbackData();
        data->intParams[0] = connectionStatus;
        napi_status st = napi_call_threadsafe_function(g_connCallbacks.tsfn_connectionStatusUpdate, data, napi_tsfn_nonblocking);
        if (st != napi_ok) delete data;
    }
}

void BridgeClSetHdrMode(int enabled, void* hdrMetadata) {
    OH_LOG_INFO(LOG_APP, "Set HDR mode: %{public}d, metadata=%{public}p", enabled, hdrMetadata);
    
    if (enabled && hdrMetadata != nullptr) {
        uint8_t* metadata = static_cast<uint8_t*>(hdrMetadata);
        OH_LOG_INFO(LOG_APP, "HDR metadata received: first 4 bytes = %02x %02x %02x %02x",
                    metadata[0], metadata[1], metadata[2], metadata[3]);
    }
    
    if (g_connCallbacks.tsfn_setHdrMode) {
        CallbackData* data = new CallbackData();
        data->intParams[0] = enabled;
        napi_status st = napi_call_threadsafe_function(g_connCallbacks.tsfn_setHdrMode, data, napi_tsfn_nonblocking);
        if (st != napi_ok) delete data;
    }
}

void BridgeClRumbleTriggers(unsigned short controllerNumber, unsigned short leftTrigger, unsigned short rightTrigger) {
    if (g_connCallbacks.tsfn_rumbleTriggers) {
        CallbackData* data = new CallbackData();
        data->intParams[0] = controllerNumber;
        data->intParams[1] = leftTrigger;
        data->intParams[2] = rightTrigger;
        napi_status st = napi_call_threadsafe_function(g_connCallbacks.tsfn_rumbleTriggers, data, napi_tsfn_nonblocking);
        if (st != napi_ok) delete data;
    }
}

void BridgeClSetMotionEventState(unsigned short controllerNumber, unsigned char motionType, unsigned short reportRateHz) {
    OH_LOG_INFO(LOG_APP, "SetMotionEventState: controller=%u, type=%u, rate=%u", controllerNumber, motionType, reportRateHz);
    if (g_connCallbacks.tsfn_setMotionEventState) {
        CallbackData* data = new CallbackData();
        data->intParams[0] = controllerNumber;
        data->intParams[1] = motionType;
        data->intParams[2] = reportRateHz;
        napi_status st = napi_call_threadsafe_function(g_connCallbacks.tsfn_setMotionEventState, data, napi_tsfn_nonblocking);
        if (st != napi_ok) delete data;
    }
}

void BridgeClSetControllerLED(unsigned short controllerNumber, unsigned char r, unsigned char g, unsigned char b) {
    if (g_connCallbacks.tsfn_setControllerLED) {
        CallbackData* data = new CallbackData();
        data->intParams[0] = controllerNumber;
        data->intParams[1] = r;
        data->intParams[2] = g;
        data->intParams[3] = b;
        napi_status st = napi_call_threadsafe_function(g_connCallbacks.tsfn_setControllerLED, data, napi_tsfn_nonblocking);
        if (st != napi_ok) delete data;
    }
}

void BridgeClResolutionChanged(unsigned int width, unsigned int height) {
    OH_LOG_INFO(LOG_APP, "Resolution changed: %ux%u", width, height);
    if (g_connCallbacks.tsfn_resolutionChanged) {
        CallbackData* data = new CallbackData();
        data->intParams[0] = width;
        data->intParams[1] = height;
        napi_call_threadsafe_function(g_connCallbacks.tsfn_resolutionChanged, data, napi_tsfn_blocking);
    }
}

void BridgeClLogMessage(const char* format, ...) {
    va_list args;
    va_start(args, format);
    char buffer[1024];
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);
    
    OH_LOG_INFO(LOG_APP, "[Moonlight] %{public}s", buffer);
}
