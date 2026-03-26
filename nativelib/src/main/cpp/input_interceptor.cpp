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
 *
 */

#include "input_interceptor.h"
#include <multimodalinput/oh_input_manager.h>
#include <hilog/log.h>
#include <cstring>
#include <dlfcn.h>

#define LOG_TAG "InputInterceptor"
#define LOG_DOMAIN 0xFF10
#define LOGI(...) OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGW(...) OH_LOG_Print(LOG_APP, LOG_WARN, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)

struct InterceptedKeyEvent {
    int32_t keyCode;
    int32_t action;     // KEY_ACTION_DOWN=1, KEY_ACTION_UP=2
    int64_t actionTime;
    int32_t deviceId;
};

static napi_threadsafe_function g_tsCallback = nullptr;
static bool g_interceptorActive = false;

typedef Input_Result (*PFN_CreateKeyEvent)(Input_KeyEvent **keyEvent);
typedef void (*PFN_DestroyKeyEvent)(Input_KeyEvent **keyEvent);
typedef Input_Result (*PFN_SetKeyEventKeyCode)(Input_KeyEvent *keyEvent, int32_t keyCode);
typedef Input_Result (*PFN_SetKeyEventAction)(Input_KeyEvent *keyEvent, int32_t action);
typedef Input_Result (*PFN_SetKeyEventActionTime)(Input_KeyEvent *keyEvent, int64_t actionTime);
typedef Input_Result (*PFN_InjectKeyEvent)(const Input_KeyEvent *keyEvent);

typedef int32_t (*PFN_GetKeyEventDeviceId)(const Input_KeyEvent *keyEvent);

static PFN_CreateKeyEvent g_pfnCreateKeyEvent = nullptr;
static PFN_DestroyKeyEvent g_pfnDestroyKeyEvent = nullptr;
static PFN_SetKeyEventKeyCode g_pfnSetKeyCode = nullptr;
static PFN_SetKeyEventAction g_pfnSetAction = nullptr;
static PFN_SetKeyEventActionTime g_pfnSetActionTime = nullptr;
static PFN_InjectKeyEvent g_pfnInjectKeyEvent = nullptr;
static PFN_GetKeyEventDeviceId g_pfnGetKeyEventDeviceId = nullptr;
static bool g_injectApiChecked = false;
static bool g_injectApiAvailable = false;

static bool CheckAndLoadInjectApi()
{
    if (g_injectApiChecked) {
        return g_injectApiAvailable;
    }
    g_injectApiChecked = true;

    void *handle = dlopen("libohinput.so", RTLD_NOW);
    if (!handle) {
        LOGW("Failed to dlopen libohinput.so for inject API");
        return false;
    }

    g_pfnCreateKeyEvent   = (PFN_CreateKeyEvent)dlsym(handle, "OH_Input_CreateKeyEvent");
    g_pfnDestroyKeyEvent  = (PFN_DestroyKeyEvent)dlsym(handle, "OH_Input_DestroyKeyEvent");
    g_pfnSetKeyCode       = (PFN_SetKeyEventKeyCode)dlsym(handle, "OH_Input_SetKeyEventKeyCode");
    g_pfnSetAction        = (PFN_SetKeyEventAction)dlsym(handle, "OH_Input_SetKeyEventAction");
    g_pfnSetActionTime    = (PFN_SetKeyEventActionTime)dlsym(handle, "OH_Input_SetKeyEventActionTime");
    g_pfnInjectKeyEvent   = (PFN_InjectKeyEvent)dlsym(handle, "OH_Input_InjectKeyEvent");

    if (g_pfnCreateKeyEvent && g_pfnDestroyKeyEvent && g_pfnSetKeyCode &&
        g_pfnSetAction && g_pfnSetActionTime && g_pfnInjectKeyEvent) {
        g_injectApiAvailable = true;
        LOGI("Key inject API available (API 13+), volume key re-injection enabled");
    } else {
        LOGW("Key inject API not available, anti-hijack feature should be disabled");
        g_pfnCreateKeyEvent  = nullptr;
        g_pfnDestroyKeyEvent = nullptr;
        g_pfnSetKeyCode      = nullptr;
        g_pfnSetAction       = nullptr;
        g_pfnSetActionTime   = nullptr;
        g_pfnInjectKeyEvent  = nullptr;
    }
    
    g_pfnGetKeyEventDeviceId = (PFN_GetKeyEventDeviceId)dlsym(handle, "OH_Input_GetKeyEventDeviceId");
    LOGI("GetKeyEventDeviceId: %{public}s", g_pfnGetKeyEventDeviceId ? "available" : "not available");
    
    return g_injectApiAvailable;
}

static bool isVolumeKey(int32_t keyCode)
{
    return keyCode == 16 || keyCode == 17 || keyCode == 22;  // VOLUME_UP / VOLUME_DOWN / VOLUME_MUTE
}

static bool reinjectVolumeKey(const Input_KeyEvent *srcEvent)
{
    if (!g_injectApiAvailable) return false;

    Input_KeyEvent *newEvent = nullptr;
    if (g_pfnCreateKeyEvent(&newEvent) != INPUT_SUCCESS || !newEvent) {
        LOGW("Failed to create key event for re-injection");
        return false;
    }

    g_pfnSetKeyCode(newEvent, OH_Input_GetKeyEventKeyCode(srcEvent));
    g_pfnSetAction(newEvent, OH_Input_GetKeyEventAction(srcEvent));
    g_pfnSetActionTime(newEvent, OH_Input_GetKeyEventActionTime(srcEvent));

    Input_Result ret = g_pfnInjectKeyEvent(newEvent);
    g_pfnDestroyKeyEvent(&newEvent);

    if (ret != INPUT_SUCCESS) {
        LOGW("Failed to inject volume key event: %{public}d (permission denied?)", ret);
        return false;
    }
    return true;
}

static void OnKeyEventCallback(const Input_KeyEvent *keyEvent)
{
    if (!keyEvent) return;

    int32_t keyCode = OH_Input_GetKeyEventKeyCode(keyEvent);

    if (isVolumeKey(keyCode)) {
        if (reinjectVolumeKey(keyEvent)) {
            return;
        }
    }

    if (!g_tsCallback) return;

    auto *data = new InterceptedKeyEvent();
    data->keyCode = keyCode;
    data->action = OH_Input_GetKeyEventAction(keyEvent);
    data->actionTime = OH_Input_GetKeyEventActionTime(keyEvent);
    data->deviceId = g_pfnGetKeyEventDeviceId ? g_pfnGetKeyEventDeviceId(keyEvent) : -1;

    napi_status status = napi_call_threadsafe_function(g_tsCallback, data, napi_tsfn_nonblocking);
    if (status != napi_ok) {
        LOGW("napi_call_threadsafe_function failed: %{public}d", status);
        delete data;
    }
}

static void CallJsCallback(napi_env env, napi_value jsCallback, void *context, void *data)
{
    if (!env || !jsCallback || !data) {
        if (data) delete static_cast<InterceptedKeyEvent *>(data);
        return;
    }

    auto *event = static_cast<InterceptedKeyEvent *>(data);

    napi_value jsEvent;
    napi_create_object(env, &jsEvent);

    napi_value keyCodeVal, actionVal, actionTimeVal, deviceIdVal;
    napi_create_int32(env, event->keyCode, &keyCodeVal);
    napi_create_int32(env, event->action, &actionVal);
    napi_create_int64(env, event->actionTime, &actionTimeVal);
    napi_create_int32(env, event->deviceId, &deviceIdVal);

    napi_set_named_property(env, jsEvent, "keyCode", keyCodeVal);
    napi_set_named_property(env, jsEvent, "action", actionVal);
    napi_set_named_property(env, jsEvent, "actionTime", actionTimeVal);
    napi_set_named_property(env, jsEvent, "deviceId", deviceIdVal);

    napi_value result;
    napi_call_function(env, nullptr, jsCallback, 1, &jsEvent, &result);

    delete event;
}

/**
 * addKeyInterceptor(callback: (event: {keyCode, action, actionTime, deviceId}) => void): number
 *
 */
static napi_value AddKeyInterceptor(napi_env env, napi_callback_info info)
{
    CheckAndLoadInjectApi();

    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    if (argc < 1) {
        LOGE("addKeyInterceptor: missing callback function parameter");
        napi_value ret;
        napi_create_int32(env, -1, &ret);
        return ret;
    }

    if (g_interceptorActive) {
        OH_Input_RemoveKeyEventInterceptor();
        g_interceptorActive = false;
    }
    if (g_tsCallback) {
        napi_release_threadsafe_function(g_tsCallback, napi_tsfn_abort);
        g_tsCallback = nullptr;
    }

    napi_value asyncResourceName;
    napi_create_string_utf8(env, "KeyInterceptorCallback", NAPI_AUTO_LENGTH, &asyncResourceName);

    napi_status status = napi_create_threadsafe_function(
        env,
        argv[0],           // JS callback
        nullptr,           // async resource
        asyncResourceName, // async resource name
        0,                 // max queue size (0 = unlimited)
        1,                 // initial thread count
        nullptr,           // thread finalize data
        nullptr,           // thread finalize callback
        nullptr,           // context
        CallJsCallback,    // call JS callback
        &g_tsCallback
    );

    if (status != napi_ok) {
        LOGE("Failed to create threadsafe function: %{public}d", status);
        napi_value ret;
        napi_create_int32(env, -2, &ret);
        return ret;
    }

    Input_Result inputRet = OH_Input_AddKeyEventInterceptor(OnKeyEventCallback, nullptr);
    if (inputRet != INPUT_SUCCESS) {
        LOGE("OH_Input_AddKeyEventInterceptor failed: %{public}d", inputRet);
        napi_release_threadsafe_function(g_tsCallback, napi_tsfn_abort);
        g_tsCallback = nullptr;
        napi_value ret;
        napi_create_int32(env, inputRet, &ret);
        return ret;
    }

    g_interceptorActive = true;
    LOGI("Key interceptor enabled");

    napi_value ret;
    napi_create_int32(env, 0, &ret);
    return ret;
}

/**
 * removeKeyInterceptor(): number
 *
 */
static napi_value RemoveKeyInterceptor(napi_env env, napi_callback_info info)
{
    int32_t result = 0;

    if (g_interceptorActive) {
        Input_Result inputRet = OH_Input_RemoveKeyEventInterceptor();
        if (inputRet != INPUT_SUCCESS) {
            LOGW("OH_Input_RemoveKeyEventInterceptor failed: %{public}d", inputRet);
            result = inputRet;
        }
        g_interceptorActive = false;
        LOGI("Key interceptor removed");
    }

    if (g_tsCallback) {
        napi_release_threadsafe_function(g_tsCallback, napi_tsfn_release);
        g_tsCallback = nullptr;
    }

    napi_value ret;
    napi_create_int32(env, result, &ret);
    return ret;
}

/**
 * isKeyInterceptorActive(): boolean
 *
 */
static napi_value IsKeyInterceptorActive(napi_env env, napi_callback_info info)
{
    napi_value ret;
    napi_get_boolean(env, g_interceptorActive, &ret);
    return ret;
}

/**
 * isInjectApiAvailable(): boolean
 *
 */
static napi_value IsInjectApiAvailable(napi_env env, napi_callback_info info)
{
    CheckAndLoadInjectApi();
    napi_value ret;
    napi_get_boolean(env, g_injectApiAvailable, &ret);
    return ret;
}

napi_value InputInterceptor_Init(napi_env env, napi_value exports)
{
    napi_value interceptorObj;
    napi_create_object(env, &interceptorObj);

    napi_property_descriptor methods[] = {
        {"addKeyInterceptor", nullptr, AddKeyInterceptor, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"removeKeyInterceptor", nullptr, RemoveKeyInterceptor, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"isKeyInterceptorActive", nullptr, IsKeyInterceptorActive, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"isInjectApiAvailable", nullptr, IsInjectApiAvailable, nullptr, nullptr, nullptr, napi_default, nullptr},
    };

    napi_define_properties(env, interceptorObj, sizeof(methods) / sizeof(methods[0]), methods);

    napi_set_named_property(env, exports, "InputInterceptor", interceptorObj);

    LOGI("InputInterceptor NAPI initialized");
    return exports;
}
