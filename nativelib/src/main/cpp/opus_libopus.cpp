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
 * @file opus_libopus.cpp
 *
 */

#include "opus_libopus.h"
#include <opus_multistream.h>
#include <opus_defines.h>
#include <hilog/log.h>
#include <mutex>
#include <cstring>

// 5 = Deep PLC only
static constexpr int DECODER_COMPLEXITY = 7;




namespace {
    static OpusMSDecoder* g_decoder = nullptr;
    static std::mutex g_mutex;
    static int g_channelCount = 0;
    static int g_samplesPerFrame = 0;
    static OPUS_MULTISTREAM_CONFIGURATION g_savedConfig;
}

namespace MoonlightOpusDecoder {

int Init(POPUS_MULTISTREAM_CONFIGURATION opusConfig) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    if (g_decoder != nullptr) {
        opus_multistream_decoder_destroy(g_decoder);
        g_decoder = nullptr;
    }
    
    memcpy(&g_savedConfig, opusConfig, sizeof(g_savedConfig));
    g_channelCount = opusConfig->channelCount;
    g_samplesPerFrame = opusConfig->samplesPerFrame;
    
    OH_LOG_INFO(LOG_APP,
        "Initializing libopus decoder: sampleRate=%{public}d, channels=%{public}d, "
        "streams=%{public}d, coupledStreams=%{public}d, samplesPerFrame=%{public}d",
        opusConfig->sampleRate, opusConfig->channelCount,
        opusConfig->streams, opusConfig->coupledStreams,
        opusConfig->samplesPerFrame);
    
    int err = 0;
    g_decoder = opus_multistream_decoder_create(
        opusConfig->sampleRate,
        opusConfig->channelCount,
        opusConfig->streams,
        opusConfig->coupledStreams,
        opusConfig->mapping,
        &err
    );
    
    if (err != OPUS_OK || g_decoder == nullptr) {
        OH_LOG_ERROR(LOG_APP, "Failed to create opus multistream decoder: %{public}d (%{public}s)",
                     err, opus_strerror(err));
        g_decoder = nullptr;
        return -1;
    }
    
    int ctlErr = opus_multistream_decoder_ctl(g_decoder, OPUS_SET_COMPLEXITY(DECODER_COMPLEXITY));
    if (ctlErr != OPUS_OK) {
        OH_LOG_WARN(LOG_APP, "Failed to set decoder complexity to %{public}d: %{public}d (%{public}s). "
                    "ML features (Deep PLC/NoLACE) may not be available.",
                    DECODER_COMPLEXITY, ctlErr, opus_strerror(ctlErr));
    } else {
        OH_LOG_INFO(LOG_APP, "Decoder complexity set to %{public}d "
                    "(Deep PLC + NoLACE enabled)",
                    DECODER_COMPLEXITY);
    }
    
    OH_LOG_INFO(LOG_APP, "libopus 1.6 decoder initialized successfully with ML enhancements");
    return 0;
}

int Decode(const unsigned char* opusData, int opusLength,
           short* pcmOut, int maxSamples) {
    if (g_decoder == nullptr) {
        return -1;
    }
    
    int decodeLen = opus_multistream_decode(
        g_decoder,
        opusData,
        opusLength,     // 0 when PLC
        pcmOut,
        maxSamples,
        0
    );
    
    if (decodeLen < 0) {
        OH_LOG_WARN(LOG_APP, "opus_multistream_decode error: %{public}d (%{public}s)",
                    decodeLen, opus_strerror(decodeLen));
        return -1;
    }
    
    return decodeLen;
}

void Cleanup() {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    if (g_decoder != nullptr) {
        opus_multistream_decoder_destroy(g_decoder);
        g_decoder = nullptr;
    }
    
    g_channelCount = 0;
    g_samplesPerFrame = 0;
    
    OH_LOG_INFO(LOG_APP, "libopus decoder cleaned up");
}

int GetChannelCount() {
    return g_channelCount;
}

int GetSamplesPerFrame() {
    return g_samplesPerFrame;
}

} // namespace MoonlightOpusDecoder
