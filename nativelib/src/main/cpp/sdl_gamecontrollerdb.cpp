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
 * https://github.com/gabomdq/SDL_GameControllerDB
 */

#include "sdl_gamecontrollerdb.h"
#include "sdl_gamecontrollerdb_data.h"
#include "gamepad_napi.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <vector>

#define BTN(idx) { MAPPING_BUTTON, idx, 0, false, 0, 255 }
#define AXIS(idx) { MAPPING_AXIS, idx, 0, false, 0, 255 }
#define AXIS_INV(idx) { MAPPING_AXIS, idx, 0, true, 0, 255 }
#define HAT(idx, mask) { MAPPING_HAT, idx, mask, false, 0, 255 }
#define NONE { MAPPING_NONE, 0, 0, false, 0, 255 }

static const GamepadMapping g_mappingDatabase[] = {
    
    {
        .vendorId = 0x045E, .productId = 0x028E,
        .name = "Xbox 360 Controller",
        .a = BTN(0), .b = BTN(1), .x = BTN(2), .y = BTN(3),
        .back = BTN(6), .guide = BTN(8), .start = BTN(7),
        .leftstick = BTN(9), .rightstick = BTN(10),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(3), .righty = AXIS(4),
        .lefttrigger = AXIS(2), .righttrigger = AXIS(5),
        .reportOffset = 0, .reportLength = 0
    },
    
    // Xbox One Controller
    {
        .vendorId = 0x045E, .productId = 0x02D1,
        .name = "Xbox One Controller",
        .a = BTN(0), .b = BTN(1), .x = BTN(2), .y = BTN(3),
        .back = BTN(6), .guide = BTN(8), .start = BTN(7),
        .leftstick = BTN(9), .rightstick = BTN(10),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(3), .righty = AXIS(4),
        .lefttrigger = AXIS(2), .righttrigger = AXIS(5),
        .reportOffset = 0, .reportLength = 0
    },
    
    // Xbox Series X|S Controller
    {
        .vendorId = 0x045E, .productId = 0x0B12,
        .name = "Xbox Series X Controller",
        .a = BTN(0), .b = BTN(1), .x = BTN(2), .y = BTN(3),
        .back = BTN(6), .guide = BTN(8), .start = BTN(7),
        .leftstick = BTN(9), .rightstick = BTN(10),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(3), .righty = AXIS(4),
        .lefttrigger = AXIS(2), .righttrigger = AXIS(5),
        .reportOffset = 0, .reportLength = 0
    },
    
    // DualShock 4
    {
        .vendorId = 0x054C, .productId = 0x05C4,
        .name = "DualShock 4",
        .a = BTN(1), .b = BTN(2), .x = BTN(0), .y = BTN(3),  // Cross=A, Circle=B, Square=X, Triangle=Y
        .back = BTN(8), .guide = BTN(12), .start = BTN(9),
        .leftstick = BTN(10), .rightstick = BTN(11),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(5),
        .lefttrigger = AXIS(3), .righttrigger = AXIS(4),
        .reportOffset = 1, .reportLength = 64
    },
    
    // DualShock 4 v2
    {
        .vendorId = 0x054C, .productId = 0x09CC,
        .name = "DualShock 4 v2",
        .a = BTN(1), .b = BTN(2), .x = BTN(0), .y = BTN(3),
        .back = BTN(8), .guide = BTN(12), .start = BTN(9),
        .leftstick = BTN(10), .rightstick = BTN(11),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(5),
        .lefttrigger = AXIS(3), .righttrigger = AXIS(4),
        .reportOffset = 1, .reportLength = 64
    },
    
    // DualSense
    {
        .vendorId = 0x054C, .productId = 0x0CE6,
        .name = "DualSense Controller",
        .a = BTN(1), .b = BTN(2), .x = BTN(0), .y = BTN(3),
        .back = BTN(8), .guide = BTN(12), .start = BTN(9),
        .leftstick = BTN(10), .rightstick = BTN(11),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(5),
        .lefttrigger = AXIS(3), .righttrigger = AXIS(4),
        .reportOffset = 1, .reportLength = 78
    },
    
    // Switch Pro Controller
    {
        .vendorId = 0x057E, .productId = 0x2009,
        .name = "Switch Pro Controller",
        .a = BTN(1), .b = BTN(0), .x = BTN(3), .y = BTN(2),
        .back = BTN(8), .guide = BTN(12), .start = BTN(9),
        .leftstick = BTN(10), .rightstick = BTN(11),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(3),
        .lefttrigger = BTN(6), .righttrigger = BTN(7),
        .reportOffset = 0, .reportLength = 64
    },
    
    // 8BitDo Pro 2
    {
        .vendorId = 0x2DC8, .productId = 0x6006,
        .name = "8BitDo Pro 2",
        .a = BTN(0), .b = BTN(1), .x = BTN(2), .y = BTN(3),
        .back = BTN(6), .guide = BTN(8), .start = BTN(7),
        .leftstick = BTN(9), .rightstick = BTN(10),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(3),
        .lefttrigger = AXIS(4), .righttrigger = AXIS(5),
        .reportOffset = 0, .reportLength = 0
    },
    
    // 8BitDo Ultimate
    {
        .vendorId = 0x2DC8, .productId = 0x3104,
        .name = "8BitDo Ultimate",
        .a = BTN(0), .b = BTN(1), .x = BTN(2), .y = BTN(3),
        .back = BTN(6), .guide = BTN(8), .start = BTN(7),
        .leftstick = BTN(9), .rightstick = BTN(10),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(3),
        .lefttrigger = AXIS(4), .righttrigger = AXIS(5),
        .reportOffset = 0, .reportLength = 0
    },
    
    // Logitech F310
    {
        .vendorId = 0x046D, .productId = 0xC21D,
        .name = "Logitech F310",
        .a = BTN(1), .b = BTN(2), .x = BTN(0), .y = BTN(3),
        .back = BTN(8), .guide = BTN(12), .start = BTN(9),
        .leftstick = BTN(10), .rightstick = BTN(11),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(3),
        .lefttrigger = BTN(6), .righttrigger = BTN(7),
        .reportOffset = 0, .reportLength = 0
    },
    
    // Logitech F710
    {
        .vendorId = 0x046D, .productId = 0xC21F,
        .name = "Logitech F710",
        .a = BTN(1), .b = BTN(2), .x = BTN(0), .y = BTN(3),
        .back = BTN(8), .guide = BTN(12), .start = BTN(9),
        .leftstick = BTN(10), .rightstick = BTN(11),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(3),
        .lefttrigger = AXIS(4), .righttrigger = AXIS(5),
        .reportOffset = 0, .reportLength = 0
    },
    
    // Razer Wolverine Ultimate
    {
        .vendorId = 0x1532, .productId = 0x0A14,
        .name = "Razer Wolverine Ultimate",
        .a = BTN(0), .b = BTN(1), .x = BTN(2), .y = BTN(3),
        .back = BTN(6), .guide = BTN(8), .start = BTN(7),
        .leftstick = BTN(9), .rightstick = BTN(10),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(3),
        .lefttrigger = AXIS(4), .righttrigger = AXIS(5),
        .reportOffset = 0, .reportLength = 0
    },
    
    {
        .vendorId = 0x0079, .productId = 0x0006,
        .name = "DragonRise Generic Controller",
        .a = BTN(2), .b = BTN(1), .x = BTN(3), .y = BTN(0),
        .back = BTN(8), .guide = NONE, .start = BTN(9),
        .leftstick = BTN(10), .rightstick = BTN(11),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(3),
        .lefttrigger = BTN(6), .righttrigger = BTN(7),
        .reportOffset = 0, .reportLength = 0
    },
    
    // HORI Fighting Stick
    {
        .vendorId = 0x0F0D, .productId = 0x00C1,
        .name = "HORI Fighting Stick",
        .a = BTN(1), .b = BTN(2), .x = BTN(0), .y = BTN(3),
        .back = BTN(8), .guide = BTN(12), .start = BTN(9),
        .leftstick = BTN(10), .rightstick = BTN(11),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = NONE, .lefty = NONE,
        .rightx = NONE, .righty = NONE,
        .lefttrigger = BTN(6), .righttrigger = BTN(7),
        .reportOffset = 0, .reportLength = 0
    },
    
    // HORIPAD
    {
        .vendorId = 0x0F0D, .productId = 0x0067,
        .name = "HORIPAD",
        .a = BTN(0), .b = BTN(1), .x = BTN(2), .y = BTN(3),
        .back = BTN(6), .guide = BTN(8), .start = BTN(7),
        .leftstick = BTN(9), .rightstick = BTN(10),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(3),
        .lefttrigger = AXIS(4), .righttrigger = AXIS(5),
        .reportOffset = 0, .reportLength = 0
    },
    
    {
        .vendorId = 0x20D6, .productId = 0xA711,
        .name = "PowerA Xbox Controller",
        .a = BTN(0), .b = BTN(1), .x = BTN(2), .y = BTN(3),
        .back = BTN(6), .guide = BTN(8), .start = BTN(7),
        .leftstick = BTN(9), .rightstick = BTN(10),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(3),
        .lefttrigger = AXIS(4), .righttrigger = AXIS(5),
        .reportOffset = 0, .reportLength = 0
    },
    
    // SteelSeries Stratus Duo
    {
        .vendorId = 0x1038, .productId = 0x1430,
        .name = "SteelSeries Stratus Duo",
        .a = BTN(0), .b = BTN(1), .x = BTN(2), .y = BTN(3),
        .back = BTN(6), .guide = BTN(8), .start = BTN(7),
        .leftstick = BTN(9), .rightstick = BTN(10),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(3),
        .lefttrigger = AXIS(4), .righttrigger = AXIS(5),
        .reportOffset = 0, .reportLength = 0
    },
    
    {
        .vendorId = 0x3575, .productId = 0x0620,
        .name = "GameSir Nova",
        .a = BTN(0), .b = BTN(1), .x = BTN(2), .y = BTN(3),
        .back = BTN(6), .guide = BTN(8), .start = BTN(7),
        .leftstick = BTN(9), .rightstick = BTN(10),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(3),
        .lefttrigger = AXIS(4), .righttrigger = AXIS(5),
        .reportOffset = 0, .reportLength = 0
    },
    
    {
        .vendorId = 0x3820, .productId = 0x0009,
        .name = "GuliKit KingKong 2 Pro",
        .a = BTN(1), .b = BTN(0), .x = BTN(3), .y = BTN(2),
        .back = BTN(8), .guide = BTN(12), .start = BTN(9),
        .leftstick = BTN(10), .rightstick = BTN(11),
        .leftshoulder = BTN(4), .rightshoulder = BTN(5),
        .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
        .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
        .leftx = AXIS(0), .lefty = AXIS(1),
        .rightx = AXIS(2), .righty = AXIS(3),
        .lefttrigger = AXIS(4), .righttrigger = AXIS(5),
        .reportOffset = 0, .reportLength = 0
    },
    
    { 0, 0, NULL, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE, 0, 0 }
};

static const GamepadMapping g_xboxDefaultMapping = {
    .vendorId = 0, .productId = 0,
    .name = "Xbox-style Default",
    .a = BTN(0), .b = BTN(1), .x = BTN(2), .y = BTN(3),
    .back = BTN(6), .guide = BTN(8), .start = BTN(7),
    .leftstick = BTN(9), .rightstick = BTN(10),
    .leftshoulder = BTN(4), .rightshoulder = BTN(5),
    .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
    .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
    .leftx = AXIS(0), .lefty = AXIS(1),
    .rightx = AXIS(2), .righty = AXIS(3),
    .lefttrigger = AXIS(4), .righttrigger = AXIS(5),
    .reportOffset = 0, .reportLength = 0
};

static const GamepadMapping g_psDefaultMapping = {
    .vendorId = 0, .productId = 0,
    .name = "PlayStation-style Default",
    .a = BTN(1), .b = BTN(2), .x = BTN(0), .y = BTN(3),  // Cross, Circle, Square, Triangle
    .back = BTN(8), .guide = BTN(12), .start = BTN(9),
    .leftstick = BTN(10), .rightstick = BTN(11),
    .leftshoulder = BTN(4), .rightshoulder = BTN(5),
    .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
    .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
    .leftx = AXIS(0), .lefty = AXIS(1),
    .rightx = AXIS(2), .righty = AXIS(5),
    .lefttrigger = AXIS(3), .righttrigger = AXIS(4),
    .reportOffset = 1, .reportLength = 64
};

static const GamepadMapping g_nintendoDefaultMapping = {
    .vendorId = 0, .productId = 0,
    .name = "Nintendo-style Default",
    .a = BTN(1), .b = BTN(0), .x = BTN(3), .y = BTN(2),
    .back = BTN(8), .guide = BTN(12), .start = BTN(9),
    .leftstick = BTN(10), .rightstick = BTN(11),
    .leftshoulder = BTN(4), .rightshoulder = BTN(5),
    .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
    .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
    .leftx = AXIS(0), .lefty = AXIS(1),
    .rightx = AXIS(2), .righty = AXIS(3),
    .lefttrigger = BTN(6), .righttrigger = BTN(7),
    .reportOffset = 0, .reportLength = 0
};

static const GamepadMapping g_genericDefaultMapping = {
    .vendorId = 0, .productId = 0,
    .name = "Generic DirectInput Default",
    .a = BTN(1), .b = BTN(2), .x = BTN(0), .y = BTN(3),
    .back = BTN(8), .guide = NONE, .start = BTN(9),
    .leftstick = BTN(10), .rightstick = BTN(11),
    .leftshoulder = BTN(4), .rightshoulder = BTN(5),
    .dpup = HAT(0, HAT_UP), .dpdown = HAT(0, HAT_DOWN),
    .dpleft = HAT(0, HAT_LEFT), .dpright = HAT(0, HAT_RIGHT),
    .leftx = AXIS(0), .lefty = AXIS(1),
    .rightx = AXIS(2), .righty = AXIS(3),
    .lefttrigger = BTN(6), .righttrigger = BTN(7),
    .reportOffset = 0, .reportLength = 0
};

typedef struct {
    uint16_t vendorId;
    const GamepadMapping* defaultMapping;
} VendorDefaultEntry;

static const VendorDefaultEntry g_vendorDefaults[] = {
    { 0x045E, &g_xboxDefaultMapping },      // Microsoft
    { 0x054C, &g_psDefaultMapping },        // Sony
    { 0x057E, &g_nintendoDefaultMapping },  // Nintendo
    { 0x2DC8, &g_xboxDefaultMapping },
    { 0x046D, &g_xboxDefaultMapping },      // Logitech
    { 0x1532, &g_xboxDefaultMapping },      // Razer
    { 0x0F0D, &g_xboxDefaultMapping },      // HORI
    { 0x20D6, &g_xboxDefaultMapping },      // PowerA
    { 0x0E6F, &g_xboxDefaultMapping },      // PDP
    { 0x0738, &g_xboxDefaultMapping },      // MadCatz
    { 0x1038, &g_xboxDefaultMapping },      // SteelSeries
    { 0x044F, &g_xboxDefaultMapping },      // Thrustmaster
    { 0x11C0, &g_psDefaultMapping },        // Nacon
    { 0x146B, &g_psDefaultMapping },        // BigBen
    { 0x2C22, &g_psDefaultMapping },        // Qanba
    { 0x3820, &g_nintendoDefaultMapping },  // GuliKit
    { 0x3575, &g_xboxDefaultMapping },      // GameSir
    { 0x3537, &g_xboxDefaultMapping },
    { 0x8555, &g_xboxDefaultMapping },      // GameSir (G4 Pro VID)
    { 0x046D, &g_xboxDefaultMapping },      // Logitech
    { 0x044F, &g_xboxDefaultMapping },      // Thrustmaster
    { 0x20BC, &g_xboxDefaultMapping },
    { 0x20D6, &g_xboxDefaultMapping },      // PowerA / BDA / Moga
    { 0x1949, &g_xboxDefaultMapping },      // Amazon / Ipega
    { 0x0955, &g_xboxDefaultMapping },      // NVIDIA
    { 0x18D1, &g_xboxDefaultMapping },      // Google Stadia
    { 0x2717, &g_xboxDefaultMapping },
    { 0x0B05, &g_xboxDefaultMapping },      // ASUS ROG
    { 0x1689, &g_xboxDefaultMapping },
    { 0x0111, &g_xboxDefaultMapping },
    { 0x358A, &g_xboxDefaultMapping },      // Backbone One
    { 0x10F5, &g_xboxDefaultMapping },      // Turtle Beach
    { 0x294B, &g_xboxDefaultMapping },      // Snakebyte
    { 0x3285, &g_psDefaultMapping },
    { 0x06A3, &g_genericDefaultMapping },   // Saitek / Cyborg
    { 0x0079, &g_genericDefaultMapping },   // DragonRise
    { 0x0810, &g_genericDefaultMapping },   // Generic
    { 0x413D, &g_genericDefaultMapping },
    { 0, NULL }
};

static std::vector<GamepadMapping> g_sdlParsedMappings;
static bool g_sdlDBInitialized = false;

/**
 * 
 *   Bytes 0-1:  Bus type (LE)
 *   Bytes 2-3:  CRC16
 *   Bytes 4-5:  Vendor ID (LE)  → hex chars 8-11
 *   Bytes 6-7:  Padding
 *   Bytes 8-9:  Product ID (LE) → hex chars 16-19
 *   Bytes 10-15: Version + padding
 */
static bool extractVidPidFromGUID(const char* guid, uint16_t* outVid, uint16_t* outPid) {
    if (!guid || strlen(guid) < 20) return false;
    
    auto hexDigit = [](char c) -> int {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        if (c >= 'A' && c <= 'F') return c - 'A' + 10;
        return -1;
    };
    
    auto hexByte = [&hexDigit](const char* s) -> int {
        int hi = hexDigit(s[0]);
        int lo = hexDigit(s[1]);
        if (hi < 0 || lo < 0) return -1;
        return (hi << 4) | lo;
    };
    
    // VID: bytes 4-5 at hex offset 8-11, little-endian
    int vidLo = hexByte(guid + 8);
    int vidHi = hexByte(guid + 10);
    if (vidLo < 0 || vidHi < 0) return false;
    *outVid = (uint16_t)(vidLo | (vidHi << 8));
    
    // PID: bytes 8-9 at hex offset 16-19, little-endian
    int pidLo = hexByte(guid + 16);
    int pidHi = hexByte(guid + 18);
    if (pidLo < 0 || pidHi < 0) return false;
    *outPid = (uint16_t)(pidLo | (pidHi << 8));
    
    return (*outVid != 0 || *outPid != 0);
}

static void initSDLGameControllerDB() {
    if (g_sdlDBInitialized) return;
    g_sdlDBInitialized = true;
    
    g_sdlParsedMappings.reserve(g_sdlGameControllerDBCount);
    
    for (int i = 0; i < g_sdlGameControllerDBCount; i++) {
        const char* entry = g_sdlGameControllerDB[i];
        if (!entry) break;
        
        GamepadMapping mapping;
        if (parseSDLMappingString(entry, &mapping)) {
            uint16_t vid = 0, pid = 0;
            if (extractVidPidFromGUID(entry, &vid, &pid)) {
                mapping.vendorId = vid;
                mapping.productId = pid;
                g_sdlParsedMappings.push_back(mapping);
            }
        }
    }
}

const GamepadMapping* findGamepadMapping(uint16_t vendorId, uint16_t productId) {
    for (int i = 0; g_mappingDatabase[i].name != NULL; i++) {
        if (g_mappingDatabase[i].vendorId == vendorId && 
            g_mappingDatabase[i].productId == productId) {
            return &g_mappingDatabase[i];
        }
    }
    
    initSDLGameControllerDB();
    for (size_t i = 0; i < g_sdlParsedMappings.size(); i++) {
        if (g_sdlParsedMappings[i].vendorId == vendorId &&
            g_sdlParsedMappings[i].productId == productId) {
            return &g_sdlParsedMappings[i];
        }
    }
    
    return NULL;
}

const GamepadMapping* getDefaultMappingByVendor(uint16_t vendorId) {
    for (int i = 0; g_vendorDefaults[i].defaultMapping != NULL; i++) {
        if (g_vendorDefaults[i].vendorId == vendorId) {
            return g_vendorDefaults[i].defaultMapping;
        }
    }
    return &g_genericDefaultMapping;
}

static bool parseElement(const char* str, MappingSource* out) {
    if (!str || !out) return false;
    
    out->type = MAPPING_NONE;
    out->index = 0;
    out->hatMask = 0;
    out->inverted = false;
    out->rangeMin = 0;
    out->rangeMax = 255;
    
    bool inverted = false;
    if (str[0] == '~') {
        inverted = true;
        str++;
    }
    
    char type = str[0];
    const char* rest = str + 1;
    
    switch (type) {
        case 'b':
            out->type = MAPPING_BUTTON;
            out->index = atoi(rest);
            break;
            
        case 'a':
            out->type = MAPPING_AXIS;
            out->inverted = inverted;
            {
                char* endptr;
                out->index = strtol(rest, &endptr, 10);
                if (*endptr == '+') {
                    out->rangeMin = 128;
                    out->rangeMax = 255;
                } else if (*endptr == '-') {
                    out->rangeMin = 0;
                    out->rangeMax = 128;
                }
            }
            break;
            
        case 'h':
            out->type = MAPPING_HAT;
            {
                const char* dotPos = strchr(rest, '.');
                if (dotPos) {
                    out->index = atoi(rest);
                    out->hatMask = atoi(dotPos + 1);
                }
            }
            break;
            
        default:
            return false;
    }
    
    return true;
}

bool parseSDLMappingString(const char* mappingString, GamepadMapping* outMapping) {
    if (!mappingString || !outMapping) return false;
    
    memset(outMapping, 0, sizeof(GamepadMapping));
    
    char* str = strdup(mappingString);
    if (!str) return false;
    
    char* token = strtok(str, ",");
    if (!token) { free(str); return false; }
    
    token = strtok(NULL, ",");
    if (token) {
        outMapping->name = strdup(token);
    }
    
    while ((token = strtok(NULL, ",")) != NULL) {
        char* colonPos = strchr(token, ':');
        if (!colonPos) continue;
        
        *colonPos = '\0';
        const char* key = token;
        const char* value = colonPos + 1;
        
        MappingSource src;
        if (!parseElement(value, &src)) continue;
        
        if (strcmp(key, "a") == 0) outMapping->a = src;
        else if (strcmp(key, "b") == 0) outMapping->b = src;
        else if (strcmp(key, "x") == 0) outMapping->x = src;
        else if (strcmp(key, "y") == 0) outMapping->y = src;
        else if (strcmp(key, "back") == 0) outMapping->back = src;
        else if (strcmp(key, "guide") == 0) outMapping->guide = src;
        else if (strcmp(key, "start") == 0) outMapping->start = src;
        else if (strcmp(key, "leftstick") == 0) outMapping->leftstick = src;
        else if (strcmp(key, "rightstick") == 0) outMapping->rightstick = src;
        else if (strcmp(key, "leftshoulder") == 0) outMapping->leftshoulder = src;
        else if (strcmp(key, "rightshoulder") == 0) outMapping->rightshoulder = src;
        else if (strcmp(key, "dpup") == 0) outMapping->dpup = src;
        else if (strcmp(key, "dpdown") == 0) outMapping->dpdown = src;
        else if (strcmp(key, "dpleft") == 0) outMapping->dpleft = src;
        else if (strcmp(key, "dpright") == 0) outMapping->dpright = src;
        else if (strcmp(key, "leftx") == 0) outMapping->leftx = src;
        else if (strcmp(key, "lefty") == 0) outMapping->lefty = src;
        else if (strcmp(key, "rightx") == 0) outMapping->rightx = src;
        else if (strcmp(key, "righty") == 0) outMapping->righty = src;
        else if (strcmp(key, "lefttrigger") == 0) outMapping->lefttrigger = src;
        else if (strcmp(key, "righttrigger") == 0) outMapping->righttrigger = src;
    }
    
    free(str);
    return true;
}

static bool readButton(const uint8_t* data, int len, const MappingSource* src, int buttonByteOffset) {
    if (src->type != MAPPING_BUTTON) return false;
    
    int byteIndex = buttonByteOffset + (src->index / 8);
    int bitIndex = src->index % 8;
    
    if (byteIndex >= len) return false;
    
    return (data[byteIndex] & (1 << bitIndex)) != 0;
}

static int16_t readAxis(const uint8_t* data, int len, const MappingSource* src, int axisOffset) {
    if (src->type != MAPPING_AXIS) return 0;
    
    int index = axisOffset + src->index;
    if (index >= len) return 0;
    
    int value = data[index];
    
    if (src->inverted) {
        value = 255 - value;
    }
    
    return (int16_t)(((int)value - 128) << 8);
}

static bool checkHat(const uint8_t* data, int len, const MappingSource* src, int hatOffset) {
    if (src->type != MAPPING_HAT) return false;
    
    int index = hatOffset + src->index;
    if (index >= len) return false;
    
    uint8_t hatValue = data[index] & 0x0F;
    
    static const uint8_t hatToMask[] = {
        HAT_UP,
        HAT_UP | HAT_RIGHT,
        HAT_RIGHT,
        HAT_DOWN | HAT_RIGHT,
        HAT_DOWN,
        HAT_DOWN | HAT_LEFT,
        HAT_LEFT,
        HAT_UP | HAT_LEFT
    };
    
    if (hatValue > 7) return false;
    
    return (hatToMask[hatValue] & src->hatMask) != 0;
}

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
) {
    if (!mapping || !data || len < 8) return;
    
    *outButtons = 0;
    *outLeftStickX = 0;
    *outLeftStickY = 0;
    *outRightStickX = 0;
    *outRightStickY = 0;
    *outLeftTrigger = 0;
    *outRightTrigger = 0;
    
    int offset = mapping->reportOffset;
    int buttonOffset = offset + 4;
    int hatOffset = offset + 4;
    int axisOffset = offset;
    
    if (mapping->leftx.type == MAPPING_AXIS) {
        *outLeftStickX = readAxis(data, len, &mapping->leftx, axisOffset);
    }
    if (mapping->lefty.type == MAPPING_AXIS) {
        *outLeftStickY = readAxis(data, len, &mapping->lefty, axisOffset);
    }
    if (mapping->rightx.type == MAPPING_AXIS) {
        *outRightStickX = readAxis(data, len, &mapping->rightx, axisOffset);
    }
    if (mapping->righty.type == MAPPING_AXIS) {
        *outRightStickY = readAxis(data, len, &mapping->righty, axisOffset);
    }
    
    if (mapping->lefttrigger.type == MAPPING_AXIS) {
        int idx = axisOffset + mapping->lefttrigger.index;
        if (idx < len) *outLeftTrigger = data[idx];
    } else if (mapping->lefttrigger.type == MAPPING_BUTTON) {
        if (readButton(data, len, &mapping->lefttrigger, buttonOffset)) {
            *outLeftTrigger = 255;
        }
    }
    
    if (mapping->righttrigger.type == MAPPING_AXIS) {
        int idx = axisOffset + mapping->righttrigger.index;
        if (idx < len) *outRightTrigger = data[idx];
    } else if (mapping->righttrigger.type == MAPPING_BUTTON) {
        if (readButton(data, len, &mapping->righttrigger, buttonOffset)) {
            *outRightTrigger = 255;
        }
    }
    
    #define CHECK_BTN(mapping_field, flag) \
        if (mapping->mapping_field.type == MAPPING_BUTTON && readButton(data, len, &mapping->mapping_field, buttonOffset)) \
            *outButtons |= flag; \
        else if (mapping->mapping_field.type == MAPPING_HAT && checkHat(data, len, &mapping->mapping_field, hatOffset)) \
            *outButtons |= flag;
    
    CHECK_BTN(a, BTN_FLAG_A);
    CHECK_BTN(b, BTN_FLAG_B);
    CHECK_BTN(x, BTN_FLAG_X);
    CHECK_BTN(y, BTN_FLAG_Y);
    CHECK_BTN(leftshoulder, BTN_FLAG_LB);
    CHECK_BTN(rightshoulder, BTN_FLAG_RB);
    CHECK_BTN(back, BTN_FLAG_BACK);
    CHECK_BTN(start, BTN_FLAG_START);
    CHECK_BTN(guide, BTN_FLAG_HOME);
    CHECK_BTN(leftstick, BTN_FLAG_LS_CLK);
    CHECK_BTN(rightstick, BTN_FLAG_RS_CLK);
    CHECK_BTN(dpup, BTN_FLAG_UP);
    CHECK_BTN(dpdown, BTN_FLAG_DOWN);
    CHECK_BTN(dpleft, BTN_FLAG_LEFT);
    CHECK_BTN(dpright, BTN_FLAG_RIGHT);
    
    #undef CHECK_BTN
}
