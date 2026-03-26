/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */


import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { getVkDisplayName, VirtualKey, VK_DISPLAY_NAMES } from '../service/CustomKeyTypes';

export interface Shortcut {
  id: string;
  name: string;
  keys: number[];
  keySequence?: number[][];
  icon?: string;
  color?: string;
  isBuiltin?: boolean;
}

export interface KeyOption {
  code: number;
  name: string;
  shortName: string;
}

export class ShortcutManager {
  private static instance: ShortcutManager;
  private shortcuts: Shortcut[] = [];
  private context: common.UIAbilityContext | null = null;
  private prefs: preferences.Preferences | null = null;
  private initialized: boolean = false;
  
  private static readonly PREFS_NAME = 'shortcut_config';
  private static readonly KEY_SHORTCUTS = 'user_shortcuts';
  private static readonly KEY_DELETED_BUILTINS = 'deleted_builtins';
  private deletedBuiltinIds: string[] = [];
  
  static getInstance(): ShortcutManager {
    if (!ShortcutManager.instance) {
      ShortcutManager.instance = new ShortcutManager();
    }
    return ShortcutManager.instance;
  }
  
  async initialize(context: common.UIAbilityContext): Promise<void> {
    if (this.initialized) return;
    
    this.context = context;
    try {
      this.prefs = await preferences.getPreferences(context, ShortcutManager.PREFS_NAME);
      await this.loadShortcuts();
      this.initialized = true;
    } catch (error) {
      console.error('ShortcutManager', `初始化失败: ${error}`);
      this.shortcuts = this.getDefaultShortcuts();
      this.initialized = true;
    }
  }
  
  getShortcuts(): Shortcut[] {
    return [...this.shortcuts];
  }
  
  getUserShortcuts(): Shortcut[] {
    return this.shortcuts.filter(s => !s.isBuiltin);
  }
  
  getBuiltinShortcuts(): Shortcut[] {
    return this.shortcuts.filter(s => s.isBuiltin);
  }
  
  async addShortcut(name: string, keys: number[], icon?: string, color?: string, keySequence?: number[][]): Promise<Shortcut> {
    const newShortcut: Shortcut = {
      id: `user_${Date.now()}`,
      name: name,
      keys: keys,
      keySequence: keySequence,
      icon: icon,
      color: color,
      isBuiltin: false
    };
    
    this.shortcuts.push(newShortcut);
    await this.saveShortcuts();
    return newShortcut;
  }
  
  async updateShortcut(id: string, name?: string, keys?: number[], icon?: string, color?: string, keySequence?: number[][]): Promise<boolean> {
    const index = this.shortcuts.findIndex(s => s.id === id);
    if (index === -1) return false;
    
    const current = this.shortcuts[index];
    this.shortcuts[index] = {
      id: current.id,
      name: name !== undefined ? name : current.name,
      keys: keys !== undefined ? keys : current.keys,
      keySequence: keySequence !== undefined ? keySequence : current.keySequence,
      icon: icon !== undefined ? icon : current.icon,
      color: color !== undefined ? color : current.color,
      isBuiltin: current.isBuiltin
    };
    await this.saveShortcuts();
    return true;
  }
  
  async deleteShortcut(id: string): Promise<boolean> {
    const index = this.shortcuts.findIndex(s => s.id === id);
    if (index === -1) return false;
    
    if (this.shortcuts[index].isBuiltin) {
      this.deletedBuiltinIds.push(id);
    }
    
    this.shortcuts.splice(index, 1);
    await this.saveShortcuts();
    return true;
  }
  
  async reorderShortcut(fromIndex: number, toIndex: number): Promise<void> {
    if (fromIndex < 0 || fromIndex >= this.shortcuts.length ||
        toIndex < 0 || toIndex >= this.shortcuts.length ||
        fromIndex === toIndex) return;
    
    const item = this.shortcuts.splice(fromIndex, 1)[0];
    this.shortcuts.splice(toIndex, 0, item);
    await this.saveShortcuts();
  }
  
  async resetToDefault(): Promise<void> {
    this.deletedBuiltinIds = [];
    this.shortcuts = this.getDefaultShortcuts();
    await this.saveShortcuts();
  }

  getDeletedBuiltinShortcuts(): Shortcut[] {
    return this.getDefaultShortcuts().filter(s => this.deletedBuiltinIds.includes(s.id));
  }

  async restoreBuiltinShortcut(id: string): Promise<boolean> {
    const idx = this.deletedBuiltinIds.indexOf(id);
    if (idx === -1) return false;

    const shortcut = this.getDefaultShortcuts().find(s => s.id === id);
    if (!shortcut) return false;

    this.deletedBuiltinIds.splice(idx, 1);
    this.shortcuts.push(shortcut);
    await this.saveShortcuts();
    return true;
  }
  
  getAvailableKeys(): KeyOption[] {
    const keys: KeyOption[] = [];
    const entries = Object.entries(VK_DISPLAY_NAMES);
    for (const entry of entries) {
      const code = Number(entry[0]);
      const shortName = entry[1] as string;
      const option: KeyOption = { code: code, name: shortName, shortName: shortName };
      keys.push(option);
    }
    return keys;
  }
  
  keysToDisplayText(keys: number[]): string {
    return keys.map(code => getVkDisplayName(code)).join('+');
  }
  
  private async loadShortcuts(): Promise<void> {
    if (!this.prefs) {
      this.shortcuts = this.getDefaultShortcuts();
      return;
    }
    
    try {
      const deletedStr = await this.prefs.get(ShortcutManager.KEY_DELETED_BUILTINS, '') as string;
      this.deletedBuiltinIds = deletedStr ? JSON.parse(deletedStr) as string[] : [];
      
      const jsonStr = await this.prefs.get(ShortcutManager.KEY_SHORTCUTS, '') as string;
      if (jsonStr) {
        const saved: Shortcut[] = JSON.parse(jsonStr);
        const savedIds = new Set(saved.map(s => s.id));
        const newDefaults = this.getDefaultShortcuts()
          .filter(s => !savedIds.has(s.id) && !this.deletedBuiltinIds.includes(s.id));
        this.shortcuts = [...saved, ...newDefaults];
      } else {
        this.shortcuts = this.getDefaultShortcuts()
          .filter(s => !this.deletedBuiltinIds.includes(s.id));
      }
    } catch (error) {
      console.error('ShortcutManager', `加载快捷键失败: ${error}`);
      this.shortcuts = this.getDefaultShortcuts();
    }
  }
  
  private async saveShortcuts(): Promise<void> {
    if (!this.prefs) return;
    
    try {
      await this.prefs.put(ShortcutManager.KEY_SHORTCUTS, JSON.stringify(this.shortcuts));
      await this.prefs.put(ShortcutManager.KEY_DELETED_BUILTINS, JSON.stringify(this.deletedBuiltinIds));
      await this.prefs.flush();
    } catch (error) {
      console.error('ShortcutManager', `保存快捷键失败: ${error}`);
    }
  }
  
  private getDefaultShortcuts(): Shortcut[] {
    return [
      {
        id: 'builtin_win',
        name: 'Win',
        keys: [VirtualKey.VK_LWIN],
        icon: '⊞',
        color: '#5BA3D0',
        isBuiltin: true
      },
      {
        id: 'builtin_toggle_cursor',
        name: '切换远端光标',
        keys: [VirtualKey.VK_CONTROL, VirtualKey.VK_MENU, VirtualKey.VK_SHIFT, VirtualKey.VK_N],
        icon: '🖱️',
        color: '#A9C4D4',
        isBuiltin: true
      },
      {
        id: 'builtin_sleep',
        name: '休眠',
        keys: [],
        keySequence: [
          [VirtualKey.VK_LWIN, 0x58],  // Win+X
          [0x55],                       // U
          [0x53]                        // S
        ],
        icon: '◐',
        color: '#909090',
        isBuiltin: true
      },
      {
        id: 'builtin_ctrl_alt_del',
        name: 'Ctrl+Alt+Del',
        keys: [VirtualKey.VK_CONTROL, VirtualKey.VK_MENU, VirtualKey.VK_DELETE],
        icon: '🔐',
        color: '#8FA3AD',
        isBuiltin: true
      },
      {
        id: 'builtin_alt_tab',
        name: 'Alt+Tab',
        keys: [VirtualKey.VK_MENU, VirtualKey.VK_TAB],
        icon: '🔄',
        color: '#B8A9C0',
        isBuiltin: true
      },
      {
        id: 'builtin_alt_f4',
        name: 'Alt+F4',
        keys: [VirtualKey.VK_MENU, VirtualKey.VK_F4],
        icon: '❌',
        color: '#C9A9A6',
        isBuiltin: true
      },
      {
        id: 'builtin_win_d',
        name: 'Win+D',
        keys: [VirtualKey.VK_LWIN, 0x44],
        icon: '🖥️',
        color: '#A7B5AA',
        isBuiltin: true
      },
      {
        id: 'builtin_win_e',
        name: 'Win+E',
        keys: [VirtualKey.VK_LWIN, 0x45],
        icon: '📁',
        color: '#D4C5A9',
        isBuiltin: true
      }
    ];
  }
}
