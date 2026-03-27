/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 ljlVink
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

/**
 * Input Kit unified interceptor.
 *
 * Uses OH_Input_AddInputEventInterceptor to receive mouse and touch events
 * from the system input pipeline, bypassing ArkUI event delivery.
 * Also uses OH_Input_AddKeyEventInterceptor for keyboard events.
 * Axis events are intentionally not handled.
 *
 * Touch events are forwarded to Moonlight via LiSendTouchEvent.
 * Mouse events are forwarded via LiSendMouseMoveEvent / LiSendMouseButtonEvent.
 * Keyboard events are forwarded to JS via a threadsafe callback.
 *
 * Permissions required:
 *   ohos.permission.INTERCEPT_INPUT_EVENT
 */

#include "input_kit_interceptor.h"
#include <multimodalinput/oh_input_manager.h>
#include <hilog/log.h>
#include <atomic>
#include <algorithm>
#include <chrono>
#include <cstring>
#include <dlfcn.h>

#include "moonlight-common-c/src/Limelight.h"

#define LOG_TAG "InputKitInterceptor"
#define LOG_DOMAIN 0xFF12
#define LOGI(...) OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGW(...) OH_LOG_Print(LOG_APP, LOG_WARN, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)

// ---------------------------------------------------------------------------
// Shared state
// ---------------------------------------------------------------------------

static std::atomic<bool> g_inputEventActive{false};
static std::atomic<bool> g_keyEventActive{false};

// Screen/window dimensions for coordinate normalization and mouse positioning
static std::atomic<int32_t> g_windowX{0};
static std::atomic<int32_t> g_windowY{0};
static std::atomic<int32_t> g_windowWidth{1080};
static std::atomic<int32_t> g_windowHeight{2400};
static std::atomic<int32_t> g_screenWidth{1080};
static std::atomic<int32_t> g_screenHeight{2400};

// Mouse state
static std::atomic<bool> g_relativeMode{false};
static int32_t g_lastMouseX = -1;
static int32_t g_lastMouseY = -1;
static std::atomic<bool> g_warpPending{false};
static int32_t g_warpTargetX = 0;
static int32_t g_warpTargetY = 0;
static int64_t g_warpTimestampMs = 0;
static constexpr int64_t WARP_TIMEOUT_MS = 100;
static constexpr int32_t WARP_TOLERANCE = 2;
static constexpr int32_t EDGE_THRESHOLD = 50;

// Reusable inject event for cursor warping
static Input_MouseEvent* g_warpInjectEvent = nullptr;

// Keyboard JS callback
struct InterceptedKeyEventData {
    int32_t keyCode;
    int32_t action;
    int64_t actionTime;
    int32_t deviceId;
};

static napi_threadsafe_function g_keyTsCallback = nullptr;

// Function pointer for GetKeyEventDeviceId (optional, API 13+)
typedef int32_t (*PFN_GetKeyEventDeviceId)(const Input_KeyEvent *keyEvent);
static PFN_GetKeyEventDeviceId g_pfnGetKeyEventDeviceId = nullptr;
static bool g_deviceIdChecked = false;

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

static void EnsureDeviceIdFn()
{
    if (g_deviceIdChecked) return;
    g_deviceIdChecked = true;
    void *handle = dlopen("libohinput.so", RTLD_NOW | RTLD_NOLOAD);
    if (!handle) handle = dlopen("libohinput.so", RTLD_NOW);
    if (handle) {
        g_pfnGetKeyEventDeviceId =
            (PFN_GetKeyEventDeviceId)dlsym(handle, "OH_Input_GetKeyEventDeviceId");
    }
}

static int MapMouseButton(int32_t button)
{
    switch (button) {
        case 0: return BUTTON_LEFT;
        case 1: return BUTTON_MIDDLE;
        case 2: return BUTTON_RIGHT;
        case 3: return BUTTON_X2; // Forward
        case 4: return BUTTON_X1; // Back
        default: return 0;
    }
}

static bool IsNearEdge(int32_t x, int32_t y)
{
    int32_t sw = g_screenWidth.load(std::memory_order_relaxed);
    int32_t sh = g_screenHeight.load(std::memory_order_relaxed);
    return x < EDGE_THRESHOLD || x > sw - EDGE_THRESHOLD ||
           y < EDGE_THRESHOLD || y > sh - EDGE_THRESHOLD;
}

static void WarpCursorToCenter()
{
    if (!g_warpInjectEvent) return;

    int32_t sw = g_screenWidth.load(std::memory_order_relaxed);
    int32_t sh = g_screenHeight.load(std::memory_order_relaxed);
    int32_t cx = sw / 2;
    int32_t cy = sh / 2;

    g_warpTargetX = cx;
    g_warpTargetY = cy;

    auto now = std::chrono::steady_clock::now();
    g_warpTimestampMs = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()).count();
    g_warpPending.store(true, std::memory_order_release);

    OH_Input_SetMouseEventAction(g_warpInjectEvent, MOUSE_ACTION_MOVE);
    OH_Input_SetMouseEventDisplayX(g_warpInjectEvent, cx);
    OH_Input_SetMouseEventDisplayY(g_warpInjectEvent, cy);
    OH_Input_SetMouseEventActionTime(g_warpInjectEvent, -1);
    int32_t ret = OH_Input_InjectMouseEvent(g_warpInjectEvent);
    if (ret != INPUT_SUCCESS) {
        g_warpPending.store(false, std::memory_order_release);
        LOGW("Cursor warp failed: %{public}d", ret);
    }
}

// ---------------------------------------------------------------------------
// Touch callback
// ---------------------------------------------------------------------------

static void OnInputKitTouchCallback(const Input_TouchEvent* event)
{
    if (!event) return;

    int32_t action   = OH_Input_GetTouchEventAction(event);
    int32_t fingerId = OH_Input_GetTouchEventFingerId(event);
    int32_t dispX    = OH_Input_GetTouchEventDisplayX(event);
    int32_t dispY    = OH_Input_GetTouchEventDisplayY(event);

    // Map Input Kit touch action to Moonlight touch event type
    uint8_t liEventType;
    switch (action) {
        case TOUCH_ACTION_DOWN:   liEventType = LI_TOUCH_EVENT_DOWN;   break;
        case TOUCH_ACTION_MOVE:   liEventType = LI_TOUCH_EVENT_MOVE;   break;
        case TOUCH_ACTION_UP:     liEventType = LI_TOUCH_EVENT_UP;     break;
        case TOUCH_ACTION_CANCEL: liEventType = LI_TOUCH_EVENT_CANCEL; break;
        default: return;
    }

    // Normalize coordinates relative to the stream view window
    int32_t wx  = g_windowX.load(std::memory_order_relaxed);
    int32_t wy  = g_windowY.load(std::memory_order_relaxed);
    int32_t ww  = g_windowWidth.load(std::memory_order_relaxed);
    int32_t wh  = g_windowHeight.load(std::memory_order_relaxed);

    float relX = (float)(dispX - wx);
    float relY = (float)(dispY - wy);
    float normX = (ww > 0) ? relX / (float)ww : 0.5f;
    float normY = (wh > 0) ? relY / (float)wh : 0.5f;
    normX = std::max(0.0f, std::min(1.0f, normX));
    normY = std::max(0.0f, std::min(1.0f, normY));

    float pressure    = (liEventType == LI_TOUCH_EVENT_UP || liEventType == LI_TOUCH_EVENT_CANCEL) ? 0.0f : 1.0f;
    float contactArea = 0.0f;

    LiSendTouchEvent(liEventType, (uint32_t)fingerId,
                     normX, normY,
                     pressure, contactArea, contactArea,
                     LI_ROT_UNKNOWN);
}

// ---------------------------------------------------------------------------
// Mouse callback
// ---------------------------------------------------------------------------

static void OnInputKitMouseCallback(const Input_MouseEvent* event)
{
    if (!event) return;

    int32_t action = OH_Input_GetMouseEventAction(event);

    switch (action) {
        case MOUSE_ACTION_MOVE: {
            int32_t x = OH_Input_GetMouseEventDisplayX(event);
            int32_t y = OH_Input_GetMouseEventDisplayY(event);

            if (g_relativeMode.load(std::memory_order_relaxed)) {
                // Relative / game mouse mode
                if (g_warpPending.load(std::memory_order_acquire)) {
                    int32_t dx = x - g_warpTargetX;
                    int32_t dy = y - g_warpTargetY;
                    if (dx >= -WARP_TOLERANCE && dx <= WARP_TOLERANCE &&
                        dy >= -WARP_TOLERANCE && dy <= WARP_TOLERANCE) {
                        g_lastMouseX = x;
                        g_lastMouseY = y;
                        g_warpPending.store(false, std::memory_order_release);
                        return;
                    }
                    auto now = std::chrono::steady_clock::now();
                    int64_t nowMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                        now.time_since_epoch()).count();
                    if (nowMs - g_warpTimestampMs > WARP_TIMEOUT_MS) {
                        g_warpPending.store(false, std::memory_order_release);
                        g_lastMouseX = x;
                        g_lastMouseY = y;
                        return;
                    }
                    g_lastMouseX = x;
                    g_lastMouseY = y;
                    return;
                }

                if (g_lastMouseX >= 0 && g_lastMouseY >= 0) {
                    int32_t dx = x - g_lastMouseX;
                    int32_t dy = y - g_lastMouseY;
                    if (dx != 0 || dy != 0) {
                        LiSendMouseMoveEvent((short)dx, (short)dy);
                    }
                }
                g_lastMouseX = x;
                g_lastMouseY = y;

                if (IsNearEdge(x, y)) {
                    WarpCursorToCenter();
                }
            } else {
                // Absolute / desktop mode
                int32_t wx = g_windowX.load(std::memory_order_relaxed);
                int32_t wy = g_windowY.load(std::memory_order_relaxed);
                int32_t ww = g_windowWidth.load(std::memory_order_relaxed);
                int32_t wh = g_windowHeight.load(std::memory_order_relaxed);

                int32_t relX = x - wx;
                int32_t relY = y - wy;
                if (relX < 0) relX = 0; else if (relX > ww) relX = ww;
                if (relY < 0) relY = 0; else if (relY > wh) relY = wh;
                LiSendMousePositionEvent((short)relX, (short)relY, (short)ww, (short)wh);
            }
            break;
        }

        case MOUSE_ACTION_BUTTON_DOWN:
        case MOUSE_ACTION_BUTTON_UP: {
            int32_t btn     = OH_Input_GetMouseEventButton(event);
            int     moonBtn = MapMouseButton(btn);
            if (moonBtn > 0) {
                char moonAction = (action == MOUSE_ACTION_BUTTON_DOWN)
                                  ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE;
                LiSendMouseButtonEvent(moonAction, moonBtn);
            }
            break;
        }

        default:
            break;
    }
}

// ---------------------------------------------------------------------------
// Keyboard callback (forwarded to JS)
// ---------------------------------------------------------------------------

static void CallKeyJsCallback(napi_env env, napi_value jsCallback, void* context, void* data)
{
    if (!env || !jsCallback || !data) {
        delete static_cast<InterceptedKeyEventData*>(data);
        return;
    }

    auto* ev = static_cast<InterceptedKeyEventData*>(data);

    napi_value jsEvent;
    napi_create_object(env, &jsEvent);

    napi_value keyCodeVal, actionVal, actionTimeVal, deviceIdVal;
    napi_create_int32(env, ev->keyCode, &keyCodeVal);
    napi_create_int32(env, ev->action, &actionVal);
    napi_create_int64(env, ev->actionTime, &actionTimeVal);
    napi_create_int32(env, ev->deviceId, &deviceIdVal);

    napi_set_named_property(env, jsEvent, "keyCode", keyCodeVal);
    napi_set_named_property(env, jsEvent, "action", actionVal);
    napi_set_named_property(env, jsEvent, "actionTime", actionTimeVal);
    napi_set_named_property(env, jsEvent, "deviceId", deviceIdVal);

    napi_value result;
    napi_call_function(env, nullptr, jsCallback, 1, &jsEvent, &result);

    delete ev;
}

static void OnInputKitKeyCallback(const Input_KeyEvent* event)
{
    if (!event || !g_keyTsCallback) return;

    auto* data = new InterceptedKeyEventData();
    data->keyCode    = OH_Input_GetKeyEventKeyCode(event);
    data->action     = OH_Input_GetKeyEventAction(event);
    data->actionTime = OH_Input_GetKeyEventActionTime(event);
    data->deviceId   = g_pfnGetKeyEventDeviceId ? g_pfnGetKeyEventDeviceId(event) : -1;

    napi_status status = napi_call_threadsafe_function(
        g_keyTsCallback, data, napi_tsfn_nonblocking);
    if (status != napi_ok) {
        LOGW("napi_call_threadsafe_function failed: %{public}d", status);
        delete data;
    }
}

// ---------------------------------------------------------------------------
// NAPI: addInputKitInterceptor(keyCallback: Function): number
// ---------------------------------------------------------------------------

static napi_value AddInputKitInterceptor(napi_env env, napi_callback_info info)
{
    EnsureDeviceIdFn();

    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    // Stop existing interceptors before re-registering
    if (g_inputEventActive.load()) {
        OH_Input_RemoveInputEventInterceptor();
        g_inputEventActive.store(false);
    }
    if (g_keyEventActive.load()) {
        OH_Input_RemoveKeyEventInterceptor();
        g_keyEventActive.store(false);
    }
    if (g_keyTsCallback) {
        napi_release_threadsafe_function(g_keyTsCallback, napi_tsfn_abort);
        g_keyTsCallback = nullptr;
    }

    // Reset mouse state
    g_lastMouseX = -1;
    g_lastMouseY = -1;
    g_warpPending.store(false);

    // Create warp inject event if needed
    if (!g_warpInjectEvent) {
        g_warpInjectEvent = OH_Input_CreateMouseEvent();
    }

    // Register input event interceptor (mouse + touch, no axis)
    static Input_InterceptorEventCallback s_callback;
    s_callback.mouseCallback = OnInputKitMouseCallback;
    s_callback.touchCallback = OnInputKitTouchCallback;
    s_callback.axisCallback  = nullptr; // Axis events not handled

    Input_Result ret = OH_Input_AddInputEventInterceptor(&s_callback, nullptr);
    if (ret != INPUT_SUCCESS) {
        LOGE("OH_Input_AddInputEventInterceptor failed: %{public}d", ret);
        napi_value result;
        napi_create_int32(env, (int32_t)ret, &result);
        return result;
    }
    g_inputEventActive.store(true);
    LOGI("Input event interceptor started (mouse + touch, no axis)");

    // Register key event interceptor if callback was provided
    if (argc >= 1) {
        napi_valuetype vtype;
        napi_typeof(env, argv[0], &vtype);
        if (vtype == napi_function) {
            napi_value asyncResourceName;
            napi_create_string_utf8(env, "InputKitKeyCallback", NAPI_AUTO_LENGTH, &asyncResourceName);

            napi_status status = napi_create_threadsafe_function(
                env, argv[0], nullptr, asyncResourceName,
                0, 1, nullptr, nullptr, nullptr,
                CallKeyJsCallback, &g_keyTsCallback);

            if (status == napi_ok) {
                Input_Result keyRet = OH_Input_AddKeyEventInterceptor(
                    OnInputKitKeyCallback, nullptr);
                if (keyRet == INPUT_SUCCESS) {
                    g_keyEventActive.store(true);
                    LOGI("Key event interceptor started");
                } else {
                    LOGW("OH_Input_AddKeyEventInterceptor failed: %{public}d (key events fallback to ArkUI)", keyRet);
                    napi_release_threadsafe_function(g_keyTsCallback, napi_tsfn_abort);
                    g_keyTsCallback = nullptr;
                }
            } else {
                LOGW("Failed to create threadsafe key callback: %{public}d", status);
            }
        }
    }

    napi_value result;
    napi_create_int32(env, 0, &result);
    return result;
}

// ---------------------------------------------------------------------------
// NAPI: removeInputKitInterceptor(): number
// ---------------------------------------------------------------------------

static napi_value RemoveInputKitInterceptor(napi_env env, napi_callback_info info)
{
    int32_t result = 0;

    if (g_inputEventActive.load()) {
        Input_Result ret = OH_Input_RemoveInputEventInterceptor();
        if (ret != INPUT_SUCCESS) {
            LOGW("OH_Input_RemoveInputEventInterceptor failed: %{public}d", ret);
            result = (int32_t)ret;
        }
        g_inputEventActive.store(false);
        LOGI("Input event interceptor removed");
    }

    if (g_keyEventActive.load()) {
        Input_Result ret = OH_Input_RemoveKeyEventInterceptor();
        if (ret != INPUT_SUCCESS && result == 0) {
            result = (int32_t)ret;
        }
        g_keyEventActive.store(false);
        LOGI("Key event interceptor (InputKit) removed");
    }

    if (g_keyTsCallback) {
        napi_release_threadsafe_function(g_keyTsCallback, napi_tsfn_release);
        g_keyTsCallback = nullptr;
    }

    if (g_warpInjectEvent) {
        OH_Input_DestroyMouseEvent(&g_warpInjectEvent);
        g_warpInjectEvent = nullptr;
    }

    napi_value nResult;
    napi_create_int32(env, result, &nResult);
    return nResult;
}

// ---------------------------------------------------------------------------
// NAPI: isInputKitInterceptorActive(): boolean
// ---------------------------------------------------------------------------

static napi_value IsInputKitInterceptorActive(napi_env env, napi_callback_info info)
{
    napi_value result;
    napi_get_boolean(env, g_inputEventActive.load(), &result);
    return result;
}

// ---------------------------------------------------------------------------
// NAPI: configureInputKitInterceptor(
//         windowX, windowY, windowWidth, windowHeight,
//         screenWidth, screenHeight, relativeMode): void
// ---------------------------------------------------------------------------

static napi_value ConfigureInputKitInterceptor(napi_env env, napi_callback_info info)
{
    size_t argc = 7;
    napi_value argv[7];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    if (argc >= 7) {
        int32_t windowX, windowY, windowWidth, windowHeight;
        int32_t screenWidth, screenHeight;
        bool    relativeMode;

        napi_get_value_int32(env, argv[0], &windowX);
        napi_get_value_int32(env, argv[1], &windowY);
        napi_get_value_int32(env, argv[2], &windowWidth);
        napi_get_value_int32(env, argv[3], &windowHeight);
        napi_get_value_int32(env, argv[4], &screenWidth);
        napi_get_value_int32(env, argv[5], &screenHeight);
        napi_get_value_bool(env, argv[6], &relativeMode);

        if (windowWidth > 0 && windowHeight > 0) {
            g_windowX.store(windowX, std::memory_order_relaxed);
            g_windowY.store(windowY, std::memory_order_relaxed);
            g_windowWidth.store(windowWidth, std::memory_order_relaxed);
            g_windowHeight.store(windowHeight, std::memory_order_relaxed);
        }
        if (screenWidth > 0 && screenHeight > 0) {
            g_screenWidth.store(screenWidth, std::memory_order_relaxed);
            g_screenHeight.store(screenHeight, std::memory_order_relaxed);
        }

        bool prevMode = g_relativeMode.load();
        g_relativeMode.store(relativeMode, std::memory_order_relaxed);
        if (relativeMode != prevMode) {
            g_lastMouseX = -1;
            g_lastMouseY = -1;
            g_warpPending.store(false);
        }

        LOGI("Config: window=(%{public}d,%{public}d,%{public}dx%{public}d) screen=%{public}dx%{public}d mode=%{public}s",
             windowX, windowY, windowWidth, windowHeight,
             screenWidth, screenHeight,
             relativeMode ? "relative" : "absolute");
    }

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

// ---------------------------------------------------------------------------
// Module init
// ---------------------------------------------------------------------------

napi_value InputKitInterceptor_Init(napi_env env, napi_value exports)
{
    napi_value interceptorObj;
    napi_create_object(env, &interceptorObj);

    napi_property_descriptor methods[] = {
        {"addInputKitInterceptor",      nullptr, AddInputKitInterceptor,      nullptr, nullptr, nullptr, napi_default, nullptr},
        {"removeInputKitInterceptor",   nullptr, RemoveInputKitInterceptor,   nullptr, nullptr, nullptr, napi_default, nullptr},
        {"isInputKitInterceptorActive", nullptr, IsInputKitInterceptorActive, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"configureInputKitInterceptor",nullptr, ConfigureInputKitInterceptor,nullptr, nullptr, nullptr, napi_default, nullptr},
    };

    napi_define_properties(env, interceptorObj,
                           sizeof(methods) / sizeof(methods[0]), methods);

    napi_set_named_property(env, exports, "InputKitInterceptor", interceptorObj);

    LOGI("InputKitInterceptor NAPI initialized");
    return exports;
}
