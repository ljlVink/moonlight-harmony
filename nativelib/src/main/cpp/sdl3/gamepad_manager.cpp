/**
 * 
 */

#include "gamepad_manager.h"
#include <SDL3/SDL.h>
#include <SDL3/SDL_gamepad.h>
#include <SDL3/SDL_joystick.h>
#include <SDL3/SDL_hidapi.h>
#include <hilog/log.h>
#include <string.h>
#include <stdlib.h>

#define LOG_TAG "SDL3-Gamepad"
#define LOGD(...) OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGI(...) OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGW(...) OH_LOG_Print(LOG_APP, LOG_WARN, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, __VA_ARGS__)

#define MAX_GAMEPADS 4

typedef struct {
    bool active;
    SDL_JoystickID instanceId;
    SDL_Gamepad* gamepad;
    SDL_Joystick* joystick;
    GamepadInfo info;
    GamepadState state;
} GamepadInstance;

static bool g_initialized = false;
static GamepadInstance g_gamepads[MAX_GAMEPADS];
static int g_connectedCount = 0;

static GamepadConnectedCallback g_connectedCallback = NULL;
static GamepadDisconnectedCallback g_disconnectedCallback = NULL;
static GamepadStateCallback g_stateCallback = NULL;

static int FindFreeSlot(void);
static int FindSlotByInstanceId(SDL_JoystickID instanceId);
static void UpdateGamepadState(GamepadInstance* inst);
static int GetGamepadType(SDL_Gamepad* gamepad);

int GamepadManager_Init(void) {
    if (g_initialized) {
        LOGW("GamepadManager already initialized");
        return 0;
    }
    
    LOGI("Initializing SDL3 GamepadManager...");
    
    if (!SDL_Init(SDL_INIT_GAMEPAD | SDL_INIT_JOYSTICK)) {
        LOGE("SDL_Init failed: %s", SDL_GetError());
        return -1;
    }
    
    memset(g_gamepads, 0, sizeof(g_gamepads));
    g_connectedCount = 0;
    
    SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI, "1");
    SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI_PS4, "1");
    SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI_PS5, "1");
    SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI_XBOX, "1");
    SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI_SWITCH, "1");
    
    int numJoysticks = 0;
    SDL_JoystickID* joysticks = SDL_GetJoysticks(&numJoysticks);
    
    LOGI("Found %d joystick(s)", numJoysticks);
    
    if (joysticks) {
        for (int i = 0; i < numJoysticks && g_connectedCount < MAX_GAMEPADS; i++) {
            SDL_JoystickID joyId = joysticks[i];
            int slot = FindFreeSlot();
            if (slot < 0) break;
            
            GamepadInstance* inst = &g_gamepads[slot];
            inst->instanceId = joyId;
            
            if (SDL_IsGamepad(joyId)) {
                inst->gamepad = SDL_OpenGamepad(joyId);
                if (inst->gamepad) {
                    inst->joystick = SDL_GetGamepadJoystick(inst->gamepad);
                    inst->info.isGamepad = true;
                    inst->info.type = GetGamepadType(inst->gamepad);
                    const char* name = SDL_GetGamepadName(inst->gamepad);
                    strncpy(inst->info.name, name ? name : "Unknown Gamepad", sizeof(inst->info.name) - 1);
                    LOGI("Opened gamepad: %s (type=%d)", inst->info.name, inst->info.type);
                }
            }
            
            if (!inst->gamepad) {
                inst->joystick = SDL_OpenJoystick(joyId);
                if (inst->joystick) {
                    inst->info.isGamepad = false;
                    inst->info.type = 0;
                    const char* name = SDL_GetJoystickName(inst->joystick);
                    strncpy(inst->info.name, name ? name : "Unknown Joystick", sizeof(inst->info.name) - 1);
                    LOGI("Opened joystick: %s", inst->info.name);
                }
            }
            
            if (inst->gamepad || inst->joystick) {
                inst->active = true;
                inst->info.deviceId = slot;
                inst->info.vendorId = SDL_GetJoystickVendor(inst->joystick);
                inst->info.productId = SDL_GetJoystickProduct(inst->joystick);
                g_connectedCount++;
                
                LOGI("Registered device[%d]: VID=0x%04X PID=0x%04X name=%s",
                     slot, inst->info.vendorId, inst->info.productId, inst->info.name);
                
                if (g_connectedCallback) {
                    g_connectedCallback(&inst->info);
                }
            }
        }
        SDL_free(joysticks);
    }
    
    g_initialized = true;
    LOGI("GamepadManager initialized, %d device(s) connected", g_connectedCount);
    return 0;
}

void GamepadManager_Quit(void) {
    if (!g_initialized) return;
    
    LOGI("Shutting down GamepadManager...");
    
    for (int i = 0; i < MAX_GAMEPADS; i++) {
        if (g_gamepads[i].active) {
            if (g_gamepads[i].gamepad) {
                SDL_CloseGamepad(g_gamepads[i].gamepad);
            } else if (g_gamepads[i].joystick) {
                SDL_CloseJoystick(g_gamepads[i].joystick);
            }
        }
    }
    
    memset(g_gamepads, 0, sizeof(g_gamepads));
    g_connectedCount = 0;
    
    SDL_Quit();
    g_initialized = false;
    
    LOGI("GamepadManager shutdown complete");
}

void GamepadManager_SetConnectedCallback(GamepadConnectedCallback callback) {
    g_connectedCallback = callback;
}

void GamepadManager_SetDisconnectedCallback(GamepadDisconnectedCallback callback) {
    g_disconnectedCallback = callback;
}

void GamepadManager_SetStateCallback(GamepadStateCallback callback) {
    g_stateCallback = callback;
}

void GamepadManager_PollEvents(void) {
    if (!g_initialized) return;
    
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
            case SDL_EVENT_GAMEPAD_ADDED: {
                LOGI("Gamepad added: instance_id=%d", event.gdevice.which);
                int slot = FindFreeSlot();
                if (slot >= 0) {
                    GamepadInstance* inst = &g_gamepads[slot];
                    inst->instanceId = event.gdevice.which;
                    inst->gamepad = SDL_OpenGamepad(event.gdevice.which);
                    if (inst->gamepad) {
                        inst->joystick = SDL_GetGamepadJoystick(inst->gamepad);
                        inst->active = true;
                        inst->info.deviceId = slot;
                        inst->info.isGamepad = true;
                        inst->info.type = GetGamepadType(inst->gamepad);
                        inst->info.vendorId = SDL_GetJoystickVendor(inst->joystick);
                        inst->info.productId = SDL_GetJoystickProduct(inst->joystick);
                        const char* name = SDL_GetGamepadName(inst->gamepad);
                        strncpy(inst->info.name, name ? name : "Unknown", sizeof(inst->info.name) - 1);
                        g_connectedCount++;
                        
                        if (g_connectedCallback) {
                            g_connectedCallback(&inst->info);
                        }
                    }
                }
                break;
            }
            
            case SDL_EVENT_JOYSTICK_ADDED: {
                if (!SDL_IsGamepad(event.jdevice.which)) {
                    LOGI("Joystick added: instance_id=%d", event.jdevice.which);
                    int slot = FindFreeSlot();
                    if (slot >= 0) {
                        GamepadInstance* inst = &g_gamepads[slot];
                        inst->instanceId = event.jdevice.which;
                        inst->joystick = SDL_OpenJoystick(event.jdevice.which);
                        if (inst->joystick) {
                            inst->active = true;
                            inst->info.deviceId = slot;
                            inst->info.isGamepad = false;
                            inst->info.type = 0;
                            inst->info.vendorId = SDL_GetJoystickVendor(inst->joystick);
                            inst->info.productId = SDL_GetJoystickProduct(inst->joystick);
                            const char* name = SDL_GetJoystickName(inst->joystick);
                            strncpy(inst->info.name, name ? name : "Unknown", sizeof(inst->info.name) - 1);
                            g_connectedCount++;
                            
                            if (g_connectedCallback) {
                                g_connectedCallback(&inst->info);
                            }
                        }
                    }
                }
                break;
            }
            
            case SDL_EVENT_GAMEPAD_REMOVED:
            case SDL_EVENT_JOYSTICK_REMOVED: {
                int slot = FindSlotByInstanceId(event.gdevice.which);
                if (slot >= 0) {
                    GamepadInstance* inst = &g_gamepads[slot];
                    LOGI("Device removed: slot=%d name=%s", slot, inst->info.name);
                    
                    if (g_disconnectedCallback) {
                        g_disconnectedCallback(inst->info.deviceId);
                    }
                    
                    if (inst->gamepad) {
                        SDL_CloseGamepad(inst->gamepad);
                    } else if (inst->joystick) {
                        SDL_CloseJoystick(inst->joystick);
                    }
                    
                    memset(inst, 0, sizeof(GamepadInstance));
                    g_connectedCount--;
                }
                break;
            }
            
            default:
                break;
        }
    }
    
    for (int i = 0; i < MAX_GAMEPADS; i++) {
        if (g_gamepads[i].active) {
            UpdateGamepadState(&g_gamepads[i]);
            if (g_stateCallback) {
                g_stateCallback(&g_gamepads[i].state);
            }
        }
    }
}

int GamepadManager_GetConnectedCount(void) {
    return g_connectedCount;
}

int GamepadManager_GetInfo(int index, GamepadInfo* info) {
    if (index < 0 || index >= MAX_GAMEPADS || !info) {
        return -1;
    }
    
    int count = 0;
    for (int i = 0; i < MAX_GAMEPADS; i++) {
        if (g_gamepads[i].active) {
            if (count == index) {
                memcpy(info, &g_gamepads[i].info, sizeof(GamepadInfo));
                return 0;
            }
            count++;
        }
    }
    return -1;
}

int GamepadManager_GetState(int32_t deviceId, GamepadState* state) {
    if (deviceId < 0 || deviceId >= MAX_GAMEPADS || !state) {
        return -1;
    }
    
    if (!g_gamepads[deviceId].active) {
        return -1;
    }
    
    memcpy(state, &g_gamepads[deviceId].state, sizeof(GamepadState));
    return 0;
}

int GamepadManager_Rumble(int32_t deviceId, uint16_t lowFreq, uint16_t highFreq, uint32_t durationMs) {
    if (deviceId < 0 || deviceId >= MAX_GAMEPADS) {
        return -1;
    }
    
    GamepadInstance* inst = &g_gamepads[deviceId];
    if (!inst->active) {
        return -1;
    }
    
    if (inst->gamepad) {
        return SDL_RumbleGamepad(inst->gamepad, lowFreq, highFreq, durationMs) ? 0 : -1;
    } else if (inst->joystick) {
        return SDL_RumbleJoystick(inst->joystick, lowFreq, highFreq, durationMs) ? 0 : -1;
    }
    
    return -1;
}

int GamepadManager_OpenUsbDevice(uint16_t vendorId, uint16_t productId, int fd) {
    LOGI("OpenUsbDevice: VID=0x%04X PID=0x%04X fd=%d", vendorId, productId, fd);
    
    return -1;
}

void GamepadManager_CloseUsbDevice(int32_t deviceId) {
    if (deviceId < 0 || deviceId >= MAX_GAMEPADS) {
        return;
    }
    
    GamepadInstance* inst = &g_gamepads[deviceId];
    if (!inst->active) {
        return;
    }
    
    LOGI("CloseUsbDevice: deviceId=%d", deviceId);
    
    if (g_disconnectedCallback) {
        g_disconnectedCallback(deviceId);
    }
    
    if (inst->gamepad) {
        SDL_CloseGamepad(inst->gamepad);
    } else if (inst->joystick) {
        SDL_CloseJoystick(inst->joystick);
    }
    
    memset(inst, 0, sizeof(GamepadInstance));
    g_connectedCount--;
}

static int FindFreeSlot(void) {
    for (int i = 0; i < MAX_GAMEPADS; i++) {
        if (!g_gamepads[i].active) {
            return i;
        }
    }
    return -1;
}

static int FindSlotByInstanceId(SDL_JoystickID instanceId) {
    for (int i = 0; i < MAX_GAMEPADS; i++) {
        if (g_gamepads[i].active && g_gamepads[i].instanceId == instanceId) {
            return i;
        }
    }
    return -1;
}

static int GetGamepadType(SDL_Gamepad* gamepad) {
    if (!gamepad) return 0;
    
    SDL_GamepadType type = SDL_GetGamepadType(gamepad);
    switch (type) {
        case SDL_GAMEPAD_TYPE_XBOX360:
        case SDL_GAMEPAD_TYPE_XBOXONE:
            return 1;  // Xbox
        case SDL_GAMEPAD_TYPE_PS3:
        case SDL_GAMEPAD_TYPE_PS4:
        case SDL_GAMEPAD_TYPE_PS5:
            return 2;  // PlayStation
        case SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_PRO:
        case SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_LEFT:
        case SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_RIGHT:
        case SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_PAIR:
            return 3;  // Nintendo
        default:
            return 0;  // Unknown
    }
}

static bool NeedsL3R3Fix(uint16_t vid, uint16_t pid) {
    bool needsFix = (vid == 0x413D && pid == 0x2103);
    static bool loggedOnce = false;
    if (!loggedOnce) {
        LOGI("NeedsL3R3Fix check: VID=0x%04X PID=0x%04X needsFix=%d", vid, pid, needsFix);
        loggedOnce = true;
    }
    return needsFix;
}

static void UpdateGamepadState(GamepadInstance* inst) {
    if (!inst || !inst->active) return;
    
    GamepadState* state = &inst->state;
    state->deviceId = inst->info.deviceId;
    state->buttons = 0;
    
    bool needsL3R3Fix = NeedsL3R3Fix(inst->info.vendorId, inst->info.productId);
    
    static bool deviceLogged = false;
    if (!deviceLogged) {
        LOGI("UpdateGamepadState: isGamepad=%d VID=0x%04X PID=0x%04X needsL3R3Fix=%d",
             inst->info.isGamepad, inst->info.vendorId, inst->info.productId, needsL3R3Fix);
        deviceLogged = true;
    }
    
    if (inst->info.isGamepad && inst->gamepad) {
        SDL_UpdateGamepads();
        
        // D-Pad
        if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_DPAD_UP))
            state->buttons |= GAMEPAD_UP_FLAG;
        if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_DPAD_DOWN))
            state->buttons |= GAMEPAD_DOWN_FLAG;
        if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_DPAD_LEFT))
            state->buttons |= GAMEPAD_LEFT_FLAG;
        if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_DPAD_RIGHT))
            state->buttons |= GAMEPAD_RIGHT_FLAG;
        
        // Face buttons (A/B/X/Y)
        if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_SOUTH))
            state->buttons |= GAMEPAD_A_FLAG;
        if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_EAST))
            state->buttons |= GAMEPAD_B_FLAG;
        if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_WEST))
            state->buttons |= GAMEPAD_X_FLAG;
        if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_NORTH))
            state->buttons |= GAMEPAD_Y_FLAG;
        
        // Shoulder buttons
        if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_LEFT_SHOULDER))
            state->buttons |= GAMEPAD_LB_FLAG;
        if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER))
            state->buttons |= GAMEPAD_RB_FLAG;
        
        // Stick buttons (L3/R3)
        if (needsL3R3Fix) {
            if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_RIGHT_STICK))
                state->buttons |= GAMEPAD_LS_CLK_FLAG;  // RIGHT_STICK -> L3
            if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_GUIDE))
                state->buttons |= GAMEPAD_RS_CLK_FLAG;  // GUIDE -> R3
            if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_LEFT_STICK))
                state->buttons |= GAMEPAD_GUIDE_FLAG;   // LEFT_STICK -> GUIDE
        } else {
            if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_LEFT_STICK))
                state->buttons |= GAMEPAD_LS_CLK_FLAG;
            if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_RIGHT_STICK))
                state->buttons |= GAMEPAD_RS_CLK_FLAG;
        }
        
        // Start/Back/Guide
        if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_START))
            state->buttons |= GAMEPAD_START_FLAG;
        if (SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_BACK))
            state->buttons |= GAMEPAD_BACK_FLAG;
        if (!needsL3R3Fix && SDL_GetGamepadButton(inst->gamepad, SDL_GAMEPAD_BUTTON_GUIDE))
            state->buttons |= GAMEPAD_GUIDE_FLAG;
        
        // Axes
        state->leftStickX = SDL_GetGamepadAxis(inst->gamepad, SDL_GAMEPAD_AXIS_LEFTX);
        state->leftStickY = SDL_GetGamepadAxis(inst->gamepad, SDL_GAMEPAD_AXIS_LEFTY);
        state->rightStickX = SDL_GetGamepadAxis(inst->gamepad, SDL_GAMEPAD_AXIS_RIGHTX);
        state->rightStickY = SDL_GetGamepadAxis(inst->gamepad, SDL_GAMEPAD_AXIS_RIGHTY);
        
        // Triggers (0-32767)
        int16_t leftTrigger = SDL_GetGamepadAxis(inst->gamepad, SDL_GAMEPAD_AXIS_LEFT_TRIGGER);
        int16_t rightTrigger = SDL_GetGamepadAxis(inst->gamepad, SDL_GAMEPAD_AXIS_RIGHT_TRIGGER);
        state->leftTrigger = (uint8_t)((leftTrigger * 255) / 32767);
        state->rightTrigger = (uint8_t)((rightTrigger * 255) / 32767);
        
    } else if (inst->joystick) {
        SDL_UpdateJoysticks();
        
        int numButtons = SDL_GetNumJoystickButtons(inst->joystick);
        int numAxes = SDL_GetNumJoystickAxes(inst->joystick);
        int numHats = SDL_GetNumJoystickHats(inst->joystick);
        
        if (numButtons > 0 && SDL_GetJoystickButton(inst->joystick, 0))
            state->buttons |= GAMEPAD_A_FLAG;
        if (numButtons > 1 && SDL_GetJoystickButton(inst->joystick, 1))
            state->buttons |= GAMEPAD_B_FLAG;
        if (numButtons > 2 && SDL_GetJoystickButton(inst->joystick, 2))
            state->buttons |= GAMEPAD_X_FLAG;
        if (numButtons > 3 && SDL_GetJoystickButton(inst->joystick, 3))
            state->buttons |= GAMEPAD_Y_FLAG;
        if (numButtons > 4 && SDL_GetJoystickButton(inst->joystick, 4))
            state->buttons |= GAMEPAD_LB_FLAG;
        if (numButtons > 5 && SDL_GetJoystickButton(inst->joystick, 5))
            state->buttons |= GAMEPAD_RB_FLAG;
        if (numButtons > 6 && SDL_GetJoystickButton(inst->joystick, 6))
            state->buttons |= GAMEPAD_BACK_FLAG;
        if (numButtons > 7 && SDL_GetJoystickButton(inst->joystick, 7))
            state->buttons |= GAMEPAD_START_FLAG;
        if (numButtons > 8 && SDL_GetJoystickButton(inst->joystick, 8))
            state->buttons |= GAMEPAD_GUIDE_FLAG;
        if (numButtons > 9 && SDL_GetJoystickButton(inst->joystick, 9))
            state->buttons |= GAMEPAD_LS_CLK_FLAG;
        if (numButtons > 10 && SDL_GetJoystickButton(inst->joystick, 10))
            state->buttons |= GAMEPAD_RS_CLK_FLAG;
        
        if (numAxes > 0)
            state->leftStickX = SDL_GetJoystickAxis(inst->joystick, 0);
        if (numAxes > 1)
            state->leftStickY = SDL_GetJoystickAxis(inst->joystick, 1);
        if (numAxes > 2)
            state->rightStickX = SDL_GetJoystickAxis(inst->joystick, 2);
        if (numAxes > 3)
            state->rightStickY = SDL_GetJoystickAxis(inst->joystick, 3);
        if (numAxes > 4) {
            int16_t lt = SDL_GetJoystickAxis(inst->joystick, 4);
            state->leftTrigger = (uint8_t)(((lt + 32768) * 255) / 65535);
        }
        if (numAxes > 5) {
            int16_t rt = SDL_GetJoystickAxis(inst->joystick, 5);
            state->rightTrigger = (uint8_t)(((rt + 32768) * 255) / 65535);
        }
        
        // HAT/D-Pad
        if (numHats > 0) {
            uint8_t hat = SDL_GetJoystickHat(inst->joystick, 0);
            if (hat & SDL_HAT_UP) state->buttons |= GAMEPAD_UP_FLAG;
            if (hat & SDL_HAT_DOWN) state->buttons |= GAMEPAD_DOWN_FLAG;
            if (hat & SDL_HAT_LEFT) state->buttons |= GAMEPAD_LEFT_FLAG;
            if (hat & SDL_HAT_RIGHT) state->buttons |= GAMEPAD_RIGHT_FLAG;
        }
    }
}
