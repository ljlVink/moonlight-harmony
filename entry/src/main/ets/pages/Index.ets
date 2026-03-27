/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { router } from "@kit.ArkUI";
import { AppColors } from "../common/Theme";
import { PreferencesUtil } from "../utils/PreferencesUtil";
import { common } from "@kit.AbilityKit";

const PRIVACY_ACCEPTED_KEY = "privacy_policy_accepted";

interface PrivacySection {
  title: string;
  content: string;
}

@Entry
@Component
struct Index {
  @State isLoading: boolean = true;
  @State showPrivacyConsent: boolean = false;

  private privacySections: PrivacySection[] = [
    {
      title: "1. 数据收集与存储",
      content:
        "本应用不会主动收集、存储或传输任何用户的个人身份信息。" +
        "所有配置数据（如服务器地址、偏好设置、配对密钥）仅存储在您的设备本地。",
    } as PrivacySection,
    {
      title: "2. 设备信息",
      content:
        '本应用会读取设备型号名称（如 "HUAWEI Mate 60 Pro"）用于串流协议握手时标识客户端。' +
        "此信息仅在局域网内与您的电脑通信时使用，不会上传至任何互联网服务器。\n" +
        "本应用会在设备本地生成并保存一个随机标识符用于配对协议，该标识符不与任何个人身份信息关联。",
    } as PrivacySection,
    {
      title: "3. 网络通信",
      content:
        "• 应用仅在您的本地网络内与电脑建立连接，传输游戏音视频流和输入指令\n" +
        "• 使用 mDNS 协议在局域网内自动发现运行 GameStream/Sunshine 的电脑\n" +
        "• 不涉及任何互联网数据上传",
    } as PrivacySection,
    {
      title: "4. 权限使用",
      content:
        "• 网络权限：与电脑建立连接，传输游戏流\n" +
        "• 网络信息：检测网络连接状态，优化串流质量\n" +
        "• 麦克风：语音聊天功能（可选，使用时单独请求授权）\n" +
        "• 振动：手柄震动反馈\n" +
        "• 加速度/陀螺仪传感器：体感控制（可选）\n" +
        "• 后台运行：保持串流连接在后台不中断",
    } as PrivacySection,
    {
      title: "5. 第三方服务",
      content: "本应用不集成任何第三方分析、广告或数据追踪服务。",
    } as PrivacySection,
    {
      title: "6. 开源合规",
      content: "本应用基于 Moonlight 项目开发，遵循 GPLv3 开源协议。源代码可在 GitHub 获取。",
    } as PrivacySection,
  ];

  aboutToAppear(): void {
    this.checkPrivacyConsent();
  }

  /**
   * Check privacy policy consent status
   */
  private async checkPrivacyConsent(): Promise<void> {
    try {
      const accepted = await PreferencesUtil.get<boolean>(PRIVACY_ACCEPTED_KEY, false);
      if (accepted) {
        this.navigateToMain();
      } else {
        this.showPrivacyConsent = true;
      }
    } catch (err) {
      console.error("Index: Failed to check privacy policy status", err);
      this.showPrivacyConsent = true;
    }
  }

  /**
   * User accepts privacy policy
   */
  private async onPrivacyAccepted(): Promise<void> {
    try {
      await PreferencesUtil.put(PRIVACY_ACCEPTED_KEY, true);
    } catch (err) {
      console.error("Index: Failed to save privacy policy consent status", err);
    }
    this.showPrivacyConsent = false;
    this.navigateToMain();
  }

  /**
   * User declines privacy policy - exit app
   */
  private onPrivacyDeclined(): void {
    const context = getContext(this) as common.UIAbilityContext;
    context.terminateSelf();
  }

  /**
   * Navigate to main page
   */
  private navigateToMain(): void {
    this.isLoading = false;
    try {
      router.replaceUrl({ url: "pages/PcListPageV2" });
    } catch (e) {
      console.error("Index: navigation failed - " + e);
    }
  }

  build() {
    Stack() {
      if (this.showPrivacyConsent) {
        Column()
          .width("100%")
          .height("100%")
          .backgroundColor("#80000000");

        Column() {
          Column({ space: 4 }) {
            Text("用户协议与隐私政策")
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TextPrimary)
            Text("请仔细阅读以下内容")
              .fontSize(13)
              .fontColor(AppColors.TextTertiary)
          }
          .width("100%")
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 24, bottom: 12, left: 20, right: 20 })
          Text("欢迎使用 Moonlight V+！在您使用本应用之前，请仔细阅读并了解我们的隐私政策：")
            .fontSize(14)
            .fontColor(AppColors.TextSecondary)
            .padding({ left: 20, right: 20, bottom: 8 })
            .width("100%")
          Scroll() {
            Column({ space: 12 }) {
              ForEach(this.privacySections, (section: PrivacySection) => {
                Column({ space: 6 }) {
                  Text(section.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TextPrimary)
                    .width("100%")
                  Text(section.content)
                    .fontSize(13)
                    .fontColor(AppColors.TextSecondary)
                    .width("100%")
                    .lineHeight(20)
                }
                .width("100%")
                .padding(12)
                .backgroundColor(AppColors.CardBackground)
                .borderRadius(8);
              })
              Text("完整隐私政策请查看项目仓库中的 PRIVACY_POLICY.md")
                .fontSize(12)
                .fontColor(AppColors.TextTertiary)
                .width("100%")
                .textAlign(TextAlign.Center)
                .padding({ top: 4, bottom: 8 })
            }
            .padding({ left: 20, right: 20 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          Column({ space: 10 }) {
            Button("同意并继续")
              .width("100%")
              .height(44)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor(AppColors.Primary)
              .borderRadius(22)
              .onClick(() => {
                this.onPrivacyAccepted();
              })
            Button("不同意")
              .width("100%")
              .height(44)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TextSecondary)
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: AppColors.Divider, style: BorderStyle.Solid })
              .borderRadius(22)
              .onClick(() => {
                this.onPrivacyDeclined();
              })
          }
          .width("100%")
          .padding({ left: 20, right: 20, top: 12, bottom: 24 })
        }
        .width("88%")
        .height("75%")
        .backgroundColor(AppColors.Background)
        .borderRadius(20)
        .shadow({
          radius: 24,
          color: "#40000000",
          offsetX: 0,
          offsetY: 8,
        })
      }
    }
    .width("100%")
    .height("100%")
    .backgroundColor(AppColors.Background);
  }
}
