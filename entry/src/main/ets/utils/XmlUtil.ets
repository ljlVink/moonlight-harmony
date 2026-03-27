/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

export class XmlUtil {
  static getValue(xml: string, tag: string, required: boolean = false): string {
    const regex = new RegExp(`<${tag}>(.*?)</${tag}>`, "s");
    const match = xml.match(regex);
    const value = match ? match[1].trim() : "";

    if (required && !value) {
      throw new Error(`XML 中未找到必需的标签: ${tag}`);
    }

    return value;
  }

  static getValues(xml: string, tag: string): string[] {
    const regex = new RegExp(`<${tag}>(.*?)</${tag}>`, "gs");
    const matches: string[] = [];
    let match: RegExpExecArray | null;

    while ((match = regex.exec(xml)) !== null) {
      matches.push(match[1].trim());
    }

    return matches;
  }

  static getIntValue(xml: string, tag: string, defaultValue: number = 0): number {
    const value = XmlUtil.getValue(xml, tag);
    const parsed = parseInt(value);
    return isNaN(parsed) ? defaultValue : parsed;
  }

  static getBoolValue(xml: string, tag: string): boolean {
    const value = XmlUtil.getValue(xml, tag).toLowerCase();
    return value === "1" || value === "true";
  }

  static hasTag(xml: string, tag: string): boolean {
    const regex = new RegExp(`<${tag}>.*?</${tag}>`, "s");
    return regex.test(xml);
  }
}
