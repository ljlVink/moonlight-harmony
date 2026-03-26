/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */


import { emitter } from '@kit.BasicServicesKit';


export const APP_STATE_EVENT_ID = 10001;

export enum AppState {
  FOREGROUND = 'foreground',
  BACKGROUND = 'background'
}

export interface AppStateEvent {
  state: AppState;
  timestamp: number;
}


export class AppStateService {
  private static instance: AppStateService;
  private currentState: AppState = AppState.FOREGROUND;
  private listeners: Set<(state: AppState) => void> = new Set();
  
  private constructor() {}
  
  static getInstance(): AppStateService {
    if (!AppStateService.instance) {
      AppStateService.instance = new AppStateService();
    }
    return AppStateService.instance;
  }
  

  getCurrentState(): AppState {
    return this.currentState;
  }
  

  onForeground(): void {
    if (this.currentState !== AppState.FOREGROUND) {
      this.currentState = AppState.FOREGROUND;
      console.info('[AppStateService] App entered foreground');
      this.notifyListeners();
      this.emitEvent();
    }
  }
  

  onBackground(): void {
    if (this.currentState !== AppState.BACKGROUND) {
      this.currentState = AppState.BACKGROUND;
      console.info('[AppStateService] App entered background');
      this.notifyListeners();
      this.emitEvent();
    }
  }
  

  addListener(callback: (state: AppState) => void): void {
    this.listeners.add(callback);
  }
  

  removeListener(callback: (state: AppState) => void): void {
    this.listeners.delete(callback);
  }
  

  subscribe(callback: (event: emitter.EventData) => void): void {
    const innerEvent: emitter.InnerEvent = {
      eventId: APP_STATE_EVENT_ID
    };
    emitter.on(innerEvent, callback);
  }
  

  unsubscribe(): void {
    emitter.off(APP_STATE_EVENT_ID);
  }
  
  private notifyListeners(): void {
    this.listeners.forEach(callback => {
      try {
        callback(this.currentState);
      } catch (err) {
        console.error('[AppStateService] Listener callback error:', err);
      }
    });
  }
  
  private emitEvent(): void {
    const eventData: emitter.EventData = {
      data: {
        state: this.currentState,
        timestamp: Date.now()
      }
    };
    const innerEvent: emitter.InnerEvent = {
      eventId: APP_STATE_EVENT_ID,
      priority: emitter.EventPriority.HIGH
    };
    emitter.emit(innerEvent, eventData);
  }
}
