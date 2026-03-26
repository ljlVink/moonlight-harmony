/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { util } from '@kit.ArkTS';
import { CryptoUtil } from './CryptoUtil';

/**
 * 
 */
export class StringUtil {
  private static textDecoder: util.TextDecoder | null = null;
  private static textEncoder: util.TextEncoder | null = null;

  private static getTextDecoder(): util.TextDecoder {
    if (!StringUtil.textDecoder) {
      StringUtil.textDecoder = util.TextDecoder.create('utf-8');
    }
    return StringUtil.textDecoder;
  }

  private static getTextEncoder(): util.TextEncoder {
    if (!StringUtil.textEncoder) {
      StringUtil.textEncoder = new util.TextEncoder();
    }
    return StringUtil.textEncoder;
  }

  /**
   * @param buffer ArrayBuffer
   */
  static arrayBufferToString(buffer: ArrayBuffer): string {
    return StringUtil.getTextDecoder().decodeToString(new Uint8Array(buffer));
  }

  /**
   * @param array Uint8Array
   */
  static uint8ArrayToString(array: Uint8Array): string {
    return StringUtil.getTextDecoder().decodeToString(array);
  }

  static stringToUint8Array(str: string): Uint8Array {
    return StringUtil.getTextEncoder().encodeInto(str);
  }

  static generateUUID(): string {
    const randomBytes = CryptoUtil.generateRandomBytes(16);
    
    randomBytes[6] = (randomBytes[6] & 0x0f) | 0x40;  // version 4
    randomBytes[8] = (randomBytes[8] & 0x3f) | 0x80;  // variant 1
    
    const hex = CryptoUtil.bytesToHex(randomBytes).toLowerCase();
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
  }
}
