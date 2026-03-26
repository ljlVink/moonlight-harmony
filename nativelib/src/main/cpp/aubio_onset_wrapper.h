/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * aubio onset detection wrapper for BassEnergyAnalyzer
 *
 * Wraps aubio's onset detection API, providing a C++ friendly interface.
 * aubio uses spectral flux + adaptive whitening + peak-picking,
 * which is more accurate than hand-written simple energy ratio schemes.
 *
 * Thread model: Called on the same decode thread as BassEnergyAnalyzer, no locking needed.
 */

#ifndef AUBIO_ONSET_WRAPPER_H
#define AUBIO_ONSET_WRAPPER_H

extern "C" {
#include "types.h"
#include "fvec.h"
#include "onset/onset.h"
}

#include <cstdint>
#include <cstring>

class AubioOnsetWrapper {
public:
    AubioOnsetWrapper() = default;

    ~AubioOnsetWrapper() {
        Destroy();
    }

    AubioOnsetWrapper(const AubioOnsetWrapper&) = delete;
    AubioOnsetWrapper& operator=(const AubioOnsetWrapper&) = delete;

    /**
     *
     */
    bool Init(int sampleRate, int hopSize, const char* method = "specflux") {
        Destroy();

        sampleRate_ = sampleRate;
        hopSize_ = hopSize;

        bufSize_ = 1;
        while (bufSize_ < static_cast<unsigned int>(hopSize * 4)) {
            bufSize_ *= 2;
        }

        onset_ = new_aubio_onset(method, bufSize_, hopSize_, sampleRate_);
        if (!onset_) {
            return false;
        }

        aubio_onset_set_threshold(onset_, 0.3f);
        aubio_onset_set_silence(onset_, -70.0f);
        aubio_onset_set_minioi_ms(onset_, 80.0f);
        aubio_onset_set_awhitening(onset_, 1);
        aubio_onset_set_compression(onset_, 1.0f);
        aubio_onset_set_delay_ms(onset_, 0.0f);

        inputBuf_ = new_fvec(hopSize_);
        onsetOut_ = new_fvec(1);

        initialized_ = true;
        return true;
    }

    void Destroy() {
        if (onset_) {
            del_aubio_onset(onset_);
            onset_ = nullptr;
        }
        if (inputBuf_) {
            del_fvec(inputBuf_);
            inputBuf_ = nullptr;
        }
        if (onsetOut_) {
            del_fvec(onsetOut_);
            onsetOut_ = nullptr;
        }
        initialized_ = false;
        accumPos_ = 0;
    }

    void Reset() {
        if (onset_) {
            aubio_onset_reset(onset_);
        }
        accumPos_ = 0;
    }

    /**
     *
     *
     */
    bool ProcessFrame(const int16_t* pcmData, int perChannelSamples,
                      int channelCount, bool& outOnsetDetected) {
        if (!initialized_ || !pcmData) {
            outOnsetDetected = false;
            return false;
        }

        outOnsetDetected = false;

        for (int i = 0; i < perChannelSamples; i++) {
            float monoSample = 0.0f;
            for (int ch = 0; ch < channelCount; ch++) {
                monoSample += static_cast<float>(pcmData[i * channelCount + ch]);
            }
            monoSample /= (32768.0f * channelCount);

            inputBuf_->data[accumPos_] = monoSample;
            accumPos_++;

            if (accumPos_ >= static_cast<int>(hopSize_)) {
                aubio_onset_do(onset_, inputBuf_, onsetOut_);
                if (onsetOut_->data[0] > 0.0f) {
                    outOnsetDetected = true;
                }
                accumPos_ = 0;
            }
        }

        return true;
    }

    float GetDescriptor() const {
        if (!onset_) return 0.0f;
        return aubio_onset_get_descriptor(onset_);
    }

    float GetThresholdedDescriptor() const {
        if (!onset_) return 0.0f;
        return aubio_onset_get_thresholded_descriptor(onset_);
    }

    void SetThreshold(float threshold) {
        if (onset_) {
            aubio_onset_set_threshold(onset_, threshold);
        }
    }

    void SetMinInterval(float ms) {
        if (onset_) {
            aubio_onset_set_minioi_ms(onset_, ms);
        }
    }

    bool IsInitialized() const { return initialized_; }

private:
    aubio_onset_t* onset_ = nullptr;
    fvec_t* inputBuf_ = nullptr;
    fvec_t* onsetOut_ = nullptr;

    int sampleRate_ = 48000;
    unsigned int hopSize_ = 240;
    unsigned int bufSize_ = 1024;
    int accumPos_ = 0;
    bool initialized_ = false;
};

#endif // AUBIO_ONSET_WRAPPER_H
