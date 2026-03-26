/**
 * 
 */

#ifndef GAMEPAD_MANAGER_H
#define GAMEPAD_MANAGER_H

#include <stdint.h>
#include <stdbool.h>

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
} GamepadState;

typedef struct {
    int32_t deviceId;
    char name[256];
    uint16_t vendorId;
    uint16_t productId;
    int type;  // 0=Unknown, 1=Xbox, 2=PS, 3=Nintendo
    bool isGamepad;  // true=SDL_Gamepad, false=SDL_Joystick
} GamepadInfo;

#define GAMEPAD_UP_FLAG         0x0001
#define GAMEPAD_DOWN_FLAG       0x0002
#define GAMEPAD_LEFT_FLAG       0x0004
#define GAMEPAD_RIGHT_FLAG      0x0008
#define GAMEPAD_START_FLAG      0x0010
#define GAMEPAD_BACK_FLAG       0x0020
#define GAMEPAD_LS_CLK_FLAG     0x0040
#define GAMEPAD_RS_CLK_FLAG     0x0080
#define GAMEPAD_LB_FLAG         0x0100
#define GAMEPAD_RB_FLAG         0x0200
#define GAMEPAD_GUIDE_FLAG      0x0400
#define GAMEPAD_A_FLAG          0x1000
#define GAMEPAD_B_FLAG          0x2000
#define GAMEPAD_X_FLAG          0x4000
#define GAMEPAD_Y_FLAG          0x8000

typedef void (*GamepadConnectedCallback)(const GamepadInfo* info);
typedef void (*GamepadDisconnectedCallback)(int32_t deviceId);
typedef void (*GamepadStateCallback)(const GamepadState* state);

int GamepadManager_Init(void);

void GamepadManager_Quit(void);

void GamepadManager_SetConnectedCallback(GamepadConnectedCallback callback);
void GamepadManager_SetDisconnectedCallback(GamepadDisconnectedCallback callback);
void GamepadManager_SetStateCallback(GamepadStateCallback callback);

void GamepadManager_PollEvents(void);

int GamepadManager_GetConnectedCount(void);

int GamepadManager_GetInfo(int index, GamepadInfo* info);

int GamepadManager_GetState(int32_t deviceId, GamepadState* state);

int GamepadManager_Rumble(int32_t deviceId, uint16_t lowFreq, uint16_t highFreq, uint32_t durationMs);

int GamepadManager_OpenUsbDevice(uint16_t vendorId, uint16_t productId, int fd);

void GamepadManager_CloseUsbDevice(int32_t deviceId);

#ifdef __cplusplus
}
#endif

#endif // GAMEPAD_MANAGER_H
