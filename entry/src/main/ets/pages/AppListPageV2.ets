/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { display, promptAction, router } from "@kit.ArkUI";
import { ComputerManager } from "../service/ComputerManager";
import { AppEntry, DisplayInfo, NvHttp } from "../service/NvHttp";
import { AppCard } from "../components/AppCard";
import { AppListViewModel, ObservableApp } from "../viewmodel/AppViewModel";
import { AppAnimation, AppColors, AppSizes, AppSpacing } from "../common/Theme";
import { common } from "@kit.AbilityKit";
import { PairState, selectBestAddress } from "../model/ComputerInfo";
import {
  OptionItem,
  OptionPickerDialog,
  OptionPickerDialogConfig,
} from "../components/OptionPickerDialog";
import { ConfirmDialog, ConfirmDialogConfig } from "../components/ConfirmDialog";

interface AppListPageParams {
  computerId: string;
}

const VERTICAL_SINGLE_ROW_THRESHOLD = 5;

const DEFAULT_VERTICAL_ROW_COUNT = 2;
const DEFAULT_HORIZONTAL_ROW_COUNT = 1;

@Entry
@Component
struct AppListPageV2 {
  @StorageProp("topSafeHeight") topSafeHeight: number = 56;
  @State viewModel: AppListViewModel = new AppListViewModel();
  @State computerName: string = "";
  @State isLoading: boolean = true;
  @State isRefreshing: boolean = false;
  @State searchText: string = "";
  @State showSearch: boolean = false;
  @State gridColumns: number = 3;
  @State rowCount: number = DEFAULT_HORIZONTAL_ROW_COUNT;
  @State isLandscape: boolean = true;
  @State availableDisplays: DisplayInfo[] = [];
  @State selectedDisplayIndex: number = -1;
  @State useVirtualDisplay: boolean = false;
  @State supportsDisplayApi: boolean = false;
  private computerId: string = "";
  private computerManager: ComputerManager = ComputerManager.getInstance();
  private nvHttp: NvHttp | null = null;
  private searchDebounceTimer: number = -1;
  private iconPollIntervalId: number = -1;

  private static readonly EMPTY_LIST_THRESHOLD = 3;
  private static readonly EMPTY_LIST_RETRY_DELAY_MS = 2000;

  private optionPickerDialogConfig: OptionPickerDialogConfig = {
    title: "",
    options: [],
    onSelect: () => {},
  };
  private confirmDialogConfig: ConfirmDialogConfig = {
    title: "",
    message: "",
    confirmButton: { text: "", onClick: () => {} },
  };

  private optionPickerDialogController: CustomDialogController | null = null;
  private confirmDialogController: CustomDialogController | null = null;

  /**
   * Show confirm dialog
   */
  private showConfirmDialog(config: ConfirmDialogConfig): void {
    this.confirmDialogConfig = config;
    this.confirmDialogController = new CustomDialogController({
      builder: ConfirmDialog({
        config: this.confirmDialogConfig,
      }),
      alignment: DialogAlignment.Center,
      customStyle: true,
      backgroundColor: Color.Transparent,
    });
    this.confirmDialogController.open();
  }

  aboutToAppear(): void {
    this.updateLayoutConfig();

    const params = router.getParams() as AppListPageParams;
    if (params?.computerId) {
      this.computerId = params.computerId;
      this.loadApps();
    } else if (this.isLoading) {
      this.isLoading = false;
    }
  }

  aboutToDisappear(): void {
    this.viewModel.cancelIconLoading();

    if (this.iconPollIntervalId !== -1) {
      clearInterval(this.iconPollIntervalId);
      this.iconPollIntervalId = -1;
    }

    if (this.searchDebounceTimer !== -1) {
      clearTimeout(this.searchDebounceTimer);
      this.searchDebounceTimer = -1;
    }
  }

  onBackPress(): boolean {
    this.viewModel.cancelIconLoading();
    return false;
  }

  /**
   * Refresh app list when page reappears
   */
  onPageShow(): void {
    this.updateLayoutConfig();

    if (!this.nvHttp && this.computerId) {
      this.loadApps();
      return;
    }

    if (this.isLoading && this.nvHttp) {
      this.isLoading = false;
    }

    this.refreshApps(true);

    if (this.viewModel.hasRunningApp) {
      setTimeout(() => this.refreshApps(true), 1000);
    }
  }

  /**
   * Update layout config (based on screen orientation and app count)
   */
  private updateLayoutConfig(): void {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      this.isLandscape = displayInfo.width > displayInfo.height;
      this.calculateOptimalRowCount();
    } catch (err) {
      this.isLandscape = true;
      this.rowCount = DEFAULT_HORIZONTAL_ROW_COUNT;
    }
  }

  /**
   * Calculate optimal row count
   */
  private calculateOptimalRowCount(): void {
    if (this.isLandscape) {
      this.rowCount = DEFAULT_HORIZONTAL_ROW_COUNT;
    } else {
      const appCount = this.viewModel.filteredApps.length;
      if (appCount === 0) {
        this.rowCount = DEFAULT_VERTICAL_ROW_COUNT;
      } else if (appCount <= VERTICAL_SINGLE_ROW_THRESHOLD) {
        this.rowCount = DEFAULT_HORIZONTAL_ROW_COUNT;
      } else {
        this.rowCount = DEFAULT_VERTICAL_ROW_COUNT;
      }
    }
  }

  private async loadApps(): Promise<void> {
    this.isLoading = true;

    try {
      const computer = this.computerManager.getComputer(this.computerId);
      if (!computer) {
        promptAction.showToast({ message: "Computer not found" });
        router.back();
        return;
      }

      if (computer.pairState !== PairState.PAIRED) {
        promptAction.showToast({ message: "Device not paired, please re-pair" });
        router.back();
        return;
      }

      this.computerName = computer.name;

      const context = getContext(this) as common.UIAbilityContext;
      this.nvHttp = new NvHttp(
        selectBestAddress(computer),
        computer.serverCert,
        context,
        computer.httpPort,
      );

      let apps: AppEntry[] = [];
      for (let attempt = 0; attempt < AppListPageV2.EMPTY_LIST_THRESHOLD; attempt++) {
        apps = await this.nvHttp.getAppList();
        if (apps.length > 0) {
          break;
        }
        console.warn(
          `AppListPageV2: Received empty list (${attempt + 1}/${AppListPageV2.EMPTY_LIST_THRESHOLD})`,
        );
        if (attempt < AppListPageV2.EMPTY_LIST_THRESHOLD - 1) {
          await new Promise<void>((resolve) =>
            setTimeout(resolve, AppListPageV2.EMPTY_LIST_RETRY_DELAY_MS),
          );
        }
      }

      const runningGameId = computer.runningGameId;
      if (runningGameId > 0) {
        for (const app of apps) {
          app.isRunning = app.id === runningGameId;
        }
      }

      this.viewModel.setApps(apps, this.nvHttp);
      this.calculateOptimalRowCount();
      this.loadDisplays();
    } catch (err) {
      promptAction.showToast({ message: `Load failed: ${(err as Error).message}` });
    } finally {
      this.isLoading = false;
    }
  }

  private async refreshApps(silent: boolean = false): Promise<void> {
    this.isRefreshing = true;

    try {
      const computer = this.computerManager.getComputer(this.computerId);
      if (computer && computer.pairState !== PairState.PAIRED) {
        promptAction.showToast({ message: "Pairing expired, please re-pair" });
        router.back();
        return;
      }

      if (this.nvHttp) {
        try {
          const serverInfo = await this.nvHttp.getServerInfo();
          if (computer) {
            computer.runningGameId = serverInfo.currentGame;
          }
        } catch {}

        let apps: AppEntry[] = [];
        for (let attempt = 0; attempt < AppListPageV2.EMPTY_LIST_THRESHOLD; attempt++) {
          apps = await this.nvHttp.getAppList();
          if (apps.length > 0) {
            break;
          }
          console.warn(
            `AppListPageV2: Refresh received empty list (${attempt + 1}/${AppListPageV2.EMPTY_LIST_THRESHOLD})`,
          );
          if (attempt < AppListPageV2.EMPTY_LIST_THRESHOLD - 1) {
            await new Promise<void>((resolve) =>
              setTimeout(resolve, AppListPageV2.EMPTY_LIST_RETRY_DELAY_MS),
            );
          }
        }

        const runningGameId = computer?.runningGameId || 0;
        for (const app of apps) {
          app.isRunning = runningGameId > 0 && app.id === runningGameId;
        }

        this.viewModel.setApps(apps, this.nvHttp);
        this.calculateOptimalRowCount();
      }
    } catch (err) {
      const errMsg = (err as Error).message || "";
      if (
        errMsg.includes("401") ||
        errMsg.includes("not authorized") ||
        errMsg.includes("Certificate verification")
      ) {
        promptAction.showToast({ message: "Pairing expired, please re-pair" });
        router.back();
        return;
      }

      if (!silent && this.viewModel.appCount === 0) {
        promptAction.showToast({ message: "Refresh failed" });
      } else {
        console.warn("AppListPageV2: Refresh failed (silent):", errMsg);
      }
    } finally {
      this.isRefreshing = false;
    }
  }

  build() {
    Stack() {
      Column()
        .width("100%")
        .height("100%")
        .backgroundColor(AppColors.Background)
      Column() {
        this.TitleBar()
        Stack() {
          if (this.isLoading) {
            this.LoadingState();
          } else if (this.viewModel.isEmpty) {
            this.EmptyState();
          } else {
            Column() {
              if (this.showSearch) {
                this.SearchBar();
              }

              this.AppGrid()
            }
            .width("100%")
            .height("100%");
          }
        }.layoutWeight(1)

        if (this.supportsDisplayApi) {
          this.DisplaySelector();
        }
      }
      .width("100%")
      .height("100%")
      .defaultFocus(true)
    }
    .width("100%")
    .height("100%")
    .backgroundColor(Color.Transparent);
  }

  @Builder
  TitleBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Image($r("app.media.ic_back"))
          .width(AppSizes.IconMedium)
          .height(AppSizes.IconMedium)
          .fillColor(AppColors.Primary)
      }
      .width(40)
      .height(40)
      .backgroundColor(AppColors.Surface)
      .borderWidth(1)
      .borderColor(AppColors.CardBorder)
      .onClick(() => router.back())
      Column() {
        Text(this.computerName || "应用列表")
          .fontSize(AppSizes.FontTitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.Primary)

        if (!this.isLoading) {
          Row() {
            Text("🎮")
              .fontSize(12)
              .margin({ right: 4 })
            Text(`${this.viewModel.filteredCount} apps`)
              .fontSize(AppSizes.FontCaption)
              .fontColor(AppColors.TextSecondary)
          }
          .margin({ top: 2 });
        }
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: AppSpacing.Medium })
      Blank()
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r("sys.symbol.magnifyingglass"))
          .fontSize(20)
          .fontColor([this.showSearch ? AppColors.TextOnPrimary : AppColors.Accent])
      }
      .width(40)
      .height(40)
      .backgroundColor(this.showSearch ? AppColors.Accent : AppColors.Surface)
      .borderWidth(1)
      .borderColor(this.showSearch ? AppColors.Accent : AppColors.CardBorder)
      .onClick(() => {
        animateTo({ duration: AppAnimation.Normal, curve: AppAnimation.EaseOut }, () => {
          this.showSearch = !this.showSearch;
          if (!this.showSearch) {
            this.searchText = "";
            this.viewModel.setSearchKeyword("");
          }
        });
      })
      Button({ type: ButtonType.Circle }) {
        if (this.isRefreshing) {
          LoadingProgress().width(20).height(20).color(AppColors.Primary);
        } else {
          Image($r("app.media.ic_refresh"))
            .width(AppSizes.IconMedium)
            .height(AppSizes.IconMedium)
            .fillColor(AppColors.Primary);
        }
      }
      .width(40)
      .height(40)
      .backgroundColor(AppColors.Surface)
      .borderWidth(1)
      .borderColor(AppColors.CardBorder)
      .margin({ left: AppSpacing.Small })
      .onClick(() => this.refreshApps())
    }
    .width("100%")
    .padding({
      left: AppSpacing.Large,
      right: AppSpacing.Large,
      top: this.topSafeHeight,
      bottom: AppSpacing.Medium,
    });
  }

  @Builder
  SearchBar() {
    Row() {
      Row() {
        SymbolGlyph($r("sys.symbol.magnifyingglass"))
          .fontSize(16)
          .fontColor([AppColors.TextTertiary])
          .margin({ right: 8 })
        TextInput({ placeholder: "Search games...", text: this.searchText })
          .layoutWeight(1)
          .height(32)
          .fontSize(14)
          .fontColor(AppColors.TextPrimary)
          .placeholderColor(AppColors.TextTertiary)
          .caretColor(AppColors.Primary)
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => {
            this.searchText = value;

            if (this.searchDebounceTimer !== -1) {
              clearTimeout(this.searchDebounceTimer);
            }
            this.searchDebounceTimer = setTimeout(() => {
              this.viewModel.setSearchKeyword(this.searchText);
              this.searchDebounceTimer = -1;
            }, 300);
          })

        if (this.searchText.length > 0) {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r("sys.symbol.xmark"))
              .fontSize(10)
              .fontColor([AppColors.TextTertiary])
          }
          .width(24)
          .height(24)
          .backgroundColor(AppColors.Surface)
          .onClick(() => {
            if (this.searchDebounceTimer !== -1) {
              clearTimeout(this.searchDebounceTimer);
              this.searchDebounceTimer = -1;
            }
            this.searchText = "";
            this.viewModel.setSearchKeyword("");
          });
        }
      }
      .height(40)
      .padding({ left: 14, right: 10 })
      .backgroundColor(AppColors.CardBackground)
      .borderRadius(20)
      .borderWidth(1)
      .borderColor(this.searchText.length > 0 ? AppColors.Primary : AppColors.CardBorder)
      .layoutWeight(1)
    }
    .width("100%")
    .padding({ left: 24, right: 24, bottom: 8 })
    .justifyContent(FlexAlign.Center)
    .transition(TransitionEffect.OPACITY.animation({ duration: AppAnimation.Normal }));
  }

  @Builder
  DisplaySelector() {
    Column() {
      Text("Foundation Sunshine exclusive feature")
        .fontSize(10)
        .fontColor(AppColors.TextTertiary)
        .margin({ bottom: 4 })
      Row() {
        Row() {
          SymbolGlyph($r("sys.symbol.display"))
            .fontSize(18)
            .fontColor([AppColors.TextSecondary])
            .margin({ right: 6 })
          Text("Stream display")
            .fontSize(13)
            .fontColor(AppColors.TextSecondary)
        }
        .margin({ right: AppSpacing.Small })
        Scroll() {
          Row({ space: 8 }) {
            Text("Default")
              .fontSize(12)
              .fontWeight(
                !this.useVirtualDisplay && this.selectedDisplayIndex === -1
                  ? FontWeight.Medium
                  : FontWeight.Normal,
              )
              .fontColor(
                !this.useVirtualDisplay && this.selectedDisplayIndex === -1
                  ? AppColors.TextOnPrimary
                  : AppColors.TextSecondary,
              )
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(
                !this.useVirtualDisplay && this.selectedDisplayIndex === -1
                  ? AppColors.Primary
                  : AppColors.Surface,
              )
              .borderRadius(16)
              .borderWidth(1)
              .borderColor(
                !this.useVirtualDisplay && this.selectedDisplayIndex === -1
                  ? AppColors.Primary
                  : AppColors.CardBorder,
              )
              .onClick(() => {
                this.useVirtualDisplay = false;
                this.selectedDisplayIndex = -1;
              })
            ForEach(
              this.availableDisplays,
              (disp: DisplayInfo, index: number) => {
                Text(disp.name)
                  .fontSize(12)
                  .fontWeight(
                    !this.useVirtualDisplay && this.selectedDisplayIndex === index
                      ? FontWeight.Medium
                      : FontWeight.Normal,
                  )
                  .fontColor(
                    !this.useVirtualDisplay && this.selectedDisplayIndex === index
                      ? AppColors.TextOnPrimary
                      : AppColors.TextSecondary,
                  )
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor(
                    !this.useVirtualDisplay && this.selectedDisplayIndex === index
                      ? AppColors.Primary
                      : AppColors.Surface,
                  )
                  .borderRadius(16)
                  .borderWidth(1)
                  .borderColor(
                    !this.useVirtualDisplay && this.selectedDisplayIndex === index
                      ? AppColors.Primary
                      : AppColors.CardBorder,
                  )
                  .onClick(() => {
                    this.useVirtualDisplay = false;
                    this.selectedDisplayIndex = index;
                  });
              },
              (disp: DisplayInfo) => `display_${disp.index}`,
            )
            Text("Virtual display")
              .fontSize(12)
              .fontWeight(this.useVirtualDisplay ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.useVirtualDisplay ? AppColors.TextOnPrimary : AppColors.TextSecondary)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(this.useVirtualDisplay ? AppColors.Primary : AppColors.Surface)
              .borderRadius(16)
              .borderWidth(1)
              .borderColor(this.useVirtualDisplay ? AppColors.Primary : AppColors.CardBorder)
              .onClick(() => {
                this.useVirtualDisplay = true;
                this.selectedDisplayIndex = -1;
              })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }.width("100%")
    }
    .width("100%")
    .alignItems(HorizontalAlign.Start)
    .padding({ left: AppSpacing.Large, right: AppSpacing.Large })
    .margin({ top: AppSpacing.Small, bottom: AppSpacing.Small });
  }

  @Builder
  LoadingState() {
    Column() {
      Column() {
        LoadingProgress()
          .width(48)
          .height(48)
          .color(AppColors.Primary)
      }
      .width(80)
      .height(80)
      .justifyContent(FlexAlign.Center)
      .borderRadius(40)
      .backgroundColor(AppColors.CardBackground)
      .borderWidth(2)
      .borderColor(AppColors.Primary)
      .shadow({ radius: 20, color: AppColors.GlowGreen, offsetX: 0, offsetY: 0 })
      Text("Loading app list...")
        .fontSize(AppSizes.FontBody)
        .fontColor(AppColors.Primary)
        .margin({ top: AppSpacing.Large })
      Text("Please wait")
        .fontSize(AppSizes.FontCaption)
        .fontColor(AppColors.TextTertiary)
        .margin({ top: AppSpacing.Small })
    }
    .width("100%")
    .height("100%")
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  EmptyState() {
    Column() {
      Text(this.viewModel.isSearchEmpty ? "🔍" : "🎮")
        .fontSize(40)
        .margin({ bottom: AppSpacing.Medium })
      Text(this.viewModel.isSearchEmpty ? "No matching apps found" : "No apps available")
        .fontSize(AppSizes.FontBody)
        .fontColor(AppColors.TextSecondary)

      if (!this.viewModel.isSearchEmpty) {
        Text("Refresh")
          .fontSize(AppSizes.FontCaption)
          .fontColor(AppColors.Accent)
          .margin({ top: AppSpacing.Medium })
          .onClick(() => this.refreshApps());
      }
    }
    .width("100%")
    .height("100%")
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  AppGrid() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          ForEach(
            this.generateRows(),
            (rowApps: ObservableApp[], rowIndex: number) => {
              Row({ space: AppSpacing.Medium }) {
                ForEach(
                  rowApps,
                  (app: ObservableApp) => {
                    AppCard({
                      app: app,
                      onTap: () => this.launchApp(app),
                      onLongPress: () => this.openAppMenu(app),
                      onSelect: () => {},
                    });
                  },
                  (app: ObservableApp) => `${app.id}_${app.isRunning}_${app.iconLoaded}`,
                )
              }
              .margin({ bottom: rowIndex < this.rowCount - 1 ? AppSpacing.Medium : 0 });
            },
            (rowApps: ObservableApp[], rowIndex: number) => {
              const appIds = rowApps.map((a) => `${a.id}:${a.isRunning ? 1 : 0}`).join(",");
              return `row_${rowIndex}_apps_${appIds}`;
            },
          )
        }
        .padding({
          left: AppSpacing.Large,
          right: AppSpacing.Large,
          top: AppSpacing.Small,
          bottom: AppSpacing.XLarge,
        })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Start)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width("100%")
      .height("100%")
      .align(Alignment.Center)
    }
    .onRefreshing(() => this.refreshApps());
  }

  /**
   * Group apps into rows
   */
  private generateRows(): ObservableApp[][] {
    const apps = this.viewModel.filteredApps;
    const rows: ObservableApp[][] = [];

    if (apps.length === 0 || this.rowCount === 0) {
      return rows;
    }

    const appsPerRow = Math.ceil(apps.length / this.rowCount);

    for (let i = 0; i < this.rowCount; i++) {
      const rowApps: ObservableApp[] = [];
      for (let j = 0; j < appsPerRow; j++) {
        const index = j * this.rowCount + i;
        if (index < apps.length) {
          rowApps.push(apps[index]);
        }
      }
      if (rowApps.length > 0) {
        rows.push(rowApps);
      }
    }

    return rows;
  }

  /**
   * Generate rowsTemplate based on row count
   */
  private generateRowsTemplate(): string {
    const templates: string[] = [];
    for (let i = 0; i < this.rowCount; i++) {
      templates.push("1fr");
    }
    return templates.join(" ");
  }

  /**
   * Load available display list (Sunshine feature)
   */
  private async loadDisplays(): Promise<void> {
    if (!this.nvHttp) return;

    try {
      this.availableDisplays = await this.nvHttp.getDisplays();
      this.supportsDisplayApi = true;
    } catch {
      this.availableDisplays = [];
      this.supportsDisplayApi = false;
    }
  }

  /**
   * Get selected display GUID
   */
  private getSelectedDisplayGuid(): string {
    if (this.useVirtualDisplay) {
      return "";
    }
    if (
      this.selectedDisplayIndex >= 0 &&
      this.selectedDisplayIndex < this.availableDisplays.length
    ) {
      const display = this.availableDisplays[this.selectedDisplayIndex];
      return display.guid || display.name;
    }
    return "";
  }

  private async launchApp(app: ObservableApp): Promise<void> {
    if (this.viewModel.hasRunningApp && this.viewModel.runningApp?.id !== app.id) {
      this.showConfirmDialog({
        title: "Confirm",
        message: `${this.viewModel.runningApp?.name} is running.\nLaunching ${app.name} will quit the current app.`,
        confirmButton: {
          text: "Continue",
          onClick: () => {
            this.doLaunchApp(app);
          },
        },
      });
    } else {
      this.doLaunchApp(app);
    }
  }

  private doLaunchApp(app: ObservableApp): void {
    const displayGuid = this.getSelectedDisplayGuid();
    router.pushUrl({
      url: "pages/StreamPage",
      params: {
        computerId: this.computerId,
        appId: app.id,
        appName: app.name,
        cmdList: app.cmdList.length > 0 ? JSON.stringify(app.cmdList) : undefined,
        resume: app.isRunning,
        displayGuid: displayGuid,
        useVdd: this.useVirtualDisplay,
      },
    });
  }

  private openAppMenu(app: ObservableApp): void {
    const options: OptionItem[] = [];
    const actionMap = new Map<string, () => void>();
    let actionIndex = 0;

    const hasOtherRunningApp =
      this.viewModel.hasRunningApp && this.viewModel.runningApp?.id !== app.id;

    if (app.isRunning) {
      const resumeKey = `action_${actionIndex++}`;
      actionMap.set(resumeKey, () => this.doLaunchApp(app));
      options.push({
        title: "Resume",
        subtitle: "Continue current game",
        value: resumeKey,
      });

      const quitKey = `action_${actionIndex++}`;
      actionMap.set(quitKey, () => this.quitApp());
      options.push({
        title: "Quit",
        subtitle: "Close current running app",
        value: quitKey,
      });
    } else if (hasOtherRunningApp) {
      const quitAndStartKey = `action_${actionIndex++}`;
      actionMap.set(quitAndStartKey, () => this.quitAndStartApp(app));
      options.push({
        title: "Quit & Launch",
        subtitle: `Quit ${this.viewModel.runningApp?.name} and launch this app`,
        value: quitAndStartKey,
      });
    } else {
      const launchKey = `action_${actionIndex++}`;
      actionMap.set(launchKey, () => this.launchApp(app));
      options.push({
        title: "Launch",
        subtitle: "Start streaming",
        value: launchKey,
      });
    }

    if (app.isHdrSupported && !app.isRunning) {
      const hdrKey = `action_${actionIndex++}`;
      actionMap.set(hdrKey, () => {
        this.doLaunchApp(app);
      });
      options.push({
        title: "Launch (HDR)",
        subtitle: "Launch in HDR mode",
        value: hdrKey,
      });
    }

    const detailsKey = `action_${actionIndex++}`;
    actionMap.set(detailsKey, () => this.showAppDetails(app));
    options.push({
      title: "View Details",
      subtitle: "Show app info",
      value: detailsKey,
    });

    let subtitle = "";
    if (app.isRunning) {
      subtitle = "Running";
    } else if (app.isHdrSupported) {
      subtitle = "HDR supported";
    }

    this.optionPickerDialogConfig = {
      title: app.name,
      subtitle: subtitle,
      options: options,
      selectedValue: "",
      onSelect: (option: OptionItem) => {
        const action = actionMap.get(option.value as string);
        if (action) {
          action();
        }
      },
    };

    this.optionPickerDialogController = new CustomDialogController({
      builder: OptionPickerDialog({
        config: this.optionPickerDialogConfig,
      }),
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      backgroundColor: Color.Transparent,
    });
    this.optionPickerDialogController.open();
  }

  /**
   * Quit current app and launch new app
   */
  private async quitAndStartApp(app: ObservableApp): Promise<void> {
    if (!this.nvHttp) return;

    try {
      if (await this.nvHttp.quitApp()) {
        promptAction.showToast({ message: "Starting new app..." });
        setTimeout(() => this.doLaunchApp(app), 500);
      } else {
        promptAction.showToast({ message: "Quit failed" });
      }
    } catch {
      promptAction.showToast({ message: "Quit failed" });
    }
  }

  /**
   * Show app details
   */
  private showAppDetails(app: ObservableApp): void {
    const lines: string[] = [
      `App name: ${app.name}`,
      `App ID: ${app.id}`,
      `HDR support: ${app.isHdrSupported ? "Yes" : "No"}`,
      `Status: ${app.isRunning ? "Running" : "Not running"}`,
    ];

    if (app.cmdList && app.cmdList.length > 0) {
      lines.push("");
      lines.push("Server commands:");
      for (const cmd of app.cmdList) {
        lines.push(`  • ${cmd.name} (${cmd.id})`);
      }
    }

    const details = lines.join("\n");

    this.confirmDialogConfig = {
      title: "App Details",
      message: details,
      confirmButton: {
        text: "OK",
        onClick: () => {},
      },
    };

    this.confirmDialogController = new CustomDialogController({
      builder: ConfirmDialog({
        config: this.confirmDialogConfig,
      }),
      alignment: DialogAlignment.Center,
      customStyle: true,
      backgroundColor: Color.Transparent,
    });
    this.confirmDialogController.open();
  }

  private async quitApp(): Promise<void> {
    if (!this.nvHttp) return;

    try {
      if (await this.nvHttp.quitApp()) {
        promptAction.showToast({ message: "App quit" });
        await this.refreshApps();
      } else {
        promptAction.showToast({ message: "Quit failed" });
      }
    } catch {
      promptAction.showToast({ message: "Quit failed" });
    }
  }
}
