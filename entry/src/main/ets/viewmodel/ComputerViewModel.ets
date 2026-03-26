/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { ComputerInfo, ComputerState, PairState, AddressHolder } from "../model/ComputerInfo";
import { ComputerManager } from "../service/ComputerManager";

@Observed
export class ObservableComputer implements AddressHolder {
  uuid: string = "";
  name: string = "";
  address: string = "";
  state: ComputerState = ComputerState.UNKNOWN;
  pairState: PairState = PairState.NOT_PAIRED;
  runningGameId: number = 0;
  serverCert: string = "";
  macAddress: string = "";
  localAddress: string = "";
  remoteAddress: string = "";
  manualAddress: string = "";
  ipv6Address: string = "";
  pairName: string = "";
  gpuType: string = "";
  isNvidiaSoftware: boolean = false;
  boxArtUrl: string = "";
  httpPort: number | undefined = undefined;

  isOnline: boolean = false;
  isPaired: boolean = false;
  isGaming: boolean = false;
  statusText: string = "离线";

  constructor(info?: ComputerInfo) {
    if (info) {
      this.updateFrom(info);
    }
  }

  updateFrom(info: ComputerInfo): void {
    this.uuid = info.uuid;
    this.name = info.name;
    this.address = info.address;
    this.state = info.state;
    this.pairState = info.pairState;
    this.runningGameId = info.runningGameId;
    this.serverCert = info.serverCert;
    this.macAddress = info.macAddress;
    this.localAddress = info.localAddress;
    this.remoteAddress = info.remoteAddress;
    this.manualAddress = info.manualAddress || "";
    this.ipv6Address = info.ipv6Address || "";
    this.pairName = info.pairName;
    this.gpuType = info.gpuType;
    this.isNvidiaSoftware = info.isNvidiaSoftware;
    this.boxArtUrl = info.boxArtUrl || "";
    this.httpPort = info.httpPort;

    this.updateCachedValues();
  }

  private updateCachedValues(): void {
    this.isOnline = this.state === ComputerState.ONLINE;
    this.isPaired = this.pairState === PairState.PAIRED;
    this.isGaming = this.runningGameId > 0;

    if (!this.isOnline) {
      this.statusText = "离线";
    } else if (!this.isPaired) {
      this.statusText = "未配对";
    } else if (this.isGaming) {
      this.statusText = "正在运行游戏";
    } else {
      this.statusText = "在线";
    }
  }

  toComputerInfo(): ComputerInfo {
    const info: ComputerInfo = {
      uuid: this.uuid,
      name: this.name,
      address: this.address,
      state: this.state,
      pairState: this.pairState,
      runningGameId: this.runningGameId,
      serverCert: this.serverCert,
      macAddress: this.macAddress,
      localAddress: this.localAddress,
      remoteAddress: this.remoteAddress,
      manualAddress: this.manualAddress || undefined,
      ipv6Address: this.ipv6Address || undefined,
      pairName: this.pairName,
      gpuType: this.gpuType,
      maxSupportedResolution: { width: 1920, height: 1080 },
      isNvidiaSoftware: this.isNvidiaSoftware,
      boxArtUrl: this.boxArtUrl,
      httpPort: this.httpPort,
    };
    return info;
  }
}

/**
 *
 */
@Observed
export class ComputerListViewModel {
  computers: ObservableComputer[] = [];

  isLoading: boolean = false;
  isRefreshing: boolean = false;

  errorMessage: string = "";

  selectedComputer: ObservableComputer | null = null;

  isPairing: boolean = false;
  pairingPin: string = "";
  pairingComputer: ObservableComputer | null = null;

  private computerManager: ComputerManager;

  constructor() {
    this.computerManager = ComputerManager.getInstance();
  }

  async loadComputers(): Promise<void> {
    if (this.isLoading) return;

    this.isLoading = true;
    this.errorMessage = "";

    try {
      const computerInfos = await this.computerManager.getComputers();
      this.updateComputerList(computerInfos);
    } catch (error) {
      const err = error as Error;
      this.errorMessage = `加载失败: ${err.message}`;
    } finally {
      this.isLoading = false;
    }
  }

  async refreshComputers(): Promise<void> {
    if (this.isRefreshing) return;

    this.isRefreshing = true;

    try {
      const computers = await this.computerManager.getComputers();
      for (const computer of computers) {
        await this.computerManager.pollComputer(computer);
      }
      this.updateComputerList(await this.computerManager.getComputers());
    } catch (error) {
      const err = error as Error;
      this.errorMessage = `刷新失败: ${err.message}`;
    } finally {
      this.isRefreshing = false;
    }
  }

  private updateComputerList(infos: ComputerInfo[]): void {
    const existingUuids = new Set(this.computers.map((c) => c.uuid));
    const newUuids = new Set(infos.map((i) => i.uuid));

    for (const computer of this.computers) {
      const info = infos.find((i) => i.uuid === computer.uuid);
      if (info) {
        computer.updateFrom(info);
      }
    }

    for (const info of infos) {
      if (!existingUuids.has(info.uuid)) {
        this.computers.push(new ObservableComputer(info));
      }
    }

    this.computers = this.computers.filter((c) => newUuids.has(c.uuid));

    this.updateCachedCounts();
  }

  private updateCachedCounts(): void {
    this.computerCount = this.computers.length;
    this.onlineCount = this.computers.filter((c) => c.isOnline).length;
  }

  async addComputer(address: string): Promise<boolean> {
    this.isLoading = true;
    this.errorMessage = "";

    try {
      const result = await this.computerManager.addComputer(address);
      if (result) {
        this.updateComputerList(await this.computerManager.getComputers());
        return true;
      } else {
        this.errorMessage = "无法连接到主机";
        return false;
      }
    } catch (error) {
      const err = error as Error;
      this.errorMessage = err.message;
      return false;
    } finally {
      this.isLoading = false;
    }
  }

  async removeComputer(uuid: string): Promise<void> {
    await this.computerManager.removeComputer(uuid);
    this.computers = this.computers.filter((c) => c.uuid !== uuid);
  }

  async startPairing(computer: ObservableComputer): Promise<string> {
    this.isPairing = true;
    this.pairingComputer = computer;

    try {
      const pin = await this.computerManager.pairComputer(computer.uuid);
      this.pairingPin = pin;
      return pin;
    } catch (error) {
      const err = error as Error;
      this.errorMessage = err.message;
      this.isPairing = false;
      this.pairingComputer = null;
      throw new Error(err.message);
    }
  }

  cancelPairing(): void {
    this.isPairing = false;
    this.pairingPin = "";
    this.pairingComputer = null;
  }

  async wakeComputer(computer: ObservableComputer): Promise<void> {
    await this.computerManager.wakeComputer(computer.uuid);
  }

  selectComputer(computer: ObservableComputer): void {
    this.selectedComputer = computer;
  }

  clearSelection(): void {
    this.selectedComputer = null;
  }

  computerCount: number = 0;
  onlineCount: number = 0;

  get isEmpty(): boolean {
    return this.computers.length === 0;
  }
}

export class ComputerDataSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private dataArray: ObservableComputer[] = [];

  totalCount(): number {
    return this.dataArray.length;
  }

  getData(index: number): ObservableComputer {
    return this.dataArray[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  reloadData(data: ObservableComputer[]): void {
    this.dataArray = data;
    this.notifyDataReload();
  }

  updateItem(index: number): void {
    this.notifyDataChange(index);
  }

  private notifyDataReload(): void {
    this.listeners.forEach((listener) => {
      listener.onDataReloaded();
    });
  }

  private notifyDataChange(index: number): void {
    this.listeners.forEach((listener) => {
      listener.onDataChange(index);
    });
  }

  notifyDataAdd(index: number): void {
    this.listeners.forEach((listener) => {
      listener.onDataAdd(index);
    });
  }

  notifyDataDelete(index: number): void {
    this.listeners.forEach((listener) => {
      listener.onDataDelete(index);
    });
  }

  pushData(data: ObservableComputer): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }

  deleteData(index: number): void {
    this.dataArray.splice(index, 1);
    this.notifyDataDelete(index);
  }
}
