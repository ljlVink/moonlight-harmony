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
 * @file native_render.cpp
 * 
 */

#include "native_render.h"
#include <cstring>
#include <dlfcn.h>
#include <time.h>

#undef LOG_TAG
#define LOG_TAG "NativeRender"

typedef OH_AVErrCode (*PFN_RenderOutputBufferAtTime)(OH_AVCodec*, uint32_t, int64_t);
static PFN_RenderOutputBufferAtTime g_pfnRenderAtTime = nullptr;
static bool g_renderAtTimeChecked = false;

static PFN_RenderOutputBufferAtTime GetRenderAtTimeFunc() {
    if (!g_renderAtTimeChecked) {
        g_renderAtTimeChecked = true;
        g_pfnRenderAtTime = (PFN_RenderOutputBufferAtTime)
            dlsym(RTLD_DEFAULT, "OH_VideoDecoder_RenderOutputBufferAtTime");
        if (!g_pfnRenderAtTime) {
            void* handle = dlopen("libnative_media_vdec.so", RTLD_NOW);
            if (handle) {
                g_pfnRenderAtTime = (PFN_RenderOutputBufferAtTime)
                    dlsym(handle, "OH_VideoDecoder_RenderOutputBufferAtTime");
            }
        }
    }
    return g_pfnRenderAtTime;
}




typedef int (*PFN_OH_NativeVSync_SetExpectedFrameRateRange)(
    OH_NativeVSync* nativeVsync, OH_NativeVSync_ExpectedRateRange* range);

static PFN_OH_NativeVSync_SetExpectedFrameRateRange g_pfnSetExpectedFrameRateRange = nullptr;
static bool g_api20Checked = false;
static bool g_api20Available = false;

static bool CheckAndLoadApi20() {
    if (g_api20Checked) {
        return g_api20Available;
    }
    g_api20Checked = true;
    
    void* handle = dlopen("libnative_vsync.so", RTLD_NOW);
    if (handle != nullptr) {
        g_pfnSetExpectedFrameRateRange = (PFN_OH_NativeVSync_SetExpectedFrameRateRange)
            dlsym(handle, "OH_NativeVSync_SetExpectedFrameRateRange");
        if (g_pfnSetExpectedFrameRateRange != nullptr) {
            g_api20Available = true;
            OH_LOG_INFO(LOG_APP, "API 20 OH_NativeVSync_SetExpectedFrameRateRange available");
        } else {
            OH_LOG_WARN(LOG_APP, "API 20 OH_NativeVSync_SetExpectedFrameRateRange not found");
        }
    } else {
        OH_LOG_WARN(LOG_APP, "Failed to load libnative_vsync.so: %{public}s", dlerror());
    }
    
    return g_api20Available;
}




NativeRender* NativeRender::instance_ = nullptr;
std::mutex NativeRender::instanceMutex_;




NativeRender* NativeRender::GetInstance() {
    std::lock_guard<std::mutex> lock(instanceMutex_);
    if (instance_ == nullptr) {
        instance_ = new NativeRender();
    }
    return instance_;
}

void NativeRender::ReleaseInstance() {
    std::lock_guard<std::mutex> lock(instanceMutex_);
    if (instance_ != nullptr) {
        delete instance_;
        instance_ = nullptr;
    }
}

NativeRender::NativeRender() {
    OH_LOG_INFO(LOG_APP, "NativeRender created");
    lastFrameTime_ = std::chrono::steady_clock::now();
}

NativeRender::~NativeRender() {
    OH_LOG_INFO(LOG_APP, "NativeRender destroyed");
    ReleaseNativeVSync();
    window_ = nullptr;
    surfaceReady_ = false;
}




void NativeRender::InitNativeVSync() {
    if (nativeVSync_ != nullptr) {
        return;
    }
    
    const char* name = "moonlight_render";
    nativeVSync_ = OH_NativeVSync_Create(name, strlen(name));
    if (nativeVSync_ != nullptr) {
        OH_LOG_INFO(LOG_APP, "NativeVSync created successfully");
    } else {
        OH_LOG_WARN(LOG_APP, "Failed to create NativeVSync");
    }
}

void NativeRender::ReleaseNativeVSync() {
    if (nativeVSync_ != nullptr) {
        OH_NativeVSync_Destroy(nativeVSync_);
        nativeVSync_ = nullptr;
        OH_LOG_INFO(LOG_APP, "NativeVSync destroyed");
    }
}




void NativeRender::SetNativeWindow(OHNativeWindow* window, uint64_t width, uint64_t height) {
    window_ = window;
    surfaceWidth_ = width;
    surfaceHeight_ = height;
    
    if (window != nullptr) {
        ConfigureNativeWindow();
        
        InitNativeVSync();
        
        if (configuredFps_ > 0 && nativeVSync_ != nullptr) {
            ApplyFrameRateRange();
        }
        
        surfaceReady_ = true;
        OH_LOG_INFO(LOG_APP, "NativeWindow set: %{public}p, size: %{public}lux%{public}lu", 
                    static_cast<void*>(window), width, height);
    } else {
        surfaceReady_ = false;
        ReleaseNativeVSync();
        OH_LOG_INFO(LOG_APP, "NativeWindow cleared");
    }
}

void NativeRender::SetConfiguredFps(int fps) {
    configuredFps_ = fps;
    OH_LOG_INFO(LOG_APP, "Configured FPS set to: %{public}d", fps);
    
    timeBaseInitialized_ = false;
    
    ApplyFrameRateRange();
    
    ApplyNativeWindowFrameRate();
}

void NativeRender::SetVsyncEnabled(bool enable) {
    bool wasEnabled = vsyncEnabled_.exchange(enable);
    if (wasEnabled != enable) {
        timeBaseInitialized_ = false;
        OH_LOG_INFO(LOG_APP, "VSync mode %{public}s", enable ? "enabled" : "disabled");
    }
}

void NativeRender::ConfigureNativeWindow() {
    if (window_ == nullptr) {
        return;
    }
    
    int32_t ret = OH_NativeWindow_NativeWindowSetScalingModeV2(window_, OH_SCALING_MODE_SCALE_TO_WINDOW_V2);
    if (ret == 0) {
        OH_LOG_INFO(LOG_APP, "ScalingModeV2 set to SCALE_TO_WINDOW_V2");
    }
    
    if (configuredFps_ > 60) {
        ApplyNativeWindowFrameRate();
    }
}




// OH_NativeWindow_SetFrameRateRange(window, min, max, expected, strategy)
// strategy: 0 = DEFAULT, 1 = EXACT
typedef int32_t (*PFN_OH_NativeWindow_SetFrameRateRange)(
    OHNativeWindow* window, int32_t min, int32_t max, int32_t expected, int32_t strategy);

static PFN_OH_NativeWindow_SetFrameRateRange g_pfnNWSetFrameRateRange = nullptr;
static bool g_nwFrameRateChecked = false;

static bool CheckAndLoadNWFrameRateApi() {
    if (g_nwFrameRateChecked) {
        return g_pfnNWSetFrameRateRange != nullptr;
    }
    g_nwFrameRateChecked = true;
    
    g_pfnNWSetFrameRateRange = (PFN_OH_NativeWindow_SetFrameRateRange)
        dlsym(RTLD_DEFAULT, "OH_NativeWindow_SetFrameRateRange");
    
    if (!g_pfnNWSetFrameRateRange) {
        void* handle = dlopen("libnative_window.so", RTLD_NOW);
        if (handle) {
            g_pfnNWSetFrameRateRange = (PFN_OH_NativeWindow_SetFrameRateRange)
                dlsym(handle, "OH_NativeWindow_SetFrameRateRange");
        }
    }
    
    if (g_pfnNWSetFrameRateRange) {
        OH_LOG_INFO(LOG_APP, "NativeWindow: OH_NativeWindow_SetFrameRateRange available");
    } else {
        OH_LOG_WARN(LOG_APP, "NativeWindow: OH_NativeWindow_SetFrameRateRange not available");
    }
    
    return g_pfnNWSetFrameRateRange != nullptr;
}

void NativeRender::ApplyNativeWindowFrameRate() {
    if (window_ == nullptr || configuredFps_ <= 60) {
        return;
    }
    
    if (!CheckAndLoadNWFrameRateApi()) {
        return;
    }
    
    int32_t ret = g_pfnNWSetFrameRateRange(window_, configuredFps_, configuredFps_, configuredFps_, 0);
    if (ret == 0) {
        OH_LOG_INFO(LOG_APP, "NativeWindow FrameRateRange set to %{public}d fps (Surface level)", configuredFps_);
    } else {
        OH_LOG_WARN(LOG_APP, "NativeWindow SetFrameRateRange failed: ret=%{public}d, fps=%{public}d", 
                    ret, configuredFps_);
    }
}

void NativeRender::ApplyFrameRateRange() {
    // NativeVSync SetExpectedFrameRateRange (API 20+)
    if (nativeVSync_ != nullptr && CheckAndLoadApi20()) {
        OH_NativeVSync_ExpectedRateRange range;
        range.min = configuredFps_;
        range.max = configuredFps_;
        range.expected = configuredFps_;
        
        int32_t ret = g_pfnSetExpectedFrameRateRange(nativeVSync_, &range);
        if (ret == 0) {
            OH_LOG_INFO(LOG_APP, "NativeVSync FrameRateRange set to fixed %{public}d fps",
                        configuredFps_);
        } else {
            OH_LOG_WARN(LOG_APP, "Failed to set NativeVSync FrameRateRange to %{public}d: ret=%{public}d", 
                        configuredFps_, ret);
        }
    }
}




int64_t NativeRender::CalculatePresentTime(int64_t pts) const {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    int64_t nowNs = static_cast<int64_t>(ts.tv_sec) * 1000000000LL + ts.tv_nsec;
    
    if (!timeBaseInitialized_) {
        baseSystemTimeNs_ = nowNs;
        basePtsUs_ = pts;
        timeBaseInitialized_ = true;
        OH_LOG_INFO(LOG_APP, "VSync time base initialized: basePts=%{public}lld us", 
                    static_cast<long long>(basePtsUs_));
    }
    
    int64_t ptsDeltaNs = (pts - basePtsUs_) * 1000LL;
    
    int64_t targetPresentTimeNs = baseSystemTimeNs_ + ptsDeltaNs;
    
    if (targetPresentTimeNs < nowNs) {
        int64_t frameIntervalNs = 1000000000LL / configuredFps_;
        targetPresentTimeNs = nowNs + frameIntervalNs / 2;
        
        baseSystemTimeNs_ = targetPresentTimeNs - ptsDeltaNs;
    }
    
    return targetPresentTimeNs;
}




void NativeRender::SubmitFrame(OH_AVCodec* codec, uint32_t bufferIndex, int64_t pts, int64_t enqueueTimeMs) {
    int32_t renderResult;
    
    if (vsyncEnabled_.load()) {
        PFN_RenderOutputBufferAtTime renderAtTime = GetRenderAtTimeFunc();
        if (renderAtTime != nullptr) {
            int64_t presentTimeNs = CalculatePresentTime(pts);
            renderResult = renderAtTime(codec, bufferIndex, presentTimeNs);
            
            if (renderResult != 0) {
                OH_LOG_WARN(LOG_APP, "RenderOutputBufferAtTime failed: %{public}d, pts=%{public}lld, presentNs=%{public}lld",
                            renderResult, static_cast<long long>(pts), static_cast<long long>(presentTimeNs));
            }
        } else {
            renderResult = OH_VideoDecoder_RenderOutputBuffer(codec, bufferIndex);
            if (renderResult != 0) {
                OH_LOG_WARN(LOG_APP, "RenderOutputBuffer (vsync fallback) failed: %{public}d", renderResult);
            }
        }
    } else {
        renderResult = OH_VideoDecoder_RenderOutputBuffer(codec, bufferIndex);
        
        if (renderResult != 0) {
            OH_LOG_WARN(LOG_APP, "RenderOutputBuffer failed: %{public}d", renderResult);
        }
    }
    
    lastFrameTime_ = std::chrono::steady_clock::now();
}
