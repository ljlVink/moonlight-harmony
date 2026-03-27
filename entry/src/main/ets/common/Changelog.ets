/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { common } from "@kit.AbilityKit";
import { util } from "@kit.ArkTS";

export interface ChangeItem {
  type: "added" | "improved" | "fixed" | "removed";
  text: string;
}

export interface ChangelogEntry {
  version: string;
  date: string;
  summary?: string;
  changes: ChangeItem[];
}

export interface ChangeTypeConfig {
  label: string;
  color: string;
}

export function getChangeTypeConfig(type: string): ChangeTypeConfig {
  switch (type) {
    case "added":
      return { label: "Added", color: "#34C759" } as ChangeTypeConfig;
    case "improved":
      return { label: "Improved", color: "#007AFF" } as ChangeTypeConfig;
    case "fixed":
      return { label: "Fixed", color: "#FF9500" } as ChangeTypeConfig;
    case "removed":
      return { label: "Removed", color: "#FF3B30" } as ChangeTypeConfig;
    default:
      return { label: "Other", color: "#8E8E93" } as ChangeTypeConfig;
  }
}

const TYPE_MAP = new Map<string, string>([
  ["新增", "added"],
  ["优化", "improved"],
  ["改进", "improved"],
  ["修复", "fixed"],
  ["移除", "removed"],
  ["删除", "removed"],
]);

export function parseChangelog(markdown: string): ChangelogEntry[] {
  const entries: ChangelogEntry[] = [];
  const lines = markdown.split("\n");

  let currentEntry: ChangelogEntry | null = null;
  let currentType: string = "added";
  let summaryLines: string[] = [];
  let collectingSummary = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith("## [")) {
      if (currentEntry !== null && summaryLines.length > 0) {
        currentEntry.summary = summaryLines.join(" ").trim();
      }

      const bracketEnd = line.indexOf("]");
      const dashIdx = line.indexOf(" - ", bracketEnd);
      if (bracketEnd > 4 && dashIdx > bracketEnd) {
        const version = line.substring(4, bracketEnd);
        const date = line.substring(dashIdx + 3).trim();
        currentEntry = {
          version: version,
          date: date,
          summary: undefined,
          changes: [],
        } as ChangelogEntry;
        entries.push(currentEntry);
        summaryLines = [];
        collectingSummary = true;
        currentType = "added";
      }
      continue;
    }

    if (line.startsWith("### ") && currentEntry !== null) {
      if (collectingSummary && summaryLines.length > 0) {
        currentEntry.summary = summaryLines.join(" ").trim();
        summaryLines = [];
      }
      collectingSummary = false;

      const typeName = line.substring(4).trim();
      const mapped = TYPE_MAP.get(typeName);
      if (mapped !== undefined) {
        currentType = mapped;
      }
      continue;
    }
    if (line.startsWith("- ") && currentEntry !== null) {
      collectingSummary = false;
      const text = line.substring(2).trim();
      if (text.length > 0) {
        currentEntry.changes.push({ type: currentType, text: text } as ChangeItem);
      }
      continue;
    }
    if (collectingSummary && currentEntry !== null) {
      const trimmed = line.trim();
      if (trimmed.length > 0 && !trimmed.startsWith("<!--") && !trimmed.startsWith("-->")) {
        summaryLines.push(trimmed);
      }
    }
  }
  if (currentEntry !== null && summaryLines.length > 0) {
    currentEntry.summary = summaryLines.join(" ").trim();
  }

  return entries;
}

export async function loadChangelog(context: common.Context): Promise<ChangelogEntry[]> {
  try {
    const resourceManager = context.resourceManager;
    const rawData: Uint8Array = resourceManager.getRawFileContentSync("CHANGELOG.md");
    const decoder = util.TextDecoder.create("utf-8");
    const markdown = decoder.decodeToString(rawData);
    return parseChangelog(markdown);
  } catch (err) {
    console.error("Failed to load changelog:", err);
    return [];
  }
}
