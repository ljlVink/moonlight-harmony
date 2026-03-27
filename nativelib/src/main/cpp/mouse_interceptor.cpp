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
 *
 *
 */

#include "mouse_interceptor.h"
#include <multimodalinput/oh_input_manager.h>
#include <hilog/log.h>
#include <atomic>
#include <chrono>

#include "moonlight-common-c/src/Limelight.h"

#define LOG_TAG "MouseInterceptor"
#define LOG_DOMAIN 0xFF11
#define LOGI(...) OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGW(...) OH_LOG_Print(LOG_APP, LOG_WARN, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)

static std::atomic<bool> g_active{false};

static std::atomic<bool> g_relativeMode{false};

static std::atomic<int32_t> g_windowX{0};
static std::atomic<int32_t> g_windowY{0};
static std::atomic<int32_t> g_windowWidth{1080};
static std::atomic<int32_t> g_windowHeight{2400};

static std::atomic<int32_t> g_screenWidth{1080};
static std::atomic<int32_t> g_screenHeight{2400};

static int32_t g_lastX = -1;
static int32_t g_lastY = -1;

static std::atomic<bool> g_warpPending{false};

static int32_t g_warpTargetX = 0;
static int32_t g_warpTargetY = 0;

static constexpr int32_t WARP_TOLERANCE = 2;

static int64_t g_warpTimestampMs = 0;
static constexpr int64_t WARP_TIMEOUT_MS = 100;

static Input_MouseEvent* g_injectEvent = nullptr;

static constexpr int32_t EDGE_THRESHOLD = 50;

static int MapMouseButton(int32_t button)
{
    switch (button) {
        case 0: return BUTTON_LEFT;
        case 1: return BUTTON_MIDDLE;
        case 2: return BUTTON_RIGHT;
        case 3: return BUTTON_X2;     // Forward
        case 4: return BUTTON_X1;     // Back
        default: return 0;
    }
}


static void WarpCursorToCenter()
{
    if (!g_injectEvent) return;

    int32_t sw = g_screenWidth.load(std::memory_order_relaxed);
    int32_t sh = g_screenHeight.load(std::memory_order_relaxed);
    int32_t centerX = sw / 2;
    int32_t centerY = sh / 2;

    g_warpTargetX = centerX;
    g_warpTargetY = centerY;

    auto now = std::chrono::steady_clock::now();
    g_warpTimestampMs = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()).count();
    g_warpPending.store(true, std::memory_order_release);

    OH_Input_SetMouseEventAction(g_injectEvent, MOUSE_ACTION_MOVE);
    OH_Input_SetMouseEventDisplayX(g_injectEvent, centerX);
    OH_Input_SetMouseEventDisplayY(g_injectEvent, centerY);
    OH_Input_SetMouseEventActionTime(g_injectEvent, -1);

    int32_t ret = OH_Input_InjectMouseEvent(g_injectEvent);
    if (ret != INPUT_SUCCESS) {
        g_warpPending.store(false, std::memory_order_release);
        LOGW("Cursor warp injection failed: %{public}d", ret);
    }
}

static bool IsNearEdge(int32_t x, int32_t y)
{
    int32_t sw = g_screenWidth.load(std::memory_order_relaxed);
    int32_t sh = g_screenHeight.load(std::memory_order_relaxed);
    return x < EDGE_THRESHOLD || x > sw - EDGE_THRESHOLD ||
           y < EDGE_THRESHOLD || y > sh - EDGE_THRESHOLD;
}

static void OnMouseEvent(const Input_MouseEvent *event)
{
    if (!event) return;

    int32_t action = OH_Input_GetMouseEventAction(event);

    switch (action) {
        case MOUSE_ACTION_MOVE: {
            int32_t x = OH_Input_GetMouseEventDisplayX(event);
            int32_t y = OH_Input_GetMouseEventDisplayY(event);

            if (g_relativeMode.load(std::memory_order_relaxed)) {

                if (g_warpPending.load(std::memory_order_acquire)) {
                    int32_t diffX = x - g_warpTargetX;
                    int32_t diffY = y - g_warpTargetY;
                    if (diffX >= -WARP_TOLERANCE && diffX <= WARP_TOLERANCE &&
                        diffY >= -WARP_TOLERANCE && diffY <= WARP_TOLERANCE) {
                        g_lastX = x;
                        g_lastY = y;
                        g_warpPending.store(false, std::memory_order_release);
                        return;
                    }

                    auto now = std::chrono::steady_clock::now();
                    int64_t nowMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                        now.time_since_epoch()).count();
                    if (nowMs - g_warpTimestampMs > WARP_TIMEOUT_MS) {
                        g_warpPending.store(false, std::memory_order_release);
                        g_lastX = x;
                        g_lastY = y;
                        LOGW("Warp timeout, resuming normal state pos=(%{public}d,%{public}d)", x, y);
                        return;
                    }

                    g_lastX = x;
                    g_lastY = y;
                    return;
                }

                if (g_lastX >= 0 && g_lastY >= 0) {
                    int32_t dx = x - g_lastX;
                    int32_t dy = y - g_lastY;
                    if (dx != 0 || dy != 0) {
                        LiSendMouseMoveEvent((short)dx, (short)dy);
                    }
                }
                g_lastX = x;
                g_lastY = y;

                if (IsNearEdge(x, y)) {
                    WarpCursorToCenter();
                }
            } else {
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
            int32_t btn = OH_Input_GetMouseEventButton(event);
            int moonBtn = MapMouseButton(btn);
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

/**
 * addMouseInterceptor(): number
 */
static napi_value AddMouseInterceptor(napi_env env, napi_callback_info info)
{
    if (g_active.load()) {
        OH_Input_RemoveMouseEventMonitor(OnMouseEvent);
        g_active.store(false);
    }

    if (!g_injectEvent) {
        g_injectEvent = OH_Input_CreateMouseEvent();
    }

    g_lastX = -1;
    g_lastY = -1;
    g_warpPending.store(false);

    Input_Result ret = OH_Input_AddMouseEventMonitor(OnMouseEvent);
    if (ret == INPUT_SUCCESS) {
        g_active.store(true);
        bool relative = g_relativeMode.load();
        LOGI("Mouse monitor started (%{public}s mode, full speed polling)", relative ? "relative/game" : "absolute/desktop");
    } else {
        LOGW("Mouse monitor start failed: %{public}d (needs INPUT_MONITORING permission, will fallback to ArkUI events)", ret);
    }

    napi_value result;
    napi_create_int32(env, ret, &result);
    return result;
}

/**
 * removeMouseInterceptor(): number
 */
static napi_value RemoveMouseInterceptor(napi_env env, napi_callback_info info)
{
    int32_t result = 0;
    if (g_active.load()) {
        Input_Result ret = OH_Input_RemoveMouseEventMonitor(OnMouseEvent);
        if (ret != INPUT_SUCCESS) {
            LOGW("Failed to remove mouse monitor: %{public}d", ret);
            result = ret;
        }
        g_active.store(false);
        LOGI("Mouse monitor stopped");
    }

    if (g_injectEvent) {
        OH_Input_DestroyMouseEvent(&g_injectEvent);
        g_injectEvent = nullptr;
    }

    napi_value nResult;
    napi_create_int32(env, result, &nResult);
    return nResult;
}

/**
 * configureMouseInterceptor(windowX, windowY, windowWidth, windowHeight,
 *                           screenWidth, screenHeight, relativeMode): void
 */
static napi_value ConfigureMouseInterceptor(napi_env env, napi_callback_info info)
{
    size_t argc = 7;
    napi_value argv[7];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    if (argc >= 7) {
        int32_t windowX, windowY, windowWidth, windowHeight;
        int32_t screenWidth, screenHeight;
        bool relativeMode;

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
            g_lastX = -1;
            g_lastY = -1;
            g_warpPending.store(false);
        }

        LOGI("Config updated: window=(%{public}d,%{public}d,%{public}dx%{public}d) screen=%{public}dx%{public}d mode=%{public}s",
             windowX, windowY, windowWidth, windowHeight,
             screenWidth, screenHeight,
             relativeMode ? "relative/game" : "absolute/desktop");
    }

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

/**
 * isMouseInterceptorActive(): boolean
 */
static napi_value IsMouseInterceptorActive(napi_env env, napi_callback_info info)
{
    napi_value result;
    napi_get_boolean(env, g_active.load(), &result);
    return result;
}

napi_value MouseInterceptor_Init(napi_env env, napi_value exports)
{
    napi_value interceptorObj;
    napi_create_object(env, &interceptorObj);

    napi_property_descriptor methods[] = {
        {"addMouseInterceptor", nullptr, AddMouseInterceptor, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"removeMouseInterceptor", nullptr, RemoveMouseInterceptor, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"configureMouseInterceptor", nullptr, ConfigureMouseInterceptor, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"isMouseInterceptorActive", nullptr, IsMouseInterceptorActive, nullptr, nullptr, nullptr, napi_default, nullptr},
    };

    napi_define_properties(env, interceptorObj, sizeof(methods) / sizeof(methods[0]), methods);
    napi_set_named_property(env, exports, "MouseInterceptor", interceptorObj);

    LOGI("MouseInterceptor NAPI initialized");
    return exports;
}
