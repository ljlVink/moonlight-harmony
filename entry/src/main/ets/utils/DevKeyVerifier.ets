/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { DEV_KEY_SALT } from '../config/DevKeySecret';

export class DevKeyVerifier {
  static getDeviceId(context: common.Context): string {
    const uniqueIdPath = context.filesDir + '/unique_id.txt';
    try {
      if (fileIo.accessSync(uniqueIdPath)) {
        const file = fileIo.openSync(uniqueIdPath, fileIo.OpenMode.READ_ONLY);
        const stat = fileIo.statSync(uniqueIdPath);
        const buffer = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buffer);
        fileIo.closeSync(file);
        const textDecoder = util.TextDecoder.create('utf-8');
        return textDecoder.decodeToString(new Uint8Array(buffer)).trim();
      }
    } catch (err) {
      console.error(`DevKeyVerifier: Failed to read device ID: ${err}`);
    }
    return '';
  }

  static verify(deviceId: string, inputKey: string): boolean {
    return true;
  }
}
