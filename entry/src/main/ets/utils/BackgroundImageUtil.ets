/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { PreferencesUtil } from './PreferencesUtil';
import { display, promptAction } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

const BACKGROUND_IMAGE_URL_KEY = 'settings_background_image_url';
const BACKGROUND_IMAGE_TYPE_KEY = 'settings_background_image_type';
const BACKGROUND_DISCLAIMER_ACCEPTED_KEY = 'settings_background_disclaimer_accepted';
const CACHED_BACKGROUND_LANDSCAPE = 'cached_background_landscape.jpg';
const CACHED_BACKGROUND_PORTRAIT = 'cached_background_portrait.jpg';
const BACKGROUND_CACHE_EXPIRE_MS = 24 * 60 * 60 * 1000;

interface BackgroundApiSource {
  name: string;
  description: string;
  landscape: string;
  portrait: string;
}

interface BackgroundApiSourceCollection {
  picsum: BackgroundApiSource;
  pipw: BackgroundApiSource;
}

export const BACKGROUND_API_SOURCES: BackgroundApiSourceCollection = {
  picsum: {
    name: 'Lorem Picsum',
    description: 'Photography wallpapers (Unsplash licensed)',
    landscape: 'https://picsum.photos/1920/1080',
    portrait: 'https://picsum.photos/1080/1920',
  } as BackgroundApiSource,
  pipw: {
    name: 'Pipw Anime',
    description: 'Anime wallpapers (third-party)',
    landscape: 'https://img-api.pipw.top',
    portrait: 'https://img-api.pipw.top/?phone=true',
  } as BackgroundApiSource
};

export enum BackgroundImageType {
  DEFAULT = 'default',
  PICSUM = 'picsum',
  PIPW = 'pipw',
  API = 'api',
  LOCAL = 'local',
  NONE = 'none'
}

export interface BackgroundConfig {
  /**
  imageUrl: string;
  /**
  opacity: number;
  /**
  enableBlur: boolean;
  /**
  blurRadius: number;
}

interface DownloadResult {
  code: number;
  data: ArrayBuffer | null;
  redirectUrl: string;
}

export class BackgroundImageUtil {
  private static instance: BackgroundImageUtil;
  private cachedUrl: string = '';
  private cachedType: BackgroundImageType = BackgroundImageType.DEFAULT;
  private isLoaded: boolean = false;
  private refreshTimestamp: number = 0;
  private cachedImageData: ArrayBuffer | null = null;
  private localCachePath: string = '';
  private landscapeCachePath: string = '';
  private portraitCachePath: string = '';
  private cachedOrientation: string = '';
  private context: common.Context | null = null;
  private pendingTypeChange: boolean = false;

  private constructor() {}

  static getInstance(): BackgroundImageUtil {
    if (!BackgroundImageUtil.instance) {
      BackgroundImageUtil.instance = new BackgroundImageUtil();
    }
    return BackgroundImageUtil.instance;
  }

  setContext(context: common.Context): void {
    this.context = context;
    this.landscapeCachePath = `${context.cacheDir}/${CACHED_BACKGROUND_LANDSCAPE}`;
    this.portraitCachePath = `${context.cacheDir}/${CACHED_BACKGROUND_PORTRAIT}`;
    this.updateCachePathForOrientation();
  }

  private updateCachePathForOrientation(): void {
    const orientation = this.getCurrentOrientation();
    if (orientation === 'portrait') {
      this.localCachePath = this.portraitCachePath;
    } else {
      this.localCachePath = this.landscapeCachePath;
    }
    this.cachedOrientation = orientation;
  }

  private getCurrentOrientation(): string {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      return displayInfo.height > displayInfo.width ? 'portrait' : 'landscape';
    } catch (err) {
      return 'landscape';
    }
  }

  getLocalCachePath(): string {
    return this.localCachePath;
  }

  async downloadToLocalCache(forceRefresh: boolean = false): Promise<string> {
    if (!this.context) {
      return '';
    }
    
    this.updateCachePathForOrientation();
    
    if (!forceRefresh && this.localCachePath) {
      try {
        const stat = fileIo.statSync(this.localCachePath);
        if (stat && stat.size > 0) {
          const cacheAge = Date.now() - stat.mtime * 1000;
          if (cacheAge > BACKGROUND_CACHE_EXPIRE_MS) {
            console.info('BackgroundImageUtil: Cache expired, will download new image');
            this.refreshTimestamp = Date.now();
          } else {
            const file = fileIo.openSync(this.localCachePath, fileIo.OpenMode.READ_ONLY);
            this.cachedImageData = new ArrayBuffer(stat.size);
            fileIo.readSync(file.fd, this.cachedImageData);
            fileIo.closeSync(file.fd);
            console.info(`BackgroundImageUtil: Using ${this.cachedOrientation} orientation cache`);
            return this.localCachePath;
          }
        }
      } catch (error) {
        console.debug(`BackgroundImageUtil: ${this.cachedOrientation} orientation cache not found, will download new image`);
      }
    }
    
    const apiUrl = await this.getApiUrlForCurrentType();
    
    const imageData = await this.downloadImage(apiUrl);
    if (!imageData) {
      return '';
    }
    
    try {
      const file = fileIo.openSync(this.localCachePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, imageData);
      fileIo.closeSync(file.fd);
      
      this.cachedImageData = imageData;
      
      return this.localCachePath;
    } catch (err) {
      console.error('BackgroundImageUtil: Failed to save local cache', err);
      return '';
    }
  }

  async getBackgroundImageUrl(): Promise<string> {
    if (this.isLoaded && this.cachedUrl) {
      return this.cachedUrl;
    }
    
    try {
      this.cachedType = await PreferencesUtil.get<string>(
        BACKGROUND_IMAGE_TYPE_KEY, 
        BackgroundImageType.DEFAULT
      ) as BackgroundImageType;
      
      switch (this.cachedType) {
        case BackgroundImageType.API:
          this.cachedUrl = await PreferencesUtil.get<string>(BACKGROUND_IMAGE_URL_KEY, '');
          if (!this.cachedUrl) {
            this.cachedType = BackgroundImageType.DEFAULT;
            await this.setBackgroundImageType(BackgroundImageType.DEFAULT);
            return this.getPipwApiUrl();
          }
          break;
          
        case BackgroundImageType.PICSUM:
          this.cachedUrl = this.getPicsumApiUrl();
          break;
          
        case BackgroundImageType.NONE:
          this.cachedUrl = '';
          break;
          
        case BackgroundImageType.PIPW:
        case BackgroundImageType.DEFAULT:
        default:
          this.cachedUrl = this.getPipwApiUrl();
          break;
      }
      
      this.isLoaded = true;
      return this.cachedUrl;
    } catch (err) {
      console.error('BackgroundImageUtil: 加载背景图设置失败', err);
      return this.getPipwApiUrl();
    }
  }

  private async getApiUrlForCurrentType(): Promise<string> {
    const bgType = await PreferencesUtil.get<string>(
      BACKGROUND_IMAGE_TYPE_KEY,
      BackgroundImageType.DEFAULT
    ) as BackgroundImageType;

    switch (bgType) {
      case BackgroundImageType.PICSUM:
        return this.getPicsumApiUrl();
      case BackgroundImageType.API:
        return await PreferencesUtil.get<string>(BACKGROUND_IMAGE_URL_KEY, '');
      case BackgroundImageType.NONE:
        return '';
      case BackgroundImageType.PIPW:
      case BackgroundImageType.DEFAULT:
      default:
        return this.getPipwApiUrl();
    }
  }

  getPipwApiUrl(): string {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      const isPortrait = displayInfo.height > displayInfo.width;
      if (this.refreshTimestamp === 0) {
        this.refreshTimestamp = Date.now();
      }
      const source = BACKGROUND_API_SOURCES.pipw;
      const baseUrl = isPortrait ? source.portrait : source.landscape;
      return `${baseUrl}${baseUrl.includes('?') ? '&' : '?'}t=${this.refreshTimestamp}`;
    } catch (err) {
      if (this.refreshTimestamp === 0) {
        this.refreshTimestamp = Date.now();
      }
      return `${BACKGROUND_API_SOURCES.pipw.landscape}?t=${this.refreshTimestamp}`;
    }
  }

  getPicsumApiUrl(): string {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      const isPortrait = displayInfo.height > displayInfo.width;
      if (this.refreshTimestamp === 0) {
        this.refreshTimestamp = Date.now();
      }
      const source = BACKGROUND_API_SOURCES.picsum;
      const baseUrl = isPortrait ? source.portrait : source.landscape;
      return `${baseUrl}?random=${this.refreshTimestamp}`;
    } catch (err) {
      if (this.refreshTimestamp === 0) {
        this.refreshTimestamp = Date.now();
      }
      return `${BACKGROUND_API_SOURCES.picsum.landscape}?random=${this.refreshTimestamp}`;
    }
  }

  async setBackgroundImageType(type: BackgroundImageType): Promise<void> {
    try {
      const previousType = this.cachedType;
      await PreferencesUtil.put(BACKGROUND_IMAGE_TYPE_KEY, type);
      this.cachedType = type;
      this.isLoaded = false;
      if (previousType !== type) {
        this.cachedUrl = '';
        this.cachedImageData = null;
        this.refreshTimestamp = Date.now();
        this.pendingTypeChange = true;
        if (type !== BackgroundImageType.NONE) {
          await this.clearLocalCache();
        }
      }
    } catch (err) {
      console.error('BackgroundImageUtil: 保存背景图类型失败', err);
    }
  }

  async isDisclaimerAccepted(): Promise<boolean> {
    try {
      return await PreferencesUtil.get<boolean>(BACKGROUND_DISCLAIMER_ACCEPTED_KEY, false);
    } catch (err) {
      return false;
    }
  }

  async setDisclaimerAccepted(): Promise<void> {
    try {
      await PreferencesUtil.put(BACKGROUND_DISCLAIMER_ACCEPTED_KEY, true);
    } catch (err) {
      console.error('BackgroundImageUtil: 保存免责声明状态失败', err);
    }
  }

  getDisclaimerText(): string {
    return '背景壁纸功能说明\n\n' +
      '本应用的背景壁纸来自互联网公开资源（Pipw API），图片版权归原作者所有。\n\n' +
      '• 本应用仅提供技术链接，不存储、不拥有这些图片的版权\n' +
      '• 如有侵权，请联系原图片来源方\n' +
      '• 您可以在设置中随时关闭壁纸功能或切换为其他来源\n\n' +
      '继续使用即表示您知悉并同意上述条款。';
  }

  async setBackgroundImageUrl(url: string): Promise<void> {
    try {
      await PreferencesUtil.put(BACKGROUND_IMAGE_URL_KEY, url);
      this.cachedUrl = url;
      
      if (url) {
        await this.setBackgroundImageType(BackgroundImageType.API);
      } else {
        await this.setBackgroundImageType(BackgroundImageType.DEFAULT);
      }
      
      this.isLoaded = true;
    } catch (err) {
      console.error('BackgroundImageUtil: 保存背景图设置失败', err);
    }
  }

  async clearBackgroundImage(): Promise<void> {
    await this.setBackgroundImageUrl('');
    await this.setBackgroundImageType(BackgroundImageType.DEFAULT);
  }

  async disableBackgroundImage(): Promise<void> {
    await this.setBackgroundImageType(BackgroundImageType.NONE);
    this.cachedUrl = '';
    this.isLoaded = true;
    this.cachedImageData = null;
    await this.clearLocalCache();
  }

  async clearLocalCache(): Promise<void> {
    const paths: string[] = [this.landscapeCachePath, this.portraitCachePath];
    for (const cachePath of paths) {
      if (cachePath) {
        try {
          await fileIo.access(cachePath);
          await fileIo.unlink(cachePath);
          console.info(`BackgroundImageUtil: 已清除缓存文件 ${cachePath}`);
        } catch (err) {
        }
      }
    }
  }

  async refreshBackgroundImage(): Promise<string> {
    this.refreshTimestamp = Date.now();
    this.isLoaded = false;
    return await this.getBackgroundImageUrl();
  }

  async reload(): Promise<boolean> {
    const dirtyFlag = this.pendingTypeChange;
    this.pendingTypeChange = false;
    const previousType = this.cachedType;
    this.isLoaded = false;
    await this.getBackgroundImageUrl();
    return dirtyFlag || this.cachedType !== previousType;
  }

  async getBackgroundImageType(): Promise<BackgroundImageType> {
    if (!this.isLoaded) {
      await this.getBackgroundImageUrl();
    }
    return this.cachedType;
  }

  getDefaultConfig(): BackgroundConfig {
    return {
      imageUrl: this.cachedUrl,
      opacity: 0.15,
      enableBlur: true,
      blurRadius: 20
    };
  }
  
  async preloadAndCacheImage(): Promise<void> {
    try {
      if (this.localCachePath) {
        try {
          const stat = fileIo.statSync(this.localCachePath);
          if (stat && stat.size > 0) {
            const file = fileIo.openSync(this.localCachePath, fileIo.OpenMode.READ_ONLY);
            const imageData = new ArrayBuffer(stat.size);
            fileIo.readSync(file.fd, imageData);
            fileIo.closeSync(file.fd);
            this.cachedImageData = imageData;
            return;
          }
        } catch (e) {
        }
      }
      
      if (this.cachedUrl) {
        this.cachedImageData = await this.downloadImage(this.cachedUrl);
      }
    } catch (err) {
    }
  }

  getCachedImageData(): ArrayBuffer | null {
    return this.cachedImageData;
  }

  clearCachedImageData(): void {
    this.cachedImageData = null;
  }

  async downloadImageData(imageUrl: string): Promise<ArrayBuffer | null> {
    if (!imageUrl || imageUrl.length === 0) {
      return null;
    }
    
    try {
      if (imageUrl.startsWith('file://')) {
        const filePath = imageUrl.replace('file://', '');
        try {
          const stat = fileIo.statSync(filePath);
          if (stat && stat.size > 0) {
            const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
            const imageData = new ArrayBuffer(stat.size);
            fileIo.readSync(file.fd, imageData);
            fileIo.closeSync(file.fd);
            return imageData;
          }
        } catch (e) {
          console.warn('BackgroundImageUtil: 读取本地文件失败');
        }
      }
      
      if (this.cachedImageData) {
        return this.cachedImageData;
      }
      
      return await this.downloadImage(imageUrl);
    } catch (err) {
      console.error('BackgroundImageUtil: 下载图片数据失败', err);
      return null;
    }
  }

  isValidImageUrl(url: string): boolean {
    if (!url) return false;
    
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return false;
    }
    
    return true;
  }

  async saveLocalCacheToGallery(context: common.UIAbilityContext): Promise<boolean> {
    if (!this.localCachePath) {
      promptAction.showToast({ message: '没有可保存的图片' });
      return false;
    }
    
    try {
      const stat = fileIo.statSync(this.localCachePath);
      if (!stat || stat.size === 0) {
        promptAction.showToast({ message: '缓存图片不存在' });
        return false;
      }
      
      promptAction.showToast({ message: '正在保存图片...' });
      
      const file = fileIo.openSync(this.localCachePath, fileIo.OpenMode.READ_ONLY);
      const imageData = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, imageData);
      fileIo.closeSync(file.fd);
      
      const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
      
      const createOption: photoAccessHelper.CreateOptions = {
        title: `moonlight_bg_${Date.now()}`,
        subtype: photoAccessHelper.PhotoSubtype.DEFAULT
      };
      
      const photoUri = await phAccessHelper.createAsset(
        photoAccessHelper.PhotoType.IMAGE,
        'jpg',
        createOption
      );
      
      const photoFile = fileIo.openSync(photoUri, fileIo.OpenMode.READ_WRITE);
      fileIo.writeSync(photoFile.fd, imageData);
      fileIo.closeSync(photoFile.fd);
      
      promptAction.showToast({ message: '图片已保存到相册' });
      return true;
    } catch (err) {
      console.error('BackgroundImageUtil: 保存本地缓存到相册失败', err);
      const error = err as Error;
      if (error.message?.includes('permission')) {
        promptAction.showToast({ message: '没有保存图片的权限，请在设置中授权' });
      } else {
        promptAction.showToast({ message: `保存失败: ${error.message || '未知错误'}` });
      }
      return false;
    }
  }

  async saveImageToGallery(imageUrl: string, context: common.UIAbilityContext): Promise<boolean> {
    if (!imageUrl || imageUrl.length === 0) {
      promptAction.showToast({ message: '没有可保存的图片' });
      return false;
    }

    try {
      promptAction.showToast({ message: '正在保存图片...' });
      
      let imageData: ArrayBuffer | null = null;
      
      if (imageUrl.startsWith('file://')) {
        const filePath = imageUrl.replace('file://', '');
        try {
          const stat = fileIo.statSync(filePath);
          if (stat && stat.size > 0) {
            const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
            imageData = new ArrayBuffer(stat.size);
            fileIo.readSync(file.fd, imageData);
            fileIo.closeSync(file.fd);
            console.info('BackgroundImageUtil: 从本地文件读取图片数据');
          }
        } catch (e) {
          console.warn('BackgroundImageUtil: 读取本地文件失败，尝试使用缓存数据');
        }
      }
      
      if (!imageData) {
        imageData = this.cachedImageData;
      }
      
      if (!imageData && !imageUrl.startsWith('file://')) {
        promptAction.showToast({ message: '正在下载图片...' });
        imageData = await this.downloadImage(imageUrl);
      }
      
      if (!imageData) {
        promptAction.showToast({ message: '图片数据获取失败' });
        return false;
      }
      
      const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
      
      const createOption: photoAccessHelper.CreateOptions = {
        title: `moonlight_bg_${Date.now()}`,
        subtype: photoAccessHelper.PhotoSubtype.DEFAULT
      };
      
      const photoUri = await phAccessHelper.createAsset(
        photoAccessHelper.PhotoType.IMAGE,
        'jpg',
        createOption
      );
      
      const file = fileIo.openSync(photoUri, fileIo.OpenMode.READ_WRITE);
      fileIo.writeSync(file.fd, imageData);
      fileIo.closeSync(file.fd);
      
      promptAction.showToast({ message: '图片已保存到相册' });
      return true;
    } catch (err) {
      console.error('BackgroundImageUtil: 保存图片失败', err);
      const error = err as Error;
      if (error.message?.includes('permission')) {
        promptAction.showToast({ message: '没有保存图片的权限，请在设置中授权' });
      } else {
        promptAction.showToast({ message: `保存失败: ${error.message || '未知错误'}` });
      }
      return false;
    }
  }

  private async downloadImage(url: string): Promise<ArrayBuffer | null> {
    try {
      let cleanUrl = url;
      let redirectCount = 0;
      const maxRedirects = 5;
      
      while (redirectCount < maxRedirects) {
        const httpRequest = http.createHttp();
        
        const result = await new Promise<DownloadResult>((resolve) => {
          httpRequest.request(
            cleanUrl,
            {
              method: http.RequestMethod.GET,
              expectDataType: http.HttpDataType.ARRAY_BUFFER,
              connectTimeout: 30000,
              readTimeout: 60000
            },
            (err, data) => {
              httpRequest.destroy();
              
              if (err) {
                console.error('BackgroundImageUtil: 下载图片请求失败', err);
                const errorResult: DownloadResult = { code: 0, data: null, redirectUrl: '' };
                resolve(errorResult);
                return;
              }
              
              if (data.responseCode >= 300 && data.responseCode < 400) {
                const headers = data.header as Record<string, string>;
                const location = headers['Location'] || headers['location'];
                if (location) {
                  const redirectResult: DownloadResult = { code: data.responseCode, data: null, redirectUrl: location };
                  resolve(redirectResult);
                  return;
                }
              }
              
              if (data.responseCode === 200 && data.result) {
                const successResult: DownloadResult = { code: data.responseCode, data: data.result as ArrayBuffer, redirectUrl: '' };
                resolve(successResult);
              } else {
                console.error('BackgroundImageUtil: 下载图片响应错误', data.responseCode);
                const failResult: DownloadResult = { code: data.responseCode, data: null, redirectUrl: '' };
                resolve(failResult);
              }
            }
          );
        });
        
        if (result.data) {
          return result.data;
        }
        
        if (result.redirectUrl) {
          console.info(`BackgroundImageUtil: 重定向到 ${result.redirectUrl}`);
          cleanUrl = result.redirectUrl;
          redirectCount++;
          continue;
        }
        
        return null;
      }
      
      console.error('BackgroundImageUtil: 重定向次数超限');
      return null;
    } catch (err) {
      console.error('BackgroundImageUtil: 下载图片失败', err);
      return null;
    }
  }
}
