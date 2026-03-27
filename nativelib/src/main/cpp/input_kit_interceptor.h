/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 ljlVink
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

/**
 * Input Kit interceptor using OH_Input_AddInputEventInterceptor.
 * Handles mouse and touch events from the system input pipeline.
 * Keyboard events are handled via OH_Input_AddKeyEventInterceptor.
 * Axis events are intentionally not handled.
 */

#ifndef INPUT_KIT_INTERCEPTOR_H
#define INPUT_KIT_INTERCEPTOR_H

#include <napi/native_api.h>

#ifdef __cplusplus
extern "C" {
#endif

napi_value InputKitInterceptor_Init(napi_env env, napi_value exports);

#ifdef __cplusplus
}
#endif

#endif // INPUT_KIT_INTERCEPTOR_H
