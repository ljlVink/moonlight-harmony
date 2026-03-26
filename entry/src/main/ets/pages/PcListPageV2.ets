/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { router, promptAction } from '@kit.ArkUI';
import { ComputerInfo, PairState, selectBestAddress } from '../model/ComputerInfo';
import { ComputerManager } from '../service/ComputerManager';
import { ComputerCard } from '../components/ComputerCard';
import { ComputerListViewModel, ObservableComputer, ComputerDataSource } from '../viewmodel/ComputerViewModel';
import { AppColors, AppSizes, AppSpacing } from '../common/Theme';
import { common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';
import { BackgroundImageUtil, BackgroundImageType } from '../utils/BackgroundImageUtil';
import { BackgroundImage } from '../components/BackgroundImage';
import { sensor } from '@kit.SensorServiceKit';
import { OptionPickerDialog, OptionPickerDialogConfig, OptionItem } from '../components/OptionPickerDialog';
import { ConfirmDialog, ConfirmDialogConfig, InfoDialog, InfoDialogConfig } from '../components/ConfirmDialog';
import { BusinessError } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { ComputerMenuHelper, ComputerMenuCallbacks } from '../viewmodel/ComputerMenuHelper';
import { PcListActions, PcListUICallbacks } from '../viewmodel/PcListActions';
import { PairingManager, PairState as PMPairState } from '../service/PairingManager';
import { QrShareService } from '../service/QrShareService';
import { CustomKeyStore } from '../service/CustomKeyStore';
import { PcListTitleBar, TitleBarConfig } from '../components/PcListTitleBar';
import { PinDialogView, AboutDialogView } from '../components/PcListDialogs';

/**
 * Computer list page (modern version)
 */
@Entry
@Component
struct PcListPageV2 {
  @State viewModel: ComputerListViewModel = new ComputerListViewModel();
  @State isRefreshing: boolean = false;
  @State isScanning: boolean = false;
  @State isInitializing: boolean = true;
  @State showPinDialog: boolean = false;
  @State currentPin: string = '';
  @State pairingComputerName: string = '';
  @State backgroundImageUrl: string = '';
  @State showAboutDialog: boolean = false;
  @State isLandscape: boolean = false;
  @State screenWidth: number = 0;
  @StorageProp('topSafeHeight') topSafeHeight: number = 56;
  
  private computerDataSource: ComputerDataSource = new ComputerDataSource();
  
  private computerManager: ComputerManager = ComputerManager.getInstance();
  private backgroundUtil: BackgroundImageUtil = BackgroundImageUtil.getInstance();
  private actions: PcListActions | null = null;
  
  private lastShakeTime: number = 0;
  private shakeThreshold: number = 15;
  private shakeCooldown: number = 2000;
  
  private optionPickerDialogConfig: OptionPickerDialogConfig = {
    title: '',
    options: [],
    onSelect: () => {}
  };
  private confirmDialogConfig: ConfirmDialogConfig = {
    title: '',
    message: '',
    confirmButton: { text: '', onClick: () => {} }
  };
  private infoDialogConfig: InfoDialogConfig = {
    title: '',
    content: ''
  };
  
  private optionPickerDialogController: CustomDialogController | null = null;
  private confirmDialogController: CustomDialogController | null = null;
  private infoDialogController: CustomDialogController | null = null;

  /**
   * Show confirm dialog
   */
  private showConfirmDialog(config: ConfirmDialogConfig): void {
    this.confirmDialogConfig = config;
    this.confirmDialogController = new CustomDialogController({
      builder: ConfirmDialog({
        config: this.confirmDialogConfig
      }),
      alignment: DialogAlignment.Center,
      customStyle: true,
      backgroundColor: Color.Transparent
    });
    this.confirmDialogController.open();
  }
  
  /**
   * Show info dialog
   */
  private showInfoDialog(config: InfoDialogConfig): void {
    this.infoDialogConfig = config;
    this.infoDialogController = new CustomDialogController({
      builder: InfoDialog({
        config: this.infoDialogConfig
      }),
      alignment: DialogAlignment.Center,
      customStyle: true,
      backgroundColor: Color.Transparent
    });
    this.infoDialogController.open();
  }

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    this.backgroundUtil.setContext(context);

    this.actions = new PcListActions({
      showConfirmDialog: (config: ConfirmDialogConfig) => this.showConfirmDialog(config),
      showInfoDialog: (config: InfoDialogConfig) => this.showInfoDialog(config),
      syncViewModel: () => { this.syncViewModelFromManager(); },
      showPinDialog: (pin: string, computerName: string) => {
        this.currentPin = pin;
        this.pairingComputerName = computerName;
        this.showPinDialog = true;
      },
      hidePinDialog: () => { this.showPinDialog = false; }
    } as PcListUICallbacks);
    
    this.initializeAsync();
    this.loadBackgroundImage();
    this.startShakeDetection();
  }
  
  private async loadBackgroundImage(): Promise<void> {
    try {
      const bgType = await this.backgroundUtil.getBackgroundImageType();
      if (bgType === BackgroundImageType.NONE) {
        this.backgroundImageUrl = '';
        return;
      }

      const disclaimerAccepted = await this.backgroundUtil.isDisclaimerAccepted();
      if (!disclaimerAccepted) {
        this.showBackgroundDisclaimerDialog();
        return;
      }
      
      const localPath = await this.backgroundUtil.downloadToLocalCache();
      if (localPath) {
        this.backgroundImageUrl = 'file://' + localPath;
      } else {
        this.backgroundImageUrl = await this.backgroundUtil.getBackgroundImageUrl();
      }
    } catch (err) {
    }
  }
  
  /**
   * Reload background image settings when page returns
   */
  private async reloadBackgroundImage(): Promise<void> {
    try {
      const typeChanged = await this.backgroundUtil.reload();
      const currentType = await this.backgroundUtil.getBackgroundImageType();
      if (currentType === BackgroundImageType.NONE) {
        this.backgroundImageUrl = '';
      } else if (typeChanged) {
        this.loadBackgroundImage();
      }
    } catch (err) {
    }
  }

  /**
   * Show background image disclaimer dialog
   */
  private showBackgroundDisclaimerDialog(): void {
    const config: ConfirmDialogConfig = {
      title: '背景壁纸功能说明',
      message: '本应用的背景壁纸来自互联网公开资源（Pipw API），图片版权归原作者所有。\n\n' +
        '• 本应用仅提供技术链接，不存储、不拥有这些图片的版权\n' +
        '• 如有侵权，请联系原图片来源方\n' +
        '• 您可以在设置中随时关闭壁纸功能或切换为其他来源\n\n' +
        '继续使用即表示您知悉并同意上述条款。',
      cancelButton: {
        text: '关闭壁纸',
        onClick: async () => {
          await this.backgroundUtil.setDisclaimerAccepted();
          await this.backgroundUtil.disableBackgroundImage();
          this.backgroundImageUrl = '';
        }
      },
      confirmButton: {
        text: '知悉并继续',
        onClick: async () => {
          await this.backgroundUtil.setDisclaimerAccepted();
          this.loadBackgroundImageAfterDisclaimer();
        }
      }
    };
    this.showConfirmDialog(config);
  }
  
  /**
   * Load background image after disclaimer accepted
   */
  private async loadBackgroundImageAfterDisclaimer(): Promise<void> {
    try {
      const localPath = await this.backgroundUtil.downloadToLocalCache();
      if (localPath) {
        this.backgroundImageUrl = 'file://' + localPath;
      } else {
        this.backgroundImageUrl = await this.backgroundUtil.getBackgroundImageUrl();
      }
    } catch (err) {
    }
  }

  private async initializeAsync(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      await this.computerManager.init(context);

      this.computerManager.setOnComputerListChangedListener(() => {
        this.syncViewModelFromManager();
      });

      this.syncViewModelFromManager();
      this.computerManager.startBackgroundScan();
      
      this.isInitializing = false;
      
      this.computerManager.refreshAllComputers().then(() => {
        this.syncViewModelFromManager();
        this.computerManager.startPolling();
      }).catch((err: Error) => {
        console.error('[MOONLIGHT] PcListPage: Refresh failed', err);
        this.computerManager.startPolling();
      });
    } catch (err) {
      console.error('PcListPage: Initialization failed', err);
      this.isInitializing = false;
    }
  }
  
  private async syncViewModelFromManager(): Promise<void> {
    const computers = await this.computerManager.getComputers();
    
    const computerMap = new Map<string, ComputerInfo>();
    for (const c of computers) {
      computerMap.set(c.uuid, c);
    }
    
    const existingMap = new Map<string, ObservableComputer>();
    for (const oc of this.viewModel.computers) {
      existingMap.set(oc.uuid, oc);
    }
    
    const newList: ObservableComputer[] = [];
    let hasChanges = false;
    
    for (const c of computers) {
      const existing = existingMap.get(c.uuid);
      if (existing) {
        existing.updateFrom(c);
        newList.push(existing);
        existingMap.delete(c.uuid);
      } else {
        newList.push(new ObservableComputer(c));
        hasChanges = true;
      }
    }
    
    if (existingMap.size > 0) {
      hasChanges = true;
    }
    
    if (hasChanges || this.viewModel.computers.length !== newList.length) {
      newList.sort((a, b) => {
        const getPriority = (c: ObservableComputer): number => {
          if (c.isOnline && c.isPaired) return 0;
          if (c.isOnline) return 1;
          return 2;
        };
        const pa = getPriority(a);
        const pb = getPriority(b);
        if (pa !== pb) {
          return pa - pb;
        }
        return a.name.localeCompare(b.name);
      });
      this.viewModel.computers = newList;
      this.computerDataSource.reloadData(newList);
    }
    
    this.viewModel.computerCount = newList.length;
    this.viewModel.onlineCount = newList.filter(c => c.isOnline).length;
  }

  aboutToDisappear(): void {
    this.computerManager.stopBackgroundScan();
    this.computerManager.stopPolling();
    this.stopShakeDetection();
  }

  onPageShow(): void {
    this.computerManager.startPolling();
    if (!this.isInitializing) {
      this.syncViewModelFromManager();
      this.computerManager.refreshAllComputers().then(() => {
        this.syncViewModelFromManager();
      }).catch((err: Error) => {
        console.warn('[MOONLIGHT] PcListPage: Refresh failed', err);
      });
      this.reloadBackgroundImage();
    }
    this.startShakeDetection();
  }
  
  onPageHide(): void {
    this.computerManager.stopPolling();
    this.stopShakeDetection();
  }
  
  private startShakeDetection(): void {
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, (data) => {
        const x = data.x;
        const y = data.y;
        const z = data.z;
        const acceleration = Math.sqrt(x * x + y * y + z * z);
        
        const shakeForce = Math.abs(acceleration - 9.8);
        
        if (shakeForce > this.shakeThreshold) {
          const now = Date.now();
          if (now - this.lastShakeTime > this.shakeCooldown) {
            this.lastShakeTime = now;
            this.refreshWallpaper();
          }
        }
      }, { interval: 100000000 });
    } catch (err) {
    }
  }
  
  private stopShakeDetection(): void {
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER);
    } catch (err) {
    }
  }

  build() {
    Stack() {
      BackgroundImage({ imageUrl: this.backgroundImageUrl, imageOpacity: 0.7 })
  
      Column() {
        PcListTitleBar({
          config: {
            onlineCount: this.viewModel.onlineCount,
            totalCount: this.viewModel.computerCount,
            onAboutClick: () => { this.showAboutDialog = true; },
            onScanImport: () => { this.scanAndImportKeys(); },
            onSettingsClick: () => { router.pushUrl({ url: 'pages/SettingsPageV2' }); }
          } as TitleBarConfig
        })
        
        if (this.isInitializing) {
          this.LoadingState()
        } else if (this.viewModel.computers.length === 0) {
          this.EmptyState()
        } else {
          this.ComputerList()
        }
        
        if (!this.isInitializing && this.viewModel.computers.length > 0) {
          this.BottomBar()
        }
      }
      .width('100%')
      .height('100%')
      .defaultFocus(true)
      
      if (this.showPinDialog) {
        PinDialogView({
          pin: this.currentPin,
          computerName: this.pairingComputerName,
          onClose: () => { this.showPinDialog = false; }
        })
      }
      
      if (this.showAboutDialog) {
        AboutDialogView({
          onClose: () => { this.showAboutDialog = false; }
        })
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const width = newValue.width as number;
      const height = newValue.height as number;
      this.screenWidth = width;
      this.isLandscape = width > height;
    })
  }

  @Builder
  LoadingState() {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color(AppColors.Primary)
      Text('正在加载...')
        .fontSize(AppSizes.FontBody)
        .fontColor(AppColors.TextSecondary)
        .margin({ top: AppSpacing.Large })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  EmptyState() {
    Column() {
      Column() {
        Text('🖥️')
          .fontSize(48)
      }
      .width(120)
      .height(120)
      .borderRadius(60)
      .backgroundColor(AppColors.Surface)
      .borderWidth(2)
      .borderColor(AppColors.Primary)
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: AppSpacing.XLarge })

      Text('开始连接')
        .fontSize(AppSizes.FontTitle)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.Primary)
        .margin({ bottom: AppSpacing.Small })

      Text('扫描网络发现运行 Foundation Sunshine 的电脑')
        .fontSize(AppSizes.FontBody)
        .fontColor(AppColors.TextSecondary)
        .textAlign(TextAlign.Center)
        .padding({ left: AppSpacing.XXLarge, right: AppSpacing.XXLarge })

      Text('或手动输入 IP 地址添加')
        .fontSize(AppSizes.FontCaption)
        .fontColor(AppColors.TextTertiary)
        .margin({ top: AppSpacing.Small })
      
      Row() {
        Button({ type: ButtonType.Normal }) {
          Row() {
            Image($r('app.media.ic_scan'))
              .width(20)
              .height(20)
              .fillColor(AppColors.TextOnPrimary)
              .margin({ right: 8 })
            Text('扫描网络')
              .fontSize(AppSizes.FontBody)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TextOnPrimary)
          }
        }
        .height(48)
        .padding({ left: AppSpacing.XLarge, right: AppSpacing.XLarge })
        .borderRadius(AppSizes.RadiusLarge)
        .backgroundColor(AppColors.Primary)
        .onClick(() => this.scanNetwork())

        Button({ type: ButtonType.Normal }) {
          Row() {
            Image($r('app.media.ic_add'))
              .width(20)
              .height(20)
              .fillColor(AppColors.Primary)
              .margin({ right: 8 })
            Text('手动添加')
              .fontSize(AppSizes.FontBody)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.Primary)
          }
        }
        .height(48)
        .padding({ left: AppSpacing.XLarge, right: AppSpacing.XLarge })
        .borderRadius(AppSizes.RadiusLarge)
        .backgroundColor(Color.Transparent)
        .borderWidth(1.5)
        .borderColor(AppColors.Primary)
        .margin({ left: AppSpacing.Medium })
        .onClick(() => router.pushUrl({ url: 'pages/AddPcPageV2' }))
      }
      .margin({ top: AppSpacing.XXLarge })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  /**
   * Calculate grid columns based on screen width
   */
  private getGridColumns(): number {
    if (this.screenWidth >= 900) return 3;
    if (this.screenWidth >= 600 || this.isLandscape) return 2;
    return 1;
  }

  @Builder
  ComputerList() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      if (this.getGridColumns() > 1) {
        Grid() {
          ForEach(this.viewModel.computers, (computer: ObservableComputer, index: number) => {
            GridItem() {
              ComputerCard({
                computer: computer,
                onTap: () => {
                  if (!computer.isOnline) {
                    this.showComputerMenu(computer);
                  } else {
                    this.actions!.handleComputerTap(computer);
                  }
                },
                onLongPress: () => this.showComputerMenu(computer),
                onQuickStream: () => this.actions!.handleQuickStream(computer)
              })
            }
          }, (computer: ObservableComputer) => computer.uuid)
        }
        .columnsTemplate(this.getGridColumns() === 3 ? '1fr 1fr 1fr' : '1fr 1fr')
        .columnsGap(AppSpacing.Medium)
        .rowsGap(AppSpacing.Medium)
        .width('100%')
        .padding({ left: AppSpacing.Large, right: AppSpacing.Large })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      } else {
        List({ space: AppSpacing.Medium }) {
          LazyForEach(this.computerDataSource, (computer: ObservableComputer, index: number) => {
            ListItem() {
              ComputerCard({
                computer: computer,
                onTap: () => {
                  if (!computer.isOnline) {
                    this.showComputerMenu(computer);
                  } else {
                    this.actions!.handleComputerTap(computer);
                  }
                },
                onLongPress: () => this.showComputerMenu(computer),
                onQuickStream: () => this.actions!.handleQuickStream(computer)
              })
            }
          }, (computer: ObservableComputer) => computer.uuid)
        }
        .width('100%')
        .padding({ left: AppSpacing.Large, right: AppSpacing.Large })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .cachedCount(5)
      }
    }
    .layoutWeight(1)
    .onRefreshing(() => {
      this.refreshComputers();
    })
  }

  @Builder
  BottomBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        if (this.isScanning) {
          LoadingProgress()
            .width(22)
            .height(22)
            .color(AppColors.TextSecondary)
        } else {
          Image($r('app.media.ic_search_network'))
            .width(22)
            .height(22)
            .fillColor(AppColors.TextSecondary)
        }
      }
      .width(44)
      .height(44)
      .backgroundColor(0x1A000000)
      .enabled(!this.isScanning)
      .onClick(() => this.scanNetwork())
      
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_add'))
          .width(28)
          .height(28)
          .fillColor(Color.White)
      }
      .width(56)
      .height(56)
      .backgroundColor(AppColors.Primary)
      .shadow({
        radius: 12,
        color: AppColors.PrimaryGlow,
        offsetX: 0,
        offsetY: 4
      })
      .margin({ left: AppSpacing.XLarge, right: AppSpacing.XLarge })
      .onClick(() => router.pushUrl({ url: 'pages/AddPcPageV2' }))
      
      SaveButton({
        icon: SaveIconStyle.FULL_FILLED, 
        buttonType: ButtonType.Circle 
      })
        .width(44)
        .height(44)
        .iconSize(22)
        .iconColor(AppColors.TextSecondary)
        .backgroundColor(0x1A000000)
        .onClick(this.handleSaveWallpaperClick)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: AppSpacing.Large,
      right: AppSpacing.Large,
      top: AppSpacing.Small,
      bottom: AppSpacing.Medium
    })
  }
  
  private async refreshWallpaper(): Promise<void> {
    try {
      promptAction.showToast({ message: '正在刷新壁纸...' });
      const localPath = await this.backgroundUtil.downloadToLocalCache(true);
      if (localPath) {
        this.backgroundImageUrl = 'file://' + localPath + '?t=' + Date.now();
        promptAction.showToast({ message: '壁纸已刷新' });
      } else {
        promptAction.showToast({ message: '刷新失败' });
      }
    } catch (err) {
      promptAction.showToast({ message: '刷新壁纸失败' });
    }
  }
  
  /**
   * SaveButton callback for saving wallpaper to album
   */
  handleSaveWallpaperClick: SaveButtonCallback = async (
    event: ClickEvent, 
    result: SaveButtonOnClickResult, 
    error?: BusinessError
  ) => {
    if (result === SaveButtonOnClickResult.SUCCESS) {
      const localPath = this.backgroundUtil.getLocalCachePath();
      if (!localPath) {
        promptAction.showToast({ message: '没有可下载的壁纸' });
        return;
      }
      
      try {
        const context = getContext(this) as common.UIAbilityContext;
        promptAction.showToast({ message: '正在保存壁纸...' });
        
        const stat = fileIo.statSync(localPath);
        if (!stat || stat.size === 0) {
          promptAction.showToast({ message: '缓存图片不存在' });
          return;
        }
        
        const file = fileIo.openSync(localPath, fileIo.OpenMode.READ_ONLY);
        const imageData = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, imageData);
        fileIo.closeSync(file.fd);
        
        const helper = photoAccessHelper.getPhotoAccessHelper(context);
        const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
        
        const photoFile = await fileIo.open(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
        await fileIo.write(photoFile.fd, imageData);
        await fileIo.close(photoFile.fd);
        
        promptAction.showToast({ message: '壁纸已保存到相册' });
      } catch (err) {
        console.error('Failed to save wallpaper', err);
        const e = err as BusinessError;
        promptAction.showToast({ message: `Save failed: ${e.message || 'Unknown error'}` });
      }
    } else if (result === SaveButtonOnClickResult.TEMPORARY_AUTHORIZATION_FAILED) {
      console.error('Save authorization failed', error);
      promptAction.showToast({ message: 'Save authorization failed' });
    }
  };

  // ==================== Business Logic ====================
  
  private async refreshComputers(): Promise<void> {
    this.isRefreshing = true;
    try {
      await this.computerManager.refreshAllComputers();
      this.syncViewModelFromManager();
    } catch (err) {
      console.error('Refresh failed', err);
    } finally {
      this.isRefreshing = false;
    }
  }

  /**
   * Scan QR code: auto-detect pairing URL or key config
   */
  private async scanAndImportKeys(): Promise<void> {
    const result = await QrShareService.scanQrCode();
    if (!result) {
      promptAction.showToast({ message: '扫码取消或失败', duration: 1500 });
      return;
    }

    const trimmed = result.trim();
    console.info(`[Scan] Scan result (${trimmed.length} chars): ${trimmed.substring(0, 100)}`);
    if (trimmed.startsWith('moonlight://pair')) {
      await this.handleQrPairing(trimmed);
      return;
    }

    const parsed = QrShareService.deserialize(trimmed);
    if (!parsed) {
      promptAction.showToast({ message: '无法识别的二维码内容', duration: 2000 });
      return;
    }
    const name = parsed[0];
    const keys = parsed[1];
    this.optionPickerDialogConfig = {
      title: `导入配置: ${name}`,
      subtitle: `包含 ${keys.length} 个按键`,
      options: [
        { title: '替换导入', value: 'replace' } as OptionItem,
        { title: '合并导入', value: 'merge' } as OptionItem,
      ],
      selectedValue: '',
      onSelect: async (option: OptionItem) => {
        if (option.value === 'replace') {
          await CustomKeyStore.saveKeys(keys);
          promptAction.showToast({ message: `已导入 "${name}" (${keys.length} 个按键)`, duration: 2000 });
        } else {
          const existing = await CustomKeyStore.getKeys();
          await CustomKeyStore.saveKeys(existing.concat(keys));
          promptAction.showToast({ message: `已合并 ${keys.length} 个按键`, duration: 2000 });
        }
      }
    };
    this.optionPickerDialogController = new CustomDialogController({
      builder: OptionPickerDialog({
        config: this.optionPickerDialogConfig
      }),
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      backgroundColor: Color.Transparent
    });
    this.optionPickerDialogController.open();
  }

  /**
   * Handle Sunshine QR pairing URL
   */
  private async handleQrPairing(url: string): Promise<void> {
    const paramStr = url.substring(url.indexOf('?') + 1);
    const params = new Map<string, string>();
    for (const part of paramStr.split('&')) {
      const eq = part.indexOf('=');
      if (eq > 0) {
        params.set(part.substring(0, eq), decodeURIComponent(part.substring(eq + 1)));
      }
    }

    const host = params.get('host') ?? '';
    const portStr = params.get('port') ?? '';
    const pin = params.get('pin') ?? '';
    const serverName = params.get('name') ?? host;

    if (!host || !pin) {
      promptAction.showToast({ message: '二维码缺少必要信息', duration: 2000 });
      return;
    }

    const address = portStr ? `${host}:${portStr}` : host;
    promptAction.showToast({ message: `正在连接 ${serverName}...`, duration: 2000 });

    try {
      const computer = await this.computerManager.addComputer(address);
      this.syncViewModelFromManager();

      if (computer.pairState === PairState.PAIRED) {
        promptAction.showToast({ message: `${serverName} 已配对`, duration: 2000 });
        return;
      }

      promptAction.showToast({ message: `Pairing with ${serverName}...`, duration: 2000 });
      const context = getContext() as common.UIAbilityContext;
      const pairingManager = new PairingManager(
        selectBestAddress(computer), computer.uuid, context, computer.httpPort
      );
      const result = await pairingManager.pair(pin);

      if (result.state === PMPairState.PAIRED) {
        let serverCertBase64 = '';
        if (result.serverCert) {
          serverCertBase64 = buffer.from(result.serverCert).toString('base64');
        }
        await this.computerManager.updateComputer(computer.uuid, {
          pairState: PairState.PAIRED,
          serverCert: serverCertBase64,
          pairName: result.pairName || ''
        });
        this.syncViewModelFromManager();
        promptAction.showToast({ message: `已成功配对 ${serverName}！` });
        router.pushUrl({ url: 'pages/AppListPageV2', params: { computerId: computer.uuid } });
      } else if (result.state === PMPairState.PIN_WRONG) {
        promptAction.showToast({ message: '二维码已过期，请在 Sunshine 重新生成', duration: 3000 });
      } else if (result.state === PMPairState.ALREADY_IN_PROGRESS) {
        promptAction.showToast({ message: '另一个设备正在配对中', duration: 2000 });
      } else {
        promptAction.showToast({ message: `配对失败: ${result.state}`, duration: 2000 });
      }
    } catch (error) {
      promptAction.showToast({ message: `连接失败: ${(error as Error).message}`, duration: 3000 });
    }
  }

  private async scanNetwork(): Promise<void> {
    this.isScanning = true;
    try {
      await this.computerManager.scanNetwork();
      this.syncViewModelFromManager();
      promptAction.showToast({ message: '扫描完成' });
    } catch (err) {
      console.error('Scan failed', err);
      promptAction.showToast({ message: 'Scan failed' });
    } finally {
      this.isScanning = false;
    }
  }

  private showComputerMenu(computer: ObservableComputer): void {
    const callbacks: ComputerMenuCallbacks = {
      onWake: (c) => this.actions!.wakeComputer(c),
      onPair: (c) => this.actions!.pairWithComputer(c),
      onResumeGame: (c) => this.actions!.resumeGame(c),
      onQuitGame: (c) => this.actions!.quitGame(c),
      onAppList: (c) => router.pushUrl({
        url: 'pages/AppListPageV2',
        params: { computerId: c.uuid }
      }),
      onUnpair: (c) => this.actions!.unpairComputer(c),
      onSleep: (c) => this.actions!.sleepComputer(c),
      onTestNetwork: (c) => this.actions!.testNetwork(c),
      onShowDetails: (c) => this.actions!.showComputerDetails(c),
      onDelete: (c) => this.actions!.deleteComputer(c)
    };
    
    const menuResult = ComputerMenuHelper.generateMenu(computer, callbacks);

    this.optionPickerDialogConfig = {
      title: computer.name,
      subtitle: computer.statusText,
      options: menuResult.options,
      selectedValue: '',
      onSelect: (option: OptionItem) => {
        const action = menuResult.actionMap.get(option.value as string);
        if (action) {
          action();
        }
      }
    };
    
    this.optionPickerDialogController = new CustomDialogController({
      builder: OptionPickerDialog({
        config: this.optionPickerDialogConfig
      }),
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      backgroundColor: Color.Transparent
    });
    this.optionPickerDialogController.open();
  }
}
