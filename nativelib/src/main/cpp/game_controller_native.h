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
 * 
 */

#ifndef GAME_CONTROLLER_NATIVE_H
#define GAME_CONTROLLER_NATIVE_H

#include <napi/native_api.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char deviceId[64];
    uint32_t buttons;
    int16_t leftStickX;
    int16_t leftStickY;
    int16_t rightStickX;
    int16_t rightStickY;
    uint8_t leftTrigger;
    uint8_t rightTrigger;
    int16_t hatX;           // D-Pad X (-1, 0, 1)
    int16_t hatY;           // D-Pad Y (-1, 0, 1)
} GameControllerState;

typedef struct {
    char deviceId[64];
    char name[256];
    int32_t product;
    int32_t version;
    char physicalAddress[64];
    int32_t deviceType;
    bool isConnected;
} GameControllerInfo;

#define GC_BTN_UP          0x0001
#define GC_BTN_DOWN        0x0002
#define GC_BTN_LEFT        0x0004
#define GC_BTN_RIGHT       0x0008
#define GC_BTN_START       0x0010
#define GC_BTN_BACK        0x0020
#define GC_BTN_LS_CLK      0x0040
#define GC_BTN_RS_CLK      0x0080
#define GC_BTN_LB          0x0100
#define GC_BTN_RB          0x0200
#define GC_BTN_HOME        0x0400
#define GC_BTN_A           0x1000
#define GC_BTN_B           0x2000
#define GC_BTN_X           0x4000
#define GC_BTN_Y           0x8000

#define GC_KEYCODE_BUTTON_A           2301
#define GC_KEYCODE_BUTTON_B           2302
#define GC_KEYCODE_BUTTON_C           2303
#define GC_KEYCODE_BUTTON_X           2304
#define GC_KEYCODE_BUTTON_Y           2305
#define GC_KEYCODE_LEFT_SHOULDER      2307
#define GC_KEYCODE_RIGHT_SHOULDER     2308
#define GC_KEYCODE_LEFT_TRIGGER       2309
#define GC_KEYCODE_RIGHT_TRIGGER      2310
#define GC_KEYCODE_BUTTON_HOME        2311
#define GC_KEYCODE_BUTTON_MENU        2312
#define GC_KEYCODE_LEFT_THUMBSTICK    2314
#define GC_KEYCODE_RIGHT_THUMBSTICK   2315
#define GC_KEYCODE_DPAD_UP            2012
#define GC_KEYCODE_DPAD_DOWN          2013
#define GC_KEYCODE_DPAD_LEFT          2014
#define GC_KEYCODE_DPAD_RIGHT         2015

typedef void (*GameControllerDeviceCallback)(
    const char* deviceId,
    bool isConnected,
    const GameControllerInfo* info
);

typedef void (*GameControllerButtonCallback)(
    const char* deviceId,
    int32_t buttonCode,
    bool isPressed
);

typedef void (*GameControllerAxisCallback)(
    const char* deviceId,
    int32_t axisType,
    double x,
    double y
);

#define GC_AXIS_LEFT_THUMBSTICK   0
#define GC_AXIS_RIGHT_THUMBSTICK  1
#define GC_AXIS_DPAD              2
#define GC_AXIS_LEFT_TRIGGER      3
#define GC_AXIS_RIGHT_TRIGGER     4

int GameController_Init(void);

void GameController_Uninit(void);

void GameController_SetDeviceCallback(GameControllerDeviceCallback callback);

void GameController_SetButtonCallback(GameControllerButtonCallback callback);

void GameController_SetAxisCallback(GameControllerAxisCallback callback);

int GameController_StartMonitor(void);

void GameController_StopMonitor(void);

void GameController_PauseInputMonitor(void);

void GameController_ResumeInputMonitor(void);

int GameController_GetDeviceCount(void);

int GameController_GetDeviceInfo(int index, GameControllerInfo* outInfo);

bool GameController_IsAvailable(void);

/**
 *
 *
 *
 */
int GameController_RefreshDevices(void);

/**
 * 
 * 
 */
int GameController_HeartbeatCheck(void);

napi_value GameControllerNapi_Init(napi_env env, napi_value exports);

#ifdef __cplusplus
}
#endif

#endif // GAME_CONTROLLER_NATIVE_H
