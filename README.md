# Moonlight V+ for HarmonyOS

<div align="center">
  <img src="entry/src/main/resources/base/media/app_icon.png" width="128" height="128" alt="Logo">

  # Moonlight V+ for HarmonyOS

  [![GitHub License](https://img.shields.io/github/license/AlkaidLab/moonlight-harmony)](LICENSE)
  [![HarmonyOS](https://img.shields.io/badge/HarmonyOS-6.0%2B-blue)](https://www.harmonyos.com/)
  [![API Version](https://img.shields.io/badge/API-20%2B-green)](https://developer.huawei.com/)

  基于 [Moonlight V+](https://github.com/qiin2333/moonlight-vplus) 的鸿蒙原生移植版本
</div>

---

此版本仅为自用版，符合gplv3要求开源分发。

## 功能特性


| 特性 | 原版 Moonlight | Moonlight V+ |
|------|:-:|:-:|
| HDR10 | ✅ | ✅ 亮度映射同步 |
| **HLG (HDR Vivid)** | ❌ | ✅ 独家 |
| **虚拟显示器** | ❌ | ✅ 无缝连接，不抢主屏 |
| **服务端指令** | ❌ | ✅ 串流中直接执行 |
| **动态码率调节** | ❌ | ✅ 串流中任意尝试大小 |
| 空间音频 | ❌ | ✅ HarmonyOS 5.0+ |
| **体感助手 (Gyro Aim)** | ❌ | ✅ 陀螺仪→右摇杆辅助瞄准 |
| Game Controller Kit | ❌ | ✅ 鸿蒙原生手柄 API |
| VRR 可变刷新率 | ❌ | ✅ 告别撕裂 |
| 性能覆盖层 | 基础 | ✅ 可拖拽/自定义项目 |
| 麦克风重定向 | ❌ | ✅ 语音开黑 |

## 相关项目

| 项目 | 说明 |
|------|------|
| [Moonlight V+ Android](https://github.com/qiin2333/moonlight-vplus) | Android 增强版客户端 |
| [Foundation Sunshine](https://github.com/qiin2333/foundation-sunshine) | 游戏串流服务端 |
| [Moonlight](https://moonlight-stream.org/) | 官方 Moonlight 项目 |
| [moonlight-common-c](https://github.com/moonlight-stream/moonlight-common-c) | 核心协议库 |

## 开发指南

### 开发环境

- DevEco Studio 6.0.0 或更高版本
- HarmonyOS SDK API 20 (HarmonyOS 6.0)
- Node.js 16.x 或更高版本

### 构建项目

```bash
# 克隆仓库
git clone https://github.com/ljlvink/moonlight-harmony.git

git submodule update --init --recursive

# if you are windows
./prebuild_win/copy_aubio.bat

./hvigorw assembleHap
```

## 许可证

本项目基于 [GPL v3](LICENSE) 许可证开源。

## 致谢

- [Moonlight Game Streaming](https://moonlight-stream.org/) - 官方 Moonlight 项目
- [moonlight-common-c](https://github.com/moonlight-stream/moonlight-common-c) - 核心协议库
- [LizardByte/Sunshine](https://github.com/LizardByte/Sunshine) - 开源串流服务端

---

<div align="center">
  
  **Powered by AlkaidLab**
  
  觉得有用的话，欢迎给个 Star。
  
</div>
