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
 * Abstract Xbox-style controller base class
 *
 * Reference: Android moonlight-android AbstractXboxController
 * Used for Xbox 360 and Xbox One controllers
 */

import { usbManager } from "@kit.BasicServicesKit";
import { AbstractController } from "./AbstractController";
import { UsbDriverListener } from "./UsbDriverListener";
import {
  ControllerType,
  ControllerCapabilities,
  ButtonFlags,
  UsbDirection,
} from "./ControllerConstants";
import { isHardwareError, createUsbError, UsbError } from "./UsbErrorCodes";
import { DdkUsbPoller } from "./DdkUsbPoller";

const TAG = "[USB-XBOX]";

export abstract class AbstractXboxController extends AbstractController {
  protected device: usbManager.USBDevice;
  protected pipe: usbManager.USBDevicePipe | null = null;

  protected inEndpoint: usbManager.USBEndpoint | null = null;
  protected outEndpoint: usbManager.USBEndpoint | null = null;
  protected usbInterface: usbManager.USBInterface | null = null;

  private inputThread: boolean = false;
  private stopped: boolean = false;

  // DDK high-speed poller (bypasses usbManager IPC)
  private ddkPoller: DdkUsbPoller | null = null;
  private useDdkPolling: boolean = false;

  constructor(
    device: usbManager.USBDevice,
    pipe: usbManager.USBDevicePipe,
    deviceId: number,
    listener: UsbDriverListener,
  ) {
    super(deviceId, listener, device.vendorId, device.productId);
    this.device = device;
    this.pipe = pipe;
    this.type = ControllerType.XBOX;
    this.capabilities = ControllerCapabilities.ANALOG_TRIGGERS | ControllerCapabilities.RUMBLE;

    // Supported buttons
    this.supportedButtonFlags =
      ButtonFlags.A_FLAG |
      ButtonFlags.B_FLAG |
      ButtonFlags.X_FLAG |
      ButtonFlags.Y_FLAG |
      ButtonFlags.UP_FLAG |
      ButtonFlags.DOWN_FLAG |
      ButtonFlags.LEFT_FLAG |
      ButtonFlags.RIGHT_FLAG |
      ButtonFlags.LB_FLAG |
      ButtonFlags.RB_FLAG |
      ButtonFlags.LS_CLK_FLAG |
      ButtonFlags.RS_CLK_FLAG |
      ButtonFlags.BACK_FLAG |
      ButtonFlags.PLAY_FLAG |
      ButtonFlags.SPECIAL_BUTTON_FLAG;
  }

  private findEndpoints(): boolean {
    if (!this.device.configs || this.device.configs.length === 0) {
      console.error(`${TAG} Device has no configuration`);
      return false;
    }

    const config = this.device.configs[0];
    if (!config.interfaces || config.interfaces.length === 0) {
      console.error(`${TAG} Configuration has no interface`);
      return false;
    }

    // Find the first interface
    this.usbInterface = config.interfaces[0];

    if (!this.usbInterface.endpoints || this.usbInterface.endpoints.length === 0) {
      console.error(`${TAG} Interface has no endpoints`);
      return false;
    }

    // Find input and output endpoints
    for (const endpoint of this.usbInterface.endpoints) {
      const direction = endpoint.direction;

      if (direction === usbManager.USBRequestDirection.USB_REQUEST_DIR_FROM_DEVICE) {
        if (this.inEndpoint !== null) {
          console.warn(`${TAG} Duplicate input endpoint found`);
          return false;
        }
        this.inEndpoint = endpoint;
        console.info(`${TAG} Found input endpoint: address=0x${endpoint.address.toString(16)}`);
      } else if (direction === usbManager.USBRequestDirection.USB_REQUEST_DIR_TO_DEVICE) {
        if (this.outEndpoint !== null) {
          console.warn(`${TAG} Duplicate output endpoint found`);
          return false;
        }
        this.outEndpoint = endpoint;
        console.info(`${TAG} Found output endpoint: address=0x${endpoint.address.toString(16)}`);
      }
    }

    // Ensure required endpoints are found
    if (this.inEndpoint === null || this.outEndpoint === null) {
      console.warn(
        `${TAG} Missing required endpoints: in=${this.inEndpoint !== null}, out=${this.outEndpoint !== null}`,
      );
      return false;
    }

    return true;
  }

  private claimInterface(): boolean {
    if (!this.pipe || !this.usbInterface) {
      return false;
    }

    try {
      const result = usbManager.claimInterface(this.pipe, this.usbInterface, true);
      if (result !== 0) {
        console.error(`${TAG} Failed to claim interface: ${result}`);
        return false;
      }
      console.info(`${TAG} Successfully claimed interface`);
      return true;
    } catch (err) {
      console.error(`${TAG} Exception claiming interface:`, err);
      return false;
    }
  }

  protected async bulkRead(timeout: number = 3000): Promise<Uint8Array | null> {
    if (!this.pipe || !this.inEndpoint) {
      throw new Error("USB pipe or endpoint not initialized");
    }

    // Create read buffer
    const buffer = new Uint8Array(64);
    const result = await usbManager.bulkTransfer(this.pipe, this.inEndpoint, buffer, timeout);

    // Negative value indicates error
    if (result < 0) {
      throw createUsbError(result);
    }

    if (result > 0) {
      return buffer.slice(0, result);
    }
    return null;
  }

  protected async bulkWrite(data: Uint8Array, timeout: number = 3000): Promise<number> {
    // DDK path: send via DDK synchronously
    if (this.useDdkPolling && this.ddkPoller) {
      const ret = this.ddkPoller.sendOutput(data);
      if (ret < 0) {
        console.error(`${TAG} DDK sendOutput failed: ret=${ret}, dataLen=${data.length}`);
      }
      return ret;
    }

    // usbManager path
    if (!this.pipe || !this.outEndpoint) {
      return -1;
    }

    try {
      // HarmonyOS bulkTransfer returns transferred bytes
      const result = await usbManager.bulkTransfer(this.pipe, this.outEndpoint, data, timeout);
      return typeof result === "number" ? result : data.length;
    } catch (err) {
      console.error(`${TAG} Bulk write failed:`, err);
      return -1;
    }
  }

  private async inputLoop(): Promise<void> {
    console.info(`${TAG} Input loop started`);

    // Initialization complete, mark ready and notify
    this.notifyDeviceAdded();

    let detectedHardwareError = false;

    while (!this.stopped) {
      try {
        // Use longer timeout (consistent with Android)
        // Returns immediately when data is available
        const buffer = await this.bulkRead(1000);

        if (this.stopped) {
          break;
        }

        if (buffer && buffer.length > 0) {
          if (this.handleRead(buffer)) {
            this.reportInput();
          }
        }
      } catch (err) {
        if (!this.stopped) {
          // Check error type
          const usbErr = err instanceof UsbError ? err : null;
          const errorCode = usbErr ? usbErr.code : 0;
          const retryable = usbErr ? usbErr.retryable : true;

          // Timeout error - continue polling
          if (errorCode === -8) {
            // USB_ERROR_TIMEOUT
            continue;
          } else if (errorCode === -4) {
            // USB_ERROR_NO_DEVICE
            // If ignore disconnect is set, continue polling
            if (this.ignoreDisconnect) {
              console.warn(
                `${TAG} Device unreachable but ignore disconnect enabled, continuing: ${err}`,
              );
              continue;
            }
            console.warn(`${TAG} Device unreachable: ${err}`);
            break;
          } else if (isHardwareError(errorCode)) {
            // If ignore disconnect is set, continue polling
            if (this.ignoreDisconnect) {
              console.warn(
                `${TAG} Hardware error detected but ignore disconnect enabled, continuing: ${err}`,
              );
              continue;
            }
            console.error(`${TAG} Hardware error detected: ${err}`);
            detectedHardwareError = true;
            break;
          } else {
            console.error(`${TAG} Input read error: ${err}`);
            // Other errors - continue if retryable, otherwise stop
            if (!retryable) {
              // If ignore disconnect is set, continue polling
              if (this.ignoreDisconnect) {
                console.warn(
                  `${TAG} Non-retryable error but ignore disconnect enabled, continuing: ${err}`,
                );
                continue;
              }
              break;
            }
          }
        }
      }
    }

    console.info(`${TAG} Input loop ended`);

    // Decide whether to notify device removal based on error type
    if (!this.stopped) {
      if (detectedHardwareError) {
        console.error(`${TAG} Stopping controller due to hardware error`);
        this.stop();
      } else {
        // Device disconnected or other error
        console.warn(`${TAG} Stopping controller due to device disconnect/IO error`);
        this.stop();
      }
    }
  }

  start(): boolean {
    console.info(
      `${TAG} Starting controller: VID=0x${this.vendorId.toString(16)}, PID=0x${this.productId.toString(16)}, DDK=${this.ddkPollingEnabled}`,
    );
    this.markInitializing();

    // Find endpoints
    if (!this.findEndpoints()) {
      console.error(`${TAG} Failed to find endpoints`);
      return false;
    }

    // ====== Try DDK path first ======
    console.info(
      `${TAG} DDK conditions: enabled=${this.ddkPollingEnabled}, available=${DdkUsbPoller.isAvailable()}, inEp=${this.inEndpoint !== null}`,
    );
    if (this.ddkPollingEnabled && DdkUsbPoller.isAvailable() && this.inEndpoint) {
      const ddkStarted = this.tryDdkPath();
      if (ddkStarted) {
        return true;
      }
      console.warn(`${TAG} DDK path failed, falling back to usbManager path`);
    }

    // ====== Fallback: usbManager path ======

    // Claim interface
    if (!this.claimInterface()) {
      console.error(`${TAG} Failed to claim interface`);
      return false;
    }

    // Perform initialization
    if (!this.doInit()) {
      console.error(`${TAG} Initialization failed`);
      return false;
    }

    // Start input loop
    this.stopped = false;
    this.inputThread = true;

    // ArkTS async polling
    this.inputLoop();

    return true;
  }

  /**
   * Try to start controller via USB DDK path
   * DDK completely bypasses usbManager, must be called before claimInterface
   *
   * @returns Whether successful
   */
  private tryDdkPath(): boolean {
    console.info(`${TAG} Trying DDK path...`);

    // Step 1: Initialize DDK
    const initResult = DdkUsbPoller.init();
    if (initResult.code !== 0) {
      console.warn(`${TAG} DDK init failed: ${initResult.error}`);
      return false;
    }

    // Step 2: Find device via DDK
    let ddkDeviceId: number | undefined;

    // Method A: GetDevices + match VID/PID
    const findResult = DdkUsbPoller.findDevice(this.vendorId, this.productId);
    if (findResult.found && findResult.deviceId !== undefined) {
      ddkDeviceId = findResult.deviceId;
    } else {
      // Method B: Construct deviceId from busNum/devAddress
      console.info(`${TAG} Device not found via GetDevices, trying makeDeviceId...`);
      const makeResult = DdkUsbPoller.makeDeviceId(this.device.busNum, this.device.devAddress);
      if (makeResult.found && makeResult.deviceId !== undefined) {
        ddkDeviceId = makeResult.deviceId;
      }
    }

    if (ddkDeviceId === undefined) {
      console.warn(`${TAG} DDK failed to get deviceId`);
      return false;
    }
    const ifaceIndex = this.usbInterface?.id ?? 0;
    const inEp = this.inEndpoint!.address;
    const outEp = this.outEndpoint?.address ?? 0;
    const maxPkt = this.inEndpoint!.maxPacketSize || 64;

    console.info(
      `${TAG} DDK device matched: deviceId=${ddkDeviceId}, iface=${ifaceIndex}, inEp=0x${inEp.toString(16)}, outEp=0x${outEp.toString(16)}`,
    );

    // Step 3: Close usbManager pipe (DDK cannot ClaimInterface on a device already connected via usbManager)
    if (this.pipe) {
      console.info(`${TAG} Closing usbManager pipe to release device for DDK...`);
      try {
        usbManager.closePipe(this.pipe);
      } catch (err) {
        console.warn(`${TAG} closePipe exception: ${err}`);
      }
      this.pipe = null;
    }

    // Step 4: Create DDK poller and start
    this.ddkPoller = new DdkUsbPoller();
    const started = this.ddkPoller.start(
      ddkDeviceId,
      ifaceIndex,
      inEp,
      outEp,
      maxPkt,
      (data: Uint8Array, length: number) => {
        if (this.stopped) return;
        if (this.handleRead(data.slice(0, length))) {
          this.reportInput();
        }
      },
      (errorCode: number) => {
        if (this.stopped) return;
        console.warn(`${TAG} DDK polling error: ${errorCode}`);

        // Check if native polling thread is still running
        const nativeStillRunning = this.ddkPoller?.isNativeRunning() ?? false;

        if (this.ignoreDisconnect) {
          if (!nativeStillRunning) {
            // Native thread exited but ignoreDisconnect is on - controller will be completely unresponsive
            console.error(
              `${TAG} DDK native thread exited! errorCode=${errorCode}, controller input will be interrupted until reconnection`,
            );
          }
          return;
        }
        console.error(`${TAG} DDK polling fatal error: ${errorCode}, stopping controller`);
        this.stop();
      },
      100, // 100ms timeout per read
    );

    if (!started) {
      console.warn(`${TAG} DDK startPoller failed`);
      this.ddkPoller = null;
      // Restore usbManager pipe (need to fallback to usbManager after DDK failure)
      this.reconnectPipe();
      return false;
    }

    // Step 4: Perform initialization via DDK (send init packet)
    this.stopped = false;
    this.useDdkPolling = true;
    this.ddkActive = true;

    // Sync ignore disconnect setting to native layer
    if (this.ignoreDisconnect) {
      this.ddkPoller.setIgnoreDisconnect(true);
    }

    if (!this.doInit()) {
      console.warn(`${TAG} doInit failed under DDK path`);
      // doInit failure doesn't necessarily terminate - some controllers don't need init
    }

    // DDK started, mark ready and notify
    this.notifyDeviceAdded();

    console.info(`${TAG} Controller started (DDK high-speed polling)`);
    return true;
  }

  stop(): void {
    if (this.stopped) {
      return;
    }

    console.info(`${TAG} Stopping controller`);
    this.stopped = true;
    this.markStopped();

    // Send rumble stop command first (must be done before DDK release, otherwise cannot send)
    this.rumble(0, 0);

    // Save DDK state, then stop DDK poller
    const wasDdkPolling = this.useDdkPolling;
    if (this.ddkPoller) {
      this.ddkPoller.stop();
      this.ddkPoller = null;
      this.useDdkPolling = false;
    }

    // Release interface (usbManager path only, DDK path is released internally by stopPoller)
    if (!wasDdkPolling && this.pipe && this.usbInterface) {
      try {
        usbManager.releaseInterface(this.pipe, this.usbInterface);
      } catch (err) {
        console.error(`${TAG} Failed to release interface:`, err);
      }
    }

    // Close pipe
    if (this.pipe) {
      try {
        usbManager.closePipe(this.pipe);
      } catch (err) {
        console.error(`${TAG} Failed to close pipe:`, err);
      }
      this.pipe = null;
    }

    // Notify device removed
    this.notifyDeviceRemoved();
  }

  isConnected(): boolean {
    return !this.stopped && (this.pipe !== null || this.useDdkPolling);
  }

  /**
   * Restore usbManager pipe (for DDK failure fallback)
   */
  private reconnectPipe(): void {
    if (this.pipe) return;
    try {
      console.info(`${TAG} Restoring usbManager pipe...`);
      this.pipe = usbManager.connectDevice(this.device);
      console.info(`${TAG} usbManager pipe restored`);
    } catch (err) {
      console.error(`${TAG} Failed to restore pipe: ${err}`);
    }
  }

  /**
   * Handle read data
   * @param buffer Read data buffer
   * @returns Whether input report should be sent
   */
  protected abstract handleRead(buffer: Uint8Array): boolean;

  /**
   * Perform device initialization
   * @returns Whether initialization succeeded
   */
  protected abstract doInit(): boolean;
}
