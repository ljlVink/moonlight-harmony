/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { ComputerInfo, ComputerInfoBuilder, ComputerState, PairState, selectBestAddress } from '../model/ComputerInfo';
import { NvHttp, ServerInfo } from './NvHttp';
import { PairingManager, PairState as PMPairState } from './PairingManager';
import { DiscoveredComputer, MdnsDiscovery } from './MdnsDiscovery';
import { ComputerPersistence } from './ComputerPersistence';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { CryptoUtil } from '../utils/CryptoUtil';
import { WakeOnLan } from './WakeOnLan';
import { getBestIpv6Address, isIPv6Address, isLanAddress } from '../utils/NetHelper';
import { connection } from '@kit.NetworkKit';
import { MAX_PORT } from '../common/NetworkConstants';
import { common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';

/**
 * Address parse result
 */
class AddressParseResult {
  host: string = '';
  port: number | undefined = undefined;
}

/**
 * Poll result
 */
interface PollResult {
  address: string;
  serverInfo: ServerInfo | null;
}

/** Polling interval (ms), aligned with Android ComputerManagerService */
const SERVERINFO_POLLING_PERIOD_MS = 5000;

/**
 * Computer Manager - manages all discovered and manually added computers
 */
export class ComputerManager {
  private static instance: ComputerManager;
  private computers: Map<string, ComputerInfo> = new Map();
  private mdnsDiscovery: MdnsDiscovery | null = null;
  private context: common.UIAbilityContext | null = null;
  private onComputerListChanged: (() => void) | null = null;
  private isInitialized: boolean = false;
  private pollingTimerId: number = -1;
  private isPollingActive: boolean = false;
  private netConnection: connection.NetConnection | null = null;
  /** Offline polling backoff: tracks consecutive offline count, polls offline hosts every N rounds */
  private offlineStreak: Map<string, number> = new Map();
  
  // Initialization & Singleton
  
  private constructor() {
    // mdnsDiscovery needs to be initialized with context in init()
  }

  static getInstance(): ComputerManager {
    if (!ComputerManager.instance) {
      ComputerManager.instance = new ComputerManager();
    }
    return ComputerManager.instance;
  }

  /**
   * Initialize with context
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    // Avoid duplicate initialization
    if (this.isInitialized) {
      console.info('ComputerManager: Already initialized, skipping');
      return;
    }
    
    this.context = context;
    this.mdnsDiscovery = new MdnsDiscovery(context);
    
    // Initialize PreferencesUtil
    PreferencesUtil.init(context);
  
    // Set mDNS discovery callback
    this.mdnsDiscovery.setOnComputerFoundListener((discovered: DiscoveredComputer) => {
      this.handleDiscoveredComputer(discovered);
    });
  
    // Load saved computers (wait for completion)
    this.computers = await ComputerPersistence.loadComputers();
  
    // Register network change listener (similar to Android registerDefaultNetworkCallback)
    this.registerNetworkListener();
  
    this.isInitialized = true;
    console.info('ComputerManager: Initialization complete');
  
    // Note: Don't trigger refresh here, let caller set callback then call refreshAllComputers()
  }

  /**
   * Set computer list change callback
   */
  setOnComputerListChangedListener(callback: () => void): void {
    this.onComputerListChanged = callback;
  }

  // mDNS Discovery
  
  /**
   * Handle mDNS discovered computer
   */
  private async handleDiscoveredComputer(discovered: DiscoveredComputer): Promise<void> {
    console.info(`ComputerManager: mDNS discovered ${discovered.name} @ ${discovered.address}:${discovered.port}`);

    const existing = this.findComputerByAddress(discovered.address);

    if (existing) {
      this.mergeDiscoveredInfo(existing, discovered);
      await this.verifyOrPollComputer(existing, discovered.address);
    } else {
      try {
        await this.addComputerInternal(discovered.address, discovered.name, discovered.port);
      } catch (err) {
        console.error(`ComputerManager: Failed to add computer ${discovered.name}: ${err}`);
      }
    }

    this.notifyListChanged();
  }

  /**
   * Find existing computer by address (matches all address fields)
   */
  private findComputerByAddress(address: string): ComputerInfo | undefined {
    return Array.from(this.computers.values())
      .find(c =>
        c.address === address ||
        c.localAddress === address ||
        c.remoteAddress === address ||
        c.manualAddress === address
      );
  }

  /**
   * Merge mDNS discovered info into existing computer
   */
  private mergeDiscoveredInfo(existing: ComputerInfo, discovered: DiscoveredComputer): void {
    if (existing.localAddress !== discovered.address) {
      existing.localAddress = discovered.address;
    }
    if (discovered.ipv6Address && existing.ipv6Address !== discovered.ipv6Address) {
      existing.ipv6Address = discovered.ipv6Address;
    }
    if (discovered.port && discovered.port !== NvHttp.DEFAULT_HTTP_PORT) {
      existing.httpPort = discovered.port;
    }
  }

  /**
   * Try to verify computer online via mDNS address, fall back to full address polling on failure
   */
  private async verifyOrPollComputer(computer: ComputerInfo, address: string): Promise<void> {
    try {
      const nvHttp = new NvHttp(address, computer.serverCert, this.context || undefined, computer.httpPort);
      const serverInfo = await nvHttp.getServerInfo();
  
      // Handle UUID reconciliation: discovered-* temporary entries get real UUID
      if (serverInfo.uniqueId && computer.uuid !== serverInfo.uniqueId) {
        this.reconcileUuid(computer, serverInfo.uniqueId);
      }
  
      computer.state = ComputerState.ONLINE;
      if (!computer.address) computer.address = address;
      computer.runningGameId = serverInfo.currentGame;
      if (serverInfo.hostname) computer.name = serverInfo.hostname;
    } catch (err) {
      console.warn(`ComputerManager: mDNS address unreachable for ${computer.name}, falling back to polling`);
      await this.pollComputer(computer);
    }
  }

  /**
   * UUID reconciliation: when polling/verification returns a real UUID different from entry's temporary UUID,
   * merge into existing real entry, or remap the UUID.
   * @returns The target entry to continue updating (may be merged existing entry)
   */
  private reconcileUuid(computer: ComputerInfo, realUuid: string): ComputerInfo {
    const existingReal = this.computers.get(realUuid);
  
    if (existingReal) {
      // Real UUID entry exists -> merge into existing entry, delete temporary entry
      console.info(`ComputerManager: Merging temporary entry ${computer.uuid} -> existing entry ${realUuid}`);
      this.computers.delete(computer.uuid);
      if (computer.manualAddress && !existingReal.manualAddress) {
        existingReal.manualAddress = computer.manualAddress;
      }
      return existingReal;
    }
  
    // Real UUID doesn't exist -> remap
    console.info(`ComputerManager: Temporary entry ${computer.uuid} got real UUID ${realUuid}`);
    this.computers.delete(computer.uuid);
    computer.uuid = realUuid;
    this.computers.set(realUuid, computer);
    return computer;
  }

  /**
   * Notify computer list changed
   */
  private notifyListChanged(): void {
    if (this.onComputerListChanged) {
      this.onComputerListChanged();
    }
  }

  // CRUD Operations
  
  /**
   * Get all computers list
   * Returns deep-copied objects to ensure ArkTS @State can detect changes
   */
  async getComputers(): Promise<ComputerInfo[]> {
    return Array.from(this.computers.values()).map(computer => ComputerPersistence.cloneComputer(computer));
  }

  /**
   * Get computer by UUID
   */
  getComputer(uuid: string): ComputerInfo | undefined {
    const computer = this.computers.get(uuid);
    return computer ? ComputerPersistence.cloneComputer(computer) : undefined;
  }

  /**
   * Update computer info (used after pairing to update serverCert etc.)
   * @param uuid Computer UUID
   * @param updates Fields to update
   */
  async updateComputer(uuid: string, updates: Partial<ComputerInfo>): Promise<void> {
    const computer = this.computers.get(uuid);
    if (!computer) {
      console.warn(`ComputerManager: updateComputer computer not found ${uuid}`);
      return;
    }
  
    // Update specified fields
    if (updates.pairState !== undefined) {
      computer.pairState = updates.pairState;
    }
    if (updates.serverCert !== undefined) {
      computer.serverCert = updates.serverCert;
    }
    if (updates.pairName !== undefined) {
      computer.pairName = updates.pairName;
    }
    if (updates.address !== undefined) {
      computer.address = updates.address;
    }
    if (updates.state !== undefined) {
      computer.state = updates.state;
    }
    
    console.info(`ComputerManager: Updated computer ${computer.name} - pairState=${computer.pairState}, serverCert=${computer.serverCert ? 'yes' : 'no'}`);
  
    // Save to persistent storage
    await this.saveComputers();
  }

  /**
   * Manually add computer
   * @param addressInput User input address, supports the following formats:
   *   - "192.168.1.100" - IPv4 address, uses default port
   *   - "192.168.1.100:47989" - IPv4 address + custom port
   *   - "::1" or "[::1]" - IPv6 address, uses default port
   *   - "[::1]:47989" - IPv6 address + custom port
   *   - "mydomain.com" - Domain name, will be saved as manualAddress
   */
  async addComputer(addressInput: string): Promise<ComputerInfo> {
    const parsed = this.parseAddressInput(addressInput);
    const result = await this.addComputerInternal(parsed.host, undefined, parsed.port);
  
    // Save user-entered address (host part only, port stored in httpPort)
    // This address is never overwritten by auto-discovery, polling tries it first
    result.manualAddress = parsed.host;
  
    // Save updated computer info
    this.computers.set(result.uuid, result);
    await this.saveComputers();
    
    this.notifyListChanged();
    return result;
  }

  /**
   * Parse user input address, extract host and port
   */
  private parseAddressInput(input: string): AddressParseResult {
    const trimmed = input.trim();
    const result = new AddressParseResult();
  
    // Check if it's an IPv6 address (contains multiple colons)
    let colonCount = 0;
    for (let i = 0; i < trimmed.length; i++) {
      if (trimmed.charAt(i) === ':') {
        colonCount++;
      }
    }
    const isLikelyIPv6 = colonCount >= 2;
  
    if (isLikelyIPv6) {
      // IPv6 address handling
      if (trimmed.startsWith('[')) {
        // Format: [::1] or [::1]:47989
        const closeBracket = trimmed.indexOf(']');
        if (closeBracket > 0) {
          result.host = trimmed.substring(1, closeBracket);
          if (closeBracket < trimmed.length - 1 && trimmed.charAt(closeBracket + 1) === ':') {
            const portStr = trimmed.substring(closeBracket + 2);
            const port = parseInt(portStr);
            if (port > 0 && port <= MAX_PORT) {
              result.port = port;
            }
          }
          return result;
        }
      } else {
        // Bare IPv6 address (no brackets), like ::1 or fe80::1
        // Note: Bare IPv6 addresses cannot unambiguously separate port (address itself contains colons)
        // Only [addr]:port format can specify IPv6 + port
        // So use the entire string as hostname
        result.host = trimmed;
        return result;
      }
    } else {
      // IPv4 or hostname
      const colonIndex = trimmed.indexOf(':');
      if (colonIndex > 0) {
        // Format: 192.168.1.100:47989
        const host = trimmed.substring(0, colonIndex);
        const portStr = trimmed.substring(colonIndex + 1);
        const port = parseInt(portStr);
        if (port > 0 && port <= MAX_PORT) {
          result.host = host;
          result.port = port;
          return result;
        }
      }
    }
  
    // Default: no port
    result.host = trimmed;
    return result;
  }

  /**
   * Internal add computer method
   * If computer with this UUID already exists, merge update instead of replace, preserving serverCert and pairing info
   */
  private async addComputerInternal(address: string, discoveredName?: string, httpPort?: number): Promise<ComputerInfo> {
    const nvHttp = new NvHttp(address, null, this.context || undefined, httpPort);
  
    try {
      // Get server info
      const serverInfo = await nvHttp.getServerInfo();
  
      // Use local address returned by server, or connection address if not available
      const localAddr = serverInfo.localAddress || address;
      const remoteAddr = serverInfo.externalAddress || '';
  
      // Check if connection address is IPv6 (contains at least 2 colons)
      const isIPv6 = address.includes(':') && address.split(':').length > 2;
  
      // Check if computer with same UUID already exists
      const existing = this.computers.get(serverInfo.uniqueId);
      if (existing) {
        // Merge update: preserve existing pairing info, update address and state
        existing.name = serverInfo.hostname || existing.name;
        existing.address = address;
        existing.localAddress = localAddr;
        if (remoteAddr) {
          existing.remoteAddress = remoteAddr;
        }
        if (isIPv6) {
          existing.ipv6Address = address;
        }
        if (serverInfo.macAddress) {
          existing.macAddress = serverInfo.macAddress;
        }
        existing.state = ComputerState.ONLINE;
        existing.runningGameId = serverInfo.currentGame || 0;
        if (httpPort) {
          existing.httpPort = httpPort;
        }
        // Key: preserve serverCert and pairState (if already paired)
        // Only update pairing state when server explicitly returns paired=true
        if (serverInfo.paired) {
          existing.pairState = PairState.PAIRED;
        }
        // If existing.serverCert already has value, don't overwrite
        // serverCert can only be obtained through pairing process
  
        console.info(`ComputerManager: Merged update for existing computer ${existing.name} (${existing.uuid}), preserving pairing info`);
        this.computers.set(existing.uuid, existing);
        await this.saveComputers();
        return existing;
      }
  
      // New computer, create new entry
      const computer = new ComputerInfoBuilder()
        .setUuid(serverInfo.uniqueId)
        .setName(serverInfo.hostname || discoveredName || address)
        .setAddress(address) // Keep original connection address
        .setLocalAddress(localAddr) // Local address returned by server
        .setRemoteAddress(remoteAddr) // External address returned by server
        .setIpv6Address(isIPv6 ? address : undefined) // If connection address is IPv6, store it
        .setMacAddress(serverInfo.macAddress || '')
        .setState(ComputerState.ONLINE)
        .setPairState(serverInfo.paired ? PairState.PAIRED : PairState.NOT_PAIRED)
        .setRunningGameId(serverInfo.currentGame || 0)
        .setHttpPort(httpPort) // Save custom port
        .build();
  
      this.computers.set(computer.uuid, computer);
      await this.saveComputers();
  
      console.info(`ComputerManager: Successfully added computer ${computer.name} (${computer.uuid}), localAddr=${localAddr}, remoteAddr=${remoteAddr}`);
      return computer;
    } catch (err) {
      // If unable to get server info, still add but mark as offline
      if (discoveredName) {
        const computer = new ComputerInfoBuilder()
          .setUuid(`discovered-${Date.now()}`)
          .setName(discoveredName)
          .setAddress(address)
          .setLocalAddress(address)
          .setState(ComputerState.UNKNOWN)
          .setPairState(PairState.NOT_PAIRED)
          .build();
  
        this.computers.set(computer.uuid, computer);
        console.info(`ComputerManager: Added unconfirmed computer ${computer.name}`);
        return computer;
      }
      throw new Error(`Cannot connect to ${address}: ${err}`);
    }
  }

  /**
   * Remove computer
   */
  async removeComputer(uuid: string): Promise<void> {
    this.computers.delete(uuid);
    await this.saveComputers();
  }

  // Polling & Network Listener
  
  /**
   * Refresh all computer status
   * Parallel polling, notify UI immediately after each completes
   */
  async refreshAllComputers(): Promise<void> {
    try {
      await Promise.all(
        Array.from(this.computers.values()).map(async (computer) => {
          try {
            // Offline backoff: more consecutive offline count, more polling rounds skipped
            const streak = this.offlineStreak.get(computer.uuid) ?? 0;
            if (streak > 0) {
              // streak=1 -> poll every 2 rounds, streak>=3 -> poll every 4 rounds (max)
              const skipInterval = Math.min(streak + 1, 4);
              // Use streak itself as counter, only poll when divisible
              this.offlineStreak.set(computer.uuid, streak + 1);
              if (streak % skipInterval !== 0) {
                return; // Skip this round
              }
            }
  
            const online = await this.pollComputer(computer);
            if (online) {
              this.offlineStreak.delete(computer.uuid);
            } else {
              this.offlineStreak.set(computer.uuid, (this.offlineStreak.get(computer.uuid) ?? 0) || 1);
            }
          } catch {
            computer.state = ComputerState.OFFLINE;
            this.offlineStreak.set(computer.uuid, (this.offlineStreak.get(computer.uuid) ?? 0) + 1);
          }
          this.notifyListChanged();
        })
      );
    } catch (err) {
      console.error('ComputerManager: refreshAllComputers error:', err);
      this.computers.forEach(computer => {
        if (computer.state === ComputerState.UNKNOWN) {
          computer.state = ComputerState.OFFLINE;
        }
      });
      this.notifyListChanged();
    }
  }

  startPolling(): void {
    if (this.isPollingActive) {
      return;
    }
    
    this.isPollingActive = true;
    console.info('ComputerManager: 启动状态轮询');
    
    this.refreshAllComputers().catch((err: Error) => {
      console.warn('ComputerManager: 初始刷新失败', err);
    });
    
    this.pollingTimerId = setInterval(async () => {
      if (!this.isPollingActive) {
        return;
      }
      
      await this.refreshAllComputers();
    }, SERVERINFO_POLLING_PERIOD_MS);
  }
  
  private registerNetworkListener(): void {
    try {
      this.netConnection = connection.createNetConnection();

      this.netConnection.on('netAvailable', () => {
        console.info('ComputerManager: 网络变为可用，重置并重新轮询');
        this.computers.forEach(c => { c.state = ComputerState.UNKNOWN; });
        this.offlineStreak.clear();

        if (this.isPollingActive) {
          this.refreshAllComputers().catch((err: Error) => {
            console.warn('ComputerManager: 网络恢复后刷新失败', err);
          });
        }
        this.notifyListChanged();
      });

      this.netConnection.on('netLost', () => {
        console.info('ComputerManager: 网络丢失，标记所有 PC 为离线');
        this.computers.forEach(c => { c.state = ComputerState.OFFLINE; });
        this.notifyListChanged();
      });

      this.netConnection.register((err) => {
        if (err) {
          console.error(`ComputerManager: 注册网络监听失败: ${JSON.stringify(err)}`);
        } else {
          console.info('ComputerManager: 网络变化监听已注册');
        }
      });
    } catch (err) {
      console.error('ComputerManager: 注册网络监听异常', err);
    }
  }

  private unregisterNetworkListener(): void {
    if (this.netConnection) {
      try {
        this.netConnection.unregister((err) => {
          if (err) {
            console.error(`ComputerManager: 取消网络监听失败: ${JSON.stringify(err)}`);
          } else {
            console.info('ComputerManager: 网络变化监听已取消');
          }
        });
      } catch (err) {
        console.error('ComputerManager: 取消网络监听异常', err);
      }
      this.netConnection = null;
    }
  }

  stopPolling(): void {
    if (this.pollingTimerId !== -1) {
      console.info('ComputerManager: 停止状态轮询');
      clearInterval(this.pollingTimerId);
      this.pollingTimerId = -1;
    }
    this.isPollingActive = false;
  }

  async pollComputer(computer: ComputerInfo): Promise<boolean> {
    const addresses = this.collectAddresses(computer);
    if (addresses.length === 0) {
      computer.state = ComputerState.OFFLINE;
      return false;
    }

    console.info(`ComputerManager: 轮询 ${computer.name}，地址: ${addresses.join(', ')}`);

    const successResult = await this.raceForFirstSuccess(
      addresses.map(addr => this.tryPollAddress(addr, computer))
    );

    if (successResult?.serverInfo) {
      this.updateComputerFromPoll(computer, successResult);
      return true;
    }

    computer.state = ComputerState.OFFLINE;
    console.info(`ComputerManager: ${computer.name} 所有地址均无法连接`);
    return false;
  }

  private collectAddresses(computer: ComputerInfo): string[] {
    const addressSet = new Set<string>();
    if (computer.manualAddress) addressSet.add(computer.manualAddress);
    if (computer.address) addressSet.add(computer.address);
    if (computer.localAddress) addressSet.add(computer.localAddress);
    if (computer.remoteAddress) addressSet.add(computer.remoteAddress);
    if (computer.ipv6Address) addressSet.add(computer.ipv6Address);
    return Array.from(addressSet);
  }

  private async tryPollAddress(address: string, computer: ComputerInfo): Promise<PollResult> {
    try {
      const nvHttp = new NvHttp(address, computer.serverCert, this.context || undefined, computer.httpPort);
      const serverInfo = await nvHttp.getServerInfo();
      return { address, serverInfo };
    } catch (err) {
      return { address, serverInfo: null };
    }
  }

  /**
   *
   */
  private raceForFirstSuccess(promises: Promise<PollResult>[]): Promise<PollResult | null> {
    const LAN_WAIT_MS = 300;

    return new Promise<PollResult | null>((resolve) => {
      let completedCount = 0;
      let hasResolved = false;
      let firstSuccessResult: PollResult | null = null;
      let lanWaitTimerId: number = -1;

      const tryResolve = (result: PollResult) => {
        if (hasResolved) return;
        hasResolved = true;
        if (lanWaitTimerId !== -1) {
          clearTimeout(lanWaitTimerId);
          lanWaitTimerId = -1;
        }
        resolve(result);
      };

      const checkAllDone = () => {
        if (completedCount === promises.length && !hasResolved) {
          hasResolved = true;
          if (lanWaitTimerId !== -1) {
            clearTimeout(lanWaitTimerId);
            lanWaitTimerId = -1;
          }
          resolve(firstSuccessResult);
        }
      };

      for (const p of promises) {
        p.then((result: PollResult) => {
          if (result.serverInfo !== null && !hasResolved) {
            if (isLanAddress(result.address)) {
              tryResolve(result);
              return;
            }
            if (!firstSuccessResult) {
              firstSuccessResult = result;
              lanWaitTimerId = setTimeout(() => {
                if (!hasResolved && firstSuccessResult) {
                  tryResolve(firstSuccessResult);
                }
              }, LAN_WAIT_MS);
            }
          }
          completedCount++;
          checkAllDone();
        }).catch(() => {
          completedCount++;
          checkAllDone();
        });
      }
    });
  }

  private updateComputerFromPoll(computer: ComputerInfo, result: PollResult): void {
    const info = result.serverInfo!;

    let target = computer;
    if (info.uniqueId && computer.uuid !== info.uniqueId) {
      target = this.reconcileUuid(computer, info.uniqueId);
    }

    if (info.hostname) {
      target.name = info.hostname;
    }

    target.state = ComputerState.ONLINE;
    target.address = result.address;
    target.runningGameId = info.currentGame;
    
    if (info.macAddress && info.macAddress !== '00:00:00:00:00:00') {
      target.macAddress = info.macAddress;
    }
    
    if (info.localAddress) target.localAddress = info.localAddress;
    if (info.externalAddress) target.remoteAddress = info.externalAddress;

    if (isIPv6Address(result.address)) {
      target.ipv6Address = result.address;
    }

    if (!target.ipv6Address && info.hostname) {
      this.lookupAndSetIpv6(target, info.hostname);
    }
    
    if (info.paired) {
      target.pairState = PairState.PAIRED;
    } else if (target.serverCert) {
      target.pairState = PairState.PAIRED;
    } else {
      target.pairState = PairState.NOT_PAIRED;
    }
    
    console.info(`ComputerManager: ${target.name} 在线 (${result.address}), game=${info.currentGame}, paired=${target.pairState}`);
    this.saveComputers();

    if (target.pairState === PairState.PAIRED && 
        (!target.boxArtUrl || target.boxArtUrl.startsWith('http'))) {
      this.loadFirstAppBoxArt(target, result.address);
    }
  }

  /**
   *
   */
  private lookupAndSetIpv6(computer: ComputerInfo, hostname: string): void {
    const tryLookup = async (host: string): Promise<string | undefined> => {
      try {
        const addresses = await connection.getAddressesByName(host);
        const ipv6List: string[] = [];
        for (const addr of addresses) {
          if (addr.family === 2 && addr.address) {
            ipv6List.push(addr.address);
          }
        }
        return getBestIpv6Address(ipv6List);
      } catch (_err) {
        return undefined;
      }
    };

    tryLookup(hostname).then((ipv6: string | undefined) => {
      if (ipv6) {
        computer.ipv6Address = ipv6;
        console.info(`ComputerManager: 为 ${computer.name} 补充 IPv6 地址: ${ipv6}`);
        this.saveComputers();
        return;
      }
      return tryLookup(`${hostname}.local`);
    }).then((ipv6: string | undefined) => {
      if (ipv6) {
        computer.ipv6Address = ipv6;
        console.info(`ComputerManager: 为 ${computer.name} 补充 IPv6 地址 (.local): ${ipv6}`);
        this.saveComputers();
      }
    }).catch(() => {
    });
  }

  private async loadFirstAppBoxArt(computer: ComputerInfo, address: string): Promise<void> {
    try {
      const nvHttp = new NvHttp(address, computer.serverCert, this.context || undefined, computer.httpPort);
      const apps = await nvHttp.getAppList();
      if (apps.length > 0) {
        const cachedPath = await nvHttp.getAppAssetCached(apps[0].id);
        if (cachedPath) {
          computer.boxArtUrl = cachedPath;
          console.info(`ComputerManager: ${computer.name} 已设置 boxArt 本地路径: ${cachedPath}`);
          await this.saveComputers();
          this.notifyListChanged();
        } else {
          console.warn(`ComputerManager: ${computer.name} 无法缓存 boxArt`);
        }
      }
    } catch (err) {
      console.warn(`ComputerManager: 无法获取 ${computer.name} 的 boxArt: ${err}`);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════════════

  async scanNetwork(): Promise<void> {
    if (!this.mdnsDiscovery) {
      console.error('ComputerManager: mDNS 发现服务未初始化');
      return;
    }

    try {
      const discovered = await this.mdnsDiscovery.discover(5000);
      console.info(`ComputerManager: mDNS 扫描完成，发现 ${discovered.length} 台电脑`);
    } catch (err) {
      console.error('ComputerManager: 网络扫描失败', err);
    }
  }

  startBackgroundScan(): void {
    if (!this.mdnsDiscovery) {
      return;
    }

    this.mdnsDiscovery.startDiscovery().catch((err: Error) => {
      console.error('ComputerManager: 后台扫描启动失败', err);
    });
  }

  stopBackgroundScan(): void {
    if (this.mdnsDiscovery) {
      this.mdnsDiscovery.stopDiscovery();
    }
  }

  async pairComputer(uuid: string): Promise<string> {
    const computer = this.computers.get(uuid);
    if (!computer) {
      throw new Error('电脑不存在');
    }

    const pin = this.generatePin();
    computer.pairState = PairState.NOT_PAIRED;

    try {
      const pairingManager = new PairingManager(
        selectBestAddress(computer), computer.uuid, this.context || undefined, computer.httpPort
      );
      const result = await pairingManager.pair(pin);

      if (result.state === PMPairState.PAIRED) {
        computer.pairState = PairState.PAIRED;
        if (result.serverCert) {
          const buf = buffer.from(result.serverCert);
          computer.serverCert = buf.toString('base64');
        }
        computer.pairName = result.pairName || '';
        await this.saveComputers();
        return pin;
      } else if (result.state === PMPairState.PIN_WRONG) {
        computer.pairState = PairState.FAILED;
        throw new Error('PIN 码错误');
      } else if (result.state === PMPairState.ALREADY_IN_PROGRESS) {
        computer.pairState = PairState.FAILED;
        throw new Error('另一个设备正在配对中');
      } else {
        computer.pairState = PairState.FAILED;
        throw new Error(`配对失败: ${result.state}`);
      }
    } catch (err) {
      if (computer.pairState !== PairState.FAILED) {
        computer.pairState = PairState.FAILED;
      }
      if (err instanceof Error) {
        throw err;
      }
      throw new Error(`配对失败: ${err}`);
    }
  }

  async unpairComputer(uuid: string): Promise<void> {
    const computer = this.computers.get(uuid);
    if (!computer) {
      throw new Error('电脑不存在');
    }

    const nvHttp = new NvHttp(selectBestAddress(computer), computer.serverCert, this.context || undefined, computer.httpPort);
    await nvHttp.unpair();
    
    computer.pairState = PairState.NOT_PAIRED;
    computer.serverCert = '';
    await this.saveComputers();
  }

  async wakeComputer(uuid: string): Promise<void> {
    const computer = this.computers.get(uuid);
    if (!computer || !computer.macAddress) {
      throw new Error('无法唤醒：缺少 MAC 地址');
    }

    await WakeOnLan.sendWolToAddresses(
      computer.macAddress,
      this.collectAddresses(computer),
      computer.httpPort || NvHttp.DEFAULT_HTTP_PORT
    );
  }

  private generatePin(): string {
    const randomBytes = CryptoUtil.generateRandomBytes(4);
    let pin = '';
    for (let i = 0; i < 4; i++) {
      pin += (randomBytes[i] % 10).toString();
    }
    return pin;
  }

  // ═══════════════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════════════

  async saveComputers(): Promise<void> {
    await ComputerPersistence.saveComputers(this.computers);
  }
}
