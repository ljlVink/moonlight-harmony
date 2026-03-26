/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * USB DDK Poller - High-speed USB polling via HarmonyOS USB DDK
 *
 * Uses OH_Usb_SendPipeRequest() synchronous API in a dedicated pthread,
 * bypassing ArkTS event loop and usbManager IPC bottleneck.
 */

#ifndef USB_DDK_POLLER_H
#define USB_DDK_POLLER_H

#include <napi/native_api.h>

void UsbDdkPoller_Init(napi_env env, napi_value exports);

#endif // USB_DDK_POLLER_H
