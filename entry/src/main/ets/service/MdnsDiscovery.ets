/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { mdns } from '@kit.NetworkKit';
import { connection } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { NvHttp } from './NvHttp';
import { getBestIpv6Address } from '../utils/NetHelper';

export interface DiscoveredComputer {
  name: string;
  address: string;
  port: number;
  ipv6Address?: string;
}

/**
 *
 */
export class MdnsDiscovery {
  private static readonly SERVICE_TYPE = '_nvstream._tcp';
  private static readonly DISCOVERY_TIMEOUT = 5000;

  private discoveryService: mdns.DiscoveryService | null = null;
  private discoveredComputers: Map<string, DiscoveredComputer> = new Map();
  private isDiscovering: boolean = false;
  private context: common.Context;
  private onComputerFound: ((computer: DiscoveredComputer) => void) | null = null;

  constructor(context: common.Context) {
    this.context = context;
  }

  setOnComputerFoundListener(callback: (computer: DiscoveredComputer) => void): void {
    this.onComputerFound = callback;
  }

  async startDiscovery(): Promise<void> {
    if (this.isDiscovering) {
      console.info('MdnsDiscovery: 已经在发现中');
      return;
    }

    this.isDiscovering = true;
    this.discoveredComputers.clear();

    console.info(`MdnsDiscovery: 开始发现服务类型 ${MdnsDiscovery.SERVICE_TYPE}`);

    try {
      this.discoveryService = mdns.createDiscoveryService(
        this.context,
        MdnsDiscovery.SERVICE_TYPE
      );
      console.info('MdnsDiscovery: 发现服务已创建');

      this.discoveryService.on('serviceFound', async (serviceInfo: mdns.LocalServiceInfo) => {
        console.info(`MdnsDiscovery: [serviceFound] 原始信息: ${JSON.stringify(serviceInfo)}`);
        try {
          const resolvedInfo = await mdns.resolveLocalService(this.context, serviceInfo);
          console.info(`MdnsDiscovery: [serviceFound] 解析后: ${JSON.stringify(resolvedInfo)}`);
          await this.handleResolvedService(resolvedInfo);
        } catch (err) {
          console.error(`MdnsDiscovery: [serviceFound] 解析失败: ${err}`);
        }
      });

      this.discoveryService.on('serviceLost', async (serviceInfo: mdns.LocalServiceInfo) => {
        console.info(`MdnsDiscovery: [serviceLost] ${serviceInfo.serviceName}`);
        try {
          const resolvedInfo = await mdns.resolveLocalService(this.context, serviceInfo);
          this.discoveredComputers.delete(resolvedInfo.serviceName);
        } catch (err) {
          this.discoveredComputers.delete(serviceInfo.serviceName);
        }
      });

      this.discoveryService.on('discoveryStart', (info: mdns.DiscoveryEventInfo) => {
        console.info(`MdnsDiscovery: 发现已开始 - ${JSON.stringify(info)}`);
        if (info.errorCode !== undefined && info.errorCode !== 0) {
          console.error(`MdnsDiscovery: 发现启动失败，错误码: ${info.errorCode}`);
          this.isDiscovering = false;
          this.discoveryService?.stopSearchingMDNS();
        }
      });

      this.discoveryService.on('discoveryStop', (info: mdns.DiscoveryEventInfo) => {
        console.info(`MdnsDiscovery: 发现已停止 - ${JSON.stringify(info)}`);
      });

      console.info('MdnsDiscovery: 调用 startSearchingMDNS()');
      this.discoveryService.startSearchingMDNS();
      console.info('MdnsDiscovery: startSearchingMDNS() 已调用');

    } catch (err) {
      const error = err as BusinessError;
      console.error(`MdnsDiscovery: 启动发现失败 - ${error.code}: ${error.message}`);
      this.isDiscovering = false;
      throw new Error(`Failed to start mDNS discovery: ${error.message}`);
    }
  }

  private async handleResolvedService(resolvedInfo: mdns.LocalServiceInfo): Promise<void> {
    if (!resolvedInfo.host) {
      console.warn('MdnsDiscovery: 解析的服务没有 host 信息');
      return;
    }

    const host = resolvedInfo.host;
    const port = host.port ?? NvHttp.DEFAULT_HTTP_PORT;

    console.info(`MdnsDiscovery: 发现服务器 ${resolvedInfo.serviceName} @ ${host.address} (family=${host.family})`);

    let primaryAddress = host.address;
    let ipv6Address: string | undefined = host.family === 2 ? host.address : undefined;

    if (host.family === 1) {
      ipv6Address = await this.lookupIpv6ForHost(resolvedInfo.serviceName);
    }

    const computer: DiscoveredComputer = {
      name: resolvedInfo.serviceName,
      address: primaryAddress,
      port: port,
      ipv6Address: ipv6Address
    };

    this.discoveredComputers.set(computer.name, computer);

    if (this.onComputerFound) {
      this.onComputerFound(computer);
    }
  }

  /**
   *
   *
   */
  private async lookupIpv6ForHost(hostname: string): Promise<string | undefined> {
    try {
      const addresses = await connection.getAddressesByName(hostname);
      const ipv6List: string[] = [];
      for (const addr of addresses) {
        if (addr.family === 2 && addr.address) {
          ipv6List.push(addr.address);
        }
      }
      if (ipv6List.length > 0) {
        const best = getBestIpv6Address(ipv6List);
        if (best) {
          console.info(`MdnsDiscovery: 为 ${hostname} 找到 IPv6 全局地址: ${best}`);
          return best;
        }
      }
    } catch (_err) {
    }

    try {
      const addresses = await connection.getAddressesByName(`${hostname}.local`);
      const ipv6List: string[] = [];
      for (const addr of addresses) {
        if (addr.family === 2 && addr.address) {
          ipv6List.push(addr.address);
        }
      }
      if (ipv6List.length > 0) {
        const best = getBestIpv6Address(ipv6List);
        if (best) {
          console.info(`MdnsDiscovery: 为 ${hostname}.local 找到 IPv6 全局地址: ${best}`);
          return best;
        }
      }
    } catch (_err) {
    }

    console.info(`MdnsDiscovery: 未能为 ${hostname} 获取 IPv6 地址`);
    return undefined;
  }

  private async resolveService(serviceInfo: mdns.LocalServiceInfo): Promise<void> {
    try {
      const resolvedService = await mdns.resolveLocalService(this.context, serviceInfo);

      console.info(`MdnsDiscovery: 解析服务 ${resolvedService.serviceName}`);
      console.info(`  - 主机地址: ${resolvedService.host?.address}`);
      console.info(`  - 主机端口: ${resolvedService.host?.port}`);
      console.info(`  - 服务端口: ${resolvedService.port}`);
      console.info(`  - 完整信息: ${JSON.stringify(resolvedService)}`);

      if (resolvedService.host?.address) {
        const port = resolvedService.host?.port || resolvedService.port || NvHttp.DEFAULT_HTTP_PORT;
        
        const computer: DiscoveredComputer = {
          name: resolvedService.serviceName,
          address: resolvedService.host.address,
          port: port
        };

        if (resolvedService.host.address.includes(':')) {
          computer.ipv6Address = resolvedService.host.address;
        }

        console.info(`MdnsDiscovery: 发现电脑 ${computer.name} @ ${computer.address}:${computer.port}`);
        this.discoveredComputers.set(computer.name, computer);

        if (this.onComputerFound) {
          this.onComputerFound(computer);
        }
      }
    } catch (err) {
      const error = err as BusinessError;
      console.error(`MdnsDiscovery: 解析服务失败 - ${error.code}: ${error.message}`);
    }
  }

  stopDiscovery(): void {
    if (!this.isDiscovering || !this.discoveryService) {
      return;
    }

    console.info('MdnsDiscovery: 停止发现');

    try {
      this.discoveryService.stopSearchingMDNS();
      this.discoveryService.off('serviceFound');
      this.discoveryService.off('serviceLost');
    } catch (err) {
      console.error('MdnsDiscovery: 停止发现失败', err);
    }

    this.discoveryService = null;
    this.isDiscovering = false;
  }

  async discover(timeout: number = MdnsDiscovery.DISCOVERY_TIMEOUT): Promise<DiscoveredComputer[]> {
    await this.startDiscovery();

    await new Promise<void>((resolve: Function) => setTimeout(resolve, timeout));

    this.stopDiscovery();

    return Array.from(this.discoveredComputers.values());
  }

  getDiscoveredComputers(): DiscoveredComputer[] {
    return Array.from(this.discoveredComputers.values());
  }

  isSearching(): boolean {
    return this.isDiscovering;
  }
}
