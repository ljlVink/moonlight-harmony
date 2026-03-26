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
 * @file aubio_onset_detector.h
 *
 *   AubioOnsetDetector detector;
 *   detector.Init(48000, 512, 1024);  // samplerate, hop_size, buf_size
 *
 *   bool onset = detector.ProcessSamples(pcm_float_mono, hop_size);
 *   if (onset) {
 *       float when_ms = detector.GetLastOnsetMs();
 *   }
 *
 *   detector.Cleanup();
 *
 */

#ifndef AUBIO_ONSET_DETECTOR_H
#define AUBIO_ONSET_DETECTOR_H

#include <cstdint>
#include <cstring>

// aubio C API
extern "C" {
#include "aubio/src/types.h"
#include "aubio/src/fvec.h"
#include "aubio/src/cvec.h"
#include "aubio/src/onset/onset.h"
}

class AubioOnsetDetector {
public:
    AubioOnsetDetector() = default;

    ~AubioOnsetDetector() {
        Cleanup();
    }

    AubioOnsetDetector(const AubioOnsetDetector&) = delete;
    AubioOnsetDetector& operator=(const AubioOnsetDetector&) = delete;

    /**
     *               "phase", "wphase", "specdiff", "kl", "mkl", "specflux"
     */
    bool Init(uint32_t sampleRate, uint32_t hopSize = 256,
              uint32_t bufSize = 512, const char* method = "hfc") {
        Cleanup();

        sampleRate_ = sampleRate;
        hopSize_ = hopSize;
        bufSize_ = bufSize;

        onset_ = new_aubio_onset(method, bufSize, hopSize, sampleRate);
        if (!onset_) {
            return false;
        }

        inputBuf_ = new_fvec(hopSize);
        outputBuf_ = new_fvec(1);
        if (!inputBuf_ || !outputBuf_) {
            Cleanup();
            return false;
        }

        initialized_ = true;
        return true;
    }

    void Cleanup() {
        if (onset_) {
            del_aubio_onset(onset_);
            onset_ = nullptr;
        }
        if (inputBuf_) {
            del_fvec(inputBuf_);
            inputBuf_ = nullptr;
        }
        if (outputBuf_) {
            del_fvec(outputBuf_);
            outputBuf_ = nullptr;
        }
        initialized_ = false;
    }

    bool ProcessSamples(const float* samples, uint32_t count) {
        if (!initialized_ || !samples || count != hopSize_) {
            return false;
        }

        std::memcpy(inputBuf_->data, samples, count * sizeof(float));

        aubio_onset_do(onset_, inputBuf_, outputBuf_);

        return outputBuf_->data[0] > 0.0f;
    }

    int ProcessInt16Interleaved(const int16_t* pcmData, int perChannelSamples,
                                int channelCount, bool& onsetDetected) {
        if (!initialized_ || !pcmData || perChannelSamples <= 0) {
            onsetDetected = false;
            return 0;
        }

        onsetDetected = false;
        int hopsProcessed = 0;

        for (int i = 0; i < perChannelSamples; i++) {
            float sample = 0.0f;
            for (int ch = 0; ch < channelCount; ch++) {
                sample += static_cast<float>(pcmData[i * channelCount + ch]);
            }
            sample /= (channelCount * 32768.0f);

            inputBuf_->data[accumPos_] = sample;
            accumPos_++;

            if (accumPos_ >= static_cast<int>(hopSize_)) {
                aubio_onset_do(onset_, inputBuf_, outputBuf_);
                if (outputBuf_->data[0] > 0.0f) {
                    onsetDetected = true;
                }
                accumPos_ = 0;
                hopsProcessed++;
            }
        }

        return hopsProcessed;
    }

    void SetThreshold(float threshold) {
        if (onset_) aubio_onset_set_threshold(onset_, threshold);
    }

    float GetThreshold() const {
        return onset_ ? aubio_onset_get_threshold(onset_) : 0.0f;
    }

    void SetSilence(float silenceDb) {
        if (onset_) aubio_onset_set_silence(onset_, silenceDb);
    }

    float GetSilence() const {
        return onset_ ? aubio_onset_get_silence(onset_) : -70.0f;
    }

    void SetMinioiMs(float ms) {
        if (onset_) aubio_onset_set_minioi_ms(onset_, ms);
    }

    float GetMinioiMs() const {
        return onset_ ? aubio_onset_get_minioi_ms(onset_) : 0.0f;
    }

    void SetAdaptiveWhitening(bool enable) {
        if (onset_) aubio_onset_set_awhitening(onset_, enable ? 1 : 0);
    }

    void SetCompression(float lambda) {
        if (onset_) aubio_onset_set_compression(onset_, lambda);
    }

    /**
    uint32_t GetLastOnset() const {
        return onset_ ? aubio_onset_get_last(onset_) : 0;
    }

    /**
    float GetLastOnsetMs() const {
        return onset_ ? aubio_onset_get_last_ms(onset_) : 0.0f;
    }

    /**
    float GetDescriptor() const {
        return onset_ ? aubio_onset_get_descriptor(onset_) : 0.0f;
    }

    /**
    float GetThresholdedDescriptor() const {
        return onset_ ? aubio_onset_get_thresholded_descriptor(onset_) : 0.0f;
    }

    /**
    void Reset() {
        if (onset_) aubio_onset_reset(onset_);
        accumPos_ = 0;
    }

    bool IsInitialized() const { return initialized_; }
    uint32_t GetHopSize() const { return hopSize_; }
    uint32_t GetBufSize() const { return bufSize_; }

private:
    aubio_onset_t* onset_ = nullptr;
    fvec_t* inputBuf_ = nullptr;
    fvec_t* outputBuf_ = nullptr;

    uint32_t sampleRate_ = 0;
    uint32_t hopSize_ = 0;
    uint32_t bufSize_ = 0;
    int accumPos_ = 0;

    bool initialized_ = false;
};

#endif // AUBIO_ONSET_DETECTOR_H
