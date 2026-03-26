/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * USB Helper - Kernel driver reattachment
 *
 * After claimInterface(force=true) detaches the kernel HID driver,
 * releaseInterface() + closePipe() do not automatically reattach it.
 * This module uses native ioctl to explicitly rebind the interface driver.
 */

#ifndef USB_HELPER_H
#define USB_HELPER_H

#include <napi/native_api.h>

void UsbHelper_Init(napi_env env, napi_value exports);

/**
 * NAPI: reattachKernelDriver(fd: number, interfaceNumber: number): number
 */
napi_value UsbHelper_ReattachKernelDriver(napi_env env, napi_callback_info info);

#endif // USB_HELPER_H
