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
 * @file video_decoder.h
 * 
 */

#ifndef VIDEO_DECODER_H
#define VIDEO_DECODER_H

#include <cstdint>
#include <mutex>
#include <shared_mutex>
#include <queue>
#include <thread>
#include <atomic>
#include <condition_variable>
#include <unordered_map>
#include <multimedia/player_framework/native_avcodec_videodecoder.h>
#include <multimedia/player_framework/native_avcapability.h>
#include <multimedia/player_framework/native_avcodec_base.h>
#include <multimedia/player_framework/native_avformat.h>
#include <multimedia/player_framework/native_avbuffer.h>
#include <native_window/external_window.h>
#include <native_buffer/native_buffer.h>
#include <hilog/log.h>

enum class VideoFrameType {
    UNKNOWN = 0,
    I_FRAME = 1,
    P_FRAME = 2,
    B_FRAME = 3
};

enum class VideoCodecType {
    H264 = 0,
    HEVC = 1,       // H.265
    AV1 = 2
};

enum class ColorSpace {
    REC_601 = 0,
    REC_709 = 1,
    REC_2020 = 2
};

enum class ColorRange {
    LIMITED = 0,
    FULL = 1
};

enum class HdrType {
    SDR = 0,
    HDR10 = 1,
    HLG = 2         // HLG (Hybrid Log-Gamma, ARIB STD-B67)
};

enum class DecoderMode {
    ASYNC = 0,
    SYNC = 1
};

struct VideoDecoderConfig {
    int width;
    int height;
    double fps;
    VideoCodecType codec;
    bool enableHdr;
    HdrType hdrType;
    ColorSpace colorSpace;
    ColorRange colorRange;
    int bufferCount;
    bool enableVsync;
    DecoderMode decoderMode;
    bool enableVrr;
};

enum class VsyncMode {
    OFF = 0,
    ON = 1,
    AUTO = 2
};

struct VideoDecoderStats {
    uint64_t totalFrames;
    uint64_t decodedFrames;
    uint64_t droppedFrames;
    uint64_t framesLost;
    int lastFrameNumber;
    double averageDecodeTimeMs;
    double maxDecodeTimeMs;
    uint64_t lastFrameCount;
    int64_t lastFpsCalculationTime;
    double currentFps;
    uint64_t lastDecodedFrameCount;
    int64_t lastRenderedFpsCalculationTime;
    double renderedFps;
    int64_t sessionStartTime;
    double globalAvgFps;
    uint64_t totalBytesReceived;
    uint64_t lastBytesCount;
    int64_t lastBitrateCalculationTime;
    double currentBitrate;  // bps
    double totalDecodeTimeMs;
    uint64_t validDecodeFrames;
    uint64_t framesWithHostLatency;
    double totalHostProcessingLatency;
    double avgHostProcessingLatency;
    uint64_t droppedByL1;
    uint64_t droppedByL2;
    uint64_t droppedByL3;
    uint64_t droppedByL4;
    uint64_t droppedByL5;
    uint64_t droppedByQueueOverflow;
    uint64_t droppedByTimeout;
};

struct BufferSegment {
    const uint8_t* data;
    int length;
};

class VideoDecoder {
public:
    VideoDecoder();
    ~VideoDecoder();
    
    int Init(const VideoDecoderConfig& config, OHNativeWindow* window);
    
    int SubmitDecodeUnit(const uint8_t* data, int size, 
                          int frameNumber, VideoFrameType frameType,
                          int64_t timestamp,
                          uint16_t hostProcessingLatency = 0);
    
    int SubmitDecodeUnitScatter(const BufferSegment* segments, int segmentCount,
                                int totalSize,
                                int frameNumber, VideoFrameType frameType,
                                int64_t timestamp,
                                uint16_t hostProcessingLatency = 0);
    
    int Start();
    
    int Stop();
    
    void Cleanup();
    
    int Flush();
    
    VideoDecoderStats GetStats() const;
    
    bool IsInitialized() const { return decoder_ != nullptr; }
    
    bool IsRunning() const { return running_; }
    
    bool CheckDecoderValid();
private:
    static void OnError(OH_AVCodec* codec, int32_t errorCode, void* userData);
    static void OnOutputFormatChanged(OH_AVCodec* codec, OH_AVFormat* format, void* userData);
    static void OnInputBufferAvailable(OH_AVCodec* codec, uint32_t index, OH_AVBuffer* data, void* userData);
    static void OnOutputBufferAvailable(OH_AVCodec* codec, uint32_t index, OH_AVBuffer* data, void* userData);
    
    const char* GetMimeType(VideoCodecType codec) const;
    
    void SyncDecodeLoop();
    
    int SyncProcessInput(int64_t timeoutUs);
    
    int SyncProcessOutput(int64_t timeoutUs);
    
    void UpdateReceivedStats(int size, int frameNumber, uint16_t hostProcessingLatency);
    
    void UpdateDecodedStats(int64_t pts, int64_t enqueueTimeMs, uint32_t flags);
    
    int CheckLatencyRecovery(VideoFrameType frameType, int size, int frameNumber, uint16_t hostProcessingLatency);
    
    void RecordEnqueueTimestamp(int64_t timestamp);
    
    OH_AVCodec* decoder_ = nullptr;
    
    mutable std::shared_mutex codecMutex_;
    
    OHNativeWindow* window_ = nullptr;
    
    VideoDecoderConfig config_;
    
    std::mutex inputMutex_;
    std::condition_variable inputCond_;
    std::queue<uint32_t> inputIndexQueue_;
    std::queue<OH_AVBuffer*> inputBufferQueue_;
    
    struct PendingFrame {
        std::vector<uint8_t> data;
        int frameNumber;
        VideoFrameType frameType;
        int64_t timestamp;
        uint16_t hostProcessingLatency;
    };
    std::mutex pendingFrameMutex_;
    std::condition_variable pendingFrameCond_;
    std::queue<PendingFrame> pendingFrameQueue_;
    size_t maxPendingFrames_{2};
    
    std::thread syncDecodeThread_;
    std::atomic<bool> syncDecodeRunning_{false};
    
    std::chrono::steady_clock::time_point lastFrameTime_;
    int64_t frameIntervalUs_{0};
    
    std::mutex timestampMutex_;
    std::unordered_map<int64_t, int64_t> timestampToEnqueueTime_;
    
    mutable std::mutex statsMutex_;
    VideoDecoderStats stats_;
    
    std::atomic<bool> running_{false};
    std::atomic<bool> configured_{false};
    
    std::atomic<bool> firstFrameReceived_{false};
    
    std::atomic<int64_t> lastInstantDecodeTimeMs_{0};
    std::atomic<bool> latencyRecoveryActive_{false};
    
    std::atomic<int64_t> lastOutputTimeMs_{0};
    
    std::atomic<int64_t> lastFrameArrivalMs_{0};
    std::atomic<int> burstFrameCount_{0};
    
    std::atomic<int64_t> lastAsyncRenderTimeMs_{0};
    
    std::atomic<int64_t> lastHealthCheckTimeMs_{0};
    std::atomic<int> consecutiveErrors_{0};
};

struct DecoderCapabilities {
    bool supportsH264;
    bool supportsHEVC;
    bool supportsAV1;
    int maxWidth;
    int maxHeight;
    int maxFps;
    bool supportsLowLatency;
    bool supports4K60;
    bool supports4K120;
    bool supports1080p120;
    int maxInstances;
};

namespace VideoDecoderInstance {
    DecoderCapabilities GetCapabilities();
    
    bool IsCodecSupported(VideoCodecType codec);
    
    int Init(int videoFormat, int width, int height, double fps, void* window);
    
    bool Init(OHNativeWindow* window);
    
    int Setup(int videoFormat, int width, int height, double fps);
    
    void SetHdrConfig(bool enableHdr, int hdrType, int colorSpace, int colorRange);
    
    void ResetHdrConfig();
    
    void SetBufferCount(int count);
    
    void SetSyncMode(bool syncMode);
    
    /**
     * 
     * 
     */
    void SetVrrEnabled(bool enabled);
    
    void SetPreciseFps(double fps);
    
    bool IsSyncMode();
    
    int SubmitDecodeUnit(const uint8_t* data, int size, int frameNumber, int frameType, uint16_t hostProcessingLatency = 0);
    
    int SubmitDecodeUnitScatter(const BufferSegment* segments, int segmentCount,
                                int totalSize, int frameNumber, int frameType,
                                uint16_t hostProcessingLatency = 0);
    
    int Start();
    
    int Stop();
    
    void Cleanup();
    
    VideoDecoderStats GetStats();
    
    void Resume();
}

#endif // VIDEO_DECODER_H