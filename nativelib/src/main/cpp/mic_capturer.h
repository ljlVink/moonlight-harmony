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
 * @file mic_capturer.h
 *
 *
 *   OH_AudioCapturer (FAST) → native callback → Opus encode → sendMicrophoneOpusData()
 */

#ifndef MIC_CAPTURER_H
#define MIC_CAPTURER_H

#include <cstdint>
#include <atomic>
#include <ohaudio/native_audiostream_base.h>
#include <ohaudio/native_audiostreambuilder.h>
#include <ohaudio/native_audiocapturer.h>
#include "opus_encoder.h"

struct MicCapturerConfig {
    int sampleRate = 48000;
    int channels = 1;
    int opusBitrate = 64000;
    int frameSizeMs = 20;
};

struct MicCapturerStats {
    uint64_t framesCapture;
    uint64_t framesEncoded;
    uint64_t framesSent;
    uint64_t framesDropped;
    bool isFastMode;
};

/**
 *
 *   MicCapturer capturer;
 *   capturer.Init(config);
 *   capturer.Start();
 *   capturer.Stop();
 *   capturer.Cleanup();
 */
class MicCapturer {
public:
    MicCapturer();
    ~MicCapturer();

    int Init(const MicCapturerConfig& config);

    int Start();

    int Stop();

    void Cleanup();

    void Pause();

    void Resume();

    bool IsRunning() const { return running_.load(std::memory_order_acquire); }
    bool IsPaused()  const { return paused_.load(std::memory_order_acquire); }

    MicCapturerStats GetStats() const;

    void UpdatePacketLossPercent(int percent) { encoder_.UpdatePacketLossPercent(percent); }

private:
    static OH_AudioData_Callback_Result OnReadData(
        OH_AudioCapturer* capturer, void* userData,
        void* buffer, int32_t length);
    static void OnError(
        OH_AudioCapturer* capturer, void* userData,
        OH_AudioStream_Result error);
    static void OnInterruptEvent(
        OH_AudioCapturer* capturer, void* userData,
        OH_AudioInterrupt_ForceType type, OH_AudioInterrupt_Hint hint);

    void ProcessPcmFrame(const uint8_t* data, int32_t length);

    OH_AudioCapturer*      capturer_ = nullptr;
    OH_AudioStreamBuilder* builder_  = nullptr;

    OhosOpusEncoder encoder_;

    static constexpr int kMaxFrameBytes = 48000 / 50 * 2 * 2; // 20ms, stereo, 16bit = 3840
    uint8_t frameBuffer_[kMaxFrameBytes] = {};
    int frameBufferPos_ = 0;
    int frameSizeBytes_ = 0;

    static constexpr int kOpusMaxOutputBytes = 4096;
    uint8_t opusOutput_[kOpusMaxOutputBytes] = {};

    MicCapturerConfig config_;

    std::atomic<bool> running_{false};
    std::atomic<bool> paused_{false};

    std::atomic<uint64_t> framesCaptured_{0};
    std::atomic<uint64_t> framesEncoded_{0};
    std::atomic<uint64_t> framesSent_{0};
    std::atomic<uint64_t> framesDropped_{0};
};

#endif // MIC_CAPTURER_H
