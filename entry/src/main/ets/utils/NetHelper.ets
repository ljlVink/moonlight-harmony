/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

/**
 *
 */

export enum AddressType {
  /**
  LAN_IPV4 = 'LAN_IPV4',
  /** IPv6 link-local (fe80::/10) */
  IPV6_LINK_LOCAL = 'IPV6_LINK_LOCAL',
  /**
  IPV6_ULA = 'IPV6_ULA',
  /**
  IPV6_GLOBAL = 'IPV6_GLOBAL',
  /**
  IPV6_TUNNEL = 'IPV6_TUNNEL',
  /**
  WAN = 'WAN',
  /**
  LOOPBACK = 'LOOPBACK',
  /**
  UNKNOWN = 'UNKNOWN',
}

function parseIPv4(address: string): number[] | null {
  const parts = address.split('.');
  if (parts.length !== 4) {
    return null;
  }
  const bytes: number[] = [];
  for (const part of parts) {
    const n = parseInt(part, 10);
    if (isNaN(n) || n < 0 || n > 255 || part !== n.toString()) {
      return null;
    }
    bytes.push(n);
  }
  return bytes;
}

/**
 *
 * - 10.0.0.0/8
 * - 172.16.0.0/12  (172.16.0.0 – 172.31.255.255)
 * - 192.168.0.0/16
 *
 */
export function isPrivateIPv4(address: string): boolean {
  const bytes = parseIPv4(address);
  if (!bytes) {
    return false;
  }
  // 10.0.0.0/8
  if (bytes[0] === 10) {
    return true;
  }
  // 172.16.0.0/12
  if (bytes[0] === 172 && bytes[1] >= 16 && bytes[1] <= 31) {
    return true;
  }
  // 192.168.0.0/16
  if (bytes[0] === 192 && bytes[1] === 168) {
    return true;
  }
  return false;
}

export function isLoopbackIPv4(address: string): boolean {
  const bytes = parseIPv4(address);
  return bytes !== null && bytes[0] === 127;
}

export function isLinkLocalIPv4(address: string): boolean {
  const bytes = parseIPv4(address);
  return bytes !== null && bytes[0] === 169 && bytes[1] === 254;
}

export function isIPv4Address(address: string): boolean {
  return parseIPv4(address) !== null;
}

function normalizeIPv6(address: string): string {
  let addr = address;
  if (addr.startsWith('[') && addr.includes(']')) {
    addr = addr.substring(1, addr.indexOf(']'));
  }
  const pctIdx = addr.indexOf('%');
  if (pctIdx !== -1) {
    addr = addr.substring(0, pctIdx);
  }
  return addr.toLowerCase();
}

export function isIPv6Address(address: string): boolean {
  if (!address) {
    return false;
  }
  let colonCount = 0;
  for (const c of address) {
    if (c === ':') {
      colonCount++;
    }
  }
  return colonCount >= 2;
}

/**
 *
 */
export function isIPv6LinkLocal(address: string): boolean {
  if (!isIPv6Address(address)) {
    return false;
  }
  const addr = normalizeIPv6(address);
  return addr.startsWith('fe80:') || addr.startsWith('fe80%') || addr === 'fe80' ||
    addr.startsWith('fe9') || addr.startsWith('fea') || addr.startsWith('feb');
}

export function isIPv6ULA(address: string): boolean {
  if (!isIPv6Address(address)) {
    return false;
  }
  const addr = normalizeIPv6(address);
  return addr.startsWith('fc') || addr.startsWith('fd');
}

/**
 *
 */
export function isIPv6SiteLocal(address: string): boolean {
  if (!isIPv6Address(address)) {
    return false;
  }
  const addr = normalizeIPv6(address);
  return addr.startsWith('fec') || addr.startsWith('fed') || addr.startsWith('fee') || addr.startsWith('fef');
}

export function isIPv6_6to4(address: string): boolean {
  if (!isIPv6Address(address)) {
    return false;
  }
  const addr = normalizeIPv6(address);
  return addr.startsWith('2002:');
}

export function isIPv6Teredo(address: string): boolean {
  if (!isIPv6Address(address)) {
    return false;
  }
  const addr = normalizeIPv6(address);
  return addr.startsWith('2001:0000:') || addr.startsWith('2001:0:');
}

export function isIPv6Loopback(address: string): boolean {
  if (!isIPv6Address(address)) {
    return false;
  }
  const addr = normalizeIPv6(address);
  return addr === '::1' || addr === '0000:0000:0000:0000:0000:0000:0000:0001';
}

/**
 *
 *   addr.isSiteLocalAddress() || addr.isLoopbackAddress() || isPrivateAddress(addr)
 */
export function isLanAddress(addressStr: string | undefined | null): boolean {
  if (!addressStr) {
    return false;
  }

  const address = stripPort(addressStr);

  if (isIPv4Address(address)) {
    return isPrivateIPv4(address) || isLoopbackIPv4(address) || isLinkLocalIPv4(address);
  }

  if (isIPv6Address(address)) {
    return isIPv6LinkLocal(address) || isIPv6ULA(address) || isIPv6SiteLocal(address) || isIPv6Loopback(address);
  }

  return false;
}

/**
 *
 */
export function isPublicAddress(addressStr: string | undefined | null): boolean {
  if (!addressStr) {
    return false;
  }
  const address = stripPort(addressStr);

  if (isIPv4Address(address)) {
    return !isPrivateIPv4(address) && !isLoopbackIPv4(address) && !isLinkLocalIPv4(address);
  }

  if (isIPv6Address(address)) {
    return !isIPv6LinkLocal(address) && !isIPv6ULA(address) && !isIPv6SiteLocal(address) &&
      !isIPv6Loopback(address) && !isIPv6_6to4(address) && !isIPv6Teredo(address);
  }

  return false;
}

/**
 *
 */
export function isLanIPv4Address(addressStr: string | undefined | null): boolean {
  if (!addressStr) {
    return false;
  }
  const address = stripPort(addressStr);
  if (!isIPv4Address(address)) {
    return false;
  }
  return isPrivateIPv4(address) || isLoopbackIPv4(address) || isLinkLocalIPv4(address);
}

export function detectAddressType(addressStr: string | undefined | null): AddressType {
  if (!addressStr) {
    return AddressType.UNKNOWN;
  }
  const address = stripPort(addressStr);

  // IPv4
  if (isIPv4Address(address)) {
    if (isLoopbackIPv4(address)) {
      return AddressType.LOOPBACK;
    }
    if (isPrivateIPv4(address) || isLinkLocalIPv4(address)) {
      return AddressType.LAN_IPV4;
    }
    return AddressType.WAN;
  }

  // IPv6
  if (isIPv6Address(address)) {
    if (isIPv6Loopback(address)) {
      return AddressType.LOOPBACK;
    }
    if (isIPv6LinkLocal(address)) {
      return AddressType.IPV6_LINK_LOCAL;
    }
    if (isIPv6ULA(address) || isIPv6SiteLocal(address)) {
      return AddressType.IPV6_ULA;
    }
    if (isIPv6_6to4(address) || isIPv6Teredo(address)) {
      return AddressType.IPV6_TUNNEL;
    }
    return AddressType.IPV6_GLOBAL;
  }

  return AddressType.UNKNOWN;
}

export function getAddressTypeLabel(addressStr: string | undefined | null): string {
  const type = detectAddressType(addressStr);
  switch (type) {
    case AddressType.LAN_IPV4:
      return '局域网';
    case AddressType.IPV6_LINK_LOCAL:
      return 'IPv6 链路本地';
    case AddressType.IPV6_ULA:
      return 'IPv6 局域网';
    case AddressType.IPV6_GLOBAL:
      return 'IPv6 公网';
    case AddressType.IPV6_TUNNEL:
      return 'IPv6 隧道';
    case AddressType.WAN:
      return '远程网络';
    case AddressType.LOOPBACK:
      return '本机环回';
    default:
      return '未知';
  }
}

/**
 *
 *
 *
 */
export function getBestIpv6Address(addresses: string[]): string | undefined {
  for (const addr of addresses) {
    if (!isIPv6Address(addr)) continue;
    const type = detectAddressType(addr);
    if (type === AddressType.IPV6_GLOBAL) {
      return addr;
    }
  }
  return undefined;
}

export function isIPv6Global(address: string): boolean {
  return detectAddressType(address) === AddressType.IPV6_GLOBAL;
}

/**
 *       "[fe80::1]:47989"   -> "fe80::1"
 *       "fe80::1%eth0"      -> "fe80::1"
 */
function stripPort(addressStr: string): string {
  let addr = addressStr.trim();

  if (addr.startsWith('[')) {
    const closeBracket = addr.indexOf(']');
    if (closeBracket !== -1) {
      addr = addr.substring(1, closeBracket);
    }
  } else if (isIPv6Address(addr)) {
    return normalizeIPv6(addr);
  } else {
    const colonIdx = addr.lastIndexOf(':');
    if (colonIdx !== -1) {
      const possiblePort = addr.substring(colonIdx + 1);
      const portNum = parseInt(possiblePort, 10);
      if (!isNaN(portNum) && portNum > 0 && portNum <= 65535 && possiblePort === portNum.toString()) {
        addr = addr.substring(0, colonIdx);
      }
    }
  }

  const pctIdx = addr.indexOf('%');
  if (pctIdx !== -1) {
    addr = addr.substring(0, pctIdx);
  }

  return addr;
}
