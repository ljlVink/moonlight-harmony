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
 * @file native_render.h
 * 
 */

#ifndef NATIVE_RENDER_H
#define NATIVE_RENDER_H

#include <native_window/external_window.h>
#include <native_vsync/native_vsync.h>
#include <multimedia/player_framework/native_avcodec_videodecoder.h>
#include <hilog/log.h>

#include <cstdint>
#include <mutex>
#include <atomic>
#include <chrono>

class NativeRender {
public:
    static NativeRender* GetInstance();
    
    static void ReleaseInstance();
    
    OHNativeWindow* GetNativeWindow() const { return window_; }
    
    void SetNativeWindow(OHNativeWindow* window, uint64_t width, uint64_t height);
    
    void SetConfiguredFps(int fps);
    
    int GetConfiguredFps() const { return configuredFps_; }
    
    void SetVsyncEnabled(bool enable);
    
    bool IsVsyncEnabled() const { return vsyncEnabled_; }
    
    void SubmitFrame(OH_AVCodec* codec, uint32_t bufferIndex, int64_t pts, int64_t enqueueTimeMs);
    
    uint64_t GetSurfaceWidth() const { return surfaceWidth_; }
    uint64_t GetSurfaceHeight() const { return surfaceHeight_; }
    
    bool IsSurfaceReady() const { return surfaceReady_; }
    
    int64_t CalculatePresentTime(int64_t pts) const;

private:
    NativeRender();
    ~NativeRender();
    
    NativeRender(const NativeRender&) = delete;
    NativeRender& operator=(const NativeRender&) = delete;
    
    void ConfigureNativeWindow();
    
    void ApplyFrameRateRange();
    
    void ApplyNativeWindowFrameRate();
    
    void InitNativeVSync();
    
    void ReleaseNativeVSync();

private:
    static NativeRender* instance_;
    static std::mutex instanceMutex_;
    
    OHNativeWindow* window_ = nullptr;
    uint64_t surfaceWidth_ = 0;
    uint64_t surfaceHeight_ = 0;
    std::atomic<bool> surfaceReady_{false};
    
    int configuredFps_ = 60;
    
    std::atomic<bool> vsyncEnabled_{false};
    
    bool frameRateApplied_ = false;
    
    mutable int64_t baseSystemTimeNs_ = 0;
    mutable int64_t basePtsUs_ = 0;
    mutable bool timeBaseInitialized_ = false;
    
    OH_NativeVSync* nativeVSync_ = nullptr;
    
    std::chrono::steady_clock::time_point lastFrameTime_;
};

#endif // NATIVE_RENDER_H
