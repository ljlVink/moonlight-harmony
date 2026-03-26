/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import socket from '@ohos.net.socket';
import { NvHttp } from './NvHttp';

interface SendResult {
  sent: number;
  errors: number;
}


export class WakeOnLan {
  private static readonly STATIC_PORTS: number[] = [
    9,
    47009,
  ];
  private static readonly DYNAMIC_PORT_BASES: number[] = [
    47998, 47999, 48000, 48002, 48010,
  ];
  
  private static readonly DEFAULT_HTTP_PORT = NvHttp.DEFAULT_HTTP_PORT;
  private static readonly MAGIC_PACKET_SIZE = 102;  // 6 + 16 * 6
  private static readonly MAC_BYTES = 6;
  private static readonly MAC_REPETITIONS = 16;
  private static readonly ZERO_MAC = '00:00:00:00:00:00';

  static async sendWolPacket(macAddress: string, address: string, httpPort: number = WakeOnLan.DEFAULT_HTTP_PORT): Promise<void> {
    WakeOnLan.validateMacAddress(macAddress);
    
    const payload = WakeOnLan.createMagicPacket(macAddress);
    const isIPv6 = WakeOnLan.isIPv6Address(address);
    
    const udpSocket = socket.constructUDPSocketInstance();
    try {
      await WakeOnLan.bindSocket(udpSocket, isIPv6);
      
      if (!isIPv6) {
        await WakeOnLan.enableBroadcast(udpSocket);
        await WakeOnLan.sendToAllPorts(udpSocket, '255.255.255.255', httpPort, payload, false);
      }
      
      await WakeOnLan.sendToAllPorts(udpSocket, address, httpPort, payload, isIPv6);
    } finally {
      udpSocket.close();
    }
  }


  static async sendWolToAddresses(macAddress: string, addresses: string[], httpPort: number = WakeOnLan.DEFAULT_HTTP_PORT): Promise<void> {
    WakeOnLan.validateMacAddress(macAddress);
    
    if (addresses.length === 0) {
      addresses = ['255.255.255.255'];
    }
    
    const payload = WakeOnLan.createMagicPacket(macAddress);
    
    const allAddresses = new Set<string>();
    allAddresses.add('255.255.255.255');
    
    for (const addr of addresses) {
      if (!WakeOnLan.isIPv6Address(addr)) {
        allAddresses.add(addr);
        const subnetBroadcast = WakeOnLan.getSubnetBroadcast(addr);
        if (subnetBroadcast) {
          allAddresses.add(subnetBroadcast);
        }
      } else {
        allAddresses.add(addr);
      }
    }
    
    const addressArray = Array.from(allAddresses);
    const ipv4Addresses = addressArray.filter(addr => !WakeOnLan.isIPv6Address(addr));
    const ipv6Addresses = addressArray.filter(addr => WakeOnLan.isIPv6Address(addr));
    
    if (ipv4Addresses.length > 0) {
      const udpSocket = socket.constructUDPSocketInstance();
      try {
        await WakeOnLan.bindSocket(udpSocket, false);
        await WakeOnLan.enableBroadcast(udpSocket);
        
        for (const addr of ipv4Addresses) {
          await WakeOnLan.sendToAllPorts(udpSocket, addr, httpPort, payload, false);
        }
      } finally {
        udpSocket.close();
      }
    }
    
    if (ipv6Addresses.length > 0) {
      const udpSocket = socket.constructUDPSocketInstance();
      try {
        await WakeOnLan.bindSocket(udpSocket, true);
        
        for (const addr of ipv6Addresses) {
          await WakeOnLan.sendToAllPorts(udpSocket, addr, httpPort, payload, true);
        }
      } finally {
        udpSocket.close();
      }
    }
  }
  
  private static getSubnetBroadcast(ipv4Address: string): string | null {
    const parts = ipv4Address.split('.');
    if (parts.length !== 4) {
      return null;
    }
    parts[3] = '255';
    return parts.join('.');
  }

  private static validateMacAddress(macAddress: string): void {
    if (!macAddress || macAddress === WakeOnLan.ZERO_MAC) {
      throw new Error('MAC 地址无效，无法发送 WOL 包');
    }
  }

  private static isIPv6Address(address: string): boolean {
    return address.includes(':') && (address.split(':').length > 2 || address.startsWith('['));
  }

  private static getSocketFamily(isIPv6: boolean): number {
    return isIPv6 ? 2 : 1;  // IPv4=1, IPv6=2
  }

  private static async bindSocket(udpSocket: socket.UDPSocket, isIPv6: boolean): Promise<void> {
    await udpSocket.bind({
      address: isIPv6 ? '::' : '0.0.0.0',
      port: 0,
      family: WakeOnLan.getSocketFamily(isIPv6)
    });
  }

  private static async enableBroadcast(udpSocket: socket.UDPSocket): Promise<void> {
    try {
      await udpSocket.setExtraOptions({ broadcast: true });
    } catch {
    }
  }

  private static async sendToAllPorts(
    udpSocket: socket.UDPSocket,
    address: string,
    httpPort: number,
    payload: ArrayBuffer,
    isIPv6: boolean
  ): Promise<SendResult> {
    const family = WakeOnLan.getSocketFamily(isIPv6);
    const allPorts = WakeOnLan.getAllPorts(httpPort);
    let sent = 0;
    let errors = 0;
    
    for (const port of allPorts) {
      try {
        const destAddr: socket.NetAddress = {
          address: address,
          port: port,
          family: family
        };
        await udpSocket.send({
          data: payload,
          address: destAddr
        });
        sent++;
      } catch {
        errors++;
      }
    }
    
    const result: SendResult = { sent: sent, errors: errors };
    return result;
  }

  private static getAllPorts(httpPort: number): number[] {
    const ports = [...WakeOnLan.STATIC_PORTS];
    const portOffset = httpPort - WakeOnLan.DEFAULT_HTTP_PORT;
    
    for (const basePort of WakeOnLan.DYNAMIC_PORT_BASES) {
      ports.push(basePort + portOffset);
    }
    
    return ports;
  }

  private static createMagicPacket(macAddress: string): ArrayBuffer {
    const macBytes = WakeOnLan.parseMacAddress(macAddress);
    const payload = new Uint8Array(WakeOnLan.MAGIC_PACKET_SIZE);
    
    payload.fill(0xFF, 0, WakeOnLan.MAC_BYTES);
    
    for (let i = 0; i < WakeOnLan.MAC_REPETITIONS; i++) {
      const offset = WakeOnLan.MAC_BYTES + i * WakeOnLan.MAC_BYTES;
      payload.set(macBytes, offset);
    }
    
    return payload.buffer;
  }

  private static parseMacAddress(macAddress: string): Uint8Array {
    const macBytes = new Uint8Array(WakeOnLan.MAC_BYTES);
    const parts = macAddress.split(/[:\-]/);
    
    for (let i = 0; i < WakeOnLan.MAC_BYTES && i < parts.length; i++) {
      const value = parseInt(parts[i], 16);
      macBytes[i] = isNaN(value) ? 0 : value;
    }
    
    return macBytes;
  }

  static isValidMacAddress(macAddress: string): boolean {
    return /^([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}$/.test(macAddress);
  }
}
