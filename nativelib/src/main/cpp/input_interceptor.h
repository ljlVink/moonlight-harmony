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

#ifndef INPUT_INTERCEPTOR_H
#define INPUT_INTERCEPTOR_H

#include <napi/native_api.h>

#ifdef __cplusplus
extern "C" {
#endif

napi_value InputInterceptor_Init(napi_env env, napi_value exports);

#ifdef __cplusplus
}
#endif

#endif // INPUT_INTERCEPTOR_H
