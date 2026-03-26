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
 * GUID,name,platform:mapping_string
 * mapping_string: a:b0,b:b1,x:b2,y:b3,back:b6,guide:b8,start:b7,leftstick:b9,...
 * 
 */

#ifndef SDL_GAMECONTROLLERDB_H
#define SDL_GAMECONTROLLERDB_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    MAPPING_NONE = 0,
    MAPPING_BUTTON,
    MAPPING_AXIS,
    MAPPING_HAT,
} MappingSourceType;

#define HAT_UP      0x01
#define HAT_RIGHT   0x02
#define HAT_DOWN    0x04
#define HAT_LEFT    0x08

typedef struct {
    MappingSourceType type;
    int index;
    int hatMask;
    bool inverted;
    int rangeMin;
    int rangeMax;
} MappingSource;

typedef struct {
    uint16_t vendorId;
    uint16_t productId;
    const char* name;
    
    MappingSource a;
    MappingSource b;
    MappingSource x;
    MappingSource y;
    MappingSource back;
    MappingSource guide;
    MappingSource start;
    MappingSource leftstick;
    MappingSource rightstick;
    MappingSource leftshoulder; // LB
    MappingSource rightshoulder;// RB
    MappingSource dpup;
    MappingSource dpdown;
    MappingSource dpleft;
    MappingSource dpright;
    
    MappingSource leftx;
    MappingSource lefty;
    MappingSource rightx;
    MappingSource righty;
    MappingSource lefttrigger;
    MappingSource righttrigger;
    
    int reportOffset;
    int reportLength;
} GamepadMapping;

/**
 * @param vendorId USB Vendor ID
 * @param productId USB Product ID
 */
const GamepadMapping* findGamepadMapping(uint16_t vendorId, uint16_t productId);

/**
 * @param vendorId USB Vendor ID
 */
const GamepadMapping* getDefaultMappingByVendor(uint16_t vendorId);

bool parseSDLMappingString(const char* mappingString, GamepadMapping* outMapping);

void applyGamepadMapping(
    const GamepadMapping* mapping,
    const uint8_t* data,
    int len,
    uint32_t* outButtons,
    int16_t* outLeftStickX,
    int16_t* outLeftStickY,
    int16_t* outRightStickX,
    int16_t* outRightStickY,
    uint8_t* outLeftTrigger,
    uint8_t* outRightTrigger
);

#ifndef BTN_FLAG_A
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
#endif

#ifdef __cplusplus
}
#endif

#endif // SDL_GAMECONTROLLERDB_H
