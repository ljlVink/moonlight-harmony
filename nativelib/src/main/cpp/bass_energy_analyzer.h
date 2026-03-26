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
 * @file bass_energy_analyzer.h
 *
 *
 *
 */

#ifndef BASS_ENERGY_ANALYZER_H
#define BASS_ENERGY_ANALYZER_H

#include <cstdint>
#include <cmath>
#include <cstring>
#include <chrono>
#include <algorithm>
#include "aubio_onset_wrapper.h"

class BassEnergyAnalyzer {
public:
    static constexpr int SCENE_GAME   = 0;
    static constexpr int SCENE_MUSIC  = 1;
    static constexpr int SCENE_AUTO   = 2;

    void Init(int sampleRate, int channelCount) {
        sampleRate_ = sampleRate;
        channelCount_ = channelCount;

        const double fc = 80.0;
        const double Q = 0.7071;  // 1/√2
        const double w0 = 2.0 * M_PI * fc / sampleRate;
        const double sinW0 = std::sin(w0);
        const double cosW0 = std::cos(w0);
        const double alpha = sinW0 / (2.0 * Q);

        const double a0 = 1.0 + alpha;
        bq_b0_ = static_cast<float>((1.0 - cosW0) / 2.0 / a0);
        bq_b1_ = static_cast<float>((1.0 - cosW0) / a0);
        bq_b2_ = bq_b0_;
        bq_a1_ = static_cast<float>(-2.0 * cosW0 / a0);
        bq_a2_ = static_cast<float>((1.0 - alpha) / a0);

        const double attackMs = 5.0;
        const double releaseMs = 80.0;
        attackCoeff_ = static_cast<float>(1.0 - std::exp(-1.0 / (sampleRate * attackMs / 1000.0)));
        releaseCoeff_ = static_cast<float>(1.0 - std::exp(-1.0 / (sampleRate * releaseMs / 1000.0)));

        noiseFloor_ = 0.0f;
        noiseFloorAlpha_ = static_cast<float>(1.0 - std::exp(-1.0 / (sampleRate * 2.0)));

        const int framesPerSec = sampleRate / std::max(240, 1);  // ~200 fps
        shortWindowAlpha_ = 2.0f / (framesPerSec * 0.08f + 1);  // ~80ms EMA
        longWindowAlpha_  = 2.0f / (framesPerSec * 0.8f  + 1);  // ~800ms EMA
        shortWindowEnergy_ = 0.0f;
        longWindowEnergy_ = 0.0f;
        prevFrameEnergy_ = 0.0f;
        onsetCooldownRemaining_ = 0;
        onsetPulseIntensity_ = 0;
        onsetPulseDecay_ = 0;

        onsetSignalAvg_ = 0.0f;
        onsetSignalAlpha_ = 2.0f / (framesPerSec * 2.0f + 1);

        onsetCooldownFrames_ = std::max(1, static_cast<int>(framesPerSec * 0.15f));

        transientCount_ = 0;
        transientWindowFrames_ = 0;
        transientWindowSize_ = sampleRate * 3;
        autoDetectedMode_ = SCENE_GAME;

        onsetHistoryWriteIdx_ = 0;
        onsetHistoryCount_ = 0;
        globalFrameCounter_ = 0;
        std::memset(onsetTimestamps_, 0, sizeof(onsetTimestamps_));

        pendingAutoMode_ = SCENE_GAME;
        pendingAutoModeCount_ = 0;

        bq_x1_ = bq_x2_ = 0.0f;
        bq_y1_ = bq_y2_ = 0.0f;
        envelope_ = 0.0f;
        rmsEnvelope_ = 0.0f;
        lastIntensity_ = 0;
        lastCallbackTime_ = std::chrono::steady_clock::now();
        enabled_ = false;
        sensitivity_ = 1.0f;
        sceneMode_ = SCENE_GAME;

        // ---- aubio onset detector ----
        int hopSize = std::max(240, 1);
        aubioOnset_.Init(sampleRate, hopSize, "specflux");
    }

    void SetEnabled(bool enabled) {
        enabled_ = enabled;
        if (!enabled) {
            bq_x1_ = bq_x2_ = 0.0f;
            bq_y1_ = bq_y2_ = 0.0f;
            envelope_ = 0.0f;
            rmsEnvelope_ = 0.0f;
            noiseFloor_ = 0.0f;
            shortWindowEnergy_ = 0.0f;
            longWindowEnergy_ = 0.0f;
            prevFrameEnergy_ = 0.0f;
            onsetSignalAvg_ = 0.0f;
            onsetCooldownRemaining_ = 0;
            onsetPulseIntensity_ = 0;
            onsetPulseDecay_ = 0;
            transientCount_ = 0;
            transientWindowFrames_ = 0;
            onsetHistoryWriteIdx_ = 0;
            onsetHistoryCount_ = 0;
            globalFrameCounter_ = 0;
            pendingAutoMode_ = SCENE_GAME;
            pendingAutoModeCount_ = 0;
            lastIntensity_ = 0;
            aubioOnset_.Reset();
        }
    }

    bool IsEnabled() const { return enabled_; }

    void SetSensitivity(float sensitivity) {
        sensitivity_ = std::max(0.1f, std::min(3.0f, sensitivity));
    }

    /**
     * @param mode SCENE_GAME(0) / SCENE_MUSIC(1) / SCENE_AUTO(2)
     */
    void SetSceneMode(int mode) {
        if (mode < SCENE_GAME || mode > SCENE_AUTO) mode = SCENE_GAME;
        sceneMode_ = mode;
        shortWindowEnergy_ = 0.0f;
        longWindowEnergy_ = 0.0f;
        prevFrameEnergy_ = 0.0f;
        onsetSignalAvg_ = 0.0f;
        onsetCooldownRemaining_ = 0;
        onsetPulseIntensity_ = 0;
        onsetPulseDecay_ = 0;
        transientCount_ = 0;
        transientWindowFrames_ = 0;
        onsetHistoryWriteIdx_ = 0;
        onsetHistoryCount_ = 0;
        globalFrameCounter_ = 0;
        pendingAutoMode_ = SCENE_GAME;
        pendingAutoModeCount_ = 0;
    }

    int GetSceneMode() const { return sceneMode_; }

    bool ProcessFrame(const int16_t* pcmData, int sampleCount, int& outIntensity,
                      int& outLowFreqRatio) {
        if (!enabled_ || pcmData == nullptr || sampleCount <= 0) {
            outIntensity = 0;
            outLowFreqRatio = 50;
            return false;
        }

        const int frameCount = sampleCount;

        float sumSquares = 0.0f;
        float frameEnergy = 0.0f;
        float fullBandEnergy = 0.0f;

        for (int i = 0; i < frameCount; i++) {
            float sample = 0.0f;
            for (int ch = 0; ch < channelCount_; ch++) {
                sample += static_cast<float>(pcmData[i * channelCount_ + ch]);
            }
            sample /= (channelCount_ * 32768.0f);
            sumSquares += sample * sample;

            fullBandEnergy += std::fabs(sample);

            float filtered = bq_b0_ * sample + bq_b1_ * bq_x1_ + bq_b2_ * bq_x2_
                           - bq_a1_ * bq_y1_ - bq_a2_ * bq_y2_;
            bq_x2_ = bq_x1_;
            bq_x1_ = sample;
            bq_y2_ = bq_y1_;
            bq_y1_ = filtered;

            float rectified = std::fabs(filtered);
            if (rectified > envelope_) {
                envelope_ += attackCoeff_ * (rectified - envelope_);
            } else {
                envelope_ += releaseCoeff_ * (rectified - envelope_);
            }

            frameEnergy += rectified;
        }

        frameEnergy = (frameCount > 0) ? (frameEnergy / frameCount) : 0.0f;
        fullBandEnergy = (frameCount > 0) ? (fullBandEnergy / frameCount) : 0.0f;

        float rms = (frameCount > 0) ? std::sqrt(sumSquares / frameCount) : 0.0f;
        if (rms > rmsEnvelope_) {
            rmsEnvelope_ += 0.3f * (rms - rmsEnvelope_);
        } else {
            rmsEnvelope_ += 0.02f * (rms - rmsEnvelope_);
        }

        const float rmsLow = 0.002f;
        const float rmsHigh = 0.015f;
        float volumeWeight;
        if (rmsEnvelope_ <= rmsLow) {
            volumeWeight = 0.0f;
        } else if (rmsEnvelope_ >= rmsHigh) {
            volumeWeight = 1.0f;
        } else {
            float t = (rmsEnvelope_ - rmsLow) / (rmsHigh - rmsLow);
            volumeWeight = t * t * (3.0f - 2.0f * t);
        }

        if (envelope_ < noiseFloor_ || noiseFloor_ < 1e-8f) {
            noiseFloor_ = envelope_;
        } else {
            noiseFloor_ += noiseFloorAlpha_ * (envelope_ - noiseFloor_);
        }

        int activeMode = sceneMode_;
        if (sceneMode_ == SCENE_AUTO) {
            activeMode = autoDetectMode(fullBandEnergy, frameCount);
        }

        bool aubioOnsetDetected = false;
        if (activeMode == SCENE_MUSIC && aubioOnset_.IsInitialized()) {
            aubioOnset_.ProcessFrame(pcmData, sampleCount, channelCount_, aubioOnsetDetected);
        }

        int intensity;
        if (activeMode == SCENE_MUSIC) {
            intensity = processMusicMode(fullBandEnergy, frameEnergy, volumeWeight,
                                         aubioOnsetDetected);
        } else {
            intensity = processGameMode(volumeWeight);
        }

        outIntensity = intensity;

        if (fullBandEnergy > 1e-6f) {
            float ratio = frameEnergy / fullBandEnergy;
            outLowFreqRatio = std::max(0, std::min(100, static_cast<int>(ratio * 100.0f)));
        } else {
            outLowFreqRatio = 50;
        }

        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - lastCallbackTime_).count();

        int minInterval = (activeMode == SCENE_MUSIC) ? 15 : 20;
        if (elapsed < minInterval) {
            return false;
        }

        int delta = std::abs(intensity - lastIntensity_);
        bool shouldCallback = (lastIntensity_ > 0 && intensity == 0)
                           || (intensity > 0 && lastIntensity_ == 0)
                           || (delta >= 3);

        if (!shouldCallback) {
            return false;
        }

        lastIntensity_ = intensity;
        lastCallbackTime_ = now;
        return true;
    }

    int GetCurrentIntensity() const { return lastIntensity_; }

private:
    int processGameMode(float volumeWeight) {
        float threshold = noiseFloor_ * 8.0f + 0.005f;
        float effectiveEnergy = std::max(0.0f, envelope_ - threshold);

        float normalized = effectiveEnergy * sensitivity_ * 10.0f;
        normalized = std::min(normalized, 1.0f);

        float mappedIntensity = std::pow(normalized, 2.5f) * volumeWeight * 100.0f;
        int intensity = static_cast<int>(mappedIntensity);
        return std::max(0, std::min(100, intensity));
    }

    /**
     *
     *
     */
    int processMusicMode(float fullBandEnergy, float lowFreqEnergy, float volumeWeight,
                         bool aubioOnsetDetected) {
        shortWindowEnergy_ += shortWindowAlpha_ * (fullBandEnergy - shortWindowEnergy_);
        longWindowEnergy_  += longWindowAlpha_  * (fullBandEnergy - longWindowEnergy_);

        if (onsetCooldownRemaining_ > 0) {
            onsetCooldownRemaining_--;
        }

        float onsetSignal = (longWindowEnergy_ > 1e-6f)
            ? (fullBandEnergy / longWindowEnergy_)
            : 0.0f;
        float smoothedOnset = (longWindowEnergy_ > 1e-6f)
            ? (shortWindowEnergy_ / longWindowEnergy_)
            : 0.0f;
        onsetSignalAvg_ += onsetSignalAlpha_ * (smoothedOnset - onsetSignalAvg_);
        float adaptiveThreshold = std::max(onsetSignalAvg_ * 1.5f, 1.5f);

        float energyDelta = fullBandEnergy - prevFrameEnergy_;
        prevFrameEnergy_ = fullBandEnergy;

        bool fallbackOnset = !aubioOnsetDetected
                          && (onsetSignal > adaptiveThreshold)
                          && (onsetCooldownRemaining_ <= 0)
                          && (energyDelta > 0.0f);

        bool isOnset = false;
        if (aubioOnsetDetected && onsetCooldownRemaining_ <= 0) {
            isOnset = true;
        } else if (fallbackOnset) {
            isOnset = true;
        }

        if (isOnset) {
            float ratio = (longWindowEnergy_ > 1e-6f)
                ? (fullBandEnergy / longWindowEnergy_) : 1.0f;
            float pulseStrength = std::min((ratio - 1.0f) / 2.0f, 1.0f);
            pulseStrength = std::pow(std::max(pulseStrength, 0.1f), 0.5f);

            float lowFreqBoost = 1.0f;
            if (lowFreqEnergy > 0.001f) {
                lowFreqBoost = 1.0f + std::min(lowFreqEnergy * 20.0f, 0.4f);
            }

            onsetPulseIntensity_ = static_cast<int>(
                pulseStrength * lowFreqBoost * sensitivity_ * volumeWeight * 100.0f
            );
            onsetPulseIntensity_ = std::max(15, std::min(100, onsetPulseIntensity_));

            onsetPulseDecay_ = 8;

            onsetCooldownRemaining_ = onsetCooldownFrames_;
        }

        if (onsetPulseDecay_ > 0) {
            float t = static_cast<float>(onsetPulseDecay_) / 8.0f;
            float decayFactor = std::exp(-3.0f * (1.0f - t));
            int output = static_cast<int>(onsetPulseIntensity_ * decayFactor);
            onsetPulseDecay_--;
            return std::max(0, std::min(100, output));
        }

        return 0;
    }

    /**
     *
     */
    int autoDetectMode(float frameEnergy, int frameCount) {
        globalFrameCounter_ += frameCount;
        transientWindowFrames_ += frameCount;

        if (frameEnergy > longWindowEnergy_ * 1.8f + 0.002f) {
            transientCount_++;

            onsetTimestamps_[onsetHistoryWriteIdx_] = globalFrameCounter_;
            onsetHistoryWriteIdx_ = (onsetHistoryWriteIdx_ + 1) % ONSET_HISTORY_SIZE;
            if (onsetHistoryCount_ < ONSET_HISTORY_SIZE) {
                onsetHistoryCount_++;
            }
        }

        if (transientWindowFrames_ >= transientWindowSize_) {
            int detectedMode = SCENE_GAME;

            if (transientCount_ >= 6 && transientCount_ <= 30) {
                if (onsetHistoryCount_ >= 4) {
                    float regularity = computeOnsetRegularity();
                    if (regularity < 0.5f) {
                        detectedMode = SCENE_MUSIC;
                    }
                }
            }

            if (detectedMode == pendingAutoMode_) {
                pendingAutoModeCount_++;
                if (pendingAutoModeCount_ >= 2) {
                    autoDetectedMode_ = detectedMode;
                }
            } else {
                pendingAutoMode_ = detectedMode;
                pendingAutoModeCount_ = 1;
            }

            transientCount_ = 0;
            transientWindowFrames_ = 0;
        }

        return autoDetectedMode_;
    }

    float computeOnsetRegularity() {
        if (onsetHistoryCount_ < 4) return 1.0f;

        float intervals[ONSET_HISTORY_SIZE];
        int n = 0;
        for (int i = 1; i < onsetHistoryCount_; i++) {
            int curIdx = (onsetHistoryWriteIdx_ - onsetHistoryCount_ + i + ONSET_HISTORY_SIZE)
                         % ONSET_HISTORY_SIZE;
            int prevIdx = (curIdx - 1 + ONSET_HISTORY_SIZE) % ONSET_HISTORY_SIZE;
            float interval = static_cast<float>(
                onsetTimestamps_[curIdx] - onsetTimestamps_[prevIdx]
            );
            if (interval > 0.0f) {
                intervals[n++] = interval;
            }
        }
        if (n < 3) return 1.0f;

        float mean = 0.0f;
        for (int i = 0; i < n; i++) mean += intervals[i];
        mean /= static_cast<float>(n);
        if (mean < 1.0f) return 1.0f;

        float variance = 0.0f;
        for (int i = 0; i < n; i++) {
            float d = intervals[i] - mean;
            variance += d * d;
        }
        variance /= static_cast<float>(n);

        // CV = stddev / mean
        return std::sqrt(variance) / mean;
    }

    int sampleRate_ = 48000;
    int channelCount_ = 2;
    bool enabled_ = false;
    float sensitivity_ = 1.0f;
    int sceneMode_ = SCENE_GAME;

    float bq_b0_ = 0.0f, bq_b1_ = 0.0f, bq_b2_ = 0.0f;
    float bq_a1_ = 0.0f, bq_a2_ = 0.0f;

    float bq_x1_ = 0.0f, bq_x2_ = 0.0f;
    float bq_y1_ = 0.0f, bq_y2_ = 0.0f;

    float attackCoeff_ = 0.0f;
    float releaseCoeff_ = 0.0f;
    float envelope_ = 0.0f;

    float rmsEnvelope_ = 0.0f;

    float noiseFloor_ = 0.0f;
    float noiseFloorAlpha_ = 0.0f;

    float shortWindowAlpha_ = 0.0f;
    float shortWindowEnergy_ = 0.0f;
    float longWindowAlpha_ = 0.0f;
    float longWindowEnergy_ = 0.0f;
    float onsetSignalAvg_ = 0.0f;
    float onsetSignalAlpha_ = 0.0f;
    float prevFrameEnergy_ = 0.0f;
    int onsetCooldownRemaining_ = 0;
    int onsetCooldownFrames_ = 0;
    int onsetPulseIntensity_ = 0;
    int onsetPulseDecay_ = 0;

    int transientCount_ = 0;
    int transientWindowFrames_ = 0;
    int transientWindowSize_ = 0;
    int autoDetectedMode_ = SCENE_GAME;

    static const int ONSET_HISTORY_SIZE = 16;
    int onsetTimestamps_[ONSET_HISTORY_SIZE] = {};
    int onsetHistoryWriteIdx_ = 0;
    int onsetHistoryCount_ = 0;
    int globalFrameCounter_ = 0;

    int pendingAutoMode_ = SCENE_GAME;
    int pendingAutoModeCount_ = 0;

    int lastIntensity_ = 0;
    std::chrono::steady_clock::time_point lastCallbackTime_;

    // ---- aubio onset detector ----
    AubioOnsetWrapper aubioOnset_;
};

#endif // BASS_ENERGY_ANALYZER_H
