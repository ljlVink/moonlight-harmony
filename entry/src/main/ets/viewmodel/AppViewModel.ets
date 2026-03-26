/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { AppEntry, NvHttp, SuperCmd } from '../service/NvHttp';

@Observed
export class ObservableApp {
  id: number = 0;
  name: string = '';
  isRunning: boolean = false;
  isHdrSupported: boolean = false;
  iconUrl: string = '';
  localIconPath: string = '';
  iconLoaded: boolean = false;
  cmdList: SuperCmd[] = [];
  
  constructor(entry?: AppEntry, iconUrl?: string) {
    if (entry) {
      this.updateFrom(entry, iconUrl);
    }
  }
  
  updateFrom(entry: AppEntry, iconUrl?: string): void {
    this.id = entry.id;
    this.name = entry.name;
    this.isRunning = entry.isRunning;
    this.isHdrSupported = entry.isHdrSupported;
    this.cmdList = entry.cmdList || [];
    if (iconUrl) {
      this.iconUrl = iconUrl;
    }
  }

  setLocalIconPath(path: string): void {
    this.localIconPath = path;
    this.iconLoaded = true;
  }
}

@Observed
export class AppListViewModel {
  apps: ObservableApp[] = [];
  
  filteredApps: ObservableApp[] = [];
  
  searchKeyword: string = '';
  
  isLoading: boolean = false;
  isRefreshing: boolean = false;
  
  errorMessage: string = '';
  
  runningApp: ObservableApp | null = null;
  
  selectedApp: ObservableApp | null = null;
  
  sortBy: 'name' | 'recent' = 'name';

  private iconLoadingCancelled: boolean = false;
  
  setApps(entries: AppEntry[], nvHttp?: NvHttp): void {
    this.iconLoadingCancelled = true;

    const runningApps = entries.filter(e => e.isRunning);
    console.info(`AppListViewModel: 加载 ${entries.length} 个应用, 正在运行: ${runningApps.map(a => `${a.name}(${a.id})`).join(', ') || '无'}`);

    this.apps = entries.map(entry => {
      const iconUrl = nvHttp ? nvHttp.getBoxArtUrl(entry.id) : '';
      return new ObservableApp(entry, iconUrl);
    });
    this.updateFilteredApps();
    this.updateRunningApp();

    if (nvHttp) {
      this.iconLoadingCancelled = false;
      this.loadAllIcons(nvHttp);
    }
  }

  cancelIconLoading(): void {
    this.iconLoadingCancelled = true;
    console.info(`AppListViewModel: 图标加载已取消`);
  }

  private async loadAllIcons(nvHttp: NvHttp): Promise<void> {
    console.info(`AppListViewModel: 开始加载 ${this.apps.length} 个应用图标`);

    for (const app of this.apps) {
      if (this.iconLoadingCancelled) {
        console.info(`AppListViewModel: 图标加载被取消，停止加载`);
        return;
      }

      try {
        const localPath = await nvHttp.getAppAssetCached(app.id);
        if (localPath && !this.iconLoadingCancelled) {
          app.setLocalIconPath(localPath);
          console.info(`AppListViewModel: 图标加载成功 ${app.name}`);
        }
      } catch (err) {
        console.warn(`AppListViewModel: 图标加载失败 ${app.name}`, err);
      }
    }

    if (!this.iconLoadingCancelled) {
      console.info(`AppListViewModel: 所有图标加载完成`);
    }
  }
  
  updateFilteredApps(): void {
    if (this.searchKeyword.trim()) {
      const keyword = this.searchKeyword.toLowerCase().trim();
      this.filteredApps = this.apps.filter(app => 
        app.name.toLowerCase().includes(keyword)
      );
    } else {
      this.filteredApps = [...this.apps];
    }
  }
  
  setSearchKeyword(keyword: string): void {
    this.searchKeyword = keyword;
    this.updateFilteredApps();
  }
  
  private updateRunningApp(): void {
    this.runningApp = this.apps.find(app => app.isRunning) || null;
  }
  
  selectApp(app: ObservableApp): void {
    this.selectedApp = app;
  }
  
  clearSelection(): void {
    this.selectedApp = null;
  }
  
  get appCount(): number {
    return this.apps.length;
  }
  
  get filteredCount(): number {
    return this.filteredApps.length;
  }
  
  get hasRunningApp(): boolean {
    return this.runningApp !== null;
  }
  
  get isEmpty(): boolean {
    return this.apps.length === 0;
  }
  
  get isSearchEmpty(): boolean {
    return this.searchKeyword.trim() !== '' && this.filteredApps.length === 0;
  }
}
