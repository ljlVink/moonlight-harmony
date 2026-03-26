/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { isLanIPv4Address, isLanAddress, isIPv6Address, isPublicAddress, detectAddressType, AddressType, getAddressTypeLabel } from '../utils/NetHelper';

export enum ComputerState {
  UNKNOWN = 0,
  ONLINE = 1,
  OFFLINE = 2,
  PAIRING = 3
}

export enum PairState {
  NOT_PAIRED = 0,
  PAIRED = 1,
  PIN_WRONG = 2,
  FAILED = 3
}

export interface Resolution {
  width: number;
  height: number;
}

export interface AddressHolder {
  address: string;
  localAddress: string;
  remoteAddress: string;
  manualAddress?: string;
  ipv6Address?: string;
}

export interface ComputerInfo extends AddressHolder {
  uuid: string;
  name: string;
  macAddress: string;
  state: ComputerState;
  pairState: PairState;
  runningGameId: number;
  serverCert: string;
  pairName: string;
  gpuType: string;
  maxSupportedResolution: Resolution;
  isNvidiaSoftware: boolean;
  boxArtUrl?: string;
  httpPort?: number;
}

export function selectBestAddress(computer: AddressHolder): string {
  if (computer.address) {
    return computer.address;
  }

  if (computer.manualAddress) return computer.manualAddress;

  if (computer.localAddress && isLanIPv4Address(computer.localAddress)) {
    return computer.localAddress;
  }

  if (computer.ipv6Address && isLanAddress(computer.ipv6Address)) {
    return computer.ipv6Address;
  }

  if (computer.localAddress) return computer.localAddress;

  if (computer.ipv6Address) return computer.ipv6Address;

  if (computer.remoteAddress) return computer.remoteAddress;

  return '';
}

export function getAddressNetworkLabel(address: string | undefined): string {
  return getAddressTypeLabel(address);
}

export function hasLanAddress(computer: ComputerInfo): boolean {
  return isLanAddress(computer.localAddress) ||
    isLanAddress(computer.address) ||
    isLanAddress(computer.manualAddress);
}

export class ComputerInfoBuilder {
  private info: ComputerInfo;

  constructor() {
    this.info = {
      uuid: '',
      name: '',
      address: '',
      localAddress: '',
      remoteAddress: '',
      manualAddress: undefined,
      ipv6Address: undefined,
      macAddress: '',
      state: ComputerState.UNKNOWN,
      pairState: PairState.NOT_PAIRED,
      runningGameId: 0,
      serverCert: '',
      pairName: '',
      gpuType: '',
      maxSupportedResolution: { width: 1920, height: 1080 },
      isNvidiaSoftware: false,
      boxArtUrl: '',
      httpPort: undefined
    };
  }

  setUuid(uuid: string): ComputerInfoBuilder {
    this.info.uuid = uuid;
    return this;
  }

  setName(name: string): ComputerInfoBuilder {
    this.info.name = name;
    return this;
  }

  setAddress(address: string): ComputerInfoBuilder {
    this.info.address = address;
    return this;
  }

  setLocalAddress(localAddress: string): ComputerInfoBuilder {
    this.info.localAddress = localAddress;
    return this;
  }

  setRemoteAddress(remoteAddress: string): ComputerInfoBuilder {
    this.info.remoteAddress = remoteAddress;
    return this;
  }

  setManualAddress(manualAddress: string | undefined): ComputerInfoBuilder {
    this.info.manualAddress = manualAddress;
    return this;
  }

  setIpv6Address(ipv6Address: string | undefined): ComputerInfoBuilder {
    this.info.ipv6Address = ipv6Address;
    return this;
  }

  setMacAddress(macAddress: string): ComputerInfoBuilder {
    this.info.macAddress = macAddress;
    return this;
  }

  setState(state: ComputerState): ComputerInfoBuilder {
    this.info.state = state;
    return this;
  }

  setPairState(pairState: PairState): ComputerInfoBuilder {
    this.info.pairState = pairState;
    return this;
  }

  setRunningGameId(gameId: number): ComputerInfoBuilder {
    this.info.runningGameId = gameId;
    return this;
  }

  setServerCert(cert: string): ComputerInfoBuilder {
    this.info.serverCert = cert;
    return this;
  }

  setPairName(pairName: string): ComputerInfoBuilder {
    this.info.pairName = pairName;
    return this;
  }

  setGpuType(gpuType: string): ComputerInfoBuilder {
    this.info.gpuType = gpuType;
    return this;
  }

  setMaxSupportedResolution(res: Resolution): ComputerInfoBuilder {
    this.info.maxSupportedResolution = res;
    return this;
  }

  setIsNvidiaSoftware(isNvidia: boolean): ComputerInfoBuilder {
    this.info.isNvidiaSoftware = isNvidia;
    return this;
  }

  setBoxArtUrl(url: string): ComputerInfoBuilder {
    this.info.boxArtUrl = url;
    return this;
  }

  setHttpPort(port: number | undefined): ComputerInfoBuilder {
    this.info.httpPort = port;
    return this;
  }

  build(): ComputerInfo {
    const result: ComputerInfo = {
      uuid: this.info.uuid,
      name: this.info.name,
      address: this.info.address,
      localAddress: this.info.localAddress,
      remoteAddress: this.info.remoteAddress,
      manualAddress: this.info.manualAddress,
      ipv6Address: this.info.ipv6Address,
      macAddress: this.info.macAddress,
      state: this.info.state,
      pairState: this.info.pairState,
      runningGameId: this.info.runningGameId,
      serverCert: this.info.serverCert,
      pairName: this.info.pairName,
      gpuType: this.info.gpuType,
      maxSupportedResolution: {
        width: this.info.maxSupportedResolution.width,
        height: this.info.maxSupportedResolution.height
      },
      isNvidiaSoftware: this.info.isNvidiaSoftware,
      boxArtUrl: this.info.boxArtUrl,
      httpPort: this.info.httpPort
    };
    return result;
  }
}
