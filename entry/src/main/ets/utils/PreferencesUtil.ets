/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { preferences } from "@kit.ArkData";
import { Context } from "@kit.AbilityKit";

export class PreferencesUtil {
  private static readonly PREFERENCES_NAME = "moonlight_settings";
  private static preferencesInstance: preferences.Preferences | null = null;
  private static contextRef: Context | null = null;

  static init(context: Context): void {
    PreferencesUtil.contextRef = context;
  }

  static async getPreferences(context?: Context): Promise<preferences.Preferences> {
    const ctx = context || PreferencesUtil.contextRef;
    if (!ctx) {
      throw new Error("PreferencesUtil: context not initialized");
    }
    if (!PreferencesUtil.preferencesInstance) {
      try {
        PreferencesUtil.preferencesInstance = await preferences.getPreferences(
          ctx,
          PreferencesUtil.PREFERENCES_NAME,
        );
      } catch (e) {
        throw new Error(`PreferencesUtil: failed to get preferences - ${e}`);
      }
    }
    return PreferencesUtil.preferencesInstance;
  }

  static async get<T>(key: string, defaultValue: T): Promise<T> {
    const prefs = await PreferencesUtil.getPreferences();
    const value = await prefs.get(key, defaultValue as preferences.ValueType);

    if (typeof defaultValue === "number" && typeof value === "string") {
      const parsed = Number(value);
      if (!isNaN(parsed)) {
        return parsed as T;
      }
    }

    return value as T;
  }

  static async put(key: string, value: preferences.ValueType): Promise<void> {
    const prefs = await PreferencesUtil.getPreferences();
    await prefs.put(key, value);
    await prefs.flush();
  }

  static async getString(
    context: Context,
    key: string,
    defaultValue: string = "",
  ): Promise<string> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return (await prefs.get(key, defaultValue)) as string;
  }

  static async setString(context: Context, key: string, value: string): Promise<void> {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(key, value);
    await prefs.flush();
  }

  static async getNumber(context: Context, key: string, defaultValue: number = 0): Promise<number> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return (await prefs.get(key, defaultValue)) as number;
  }

  static async setNumber(context: Context, key: string, value: number): Promise<void> {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(key, value);
    await prefs.flush();
  }

  static async getBoolean(
    context: Context,
    key: string,
    defaultValue: boolean = false,
  ): Promise<boolean> {
    const prefs = await PreferencesUtil.getPreferences(context);
    return (await prefs.get(key, defaultValue)) as boolean;
  }

  static async setBoolean(context: Context, key: string, value: boolean): Promise<void> {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.put(key, value);
    await prefs.flush();
  }

  static async remove(context: Context, key: string): Promise<void> {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.delete(key);
    await prefs.flush();
  }

  static async clear(context: Context): Promise<void> {
    const prefs = await PreferencesUtil.getPreferences(context);
    await prefs.clear();
    await prefs.flush();
  }
}
