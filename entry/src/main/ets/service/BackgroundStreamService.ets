/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */


import { avSession as AVSessionManager } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { image } from '@kit.ImageKit';

const TAG = '[BackgroundStreamService]';


export interface BroadcastControlCallbacks {

  onStop?: () => void;
}

export class BackgroundStreamService {
  private static instance: BackgroundStreamService;
  private session: AVSessionManager.AVSession | null = null;
  private isRunning: boolean = false;
  private context: common.UIAbilityContext | null = null;
  private notificationId: number = 0;
  private gameName: string = 'Moonlight Streaming';
  private controlCallbacks: BroadcastControlCallbacks | null = null;

  private constructor() {}

  static getInstance(): BackgroundStreamService {
    if (!BackgroundStreamService.instance) {
      BackgroundStreamService.instance = new BackgroundStreamService();
    }
    return BackgroundStreamService.instance;
  }


  async start(context: common.UIAbilityContext, gameName?: string, callbacks?: BroadcastControlCallbacks): Promise<void> {
    if (this.isRunning) {
      console.info(`${TAG} Already running, skipping`);
      return;
    }

    this.context = context;
    this.gameName = gameName || 'Moonlight Streaming';
    this.controlCallbacks = callbacks || null;

    try {
      this.registerCancelListener();
      
      await this.createAVSession(this.gameName);
      
      await this.startContinuousTask();

      this.isRunning = true;
      console.info(`${TAG} Background keep-alive started`);
    } catch (err) {
      console.error(`${TAG} Failed to start background keep-alive:`, err);
      await this.cleanup();
    }
  }


  async stop(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    console.info(`${TAG} Stopping background keep-alive...`);
    await this.cleanup();
    this.isRunning = false;
    console.info(`${TAG} Background keep-alive stopped`);
  }


  getIsRunning(): boolean {
    return this.isRunning;
  }




  private registerCancelListener(): void {
    try {
      backgroundTaskManager.on('continuousTaskCancel', (info) => {
        console.error(`${TAG} Background task cancelled by system! info=${JSON.stringify(info)}`);
      });
    } catch (err) {
      console.warn(`${TAG} Failed to register cancel listener:`, err);
    }
  }


  private unregisterCancelListener(): void {
    try {
      backgroundTaskManager.off('continuousTaskCancel');
    } catch (err) {
      // ignore
    }
  }


  private async createAVSession(gameName: string): Promise<void> {
    try {

      this.session = await AVSessionManager.createAVSession(
        this.context!,
        'MoonlightStreaming',
        'audio'
      );
      console.info(`${TAG} AVSession created, sessionId=${this.session.sessionId}`);


      let coverImage: image.PixelMap | undefined = undefined;
      try {
        const resourceManager = this.context!.resourceManager;
        const iconData: Uint8Array = resourceManager.getMediaContentSync($r('app.media.app_icon').id);
        const imageSource: image.ImageSource = image.createImageSource(iconData.buffer as ArrayBuffer);
        coverImage = await imageSource.createPixelMap({
          desiredSize: { width: 800, height: 800 }
        });
        imageSource.release();
      } catch (imgErr) {
        console.warn(`${TAG} Failed to load cover image:`, imgErr);
      }


      const metadata: AVSessionManager.AVMetadata = {
        assetId: 'moonlight_streaming',
        title: gameName,
        artist: 'Moonlight Game Streaming',
        mediaImage: coverImage,
      } as AVSessionManager.AVMetadata;
      await this.session.setAVMetadata(metadata);



      this.session.on('play', () => {
        console.info(`${TAG} Media control: play`);
        this.setPlaybackState(AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY);
      });

      this.session.on('pause', () => {
        console.info(`${TAG} Media control: pause`);
        this.setPlaybackState(AVSessionManager.PlaybackState.PLAYBACK_STATE_PAUSE);
      });

      this.session.on('stop', () => {
        console.info(`${TAG} Media control: stop → disconnect stream`);
        if (this.controlCallbacks?.onStop) {
          this.controlCallbacks.onStop();
        }
      });


      await this.setPlaybackState(AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY);


      await this.session.activate();
      console.info(`${TAG} AVSession activated`);
    } catch (err) {
      const error = err as BusinessError;
      console.error(`${TAG} Failed to create AVSession: code=${error.code}, msg=${error.message}`);
      throw new Error(`Failed to create AVSession: ${error.message}`);
    }
  }


  private async setPlaybackState(state: AVSessionManager.PlaybackState): Promise<void> {
    if (!this.session) return;
    try {
      const playbackState: AVSessionManager.AVPlaybackState = {
        state: state,
        speed: 1.0,
      };
      await this.session.setAVPlaybackState(playbackState);
    } catch (err) {
      console.warn(`${TAG} Failed to set playback state:`, err);
    }
  }


  private async startContinuousTask(): Promise<void> {
    try {

      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: 'com.alkaidlab.sdream',
          abilityName: 'EntryAbility'
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent: WantAgent = await wantAgent.getWantAgent(wantAgentInfo);


      const bgModes: string[] = ['dataTransfer', 'audioPlayback'];
      const result = await backgroundTaskManager.startBackgroundRunning(
        this.context!,
        bgModes,
        agent
      );
      this.notificationId = result.notificationId;
      console.info(`${TAG} Continuous task started (dataTransfer+audioPlayback), notificationId=${this.notificationId}`);


      await this.updateNotification();
    } catch (err) {
      const error = err as BusinessError;
      console.error(`${TAG} Failed to start continuous task: code=${error.code}, msg=${error.message}`);
      throw new Error(`Failed to start continuous task: ${error.message}`);
    }
  }


  private async updateNotification(): Promise<void> {
    if (this.notificationId <= 0) {
      return;
    }
    try {
      const request: notificationManager.NotificationRequest = {
        id: this.notificationId,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: 'Moonlight Streaming',
            text: this.gameName,
          }
        },
      };
      await notificationManager.publish(request);
      console.info(`${TAG} Notification updated: ${this.gameName}`);
    } catch (err) {
      console.warn(`${TAG} Failed to update notification:`, err);
    }
  }


  private async cleanup(): Promise<void> {

    this.unregisterCancelListener();


    try {
      if (this.context) {
        await backgroundTaskManager.stopBackgroundRunning(this.context);
        console.info(`${TAG} Background task stopped`);
      }
    } catch (err) {
      console.warn(`${TAG} Failed to stop background task:`, err);
    }


    if (this.session) {
      try {

        this.session.off('play');
        this.session.off('pause');
        this.session.off('stop');

        await this.session.deactivate();
        await this.session.destroy();
        console.info(`${TAG} AVSession destroyed`);
      } catch (err) {
        console.warn(`${TAG} Failed to destroy AVSession:`, err);
      }
      this.session = null;
    }

    this.context = null;
    this.controlCallbacks = null;
  }
}
