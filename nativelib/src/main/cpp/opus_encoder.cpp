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
 * @file opus_encoder.cpp
 *
 *
 */

#include "opus_encoder.h"
#include <opus.h>
#include <hilog/log.h>
#include <cstring>
#include <algorithm>

#define LOG_TAG "OpusEncoder"

// =============================================================================
// =============================================================================

OhosOpusEncoder::OhosOpusEncoder() {
    OH_LOG_INFO(LOG_APP, "OhosOpusEncoder constructor (libopus)");
}

OhosOpusEncoder::~OhosOpusEncoder() {
    OH_LOG_INFO(LOG_APP, "OhosOpusEncoder destructor");
    Cleanup();
}

int OhosOpusEncoder::Init(int sampleRate, int channels, int bitrate) {
    OH_LOG_INFO(LOG_APP, "Init (libopus): sampleRate=%{public}d, channels=%{public}d, bitrate=%{public}d",
                sampleRate, channels, bitrate);

    if (initialized_.load(std::memory_order_acquire)) {
        OH_LOG_WARN(LOG_APP, "Opus encoder already initialized, cleaning up first");
        Cleanup();
    }

    sampleRate_ = sampleRate;
    channels_ = channels;
    bitrate_ = bitrate;
    frameSize_ = sampleRate / 50;

    int error = 0;
    encoder_ = opus_encoder_create(sampleRate_, channels_, OPUS_APPLICATION_VOIP, &error);
    if (error != OPUS_OK || encoder_ == nullptr) {
        OH_LOG_ERROR(LOG_APP, "opus_encoder_create failed: %{public}d (%{public}s)",
                     error, opus_strerror(error));
        encoder_ = nullptr;
        return -1;
    }

    opus_encoder_ctl(encoder_, OPUS_SET_BITRATE(bitrate_));

    opus_encoder_ctl(encoder_, OPUS_SET_SIGNAL(OPUS_SIGNAL_VOICE));

    opus_encoder_ctl(encoder_, OPUS_SET_COMPLEXITY(6));

    opus_encoder_ctl(encoder_, OPUS_SET_DTX(1));

    opus_encoder_ctl(encoder_, OPUS_SET_EXPERT_FRAME_DURATION(OPUS_FRAMESIZE_20_MS));

    opus_encoder_ctl(encoder_, OPUS_SET_INBAND_FEC(1));

    opus_encoder_ctl(encoder_, OPUS_SET_PACKET_LOSS_PERC(1));

    opus_int32 actualBitrate = 0, actualComplexity = 0, actualDtx = 0, actualFec = 0;
    opus_encoder_ctl(encoder_, OPUS_GET_BITRATE(&actualBitrate));
    opus_encoder_ctl(encoder_, OPUS_GET_COMPLEXITY(&actualComplexity));
    opus_encoder_ctl(encoder_, OPUS_GET_DTX(&actualDtx));
    opus_encoder_ctl(encoder_, OPUS_GET_INBAND_FEC(&actualFec));

    OH_LOG_INFO(LOG_APP,
        "libopus encoder ready: bitrate=%{public}d complexity=%{public}d DTX=%{public}d FEC=%{public}d frameSize=%{public}d",
        actualBitrate, actualComplexity, actualDtx, actualFec, frameSize_);

    hasError_.store(false, std::memory_order_release);
    initialized_.store(true, std::memory_order_release);
    return 0;
}

int OhosOpusEncoder::Encode(const uint8_t* pcmData, int pcmLength, uint8_t* opusOutput, int maxOutputLen) {
    if (pcmData == nullptr || pcmLength <= 0 || opusOutput == nullptr || maxOutputLen <= 0) {
        return -1;
    }

    if (!initialized_.load(std::memory_order_acquire) || encoder_ == nullptr) {
        return -1;
    }

    int expectedBytes = frameSize_ * channels_ * 2;
    if (pcmLength < expectedBytes) {
        OH_LOG_WARN(LOG_APP, "PCM data too short: %{public}d < %{public}d", pcmLength, expectedBytes);
        return -1;
    }

    int encodedLen = opus_encode(
        encoder_,
        reinterpret_cast<const opus_int16*>(pcmData),
        frameSize_,
        opusOutput,
        maxOutputLen
    );

    if (encodedLen < 0) {
        OH_LOG_ERROR(LOG_APP, "opus_encode failed: %{public}d (%{public}s)",
                     encodedLen, opus_strerror(encodedLen));
        hasError_.store(true, std::memory_order_release);
        return -1;
    }

    return encodedLen;
}

void OhosOpusEncoder::UpdatePacketLossPercent(int percent) {
    if (!initialized_.load(std::memory_order_acquire) || encoder_ == nullptr) {
        return;
    }
    percent = std::max(0, std::min(100, percent));
    int prev = currentLossPercent_.exchange(percent, std::memory_order_relaxed);
    if (prev != percent) {
        opus_encoder_ctl(encoder_, OPUS_SET_PACKET_LOSS_PERC(percent));
        OH_LOG_INFO(LOG_APP, "Opus encoder packet loss updated: %{public}d%% -> %{public}d%%", prev, percent);
    }
}

void OhosOpusEncoder::Cleanup() {
    OH_LOG_INFO(LOG_APP, "Cleanup (libopus)");

    initialized_.store(false, std::memory_order_release);

    if (encoder_ != nullptr) {
        opus_encoder_destroy(encoder_);
        encoder_ = nullptr;
    }

    hasError_.store(false, std::memory_order_release);
    currentLossPercent_.store(1, std::memory_order_relaxed);
    OH_LOG_INFO(LOG_APP, "Cleanup completed");
}
