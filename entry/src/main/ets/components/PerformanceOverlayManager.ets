/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

export class PerfIcons {
  static readonly RESOLUTION: string = "📱";
  static readonly DECODER: string = "🎬";
  static readonly PACKET_LOSS: string = "📶";
  static readonly BITRATE: string = "⏳";
  static readonly NETWORK: string = "🌐";
  static readonly DECODE_NORMAL: string = "⏱️";
  static readonly DECODE_HOT: string = "🥵";
  static readonly HOST: string = "🖥️";
  static readonly BATTERY: string = "🔋";
  static readonly CHARGING: string = "⚡";
}

export class PerfLabels {
  static readonly RESOLUTION: string = "分辨率";
  static readonly DECODER: string = "解码器";
  static readonly FPS: string = "帧率";
  static readonly PACKET_LOSS: string = "丢包率";
  static readonly BITRATE: string = "带宽";
  static readonly NETWORK: string = "网络状态";
  static readonly DECODE: string = "解码延迟";
  static readonly HOST: string = "主机延迟";
  static readonly BATTERY: string = "电池";
}

export enum PerformanceItem {
  RESOLUTION = "resolution",
  DECODER = "decoder",
  RENDER_FPS = "render_fps",
  PACKET_LOSS = "packet_loss",
  BITRATE = "bitrate",
  NETWORK_LATENCY = "network_latency",
  DECODE_LATENCY = "decode_latency",
  HOST_LATENCY = "host_latency",
  BATTERY = "battery",
}

export enum SnapPosition {
  TOP_LEFT = "top_left",
  TOP_CENTER = "top_center",
  TOP_RIGHT = "top_right",
  CENTER_LEFT = "center_left",
  CENTER = "center",
  CENTER_RIGHT = "center_right",
  BOTTOM_LEFT = "bottom_left",
  BOTTOM_CENTER = "bottom_center",
  BOTTOM_RIGHT = "bottom_right",
}

export class PerformanceData {
  streamWidth: number = 0;
  streamHeight: number = 0;
  targetFps: number = 0;
  receivedFps: number = 0;
  renderedFps: number = 0;
  codec: string = "";
  isHdr: boolean = false;
  packetLoss: number = 0;
  bitrate: number = 0;
  decodeLatency: number = 0;
  networkLatency: number = 0;
  hostLatency: number = 0;
  batteryLevel: number = 100;
  isCharging: boolean = false;
}

@Observed
export class OverlayConfig {
  isVertical: boolean = true;
  isLocked: boolean = false;
  position: SnapPosition = SnapPosition.TOP_RIGHT;
  enabledItems: Set<string> = new Set<string>();
  bgOpacity: number = 0.53;
}

export class PerformanceItemInfo {
  title: string;
  description: string;

  constructor(title: string, description: string) {
    this.title = title;
    this.description = description;
  }
}

export class Position {
  x: number;
  y: number;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

export function getDefaultOverlayConfig(): OverlayConfig {
  const config = new OverlayConfig();
  config.isVertical = true;
  config.isLocked = false;
  config.position = SnapPosition.TOP_RIGHT;
  config.enabledItems = new Set<string>([
    PerformanceItem.RESOLUTION,
    PerformanceItem.DECODER,
    PerformanceItem.RENDER_FPS,
    PerformanceItem.PACKET_LOSS,
    PerformanceItem.BITRATE,
    PerformanceItem.NETWORK_LATENCY,
    PerformanceItem.DECODE_LATENCY,
    PerformanceItem.HOST_LATENCY,
  ]);
  return config;
}

export function getPerformanceItemInfo(item: PerformanceItem): PerformanceItemInfo {
  switch (item) {
    case PerformanceItem.RESOLUTION:
      return new PerformanceItemInfo(
        `${PerfIcons.RESOLUTION} 分辨率`,
        "显示当前串流的分辨率和帧率。客户端分辨率是从服务器接收的视频分辨率，这可能与主机端设置的分辨率不同。",
      );
    case PerformanceItem.DECODER:
      return new PerformanceItemInfo(
        `${PerfIcons.DECODER} 解码器`,
        "显示当前使用的视频编解码器。HEVC比AVC提供更好的压缩效率，在相同码率下能获得更好的画质。HDR表示正在使用高动态范围，能显示更丰富的色彩和对比度。",
      );
    case PerformanceItem.RENDER_FPS:
      return new PerformanceItemInfo(
        `📊 帧率`,
        "Rx为从服务器接收的帧率，Rd为实际渲染到屏幕的帧率。如果渲染帧率低于接收帧率，可能是解码或显示瓶颈。",
      );
    case PerformanceItem.PACKET_LOSS:
      return new PerformanceItemInfo(
        `${PerfIcons.PACKET_LOSS} 丢包率`,
        "显示网络传输过程中丢失的数据包百分比。低于1%是优秀，1-5%是可接受，高于5%可能导致画面卡顿或花屏。",
      );
    case PerformanceItem.BITRATE:
      return new PerformanceItemInfo(
        `${PerfIcons.BITRATE} 码率`,
        "当前视频流的下载带宽。带宽越高，画质越好，但也需要更快的网络连接。建议根据网络带宽调整码率设置。",
      );
    case PerformanceItem.NETWORK_LATENCY:
      return new PerformanceItemInfo(
        `${PerfIcons.NETWORK} 网络延迟`,
        "网络往返延迟(RTT)，即数据包从客户端到服务器再返回的时间。低于20ms是优秀，20-50ms是良好，高于100ms可能感受到明显延迟。",
      );
    case PerformanceItem.DECODE_LATENCY:
      return new PerformanceItemInfo(
        `${PerfIcons.DECODE_NORMAL} 解码延迟`,
        "视频帧解码所需的时间。低于10ms是优秀，10-20ms是正常，高于20ms可能需要降低分辨率或使用硬件解码器。",
      );
    case PerformanceItem.HOST_LATENCY:
      return new PerformanceItemInfo(
        `${PerfIcons.HOST} 主机延迟`,
        "服务器端渲染和编码游戏画面所需的时间。这取决于服务器的硬件性能和当前运行的游戏。较新的显卡通常有更低的编码延迟。",
      );
    case PerformanceItem.BATTERY:
      return new PerformanceItemInfo(
        `${PerfIcons.BATTERY} 电池`,
        "显示当前设备的电池电量。串流游戏会消耗较多电量，建议在电量充足时或连接充电器时进行长时间串流。",
      );
    default:
      return new PerformanceItemInfo("未知", "");
  }
}

export function isClockTime(): boolean {
  return new Date().getMinutes() % 15 === 0;
}

export function getMoonPhaseIcon(locked: boolean = false): string {
  if (locked) {
    return "📌";
  }

  const date = new Date();
  const lp = 2551443;
  const newMoon = new Date(1970, 0, 7, 20, 35, 0);
  const phase = ((date.getTime() - newMoon.getTime()) / 1000) % lp;
  const phaseIndex = Math.floor(phase / (lp / 8));

  const icons = ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"];
  return icons[phaseIndex] || "🌙";
}

export function formatDataRate(bps: number): string {
  const bytesPerSec = bps / 8;

  if (bytesPerSec >= 1024 * 1024) {
    return `${(bytesPerSec / (1024 * 1024)).toFixed(1)} MB/s`;
  } else if (bytesPerSec >= 1024) {
    return `${(bytesPerSec / 1024).toFixed(0)} KB/s`;
  }
  return `${bytesPerSec.toFixed(0)} B/s`;
}

export function getDecoderString(codec: string, isHdr: boolean): string {
  let result = codec.toUpperCase();
  if (result.includes("HEVC") || result.includes("H265")) {
    result = "HEVC";
  } else if (result.includes("AVC") || result.includes("H264")) {
    result = "AVC";
  } else if (result.includes("AV1")) {
    result = "AV1";
  }
  if (isHdr) {
    result += " HDR";
  }
  return result;
}

export function getPacketLossColor(loss: number): string {
  if (loss < 1.0) return "#7D9D7D";
  if (loss < 5.0) return "#D4A574";
  return "#B57D7D";
}

export function getLatencyColor(ms: number): string {
  if (ms < 10) return "#7D9D7D";
  if (ms < 20) return "#D597E3";
  return "#B57D7D";
}

export function getBatteryColor(level: number): string {
  if (level > 50) return "#90EE90";
  if (level > 20) return "#FFA500";
  return "#FF6B6B";
}

export function calculateSnapPosition(
  position: SnapPosition,
  screenWidth: number,
  screenHeight: number,
  overlayWidth: number,
  overlayHeight: number,
): Position {
  let x: number;
  let y: number;

  switch (position) {
    case SnapPosition.TOP_LEFT:
      x = 0;
      y = 0;
      break;
    case SnapPosition.TOP_CENTER:
      x = (screenWidth - overlayWidth) / 2;
      y = 0;
      break;
    case SnapPosition.TOP_RIGHT:
      x = screenWidth - overlayWidth;
      y = 0;
      break;
    case SnapPosition.CENTER_LEFT:
      x = 0;
      y = (screenHeight - overlayHeight) / 2;
      break;
    case SnapPosition.CENTER:
      x = (screenWidth - overlayWidth) / 2;
      y = (screenHeight - overlayHeight) / 2;
      break;
    case SnapPosition.CENTER_RIGHT:
      x = screenWidth - overlayWidth;
      y = (screenHeight - overlayHeight) / 2;
      break;
    case SnapPosition.BOTTOM_LEFT:
      x = 0;
      y = screenHeight - overlayHeight;
      break;
    case SnapPosition.BOTTOM_CENTER:
      x = (screenWidth - overlayWidth) / 2;
      y = screenHeight - overlayHeight;
      break;
    case SnapPosition.BOTTOM_RIGHT:
      x = screenWidth - overlayWidth;
      y = screenHeight - overlayHeight;
      break;
    default:
      x = 0;
      y = 0;
  }

  return new Position(x, y);
}

export function getSnapBorderRadius(position: SnapPosition, radius: number = 12): BorderRadiuses {
  switch (position) {
    case SnapPosition.TOP_LEFT:
      return { topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: radius };
    case SnapPosition.TOP_CENTER:
      return { topLeft: 0, topRight: 0, bottomLeft: radius, bottomRight: radius };
    case SnapPosition.TOP_RIGHT:
      return { topLeft: 0, topRight: 0, bottomLeft: radius, bottomRight: 0 };
    case SnapPosition.CENTER_LEFT:
      return { topLeft: 0, topRight: radius, bottomLeft: 0, bottomRight: radius };
    case SnapPosition.CENTER:
      return { topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius };
    case SnapPosition.CENTER_RIGHT:
      return { topLeft: radius, topRight: 0, bottomLeft: radius, bottomRight: 0 };
    case SnapPosition.BOTTOM_LEFT:
      return { topLeft: 0, topRight: radius, bottomLeft: 0, bottomRight: 0 };
    case SnapPosition.BOTTOM_CENTER:
      return { topLeft: radius, topRight: radius, bottomLeft: 0, bottomRight: 0 };
    case SnapPosition.BOTTOM_RIGHT:
      return { topLeft: radius, topRight: 0, bottomLeft: 0, bottomRight: 0 };
    default:
      return { topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius };
  }
}

const ALL_SNAP_POSITIONS: SnapPosition[] = [
  SnapPosition.TOP_LEFT,
  SnapPosition.TOP_CENTER,
  SnapPosition.TOP_RIGHT,
  SnapPosition.CENTER_LEFT,
  SnapPosition.CENTER,
  SnapPosition.CENTER_RIGHT,
  SnapPosition.BOTTOM_LEFT,
  SnapPosition.BOTTOM_CENTER,
  SnapPosition.BOTTOM_RIGHT,
];

export function findNearestSnapPosition(
  currentX: number,
  currentY: number,
  screenWidth: number,
  screenHeight: number,
  overlayWidth: number,
  overlayHeight: number,
): SnapPosition {
  let nearestPosition = SnapPosition.TOP_LEFT;
  let minDistance = Infinity;

  for (let i = 0; i < ALL_SNAP_POSITIONS.length; i++) {
    const pos = ALL_SNAP_POSITIONS[i];
    const snapPos = calculateSnapPosition(
      pos,
      screenWidth,
      screenHeight,
      overlayWidth,
      overlayHeight,
    );
    const distance = Math.sqrt(
      Math.pow(currentX - snapPos.x, 2) + Math.pow(currentY - snapPos.y, 2),
    );

    if (distance < minDistance) {
      minDistance = distance;
      nearestPosition = pos;
    }
  }

  return nearestPosition;
}
