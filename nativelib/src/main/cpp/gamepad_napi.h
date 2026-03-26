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

#ifndef GAMEPAD_NAPI_H
#define GAMEPAD_NAPI_H

#include <napi/native_api.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int32_t deviceId;
    uint32_t buttons;
    int16_t leftStickX;
    int16_t leftStickY;
    int16_t rightStickX;
    int16_t rightStickY;
    uint8_t leftTrigger;
    uint8_t rightTrigger;
} NapiGamepadState;

typedef struct {
    int32_t deviceId;
    uint16_t vendorId;
    uint16_t productId;
    char name[256];
    int32_t type;           // 0=Unknown, 1=Xbox, 2=PlayStation, 3=Switch
    bool isConnected;
} NapiGamepadInfo;

#define BTN_FLAG_UP          0x0001
#define BTN_FLAG_DOWN        0x0002
#define BTN_FLAG_LEFT        0x0004
#define BTN_FLAG_RIGHT       0x0008
#define BTN_FLAG_START       0x0010
#define BTN_FLAG_BACK        0x0020
#define BTN_FLAG_LS_CLK      0x0040
#define BTN_FLAG_RS_CLK      0x0080
#define BTN_FLAG_LB          0x0100
#define BTN_FLAG_RB          0x0200
#define BTN_FLAG_HOME        0x0400
#define BTN_FLAG_A           0x1000
#define BTN_FLAG_B           0x2000
#define BTN_FLAG_X           0x4000
#define BTN_FLAG_Y           0x8000

#define BTN_FLAG_PADDLE1     0x00010000
#define BTN_FLAG_PADDLE2     0x00020000
#define BTN_FLAG_PADDLE3     0x00040000
#define BTN_FLAG_PADDLE4     0x00080000
#define BTN_FLAG_TOUCHPAD    0x00100000
#define BTN_FLAG_MISC        0x00200000


napi_value GamepadNapi_Init(napi_env env, napi_value exports);

// parseHidReport(vendorId: number, productId: number, data: Uint8Array): GamepadState
napi_value GamepadNapi_ParseHidReport(napi_env env, napi_callback_info info);

// getGamepadType(vendorId: number, productId: number): number
napi_value GamepadNapi_GetGamepadType(napi_env env, napi_callback_info info);

// isSupportedGamepad(vendorId: number, productId: number): boolean
napi_value GamepadNapi_IsSupportedGamepad(napi_env env, napi_callback_info info);

// getGamepadName(vendorId: number, productId: number): string
napi_value GamepadNapi_GetGamepadName(napi_env env, napi_callback_info info);

// createRumbleCommand(vendorId: number, productId: number, lowFreq: number, highFreq: number): Uint8Array | null
napi_value GamepadNapi_CreateRumbleCommand(napi_env env, napi_callback_info info);

#ifdef __cplusplus
}
#endif

#endif // GAMEPAD_NAPI_H
