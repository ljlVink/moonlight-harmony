/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { PreferencesUtil } from "../utils/PreferencesUtil";
import { display } from "@kit.ArkUI";
import {
  cloneKeyDef,
  createDefaultProfile,
  CustomKeyDef,
  CustomKeyProfile,
  generateKeyId,
} from "./CustomKeyTypes";

interface ExportData {
  version: number;
  profile: CustomKeyProfile;
}

const STORAGE_KEY_PROFILES = "custom_key_profiles";
const STORAGE_KEY_ACTIVE = "custom_key_active_profile";
const STORAGE_KEY_GAME_PROFILES = "custom_key_game_profiles";

export class CustomKeyStore {
  private static profiles: CustomKeyProfile[] | null = null;
  private static activeProfileName: string = "";
  private static gameProfiles: Record<string, string> | null = null;

  static async init(): Promise<void> {
    try {
      const json = await PreferencesUtil.get<string>(STORAGE_KEY_PROFILES, "");
      if (json) {
        CustomKeyStore.profiles = JSON.parse(json) as CustomKeyProfile[];
      } else {
        CustomKeyStore.profiles = [];
      }
      CustomKeyStore.activeProfileName = await PreferencesUtil.get<string>(STORAGE_KEY_ACTIVE, "");

      if (CustomKeyStore.profiles.length === 0) {
        const defaultProfile = createDefaultProfile("默认");
        CustomKeyStore.profiles.push(defaultProfile);
        CustomKeyStore.activeProfileName = defaultProfile.name;
        await CustomKeyStore.save();
      }

      if (!CustomKeyStore.profiles.find((p) => p.name === CustomKeyStore.activeProfileName)) {
        CustomKeyStore.activeProfileName = CustomKeyStore.profiles[0].name;
        await PreferencesUtil.put(STORAGE_KEY_ACTIVE, CustomKeyStore.activeProfileName);
      }

      if (CustomKeyStore.migrateAbsoluteToPercent()) {
        await CustomKeyStore.save();
        console.info("[CustomKeyStore] 坐标迁移完成: absolute vp → percent");
      }

      const gameJson = await PreferencesUtil.get<string>(STORAGE_KEY_GAME_PROFILES, "");
      if (gameJson) {
        CustomKeyStore.gameProfiles = JSON.parse(gameJson) as Record<string, string>;
      } else {
        CustomKeyStore.gameProfiles = {};
      }
    } catch (e) {
      console.error("[CustomKeyStore] init failed:", JSON.stringify(e));
      CustomKeyStore.profiles = [createDefaultProfile("默认")];
      CustomKeyStore.activeProfileName = "默认";
    }
  }

  private static async ensureInit(): Promise<void> {
    if (CustomKeyStore.profiles === null) {
      await CustomKeyStore.init();
    }
  }

  private static async save(): Promise<void> {
    const json = JSON.stringify(CustomKeyStore.profiles);
    await PreferencesUtil.put(STORAGE_KEY_PROFILES, json);
    await PreferencesUtil.put(STORAGE_KEY_ACTIVE, CustomKeyStore.activeProfileName);
  }

  private static migrateAbsoluteToPercent(): boolean {
    if (!CustomKeyStore.profiles) return false;

    const displayInfo = display.getDefaultDisplaySync();
    const screenWVp = px2vp(displayInfo.width);
    const screenHVp = px2vp(displayInfo.height);
    if (screenWVp <= 0 || screenHVp <= 0) return false;

    let migrated = false;
    for (const profile of CustomKeyStore.profiles) {
      if (CustomKeyStore.migrateProfileKeys(profile)) {
        migrated = true;
      }
    }
    return migrated;
  }

  private static migrateProfileKeys(profile: CustomKeyProfile): boolean {
    const displayInfo = display.getDefaultDisplaySync();
    const screenWVp = px2vp(displayInfo.width);
    const screenHVp = px2vp(displayInfo.height);
    if (screenWVp <= 0 || screenHVp <= 0) return false;

    let migrated = false;
    for (const key of profile.keys) {
      const oldX = key.x;
      const oldY = key.y;
      if (oldX !== undefined && oldX > 1 && (key.xPercent === undefined || key.xPercent === 0)) {
        key.xPercent = Math.max(0, Math.min(1, oldX / screenWVp));
        key.yPercent = Math.max(0, Math.min(1, (oldY ?? 0) / screenHVp));
        key.x = undefined;
        key.y = undefined;
        migrated = true;
      }
    }
    return migrated;
  }

  static async getProfileNames(): Promise<string[]> {
    await CustomKeyStore.ensureInit();
    return CustomKeyStore.profiles!.map((p) => p.name);
  }

  static async getActiveProfileName(): Promise<string> {
    await CustomKeyStore.ensureInit();
    return CustomKeyStore.activeProfileName;
  }

  static async getActiveProfile(): Promise<CustomKeyProfile> {
    await CustomKeyStore.ensureInit();
    const profile = CustomKeyStore.profiles!.find(
      (p) => p.name === CustomKeyStore.activeProfileName,
    );
    return profile ?? CustomKeyStore.profiles![0];
  }

  static async switchProfile(name: string): Promise<CustomKeyProfile | null> {
    await CustomKeyStore.ensureInit();
    const profile = CustomKeyStore.profiles!.find((p) => p.name === name);
    if (!profile) return null;
    CustomKeyStore.activeProfileName = name;
    await PreferencesUtil.put(STORAGE_KEY_ACTIVE, name);
    return profile;
  }

  static async cycleNextProfile(): Promise<CustomKeyProfile | null> {
    await CustomKeyStore.ensureInit();
    if (CustomKeyStore.profiles!.length <= 1) return null;
    const currentIdx = CustomKeyStore.profiles!.findIndex(
      (p) => p.name === CustomKeyStore.activeProfileName,
    );
    const nextIdx = (currentIdx + 1) % CustomKeyStore.profiles!.length;
    const next = CustomKeyStore.profiles![nextIdx];
    CustomKeyStore.activeProfileName = next.name;
    await PreferencesUtil.put(STORAGE_KEY_ACTIVE, next.name);
    return next;
  }

  static async createProfile(name: string): Promise<CustomKeyProfile | null> {
    await CustomKeyStore.ensureInit();
    if (CustomKeyStore.profiles!.find((p) => p.name === name)) {
      return null;
    }
    const profile = createDefaultProfile(name);
    CustomKeyStore.profiles!.push(profile);
    CustomKeyStore.activeProfileName = name;
    await CustomKeyStore.save();
    return profile;
  }

  static async deleteProfile(name: string): Promise<boolean> {
    await CustomKeyStore.ensureInit();
    if (CustomKeyStore.profiles!.length <= 1) return false;
    const idx = CustomKeyStore.profiles!.findIndex((p) => p.name === name);
    if (idx === -1) return false;
    CustomKeyStore.profiles!.splice(idx, 1);
    if (CustomKeyStore.activeProfileName === name) {
      CustomKeyStore.activeProfileName = CustomKeyStore.profiles![0].name;
    }
    await CustomKeyStore.save();
    return true;
  }

  static async renameProfile(oldName: string, newName: string): Promise<boolean> {
    await CustomKeyStore.ensureInit();
    if (CustomKeyStore.profiles!.find((p) => p.name === newName)) return false;
    const profile = CustomKeyStore.profiles!.find((p) => p.name === oldName);
    if (!profile) return false;
    profile.name = newName;
    if (CustomKeyStore.activeProfileName === oldName) {
      CustomKeyStore.activeProfileName = newName;
    }
    await CustomKeyStore.save();
    return true;
  }

  static async duplicateProfile(newName: string): Promise<CustomKeyProfile | null> {
    await CustomKeyStore.ensureInit();
    if (CustomKeyStore.profiles!.find((p) => p.name === newName)) {
      return null;
    }
    const source = await CustomKeyStore.getActiveProfile();
    const cloned: CustomKeyProfile = {
      name: newName,
      keys: source.keys.map((k) => {
        const copy = cloneKeyDef(k);
        copy.id = generateKeyId();
        return copy;
      }),
    };
    CustomKeyStore.profiles!.push(cloned);
    CustomKeyStore.activeProfileName = newName;
    await CustomKeyStore.save();
    return cloned;
  }

  static async getKeys(): Promise<CustomKeyDef[]> {
    const profile = await CustomKeyStore.getActiveProfile();
    return profile.keys;
  }

  static async addKey(key: CustomKeyDef): Promise<void> {
    const profile = await CustomKeyStore.getActiveProfile();
    profile.keys.push(key);
    await CustomKeyStore.save();
  }

  static async updateKey(key: CustomKeyDef): Promise<void> {
    const profile = await CustomKeyStore.getActiveProfile();
    const idx = profile.keys.findIndex((k) => k.id === key.id);
    if (idx !== -1) {
      profile.keys[idx] = key;
      await CustomKeyStore.save();
    }
  }

  static async deleteKey(keyId: string): Promise<void> {
    const profile = await CustomKeyStore.getActiveProfile();
    const idx = profile.keys.findIndex((k) => k.id === keyId);
    if (idx !== -1) {
      profile.keys.splice(idx, 1);
      await CustomKeyStore.save();
    }
  }

  static async saveKeys(keys: CustomKeyDef[]): Promise<void> {
    const profile = await CustomKeyStore.getActiveProfile();
    profile.keys = keys;
    await CustomKeyStore.save();
  }

  static async exportProfile(): Promise<string> {
    const profile = await CustomKeyStore.getActiveProfile();
    const exportData: ExportData = {
      version: 1,
      profile: profile,
    };
    return JSON.stringify(exportData);
  }

  static async importProfile(json: string): Promise<boolean> {
    try {
      const data = JSON.parse(json) as ExportData;
      if (!data.profile || !data.profile.name || !Array.isArray(data.profile.keys)) {
        return false;
      }
      await CustomKeyStore.ensureInit();
      let name = data.profile.name;
      let suffix = 1;
      while (CustomKeyStore.profiles!.find((p) => p.name === name)) {
        name = `${data.profile.name} (${suffix++})`;
      }
      data.profile.name = name;
      CustomKeyStore.migrateProfileKeys(data.profile);
      CustomKeyStore.profiles!.push(data.profile);
      CustomKeyStore.activeProfileName = name;
      await CustomKeyStore.save();
      return true;
    } catch (e) {
      console.error("[CustomKeyStore] import failed:", JSON.stringify(e));
      return false;
    }
  }

  static async mergeImportKeys(json: string): Promise<number> {
    try {
      const data = JSON.parse(json) as ExportData;
      if (!data.profile || !Array.isArray(data.profile.keys) || data.profile.keys.length === 0) {
        return -1;
      }
      CustomKeyStore.migrateProfileKeys(data.profile);
      const profile = await CustomKeyStore.getActiveProfile();
      let count = 0;
      for (const key of data.profile.keys) {
        key.id = generateKeyId();
        key.xPercent = Math.max(0, Math.min(1, (key.xPercent ?? 0.5) + 0.02));
        key.yPercent = Math.max(0, Math.min(1, (key.yPercent ?? 0.5) + 0.02));
        profile.keys.push(key);
        count++;
      }
      await CustomKeyStore.save();
      return count;
    } catch (e) {
      console.error("[CustomKeyStore] merge import failed:", JSON.stringify(e));
      return -1;
    }
  }

  static async getGameProfileName(appId: number): Promise<string | null> {
    await CustomKeyStore.ensureInit();
    const name = CustomKeyStore.gameProfiles?.[String(appId)];
    if (!name) return null;
    if (!CustomKeyStore.profiles!.find((p) => p.name === name)) {
      CustomKeyStore.gameProfiles![String(appId)] = "";
      await PreferencesUtil.put(
        STORAGE_KEY_GAME_PROFILES,
        JSON.stringify(CustomKeyStore.gameProfiles),
      );
      return null;
    }
    return name;
  }

  static async setGameProfile(appId: number, profileName: string): Promise<void> {
    await CustomKeyStore.ensureInit();
    if (!CustomKeyStore.gameProfiles) {
      CustomKeyStore.gameProfiles = {};
    }
    CustomKeyStore.gameProfiles[String(appId)] = profileName;
    await PreferencesUtil.put(
      STORAGE_KEY_GAME_PROFILES,
      JSON.stringify(CustomKeyStore.gameProfiles),
    );
  }

  static async loadGameProfile(appId: number): Promise<CustomKeyProfile | null> {
    const name = await CustomKeyStore.getGameProfileName(appId);
    if (!name) return null;
    if (name === CustomKeyStore.activeProfileName) return null;
    return CustomKeyStore.switchProfile(name);
  }
}
