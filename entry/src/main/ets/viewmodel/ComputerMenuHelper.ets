/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { OptionItem } from '../components/OptionPickerDialog';
import { ObservableComputer } from './ComputerViewModel';
export interface ComputerMenuCallbacks {
  onWake: (computer: ObservableComputer) => void;
  onPair: (computer: ObservableComputer) => void;
  onResumeGame: (computer: ObservableComputer) => void | Promise<void>;
  onQuitGame: (computer: ObservableComputer) => void;
  onAppList: (computer: ObservableComputer) => void;
  onUnpair: (computer: ObservableComputer) => void;
  onSleep: (computer: ObservableComputer) => void;
  onTestNetwork: (computer: ObservableComputer) => void;
  onShowDetails: (computer: ObservableComputer) => void;
  onDelete: (computer: ObservableComputer) => void;
}

export interface ComputerMenuResult {
  options: OptionItem[];
  actionMap: Map<string, () => void>;
}

export class ComputerMenuHelper {
  static generateMenu(computer: ObservableComputer, callbacks: ComputerMenuCallbacks): ComputerMenuResult {
    const options: OptionItem[] = [];
    const actionMap = new Map<string, () => void>();
    let actionIndex = 0;
    
    if (!computer.isOnline) {
      const key = `action_${actionIndex++}`;
      actionMap.set(key, () => callbacks.onWake(computer));
      options.push({
        title: '发送唤醒包 (WOL)',
        subtitle: '尝试通过网络唤醒电脑',
        value: key
      });
    } 
    else if (!computer.isPaired) {
      const key = `action_${actionIndex++}`;
      actionMap.set(key, () => callbacks.onPair(computer));
      options.push({
        title: '配对',
        subtitle: '与电脑建立安全连接',
        value: key
      });
    } 
    else {
      if (computer.isGaming) {
        const resumeKey = `action_${actionIndex++}`;
        actionMap.set(resumeKey, () => callbacks.onResumeGame(computer));
        options.push({
          title: '恢复游戏',
          subtitle: '继续之前的游戏会话',
          value: resumeKey
        });
        
        const quitKey = `action_${actionIndex++}`;
        actionMap.set(quitKey, () => callbacks.onQuitGame(computer));
        options.push({
          title: '退出游戏',
          subtitle: '结束当前运行的游戏',
          value: quitKey
        });
      }
      
      const appListKey = `action_${actionIndex++}`;
      actionMap.set(appListKey, () => callbacks.onAppList(computer));
      options.push({
        title: '应用列表',
        subtitle: '查看可串流的应用',
        value: appListKey
      });
      
      const unpairKey = `action_${actionIndex++}`;
      actionMap.set(unpairKey, () => callbacks.onUnpair(computer));
      options.push({
        title: '取消配对',
        subtitle: '断开与电脑的配对',
        value: unpairKey
      });
      
      const sleepKey = `action_${actionIndex++}`;
      actionMap.set(sleepKey, () => callbacks.onSleep(computer));
      options.push({
        title: '休眠电脑',
        subtitle: '让电脑进入休眠状态',
        value: sleepKey
      });
    }
    
    const networkKey = `action_${actionIndex++}`;
    actionMap.set(networkKey, () => callbacks.onTestNetwork(computer));
    options.push({
      title: '网络测试',
      subtitle: '测试与电脑的网络连接',
      value: networkKey
    });
    
    const detailsKey = `action_${actionIndex++}`;
    actionMap.set(detailsKey, () => callbacks.onShowDetails(computer));
    options.push({
      title: '查看详情',
      subtitle: '显示电脑的详细信息',
      value: detailsKey
    });
    
    const deleteKey = `action_${actionIndex++}`;
    actionMap.set(deleteKey, () => callbacks.onDelete(computer));
    options.push({
      title: '删除电脑',
      subtitle: '从列表中移除此电脑',
      value: deleteKey
    });
    
    return { options, actionMap };
  }
}
