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
 * @file opus_libopus.h
 * 
 */

#ifndef OPUS_LIBOPUS_H
#define OPUS_LIBOPUS_H

extern "C" {
#include "moonlight-common-c/src/Limelight.h"
}

namespace MoonlightOpusDecoder {
    int Init(POPUS_MULTISTREAM_CONFIGURATION opusConfig);
    
    int Decode(const unsigned char* opusData, int opusLength,
               short* pcmOut, int maxSamples);
    
    void Cleanup();
    
    int GetChannelCount();
    
    int GetSamplesPerFrame();
}

#endif // OPUS_LIBOPUS_H
