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
 *
 * https://libusb.sourceforge.io/api-1.0/group__libusb__misc.html
 */

export interface ErrorAnalysisResult {
  likelySleepMode: boolean;
  likelyDisconnected: boolean;
  confidence: number;
}

export class UsbError extends Error {
  code: number;
  retryable: boolean;

  constructor(message: string, code: number, retryable: boolean) {
    super(message);
    this.code = code;
    this.retryable = retryable;
  }
}

export const USB_SUCCESS = 0;
export const USB_ERROR_IO = -1;
export const USB_ERROR_INVALID_PARAM = -2;
export const USB_ERROR_ACCESS = -3;
export const USB_ERROR_NO_DEVICE = -4;
export const USB_ERROR_NOT_FOUND = -5;
export const USB_ERROR_BUSY = -6;
export const USB_ERROR_TIMEOUT = -8;
export const USB_ERROR_PIPE = -9;
export const USB_ERROR_INTERRUPTED = -10;
export const USB_ERROR_NO_MEM = -11;
export const USB_ERROR_NOT_SUPPORTED = -12;
export const USB_ERROR_OTHER = -99;

/**
 *
 *
 */
export function isSleepModeError(errorCode: number): boolean {
  return errorCode === USB_ERROR_NO_DEVICE || errorCode === USB_ERROR_TIMEOUT;
}

/**
 *
 *
 */
export function isHardwareError(errorCode: number): boolean {
  return (
    errorCode === USB_ERROR_PIPE || errorCode === USB_ERROR_IO || errorCode === USB_ERROR_ACCESS
  );
}

export function shouldRetry(errorCode: number): boolean {
  return isSleepModeError(errorCode);
}

export function analyzeErrorPattern(errorHistory: number[]): ErrorAnalysisResult {
  if (errorHistory.length === 0) {
    const result: ErrorAnalysisResult = {
      likelySleepMode: false,
      likelyDisconnected: false,
      confidence: 0,
    };
    return result;
  }

  const lastError = errorHistory[0];

  if (lastError === USB_ERROR_PIPE) {
    const result: ErrorAnalysisResult = {
      likelySleepMode: false,
      likelyDisconnected: true,
      confidence: 0.95,
    };
    return result;
  }

  if (lastError === USB_ERROR_IO) {
    const result: ErrorAnalysisResult = {
      likelySleepMode: false,
      likelyDisconnected: true,
      confidence: 0.85,
    };
    return result;
  }

  if (lastError === USB_ERROR_TIMEOUT) {
    let allTimeouts = true;
    for (let i = 0; i < errorHistory.length; i++) {
      if (errorHistory[i] !== USB_ERROR_TIMEOUT) {
        allTimeouts = false;
        break;
      }
    }
    if (allTimeouts) {
      const result: ErrorAnalysisResult = {
        likelySleepMode: true,
        likelyDisconnected: false,
        confidence: 0.8,
      };
      return result;
    }
  }

  if (lastError === USB_ERROR_NO_DEVICE) {
    let hadTimeout = false;
    for (let i = 0; i < errorHistory.length; i++) {
      if (errorHistory[i] === USB_ERROR_TIMEOUT) {
        hadTimeout = true;
        break;
      }
    }
    if (hadTimeout) {
      const result: ErrorAnalysisResult = {
        likelySleepMode: true,
        likelyDisconnected: false,
        confidence: 0.75,
      };
      return result;
    }
    const result: ErrorAnalysisResult = {
      likelySleepMode: false,
      likelyDisconnected: true,
      confidence: 0.6,
    };
    return result;
  }

  const result: ErrorAnalysisResult = {
    likelySleepMode: false,
    likelyDisconnected: false,
    confidence: 0.5,
  };
  return result;
}

export function getErrorDescription(errorCode: number): string {
  switch (errorCode) {
    case USB_SUCCESS:
      return "成功";
    case USB_ERROR_IO:
      return "I/O 错误 - 可能是真实的 USB 硬件问题";
    case USB_ERROR_INVALID_PARAM:
      return "无效参数";
    case USB_ERROR_ACCESS:
      return "访问拒绝 - 可能需要权限";
    case USB_ERROR_NO_DEVICE:
      return "设备不存在 - 设备已拔出或进入省电模式";
    case USB_ERROR_NOT_FOUND:
      return "未找到";
    case USB_ERROR_BUSY:
      return "资源繁忙";
    case USB_ERROR_TIMEOUT:
      return "超时 - 设备可能进入省电模式";
    case USB_ERROR_PIPE:
      return "管道错误 - 真实的 USB 通信错误";
    case USB_ERROR_INTERRUPTED:
      return "中断";
    case USB_ERROR_NO_MEM:
      return "没有内存";
    case USB_ERROR_NOT_SUPPORTED:
      return "不支持的操作";
    default:
      return `未知错误 (${errorCode})`;
  }
}

export function createUsbError(errorCode: number): UsbError {
  const desc = getErrorDescription(errorCode);

  if (isSleepModeError(errorCode)) {
    return new UsbError(`${desc} [可重试]`, errorCode, true);
  } else if (isHardwareError(errorCode)) {
    return new UsbError(`${desc} [硬件错误]`, errorCode, false);
  } else {
    return new UsbError(`USB 读取失败: ${desc}`, errorCode, true);
  }
}
