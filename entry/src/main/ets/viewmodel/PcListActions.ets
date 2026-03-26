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
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';
import { ObservableComputer } from './ComputerViewModel';
import { ComputerManager } from '../service/ComputerManager';
import { PairingManager, PairState as PMPairState } from '../service/PairingManager';
import { NvHttp, ServerInfo } from '../service/NvHttp';
import { PairState, ComputerState, selectBestAddress, ComputerInfo } from '../model/ComputerInfo';
import { ConfirmDialogConfig, InfoDialogConfig } from '../components/ConfirmDialog';
import { AppColors } from '../common/Theme';

/**
interface AddressTestResult {
  address: string;
  reachable: boolean;
  latencyMs: number;
  serverInfo: ServerInfo | null;
  error: string;
}

export interface PcListUICallbacks {
  showConfirmDialog: (config: ConfirmDialogConfig) => void;
  showInfoDialog: (config: InfoDialogConfig) => void;
  syncViewModel: () => void;
  showPinDialog: (pin: string, computerName: string) => void;
  hidePinDialog: () => void;
}

export class PcListActions {
  private computerManager: ComputerManager;
  private ui: PcListUICallbacks;

  constructor(ui: PcListUICallbacks) {
    this.computerManager = ComputerManager.getInstance();
    this.ui = ui;
  }

  /**
  handleComputerTap(computer: ObservableComputer): void {
    if (!computer.isOnline) {
      return;
    }
    if (computer.isPaired) {
      router.pushUrl({ url: 'pages/AppListPageV2', params: { computerId: computer.uuid } });
      return;
    }
    this.pairWithComputer(computer);
  }

  /**
  async handleQuickStream(computer: ObservableComputer): Promise<void> {
    if (!computer.isOnline || !computer.isPaired) {
      promptAction.showToast({ message: '设备未就绪' });
      return;
    }
    try {
      promptAction.showToast({ message: '正在准备串流...', duration: 1000 });
      const computerInfo = this.computerManager.getComputer(computer.uuid);
      if (!computerInfo || computerInfo.pairState !== PairState.PAIRED) {
        promptAction.showToast({ message: '设备未配对' });
        return;
      }
      const context = getContext() as common.UIAbilityContext;
      const nvHttp = new NvHttp(selectBestAddress(computerInfo), computerInfo.serverCert, context, computerInfo.httpPort);
      const apps = await nvHttp.getAppList();
      if (computer.runningGameId > 0) {
        const runningApp = apps.find(a => a.id === computer.runningGameId);
        const cmdList = runningApp?.cmdList;
        router.pushUrl({
          url: 'pages/StreamPage',
          params: {
            computerId: computer.uuid,
            appId: computer.runningGameId,
            appName: runningApp?.name || '正在运行',
            cmdList: cmdList && cmdList.length > 0 ? JSON.stringify(cmdList) : undefined,
            resume: true
          }
        });
        return;
      }
      if (apps.length === 0) {
        promptAction.showToast({ message: '没有可用的应用' });
        return;
      }
      const firstApp = apps[0];
      router.pushUrl({
        url: 'pages/StreamPage',
        params: {
          computerId: computer.uuid,
          appId: firstApp.id,
          appName: firstApp.name,
          cmdList: firstApp.cmdList && firstApp.cmdList.length > 0 ? JSON.stringify(firstApp.cmdList) : undefined,
          resume: false
        }
      });
    } catch (err) {
      promptAction.showToast({ message: `启动失败: ${(err as Error).message}` });
    }
  }

  /**
  async pairWithComputer(computer: ObservableComputer): Promise<void> {
    if (!computer.isOnline) {
      promptAction.showToast({ message: '电脑离线，无法配对' });
      return;
    }
    const pin = PairingManager.generatePin();
    this.ui.showPinDialog(pin, computer.name);
    try {
      const context = getContext() as common.UIAbilityContext;
      const pairingManager = new PairingManager(selectBestAddress(computer), computer.uuid, context, computer.httpPort);
      const result = await pairingManager.pair(pin);
      this.ui.hidePinDialog();
      if (result.state === PMPairState.PAIRED) {
        let serverCertBase64 = '';
        if (result.serverCert) {
          const buf = buffer.from(result.serverCert);
          serverCertBase64 = buf.toString('base64');
        }
        await this.computerManager.updateComputer(computer.uuid, {
          pairState: PairState.PAIRED,
          serverCert: serverCertBase64,
          pairName: result.pairName || ''
        });
        this.ui.syncViewModel();
        promptAction.showToast({ message: '配对成功！' });
        router.pushUrl({ url: 'pages/AppListPageV2', params: { computerId: computer.uuid } });
      } else if (result.state === PMPairState.PIN_WRONG) {
        promptAction.showToast({ message: 'PIN 码错误，请重试' });
      } else if (result.state === PMPairState.ALREADY_IN_PROGRESS) {
        promptAction.showToast({ message: '另一个设备正在配对中' });
      } else {
        promptAction.showToast({ message: `配对失败: ${result.state}` });
      }
    } catch (error) {
      this.ui.hidePinDialog();
      promptAction.showToast({ message: `配对失败: ${(error as Error).message}` });
    }
  }

  /**
  async wakeComputer(computer: ObservableComputer): Promise<void> {
    if (!computer.macAddress || computer.macAddress === '00:00:00:00:00:00') {
      promptAction.showToast({ message: '缺少有效的 MAC 地址。请先在电脑在线时配对，以获取 MAC 地址。' });
      return;
    }
    try {
      await this.computerManager.wakeComputer(computer.uuid);
      promptAction.showToast({ message: '唤醒包已发送' });
    } catch (err) {
      promptAction.showToast({ message: `发送失败: ${err instanceof Error ? err.message : String(err)}` });
    }
  }

  /**
  quitGame(computer: ObservableComputer): void {
    if (!computer.isOnline) {
      promptAction.showToast({ message: '电脑离线，无法退出游戏' });
      return;
    }
    if (!computer.isPaired) {
      promptAction.showToast({ message: '未配对，无法退出游戏' });
      return;
    }
    if (!computer.runningGameId || computer.runningGameId <= 0) {
      promptAction.showToast({ message: '没有正在运行的游戏' });
      return;
    }
    this.ui.showConfirmDialog({
      title: '退出游戏',
      message: '确定要退出当前运行的游戏吗？',
      confirmButton: {
        text: '退出',
        color: AppColors.Error,
        onClick: async () => {
          try {
            promptAction.showToast({ message: '正在退出游戏...' });
            const context = getContext() as common.UIAbilityContext;
            const nvHttp = new NvHttp(selectBestAddress(computer), computer.serverCert || null, context, computer.httpPort);
            const success = await nvHttp.quitApp();
            if (success) {
              promptAction.showToast({ message: '游戏已退出' });
              await this.computerManager.pollComputer(computer.toComputerInfo());
              this.ui.syncViewModel();
            } else {
              promptAction.showToast({ message: '退出游戏失败' });
            }
          } catch (error) {
            promptAction.showToast({ message: `退出游戏失败: ${(error as Error).message}` });
          }
        }
      }
    });
  }

  /**
  sleepComputer(computer: ObservableComputer): void {
    if (!computer.isOnline) {
      promptAction.showToast({ message: '电脑离线，无法休眠' });
      return;
    }
    if (!computer.isPaired) {
      promptAction.showToast({ message: '未配对，无法发送休眠命令' });
      return;
    }
    this.ui.showConfirmDialog({
      title: '休眠电脑',
      message: `确定要让 "${computer.name}" 进入睡眠模式吗？`,
      confirmButton: {
        text: '休眠',
        onClick: async () => {
          try {
            promptAction.showToast({ message: '正在发送休眠命令...' });
            const context = getContext() as common.UIAbilityContext;
            const nvHttp = new NvHttp(selectBestAddress(computer), computer.serverCert || null, context, computer.httpPort);
            const success = await nvHttp.pcSleep();
            if (success) {
              promptAction.showToast({ message: '睡眠命令已发送' });
              computer.state = ComputerState.OFFLINE;
              this.ui.syncViewModel();
            } else {
              promptAction.showToast({ message: '发送睡眠命令失败' });
            }
          } catch (error) {
            promptAction.showToast({ message: `发送睡眠命令失败: ${(error as Error).message}` });
          }
        }
      }
    });
  }

  /**
  async resumeGame(computer: ObservableComputer): Promise<void> {
    try {
      const computerInfo = this.computerManager.getComputer(computer.uuid);
      if (computerInfo) {
        const context = getContext() as common.UIAbilityContext;
        const nvHttp = new NvHttp(selectBestAddress(computerInfo), computerInfo.serverCert, context, computerInfo.httpPort);
        const apps = await nvHttp.getAppList();
        const runningApp = apps.find(a => a.id === computer.runningGameId);
        const cmdList = runningApp?.cmdList;
        router.pushUrl({
          url: 'pages/StreamPage',
          params: {
            computerId: computer.uuid,
            appId: computer.runningGameId,
            appName: runningApp?.name,
            cmdList: cmdList && cmdList.length > 0 ? JSON.stringify(cmdList) : undefined,
            resume: true
          }
        });
        return;
      }
    } catch {
    }
    router.pushUrl({
      url: 'pages/StreamPage',
      params: { computerId: computer.uuid, appId: computer.runningGameId, resume: true }
    });
  }

  /**
  unpairComputer(computer: ObservableComputer): void {
    this.ui.showConfirmDialog({
      title: '取消配对',
      message: `确定要取消与 ${computer.name} 的配对吗？`,
      confirmButton: {
        text: '确定',
        color: AppColors.Error,
        onClick: async () => {
          try {
            await this.computerManager.unpairComputer(computer.uuid);
            promptAction.showToast({ message: '已取消配对' });
            this.ui.syncViewModel();
          } catch (_e) {
            promptAction.showToast({ message: '操作失败' });
          }
        }
      }
    });
  }

  /**
  deleteComputer(computer: ObservableComputer): void {
    this.ui.showConfirmDialog({
      title: '删除电脑',
      message: `确定要删除 ${computer.name} 吗？`,
      confirmButton: {
        text: '删除',
        color: AppColors.Error,
        onClick: async () => {
          try {
            await this.computerManager.removeComputer(computer.uuid);
            promptAction.showToast({ message: '已删除' });
            this.ui.syncViewModel();
          } catch (_e) {
            promptAction.showToast({ message: '删除失败' });
          }
        }
      }
    });
  }

  /**
  async testNetwork(computer: ObservableComputer): Promise<void> {
    promptAction.showToast({ message: '正在检测网络…' });
    const computerInfo = computer.toComputerInfo();

    const addressSet = new Set<string>();
    if (computerInfo.manualAddress) addressSet.add(computerInfo.manualAddress);
    if (computerInfo.address) addressSet.add(computerInfo.address);
    if (computerInfo.localAddress) addressSet.add(computerInfo.localAddress);
    if (computerInfo.remoteAddress) addressSet.add(computerInfo.remoteAddress);
    if (computerInfo.ipv6Address) addressSet.add(computerInfo.ipv6Address);
    const addresses = Array.from(addressSet);

    if (addresses.length === 0) {
      this.ui.showInfoDialog({ title: '网络测试', content: '没有可用的连接地址' });
      return;
    }

    const TEST_ROUNDS = 3;
    const results: AddressTestResult[] = [];

    for (const addr of addresses) {
      const roundLatencies: number[] = [];
      let lastServerInfo: ServerInfo | null = null;
      let lastError = '';

      for (let i = 0; i < TEST_ROUNDS; i++) {
        const startMs = Date.now();
        try {
          const nvHttp = new NvHttp(addr, computerInfo.serverCert, undefined, computerInfo.httpPort);
          const info = await nvHttp.getServerInfo();
          const elapsed = Date.now() - startMs;
          roundLatencies.push(elapsed);
          lastServerInfo = info;
        } catch (err) {
          lastError = (err as Error).message || String(err);
          break;
        }
      }

      const avgLatency = roundLatencies.length > 0
        ? roundLatencies.reduce((a, b) => a + b, 0) / roundLatencies.length
        : 0;

      results.push({
        address: addr,
        reachable: roundLatencies.length > 0,
        latencyMs: Math.round(avgLatency),
        serverInfo: lastServerInfo,
        error: lastError
      });
    }

    const lines: string[] = [];
    const reachableResults = results.filter(r => r.reachable);
    const unreachableResults = results.filter(r => !r.reachable);

    const serverInfo = reachableResults.find(r => r.serverInfo)?.serverInfo;

    if (reachableResults.length > 0) {
      lines.push('✅ 连接成功');
      lines.push('');

      for (const r of reachableResults) {
        const label = this.getAddressLabel(r.address, computerInfo);
        const quality = r.latencyMs < 10 ? '极佳' : r.latencyMs < 30 ? '良好' : r.latencyMs < 80 ? '一般' : '较高';
        lines.push(`${label}: ${r.latencyMs}ms (${quality})`);
      }

      if (serverInfo) {
        lines.push('');
        lines.push(`主机名: ${serverInfo.hostname}`);
        if (serverInfo.gpuType) lines.push(`GPU: ${serverInfo.gpuType}`);
        lines.push(`配对: ${computer.isPaired ? '已配对' : '未配对'}`);
        if (serverInfo.currentGame > 0) lines.push(`运行中游戏 ID: ${serverInfo.currentGame}`);
      }
    } else {
      lines.push('❌ 所有地址均无法连接');
    }

    if (unreachableResults.length > 0) {
      lines.push('');
      for (const r of unreachableResults) {
        const label = this.getAddressLabel(r.address, computerInfo);
        const shortErr = r.error.length > 60 ? r.error.substring(0, 60) + '…' : r.error;
        lines.push(`❌ ${label}: ${shortErr || '超时'}`);
      }
    }

    this.ui.showInfoDialog({ title: '网络测试 — ' + computer.name, content: lines.join('\n') });
  }

  /**
  private getAddressLabel(address: string, computerInfo: ComputerInfo): string {
    if (address === computerInfo.manualAddress) return `手动 (${address})`;
    if (address === computerInfo.localAddress) return `局域网 (${address})`;
    if (address === computerInfo.remoteAddress) return `远程 (${address})`;
    if (address === computerInfo.ipv6Address) return `IPv6 (${address})`;
    return address;
  }

  /**
  showComputerDetails(computer: ObservableComputer): void {
    const stateText = computer.isOnline ? '在线' : '离线';
    const pairText = computer.isPaired ? '已配对' : '未配对';
    const gamingText = computer.isGaming ? `正在运行游戏 (ID: ${computer.runningGameId})` : '空闲';

    const addressLines: string[] = [];
    const info = computer.toComputerInfo();
    if (info.manualAddress) { addressLines.push(`手动地址: ${info.manualAddress}`); }
    if (info.localAddress) { addressLines.push(`本地地址: ${info.localAddress}`); }
    if (info.remoteAddress) { addressLines.push(`远程地址: ${info.remoteAddress}`); }
    if (info.address && info.address !== info.localAddress && info.address !== info.remoteAddress && info.address !== info.manualAddress) {
      addressLines.push(`当前地址: ${info.address}`);
    }
    if (addressLines.length === 0) { addressLines.push(`地址: 未知`); }

    const details = [
      `名称: ${computer.name}`,
      `状态: ${stateText}`,
      `配对: ${pairText}`,
      `游戏: ${gamingText}`,
      ``,
      `UUID: ${computer.uuid}`,
      ...addressLines,
      `MAC 地址: ${computer.macAddress || '未知'}`,
      `HTTPS 端口: ${NvHttp.DEFAULT_HTTPS_PORT}`,
      `HTTP 端口: ${info.httpPort || NvHttp.DEFAULT_HTTP_PORT}`,
    ].join('\n');

    this.ui.showInfoDialog({ title: computer.name, content: details });
  }
}
