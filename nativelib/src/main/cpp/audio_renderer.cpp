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
 * @file audio_renderer.cpp
 * @brief HarmonyOS OHAudio audio renderer implementation
 */

#include "audio_renderer.h"
#include <hilog/log.h>
#include <cstring>
#include <dlfcn.h>
#include <qos/qos.h>
#include <algorithm>

#define LOG_TAG "AudioRenderer"

// =============================================================================
// OHAudio callback API dynamic loading (compatibility for older devices)
// =============================================================================

// Function pointer type definitions - Renderer
typedef OH_AudioStream_Result (*PFN_SetRendererWriteDataCb)(
    OH_AudioStreamBuilder*, OH_AudioRenderer_OnWriteDataCallback, void*);
typedef OH_AudioStream_Result (*PFN_SetRendererInterruptCb)(
    OH_AudioStreamBuilder*, OH_AudioRenderer_OnInterruptCallback, void*);
typedef OH_AudioStream_Result (*PFN_SetRendererErrorCb)(
    OH_AudioStreamBuilder*, OH_AudioRenderer_OnErrorCallback, void*);
typedef OH_AudioStream_Result (*PFN_SetRendererOutputDeviceChangeCb)(
    OH_AudioStreamBuilder*, OH_AudioRenderer_OutputDeviceChangeCallback, void*);

// Function pointer type definitions - Spatial audio (API 20+)
typedef OH_AudioStream_Result (*PFN_SetSpatializationEnabled)(
    OH_AudioStreamBuilder* builder, bool spatializationEnabled);

// Global function pointers
static PFN_SetRendererWriteDataCb       g_pfnSetRendererWriteDataCb = nullptr;
static PFN_SetRendererInterruptCb       g_pfnSetRendererInterruptCb = nullptr;
static PFN_SetRendererErrorCb           g_pfnSetRendererErrorCb = nullptr;
static PFN_SetRendererOutputDeviceChangeCb g_pfnSetRendererDeviceChangeCb = nullptr;
static PFN_SetSpatializationEnabled     g_pfnSetSpatializationEnabled = nullptr;

static bool g_audioApisChecked = false;
static bool g_writeDataCbAvailable = false;
static bool g_spatialAudioAvailable = false;

// Load all optional OHAudio APIs
static void LoadAudioApis() {
    if (g_audioApisChecked) return;
    g_audioApisChecked = true;
    
    void* handle = dlopen("libohaudio.so", RTLD_NOW);
    if (!handle) {
        OH_LOG_ERROR(LOG_APP, "Failed to dlopen libohaudio.so");
        return;
    }

    // Renderer new-style callbacks
    g_pfnSetRendererWriteDataCb = (PFN_SetRendererWriteDataCb)
        dlsym(handle, "OH_AudioStreamBuilder_SetRendererWriteDataCallback");
    g_pfnSetRendererInterruptCb = (PFN_SetRendererInterruptCb)
        dlsym(handle, "OH_AudioStreamBuilder_SetRendererInterruptCallback");
    g_pfnSetRendererErrorCb = (PFN_SetRendererErrorCb)
        dlsym(handle, "OH_AudioStreamBuilder_SetRendererErrorCallback");
    g_pfnSetRendererDeviceChangeCb = (PFN_SetRendererOutputDeviceChangeCb)
        dlsym(handle, "OH_AudioStreamBuilder_SetRendererOutputDeviceChangeCallback");

    // Spatial audio (API 20+)
    g_pfnSetSpatializationEnabled = (PFN_SetSpatializationEnabled)
        dlsym(handle, "OH_AudioStreamBuilder_SetSpatializationEnabled");

    g_writeDataCbAvailable = (g_pfnSetRendererWriteDataCb != nullptr);
    g_spatialAudioAvailable = (g_pfnSetSpatializationEnabled != nullptr);

    OH_LOG_INFO(LOG_APP, "OHAudio API probe: WriteDataCb=%{public}s InterruptCb=%{public}s "
                "ErrorCb=%{public}s DeviceChangeCb=%{public}s SpatialAudio=%{public}s",
                g_pfnSetRendererWriteDataCb ? "Y" : "N",
                g_pfnSetRendererInterruptCb ? "Y" : "N",
                g_pfnSetRendererErrorCb ? "Y" : "N",
                g_pfnSetRendererDeviceChangeCb ? "Y" : "N",
                g_pfnSetSpatializationEnabled ? "Y" : "N");
    // Don't dlclose, keep library loaded
}

// =============================================================================
// AudioRenderer class implementation
// =============================================================================

AudioRenderer::AudioRenderer() {
    // ringBuffer_ is dynamically allocated in Init
}

AudioRenderer::~AudioRenderer() {
    Cleanup();
}

int AudioRenderer::Init(const AudioRendererConfig& config) {
    if (renderer_ != nullptr) {
        OH_LOG_WARN(LOG_APP, "AudioRenderer already initialized, cleaning up first to reinitialize");
        Cleanup();  // Clean up old instance before re-initializing
    }
    
    config_ = config;
    
    // Dynamically allocate ring buffer: calculate capacity based on actual channels and sample rate
    int usableSamples = config_.sampleRate * config_.channelCount * TARGET_BUFFER_MS / 1000;
    // Align to frame boundary (channelCount × samplesPerFrame)
    int frameSize = config_.channelCount * config_.samplesPerFrame;
    if (frameSize > 0) {
        usableSamples = ((usableSamples + frameSize - 1) / frameSize) * frameSize;
    }
    // SPSC ring buffer needs 1 extra slot to distinguish full/empty
    ringCapacity_ = usableSamples + 1;
    
    // Release old buffer (if any)
    delete[] ringBuffer_;
    ringBuffer_ = new int16_t[ringCapacity_];
    memset(ringBuffer_, 0, ringCapacity_ * sizeof(int16_t));
    
    OH_LOG_INFO(LOG_APP, "Ring buffer: capacity=%{public}d samples (%{public}dms for %{public}dch @%{public}dHz), "
                "latency cap=%{public}dms",
                ringCapacity_ - 1,
                TARGET_BUFFER_MS,
                config_.channelCount,
                config_.sampleRate,
                MAX_AUDIO_LATENCY_MS);
    
    OH_LOG_INFO(LOG_APP, "Initializing audio renderer: sampleRate=%{public}d, channels=%{public}d, samplesPerFrame=%{public}d",
                config_.sampleRate, config_.channelCount, config_.samplesPerFrame);
    
    // Create AudioStreamBuilder
    OH_AudioStream_Result result = OH_AudioStreamBuilder_Create(&builder_, AUDIOSTREAM_TYPE_RENDERER);
    if (result != AUDIOSTREAM_SUCCESS || builder_ == nullptr) {
        OH_LOG_ERROR(LOG_APP, "Failed to create AudioStreamBuilder: %{public}d", result);
        return -1;
    }
    
    // Set sample rate
    result = OH_AudioStreamBuilder_SetSamplingRate(builder_, config_.sampleRate);
    if (result != AUDIOSTREAM_SUCCESS) {
        OH_LOG_ERROR(LOG_APP, "Failed to set sampling rate: %{public}d", result);
        OH_AudioStreamBuilder_Destroy(builder_);
        builder_ = nullptr;
        return -1;
    }
    
    // Set channel count
    result = OH_AudioStreamBuilder_SetChannelCount(builder_, config_.channelCount);
    if (result != AUDIOSTREAM_SUCCESS) {
        OH_LOG_ERROR(LOG_APP, "Failed to set channel count: %{public}d", result);
        OH_AudioStreamBuilder_Destroy(builder_);
        builder_ = nullptr;
        return -1;
    }
    
    // Set channel layout
    // Select appropriate layout based on channel count
    OH_AudioChannelLayout channelLayout;
    switch (config_.channelCount) {
        case 1:
            channelLayout = CH_LAYOUT_MONO;
            break;
        case 2:
            channelLayout = CH_LAYOUT_STEREO;
            break;
        case 6:
            // 5.1 surround: FL, FR, FC, LFE, BL, BR
            channelLayout = CH_LAYOUT_5POINT1;
            break;
        case 8:
            // 7.1 surround: FL, FR, FC, LFE, BL, BR, SL, SR
            channelLayout = CH_LAYOUT_7POINT1;
            break;
        default:
            // For unsupported channel counts, use UNKNOWN to let system decide
            OH_LOG_WARN(LOG_APP, "Unsupported channel count %{public}d, using CH_LAYOUT_UNKNOWN", 
                        config_.channelCount);
            channelLayout = CH_LAYOUT_UNKNOWN;
            break;
    }
    
    OH_LOG_INFO(LOG_APP, "Setting channel layout for %{public}d channels: 0x%{public}llx",
                config_.channelCount, static_cast<long long>(channelLayout));
    
    result = OH_AudioStreamBuilder_SetChannelLayout(builder_, channelLayout);
    if (result != AUDIOSTREAM_SUCCESS) {
        OH_LOG_ERROR(LOG_APP, "Failed to set channel layout: %{public}d", result);
        OH_AudioStreamBuilder_Destroy(builder_);
        builder_ = nullptr;
        return -1;
    }
    
    // Set sample format (16-bit PCM)
    result = OH_AudioStreamBuilder_SetSampleFormat(builder_, AUDIOSTREAM_SAMPLE_S16LE);
    if (result != AUDIOSTREAM_SUCCESS) {
        OH_LOG_ERROR(LOG_APP, "Failed to set sample format: %{public}d", result);
        OH_AudioStreamBuilder_Destroy(builder_);
        builder_ = nullptr;
        return -1;
    }
    
    // Set encoding type (PCM)
    result = OH_AudioStreamBuilder_SetEncodingType(builder_, AUDIOSTREAM_ENCODING_TYPE_RAW);
    if (result != AUDIOSTREAM_SUCCESS) {
        OH_LOG_ERROR(LOG_APP, "Failed to set encoding type: %{public}d", result);
        OH_AudioStreamBuilder_Destroy(builder_);
        builder_ = nullptr;
        return -1;
    }
    
    // Set usage (game)
    result = OH_AudioStreamBuilder_SetRendererInfo(builder_, AUDIOSTREAM_USAGE_GAME);
    if (result != AUDIOSTREAM_SUCCESS) {
        OH_LOG_WARN(LOG_APP, "Failed to set renderer usage: %{public}d", result);
        // Non-fatal error, continue
    }
    
    // Set low-latency mode
    // Note: Use NORMAL mode when spatial audio is enabled, as FAST mode bypasses DSP spatialization
    OH_AudioStream_LatencyMode latencyMode = config_.enableSpatialAudio 
        ? AUDIOSTREAM_LATENCY_MODE_NORMAL 
        : AUDIOSTREAM_LATENCY_MODE_FAST;
    result = OH_AudioStreamBuilder_SetLatencyMode(builder_, latencyMode);
    if (result != AUDIOSTREAM_SUCCESS) {
        OH_LOG_WARN(LOG_APP, "Failed to set latency mode: %{public}d", result);
        // Non-fatal error, continue
    } else {
        OH_LOG_INFO(LOG_APP, "Audio latency mode: %{public}s",
                    latencyMode == AUDIOSTREAM_LATENCY_MODE_FAST ? "FAST" : "NORMAL (spatial audio)");
    }
    
    // Set callback frame size (API 12+)
    // Match Opus decode frame size (typically 240 samples = 5ms @48kHz)
    result = OH_AudioStreamBuilder_SetFrameSizeInCallback(builder_, config_.samplesPerFrame);
    if (result == AUDIOSTREAM_SUCCESS) {
        OH_LOG_INFO(LOG_APP, "Audio callback frame size set to %{public}d samples", config_.samplesPerFrame);
    } else {
        OH_LOG_WARN(LOG_APP, "Failed to set callback frame size: %{public}d (using system default)", result);
    }
    
    // Try to enable spatial audio (HarmonyOS 5.0+ API 20)
    LoadAudioApis();
    if (config_.enableSpatialAudio && g_spatialAudioAvailable && g_pfnSetSpatializationEnabled != nullptr) {
        result = g_pfnSetSpatializationEnabled(builder_, true);
        if (result == AUDIOSTREAM_SUCCESS) {
            OH_LOG_INFO(LOG_APP, "Spatial audio enabled successfully");
        } else {
            OH_LOG_WARN(LOG_APP, "Failed to enable spatial audio: %{public}d", result);
        }
    } else if (config_.enableSpatialAudio) {
        OH_LOG_INFO(LOG_APP, "Spatial audio not available on this device/API level");
    }
    
    // Set callbacks via dlsym-loaded function pointers (compatibility for older devices)
    LoadAudioApis();

    // Data write callback (required)
    if (g_pfnSetRendererWriteDataCb) {
        result = g_pfnSetRendererWriteDataCb(builder_,
            (OH_AudioRenderer_OnWriteDataCallback)OnWriteData, this);
        if (result != AUDIOSTREAM_SUCCESS) {
            OH_LOG_ERROR(LOG_APP, "Failed to set write data callback: %{public}d", result);
            OH_AudioStreamBuilder_Destroy(builder_);
            builder_ = nullptr;
            return -1;
        }
    } else {
        OH_LOG_ERROR(LOG_APP, "SetRendererWriteDataCallback not available on this device!");
        OH_AudioStreamBuilder_Destroy(builder_);
        builder_ = nullptr;
        return -1;
    }
    
    // Interrupt event callback (optional - not available on some API 12 devices)
    if (g_pfnSetRendererInterruptCb) {
        result = g_pfnSetRendererInterruptCb(builder_,
            (OH_AudioRenderer_OnInterruptCallback)OnInterruptEvent, this);
        if (result != AUDIOSTREAM_SUCCESS) {
            OH_LOG_WARN(LOG_APP, "Failed to set interrupt callback: %{public}d", result);
        }
    } else {
        OH_LOG_INFO(LOG_APP, "SetRendererInterruptCallback not available, skipping");
    }
    
    // Error callback (optional)
    if (g_pfnSetRendererErrorCb) {
        result = g_pfnSetRendererErrorCb(builder_,
            (OH_AudioRenderer_OnErrorCallback)OnError, this);
        if (result != AUDIOSTREAM_SUCCESS) {
            OH_LOG_WARN(LOG_APP, "Failed to set error callback: %{public}d", result);
        }
    } else {
        OH_LOG_INFO(LOG_APP, "SetRendererErrorCallback not available, skipping");
    }
    
    // Device change callback (optional)
    if (g_pfnSetRendererDeviceChangeCb) {
        result = g_pfnSetRendererDeviceChangeCb(builder_,
            (OH_AudioRenderer_OutputDeviceChangeCallback)OnDeviceChange, this);
        if (result != AUDIOSTREAM_SUCCESS) {
            OH_LOG_WARN(LOG_APP, "Failed to set device change callback: %{public}d", result);
        }
    } else {
        OH_LOG_INFO(LOG_APP, "SetRendererOutputDeviceChangeCallback not available, skipping");
    }
    
    // Create renderer
    result = OH_AudioStreamBuilder_GenerateRenderer(builder_, &renderer_);
    if (result != AUDIOSTREAM_SUCCESS || renderer_ == nullptr) {
        OH_LOG_ERROR(LOG_APP, "Failed to generate renderer: %{public}d", result);
        OH_AudioStreamBuilder_Destroy(builder_);
        builder_ = nullptr;
        return -1;
    }
    
    // Set initial volume (if configured)
    if (config_.volume > 0.0f && config_.volume <= 1.0f) {
        SetVolume(config_.volume);
    }
    
    configured_ = true;
    OH_LOG_INFO(LOG_APP, "Audio renderer initialized successfully");
    
    return 0;
}

int AudioRenderer::SetVolume(float volume) {
    if (renderer_ == nullptr) {
        OH_LOG_ERROR(LOG_APP, "Renderer not initialized");
        return -1;
    }
    
    // Clamp volume range
    if (volume < 0.0f) volume = 0.0f;
    if (volume > 1.0f) volume = 1.0f;
    
    OH_AudioStream_Result result = OH_AudioRenderer_SetVolume(renderer_, volume);
    if (result != AUDIOSTREAM_SUCCESS) {
        OH_LOG_ERROR(LOG_APP, "Failed to set volume to %{public}f: %{public}d", volume, result);
        return -1;
    }
    
    OH_LOG_INFO(LOG_APP, "Audio volume set to: %{public}f", volume);
    return 0;
}

int AudioRenderer::Start() {
    if (!configured_ || renderer_ == nullptr) {
        OH_LOG_ERROR(LOG_APP, "Renderer not configured");
        return -1;
    }
    
    // Clear OHAudio internal buffer to avoid playing stale data
    OH_AudioRenderer_Flush(renderer_);
    
    // Clear ring buffer
    ringHead_.store(0, std::memory_order_relaxed);
    ringTail_.store(0, std::memory_order_relaxed);
    wasUnderrun_.store(false, std::memory_order_relaxed);
    
    OH_AudioStream_Result result = OH_AudioRenderer_Start(renderer_);
    if (result != AUDIOSTREAM_SUCCESS) {
        OH_LOG_ERROR(LOG_APP, "Failed to start renderer: %{public}d", result);
        return -1;
    }
    
    running_ = true;
    needRestart_ = false;
    consecutiveErrors_ = 0;
    OH_LOG_INFO(LOG_APP, "Audio renderer started");
    
    return 0;
}

int AudioRenderer::Stop() {
    running_ = false;
    
    if (renderer_ != nullptr) {
        OH_AudioRenderer_Stop(renderer_);
    }
    
    // Clear ring buffer
    ringHead_.store(0, std::memory_order_relaxed);
    ringTail_.store(0, std::memory_order_relaxed);
    wasUnderrun_.store(false, std::memory_order_relaxed);
    
    OH_LOG_INFO(LOG_APP, "Audio renderer stopped");
    return 0;
}

void AudioRenderer::Cleanup() {
    Stop();
    
    if (renderer_ != nullptr) {
        OH_AudioRenderer_Release(renderer_);
        renderer_ = nullptr;
    }
    
    if (builder_ != nullptr) {
        OH_AudioStreamBuilder_Destroy(builder_);
        builder_ = nullptr;
    }
    
    configured_ = false;
    
    // Release dynamic ring buffer
    delete[] ringBuffer_;
    ringBuffer_ = nullptr;
    ringCapacity_ = 0;
    
    OH_LOG_INFO(LOG_APP, "Audio renderer cleaned up");
}

int AudioRenderer::PlaySamples(const int16_t* pcmData, int sampleCount) {
    if (renderer_ == nullptr) {
        return -1;
    }
    
    // If restart needed, try to recover
    if (needRestart_.load(std::memory_order_relaxed)) {
        TryRestart();
    }
    
    if (!running_) {
        return -1;
    }
    
    // Write to ring buffer (lock-free SPSC)
    // Producer only writes ringTail_, doesn't touch ringHead_ (consumer's variable)
    int dataSize = sampleCount * config_.channelCount;
    int tail = ringTail_.load(std::memory_order_relaxed);
    int head = ringHead_.load(std::memory_order_acquire);
    
    // Calculate available space (keep 1 slot gap to distinguish full/empty)
    int available;
    if (tail >= head) {
        available = ringCapacity_ - (tail - head) - 1;
    } else {
        available = head - tail - 1;
    }
    
    if (available < dataSize) {
        // Buffer full -> drop new data
        // Don't advance head (consumer's write variable), maintain SPSC contract
        droppedSamples_.fetch_add(sampleCount, std::memory_order_relaxed);
        return 0;
    }
    
    // Write data to ring buffer
    int firstPart = std::min(dataSize, ringCapacity_ - tail);
    memcpy(ringBuffer_ + tail, pcmData, firstPart * sizeof(int16_t));
    if (firstPart < dataSize) {
        memcpy(ringBuffer_, pcmData + firstPart, (dataSize - firstPart) * sizeof(int16_t));
    }
    ringTail_.store((tail + dataSize) % ringCapacity_, std::memory_order_release);
    
    totalSamples_.fetch_add(sampleCount, std::memory_order_relaxed);
    
    return 0;
}

int AudioRenderer::TryRestart() {
    OH_LOG_INFO(LOG_APP, "Attempting audio renderer restart...");
    
    if (renderer_ == nullptr) {
        OH_LOG_ERROR(LOG_APP, "Cannot restart: renderer is null");
        return -1;
    }
    
    // Stop current renderer first
    OH_AudioRenderer_Stop(renderer_);
    
    // Clear ring buffer + OHAudio internal buffer to avoid playing stale data
    ringHead_.store(0, std::memory_order_relaxed);
    ringTail_.store(0, std::memory_order_relaxed);
    wasUnderrun_.store(false, std::memory_order_relaxed);
    OH_AudioRenderer_Flush(renderer_);
    
    // Try to restart
    OH_AudioStream_Result result = OH_AudioRenderer_Start(renderer_);
    if (result != AUDIOSTREAM_SUCCESS) {
        OH_LOG_ERROR(LOG_APP, "Failed to restart renderer: %{public}d", result);
        
        // Full renderer rebuild
        OH_LOG_INFO(LOG_APP, "Attempting full renderer rebuild...");
        OH_AudioRenderer_Release(renderer_);
        renderer_ = nullptr;
        
        if (builder_ != nullptr) {
            result = OH_AudioStreamBuilder_GenerateRenderer(builder_, &renderer_);
            if (result != AUDIOSTREAM_SUCCESS || renderer_ == nullptr) {
                OH_LOG_ERROR(LOG_APP, "Failed to rebuild renderer: %{public}d", result);
                return -1;
            }
            
            if (config_.volume > 0.0f && config_.volume <= 1.0f) {
                OH_AudioRenderer_SetVolume(renderer_, config_.volume);
            }
            
            result = OH_AudioRenderer_Start(renderer_);
            if (result != AUDIOSTREAM_SUCCESS) {
                OH_LOG_ERROR(LOG_APP, "Failed to start rebuilt renderer: %{public}d", result);
                return -1;
            }
        } else {
            OH_LOG_ERROR(LOG_APP, "Cannot rebuild: builder is null");
            return -1;
        }
    }
    
    running_ = true;
    needRestart_ = false;
    consecutiveErrors_ = 0;
    OH_LOG_INFO(LOG_APP, "Audio renderer restarted successfully");
    return 0;
}

AudioRendererStats AudioRenderer::GetStats() const {
    AudioRendererStats stats;
    stats.totalSamples = totalSamples_.load(std::memory_order_relaxed);
    stats.playedSamples = playedSamples_.load(std::memory_order_relaxed);
    stats.droppedSamples = droppedSamples_.load(std::memory_order_relaxed);
    stats.underruns = underruns_.load(std::memory_order_relaxed);
    
    // Calculate current buffer latency
    int head = ringHead_.load(std::memory_order_relaxed);
    int tail = ringTail_.load(std::memory_order_relaxed);
    int buffered;
    if (tail >= head) {
        buffered = tail - head;
    } else {
        buffered = ringCapacity_ - head + tail;
    }
    int bufferedSamples = buffered / std::max(config_.channelCount, 1);
    stats.latencyMs = (config_.sampleRate > 0) 
        ? (bufferedSamples * 1000.0 / config_.sampleRate) 
        : 0.0;
    
    return stats;
}

double AudioRenderer::GetBufferLatencyMs() const {
    int head = ringHead_.load(std::memory_order_relaxed);
    int tail = ringTail_.load(std::memory_order_relaxed);
    int buffered = (tail >= head) ? (tail - head) : (ringCapacity_ - head + tail);
    int channelCount = std::max(config_.channelCount, 1);
    return (config_.sampleRate > 0)
        ? ((double)(buffered / channelCount) * 1000.0 / config_.sampleRate)
        : 0.0;
}

// =============================================================================
// OHAudio callback implementations
// =============================================================================

OH_AudioData_Callback_Result AudioRenderer::OnWriteData(OH_AudioRenderer* renderer, void* userData,
                                    void* buffer, int32_t bufferLen) {
    AudioRenderer* self = static_cast<AudioRenderer*>(userData);
    if (self == nullptr || !self->running_) {
        // Fill with silence
        memset(buffer, 0, bufferLen);
        return AUDIO_DATA_CALLBACK_RESULT_VALID;
    }
    
    // Always set audio callback thread QoS to highest priority
    static thread_local bool qosSet = false;
    if (!qosSet) {
        int ret = OH_QoS_SetThreadQoS(QOS_USER_INTERACTIVE);
        if (ret == 0) {
            OH_LOG_INFO(LOG_APP, "Audio callback thread QoS set to USER_INTERACTIVE");
        }
        qosSet = true;
    }
    
    // Read from ring buffer (lock-free SPSC consumer side)
    int16_t* outBuffer = static_cast<int16_t*>(buffer);
    int samplesNeeded = bufferLen / sizeof(int16_t);
    
    int head = self->ringHead_.load(std::memory_order_relaxed);
    int tail = self->ringTail_.load(std::memory_order_acquire);
    int channelCount = std::max(self->config_.channelCount, 1);

    // Calculate readable data amount
    int available;
    if (tail >= head) {
        available = tail - head;
    } else {
        available = self->ringCapacity_ - head + tail;
    }
    
    // Latency trimming (consumer side): skip old data if buffer accumulated too much
    // Advancing head in consumer thread is SPSC-safe (head is consumer's write variable)
    if (available > 0 && self->config_.sampleRate > 0) {
        int bufferedFrames = available / channelCount;
        double latencyMs = (double)bufferedFrames * 1000.0 / self->config_.sampleRate;
        if (latencyMs > MAX_AUDIO_LATENCY_MS) {
            // Jump to keep only MAX_AUDIO_LATENCY_MS/2 of data, leaving room for subsequent frames
            int targetSamples = self->config_.sampleRate * channelCount * MAX_AUDIO_LATENCY_MS / 2 / 1000;
            // Align to frame boundary
            targetSamples = (targetSamples / channelCount) * channelCount;
            int toDrop = available - targetSamples;
            if (toDrop > 0) {
                toDrop = (toDrop / channelCount) * channelCount;
                head = (head + toDrop) % self->ringCapacity_;
                self->ringHead_.store(head, std::memory_order_release);
                available -= toDrop;
                self->droppedSamples_.fetch_add(toDrop / channelCount, std::memory_order_relaxed);
                // Mark need fade-in (waveform discontinuous after skipping data)
                self->wasUnderrun_.store(true, std::memory_order_relaxed);
            }
        }
    }
    
    int toCopy = std::min(available, samplesNeeded);
    // Adaptive fade length: adjust based on gap size, larger gap needs longer fade to reduce clicks
    // Base: 96 frames (~2ms @48kHz), Max: 480 frames (~10ms @48kHz)
    static constexpr int FADE_FRAMES_MIN = 96;
    static constexpr int FADE_FRAMES_MAX = 480;
    int gap = samplesNeeded - toCopy;
    // Larger gap (less data) -> longer fade
    int FADE_FRAMES;
    if (gap <= 0 || samplesNeeded <= 0) {
        FADE_FRAMES = FADE_FRAMES_MIN;
    } else {
        // Linear interpolation: gap 0->samplesNeeded, fade MIN->MAX
        float gapRatio = (float)gap / (float)samplesNeeded;
        FADE_FRAMES = FADE_FRAMES_MIN + (int)((FADE_FRAMES_MAX - FADE_FRAMES_MIN) * gapRatio);
    }
    
    if (toCopy > 0) {
        // Read from ring buffer
        int firstPart = std::min(toCopy, self->ringCapacity_ - head);
        memcpy(outBuffer, self->ringBuffer_ + head, firstPart * sizeof(int16_t));
        if (firstPart < toCopy) {
            memcpy(outBuffer + firstPart, self->ringBuffer_, (toCopy - firstPart) * sizeof(int16_t));
        }
        self->ringHead_.store((head + toCopy) % self->ringCapacity_, std::memory_order_release);
        
        // Underrun recovery: apply fade-in to start data to avoid silence->signal waveform jump
        if (self->wasUnderrun_.load(std::memory_order_relaxed)) {
            // Step by frame (channelCount samples per frame), ensure all channels get same gain
            int fadeFrames = std::min(toCopy / channelCount, FADE_FRAMES);
            for (int f = 0; f < fadeFrames; f++) {
                float gain = (float)f / (float)fadeFrames;
                for (int c = 0; c < channelCount; c++) {
                    outBuffer[f * channelCount + c] = (int16_t)(outBuffer[f * channelCount + c] * gain);
                }
            }
        }
    }
    
    // If data insufficient, fill with silence (underrun)
    if (toCopy < samplesNeeded) {
        // Calculate deficit ratio: only fade out for significant deficit (small gap just fill silence)
        int gap = samplesNeeded - toCopy;
        bool significantUnderrun = (gap > samplesNeeded / 4);  // Only fade out if >25% deficit
        
        if (toCopy > 0 && significantUnderrun) {
            // Apply fade-out to trailing valid data to avoid signal->silence waveform jump
            // Step by frame to ensure multi-channel sync
            int fadeFrames = std::min(toCopy / channelCount, FADE_FRAMES);
            int fadeStartSample = toCopy - fadeFrames * channelCount;
            for (int f = 0; f < fadeFrames; f++) {
                float gain = 1.0f - (float)f / (float)fadeFrames;
                for (int c = 0; c < channelCount; c++) {
                    int idx = fadeStartSample + f * channelCount + c;
                    outBuffer[idx] = (int16_t)(outBuffer[idx] * gain);
                }
            }
        }
        memset(outBuffer + toCopy, 0, (samplesNeeded - toCopy) * sizeof(int16_t));
        self->underruns_.fetch_add(1, std::memory_order_relaxed);
        self->wasUnderrun_.store(true, std::memory_order_relaxed);
    } else {
        self->wasUnderrun_.store(false, std::memory_order_relaxed);
    }
    
    // Update played samples count (per channel)
    self->playedSamples_.fetch_add(toCopy / channelCount, std::memory_order_relaxed);
    
    return AUDIO_DATA_CALLBACK_RESULT_VALID;
}

void AudioRenderer::OnDeviceChange(OH_AudioRenderer* renderer, void* userData,
                                    OH_AudioStream_DeviceChangeReason reason) {
    OH_LOG_INFO(LOG_APP, "Audio output device changed: reason=%{public}d", reason);
    
    AudioRenderer* self = static_cast<AudioRenderer*>(userData);
    if (self == nullptr) return;
    
    if (reason == REASON_OLD_DEVICE_UNAVAILABLE) {
        // Old device unavailable (e.g. headphone unplugged), schedule restart
        OH_LOG_WARN(LOG_APP, "Audio device unavailable, scheduling restart");
        self->needRestart_ = true;
    }
}

void AudioRenderer::OnInterruptEvent(OH_AudioRenderer* renderer, void* userData,
                                         OH_AudioInterrupt_ForceType type,
                                         OH_AudioInterrupt_Hint hint) {
    OH_LOG_INFO(LOG_APP, "Audio interrupt: type=%{public}d, hint=%{public}d", type, hint);
    
    AudioRenderer* self = static_cast<AudioRenderer*>(userData);
    if (self == nullptr) return;
    
    if (hint == AUDIOSTREAM_INTERRUPT_HINT_PAUSE) {
        OH_LOG_WARN(LOG_APP, "Audio paused by system interrupt");
        self->running_ = false;
    } else if (hint == AUDIOSTREAM_INTERRUPT_HINT_RESUME) {
        OH_LOG_INFO(LOG_APP, "Audio resume hint received, scheduling restart");
        self->needRestart_ = true;
    } else if (hint == AUDIOSTREAM_INTERRUPT_HINT_STOP) {
        OH_LOG_WARN(LOG_APP, "Audio stopped by system, scheduling restart");
        self->running_ = false;
        self->needRestart_ = true;
    }
}

void AudioRenderer::OnError(OH_AudioRenderer* renderer, void* userData,
                                OH_AudioStream_Result error) {
    OH_LOG_ERROR(LOG_APP, "Audio renderer error: %{public}d", error);
    
    AudioRenderer* self = static_cast<AudioRenderer*>(userData);
    if (self == nullptr) return;
    
    int errors = ++self->consecutiveErrors_;
    OH_LOG_ERROR(LOG_APP, "Audio consecutive errors: %{public}d", errors);
    
    if (errors >= MAX_ERRORS_BEFORE_RESTART) {
        OH_LOG_WARN(LOG_APP, "Too many audio errors, scheduling restart");
        self->running_ = false;
        self->needRestart_ = true;
    }
}

// =============================================================================
// Global simplified interface
// =============================================================================

namespace {
    // Use atomic pointer for thread-safety of high-frequency calls like PlaySamples
    // Cleanup uses mutex to ensure mutual exclusion with Init
    static std::atomic<AudioRenderer*> g_audioRenderer{nullptr};
    static std::mutex g_audioRendererMutex;
}

namespace AudioRendererInstance {

// Spatial audio config (can be set via NAPI)
static bool g_enableSpatialAudio = false;

void SetSpatialAudioEnabled(bool enabled) {
    g_enableSpatialAudio = enabled;
    OH_LOG_INFO(LOG_APP, "Spatial audio setting: %{public}s", enabled ? "enabled" : "disabled");
}

bool IsSpatialAudioEnabled() {
    return g_enableSpatialAudio;
}

int Init(int sampleRate, int channelCount, int samplesPerFrame) {
    std::lock_guard<std::mutex> lock(g_audioRendererMutex);
    
    AudioRenderer* old = g_audioRenderer.exchange(nullptr, std::memory_order_acq_rel);
    if (old != nullptr) {
        delete old;
    }
    
    AudioRenderer* renderer = new AudioRenderer();
    
    AudioRendererConfig config;
    config.sampleRate = sampleRate;
    config.channelCount = channelCount;
    config.samplesPerFrame = samplesPerFrame;
    config.bitsPerSample = 16;
    config.volume = 1.0f;
    config.enableSpatialAudio = g_enableSpatialAudio;
    
    int ret = renderer->Init(config);
    if (ret == 0) {
        g_audioRenderer.store(renderer, std::memory_order_release);
    } else {
        delete renderer;
    }
    return ret;
}

int SetVolume(float volume) {
    AudioRenderer* renderer = g_audioRenderer.load(std::memory_order_acquire);
    if (renderer == nullptr) {
        return -1;
    }
    return renderer->SetVolume(volume);
}

int PlaySamples(const int16_t* pcmData, int sampleCount) {
    AudioRenderer* renderer = g_audioRenderer.load(std::memory_order_acquire);
    if (renderer == nullptr) {
        return -1;
    }
    return renderer->PlaySamples(pcmData, sampleCount);
}

int Start() {
    AudioRenderer* renderer = g_audioRenderer.load(std::memory_order_acquire);
    if (renderer == nullptr) {
        return -1;
    }
    return renderer->Start();
}

int Stop() {
    AudioRenderer* renderer = g_audioRenderer.load(std::memory_order_acquire);
    if (renderer == nullptr) {
        return -1;
    }
    return renderer->Stop();
}

void Cleanup() {
    std::lock_guard<std::mutex> lock(g_audioRendererMutex);
    
    AudioRenderer* old = g_audioRenderer.exchange(nullptr, std::memory_order_acq_rel);
    if (old != nullptr) {
        delete old;
    }
}

AudioRendererStats GetStats() {
    AudioRenderer* renderer = g_audioRenderer.load(std::memory_order_acquire);
    if (renderer != nullptr) {
        return renderer->GetStats();
    }
    return AudioRendererStats{};
}

double GetBufferLatencyMs() {
    AudioRenderer* renderer = g_audioRenderer.load(std::memory_order_acquire);
    if (renderer != nullptr) {
        return renderer->GetBufferLatencyMs();
    }
    return 0.0;
}

} // namespace AudioRendererInstance
