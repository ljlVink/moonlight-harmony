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
 * @file audio_renderer.h
 * 
 * 
 */

#ifndef AUDIO_RENDERER_H
#define AUDIO_RENDERER_H

#include <cstdint>
#include <mutex>
#include <atomic>
#include <ohaudio/native_audiostream_base.h>
#include <ohaudio/native_audiostreambuilder.h>
#include <ohaudio/native_audiorenderer.h>

struct AudioRendererConfig {
    int sampleRate;
    int channelCount;
    int samplesPerFrame;
    int bitsPerSample;
    float volume;
    bool enableSpatialAudio;
};

struct AudioRendererStats {
    uint64_t totalSamples;
    uint64_t playedSamples;
    uint64_t droppedSamples;
    uint32_t underruns;
    double latencyMs;
};

class AudioRenderer {
public:
    AudioRenderer();
    ~AudioRenderer();
    
    int Init(const AudioRendererConfig& config);
    
    int Start();
    
    int SetVolume(float volume);
    
    int Stop();
    
    void Cleanup();
    
    int PlaySamples(const int16_t* pcmData, int sampleCount);
    
    AudioRendererStats GetStats() const;
    
    double GetBufferLatencyMs() const;
    
    bool IsInitialized() const { return renderer_ != nullptr; }
    
    bool IsRunning() const { return running_; }

private:
    static OH_AudioData_Callback_Result OnWriteData(OH_AudioRenderer* renderer, void* userData,
                                                     void* buffer, int32_t bufferLen);
    static void OnDeviceChange(OH_AudioRenderer* renderer, void* userData,
                                OH_AudioStream_DeviceChangeReason reason);
    static void OnInterruptEvent(OH_AudioRenderer* renderer, void* userData,
                                  OH_AudioInterrupt_ForceType type,
                                  OH_AudioInterrupt_Hint hint);
    static void OnError(OH_AudioRenderer* renderer, void* userData,
                         OH_AudioStream_Result error);

    OH_AudioRenderer* renderer_ = nullptr;
    OH_AudioStreamBuilder* builder_ = nullptr;
    
    AudioRendererConfig config_;
    
    // =========================================================================
    // =========================================================================
    //
    static constexpr int TARGET_BUFFER_MS = 50;
    static constexpr int MAX_AUDIO_LATENCY_MS = 40;
    
    int ringCapacity_ = 0;
    int16_t* ringBuffer_ = nullptr;
    std::atomic<int> ringHead_{0};
    std::atomic<int> ringTail_{0};
    
    std::atomic<uint64_t> totalSamples_{0};
    std::atomic<uint64_t> playedSamples_{0};
    std::atomic<uint64_t> droppedSamples_{0};
    std::atomic<uint32_t> underruns_{0};
    
    std::atomic<bool> wasUnderrun_{false};
    
    std::atomic<bool> running_{false};
    std::atomic<bool> configured_{false};
    
    std::atomic<bool> needRestart_{false};
    std::atomic<int> consecutiveErrors_{0};
    static constexpr int MAX_ERRORS_BEFORE_RESTART = 3;
    
    int TryRestart();
};

namespace AudioRendererInstance {
    void SetSpatialAudioEnabled(bool enabled);
    
    bool IsSpatialAudioEnabled();
    
    int Init(int sampleRate, int channelCount, int samplesPerFrame);
    
    int SetVolume(float volume);
    
    int PlaySamples(const int16_t* pcmData, int sampleCount);
    
    int Start();
    
    int Stop();
    
    void Cleanup();
    
    AudioRendererStats GetStats();
    
    double GetBufferLatencyMs();
}

#endif // AUDIO_RENDERER_H
