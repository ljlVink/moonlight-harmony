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
 * @file opus_encoder.h
 *
 */

#ifndef OPUS_ENCODER_H
#define OPUS_ENCODER_H

#include <cstdint>
#include <atomic>

// Forward declaration — libopus
struct OpusEncoder;

/**
 *
 */
class OhosOpusEncoder {
public:
    OhosOpusEncoder();
    ~OhosOpusEncoder();

    int Init(int sampleRate, int channels, int bitrate);

    int Encode(const uint8_t* pcmData, int pcmLength, uint8_t* opusOutput, int maxOutputLen);

    void Cleanup();

    bool IsInitialized() const { return initialized_.load(std::memory_order_acquire); }

    bool HasError() const { return hasError_.load(std::memory_order_acquire); }

    void UpdatePacketLossPercent(int percent);

private:
    ::OpusEncoder* encoder_ = nullptr;
    int sampleRate_ = 48000;
    int channels_ = 1;
    int bitrate_ = 64000;
    int frameSize_ = 960; // samples per channel per frame (20ms @ 48kHz)

    std::atomic<bool> initialized_{false};
    std::atomic<bool> hasError_{false};
    std::atomic<int> currentLossPercent_{1};
};

#endif // OPUS_ENCODER_H
