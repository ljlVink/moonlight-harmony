/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * USB Helper - Kernel driver reattachment implementation
 *
 * Uses Linux USBDEVFS ioctl to rebind USB interface drivers.
 * Fixes the issue where releaseInterface() does not automatically
 * reattach the kernel HID driver after claimInterface(force=true).
 */

#include "usb_helper.h"

#include <sys/ioctl.h>
#include <errno.h>
#include <string.h>
#include <hilog/log.h>

#define LOG_TAG "USB-Helper"

// ============================================================
// ============================================================

struct usbdevfs_ioctl_arg {
    int ifno;
    int ioctl_code;
    void *data;
};

// _IO(type, nr) = ((type) << 8) | (nr)
// _IOC(dir, type, nr, size) = ((dir) << 30) | ((type) << 8) | (nr) | ((size) << 16)
// dir: 0=none, 1=write, 2=read, 3=read|write

// USBDEVFS_CONNECT = _IO('U', 23)
#define USBDEVFS_CONNECT_NR 23

// USBDEVFS_IOCTL = _IOWR('U', 18, struct usbdevfs_ioctl)
// _IOWR: dir=3 (read|write), type='U'(0x55), nr=18
#define USBDEVFS_IOCTL_CMD  ((3u << 30) | (0x55u << 8) | 18u | ((unsigned int)sizeof(struct usbdevfs_ioctl_arg) << 16))

// _IO('U', 23) = (0x55 << 8) | 23 = 0x5517
#define USBDEVFS_CONNECT_CODE ((0x55u << 8) | USBDEVFS_CONNECT_NR)

// USBDEVFS_RESET = _IO('U', 20)
#define USBDEVFS_RESET_CMD ((0x55u << 8) | 20u)

static int reattach_kernel_driver(int fd, int interfaceNumber) {
    struct usbdevfs_ioctl_arg arg;
    memset(&arg, 0, sizeof(arg));
    arg.ifno = interfaceNumber;
    arg.ioctl_code = USBDEVFS_CONNECT_CODE;
    arg.data = NULL;

    OH_LOG_INFO(LOG_APP, "[%{public}s] Attempting kernel driver reattach: fd=%{public}d, iface=%{public}d",
                LOG_TAG, fd, interfaceNumber);

    int ret = ioctl(fd, USBDEVFS_IOCTL_CMD, &arg);
    if (ret < 0) {
        int err = errno;
        OH_LOG_WARN(LOG_APP, "[%{public}s] ioctl USBDEVFS_CONNECT failed: fd=%{public}d, iface=%{public}d, "
                    "errno=%{public}d (%{public}s)",
                    LOG_TAG, fd, interfaceNumber, err, strerror(err));
        return -err;
    }

    OH_LOG_INFO(LOG_APP, "[%{public}s] Kernel driver reattached: fd=%{public}d, iface=%{public}d, ret=%{public}d",
                LOG_TAG, fd, interfaceNumber, ret);
    return 0;
}

static int reset_usb_device(int fd) {
    OH_LOG_INFO(LOG_APP, "[%{public}s] Attempting USB device reset: fd=%{public}d", LOG_TAG, fd);

    int ret = ioctl(fd, USBDEVFS_RESET_CMD, NULL);
    if (ret < 0) {
        int err = errno;
        OH_LOG_WARN(LOG_APP, "[%{public}s] ioctl USBDEVFS_RESET failed: fd=%{public}d, errno=%{public}d (%{public}s)",
                    LOG_TAG, fd, err, strerror(err));
        return -err;
    }

    OH_LOG_INFO(LOG_APP, "[%{public}s] USB device reset succeeded: fd=%{public}d", LOG_TAG, fd);
    return 0;
}

// ============================================================
// ============================================================

/**
 * NAPI: UsbHelper.reattachKernelDriver(fd: number, interfaceNumber: number): number
 */
napi_value UsbHelper_ReattachKernelDriver(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) {
        OH_LOG_ERROR(LOG_APP, "[%{public}s] reattachKernelDriver: insufficient arguments", LOG_TAG);
        napi_value result;
        napi_create_int32(env, -1, &result);
        return result;
    }

    int32_t fd = -1;
    int32_t interfaceNumber = 0;
    napi_get_value_int32(env, args[0], &fd);
    napi_get_value_int32(env, args[1], &interfaceNumber);

    int ret = reattach_kernel_driver(fd, interfaceNumber);

    if (ret < 0) {
        OH_LOG_WARN(LOG_APP, "[%{public}s] CONNECT failed (ret=%{public}d), trying RESET fallback",
                    LOG_TAG, ret);
        ret = reset_usb_device(fd);
        if (ret == 0) {
            napi_value result;
            napi_create_int32(env, 1, &result);
            return result;
        }
    }

    napi_value result;
    napi_create_int32(env, ret, &result);
    return result;
}

void UsbHelper_Init(napi_env env, napi_value exports) {
    napi_value usbHelperObj;
    napi_create_object(env, &usbHelperObj);

    napi_property_descriptor methods[] = {
        { "reattachKernelDriver", nullptr, UsbHelper_ReattachKernelDriver,
          nullptr, nullptr, nullptr, napi_default, nullptr },
    };

    napi_define_properties(env, usbHelperObj,
                           sizeof(methods) / sizeof(methods[0]), methods);

    napi_set_named_property(env, exports, "UsbHelper", usbHelperObj);

    OH_LOG_INFO(LOG_APP, "[%{public}s] USB Helper NAPI initialized", LOG_TAG);
}
