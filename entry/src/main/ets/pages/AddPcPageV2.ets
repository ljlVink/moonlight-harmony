/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { router, promptAction } from "@kit.ArkUI";
import { ComputerManager } from "../service/ComputerManager";
import { AppColors, AppSizes, AppSpacing, AppAnimation, AppShadows } from "../common/Theme";

class AddressPortResult {
  address: string = "";
  port: number | undefined = undefined;
}

@Entry
@Component
struct AddPcPageV2 {
  @StorageProp("topSafeHeight") topSafeHeight: number = 56;
  @State ipAddress: string = "";
  @State isAdding: boolean = false;
  @State errorMessage: string = "";

  @State isValidInput: boolean = false;
  @State showSuccess: boolean = false;
  @State inputFocused: boolean = false;
  @State headerOffset: number = -20;
  @State headerOpacity: number = 0;

  @State dianLaoIndex: number = 0;

  @State dianLaoScale: number = 1;
  @State dianLaoBounce: number = 0;

  private computerManager: ComputerManager = ComputerManager.getInstance();

  private readonly dianLaoQuotes: string[] = [
    "正在初始化颠佬协议...",
    "连接上了就是颠佬 ⚡",
    "一键串流，原神启动！",
    "今日份の串流开始了",
    "显卡在燃烧，颠佬在微笑",
    "new DianLao().connect() 🔌",
    "sudo moonlight --dian-lao",
    "延迟 < 10ms = 颠佬认证 ✓",
    "串流の呼吸・壱ノ型",
  ];

  aboutToAppear() {
    this.dianLaoIndex = Math.floor(Math.random() * this.dianLaoQuotes.length);

    setTimeout(() => {
      animateTo(
        {
          duration: AppAnimation.Slow,
          curve: Curve.EaseOut,
        },
        () => {
          this.headerOffset = 0;
          this.headerOpacity = 1;
        },
      );
    }, 100);

    setTimeout(() => {
      this.startDianLaoBounce();
    }, 600);
  }

  build() {
    Column() {
      this.NavBar()
      Scroll() {
        Column() {
          this.HeroSection()

          this.InputCard()

          this.HelpSection()
          Blank().height(40)
        }
        .width("100%")
        .constraintSize({ minHeight: "100%" })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width("100%")
    .height("100%")
    .backgroundColor(AppColors.Background);
  }

  @Builder
  NavBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Image($r("app.media.ic_back"))
          .width(20)
          .height(20)
          .fillColor(AppColors.TextPrimary)
      }
      .width(36)
      .height(36)
      .backgroundColor(AppColors.CardBackground)
      .shadow(AppShadows.Small)
      .onClick(() => router.back())
      Blank()
    }
    .width("100%")
    .height(56)
    .padding({ left: AppSpacing.Large, right: AppSpacing.Large })
    .margin({ top: this.topSafeHeight - 12 });
  }

  @Builder
  HeroSection() {
    Column() {
      Stack() {
        Circle()
          .width(120)
          .height(120)
          .fill(AppColors.PrimaryGlow)
          .opacity(0.3)
          .scale({ x: this.dianLaoScale, y: this.dianLaoScale })
          .animation({
            duration: 2000,
            curve: Curve.EaseInOut,
            iterations: -1,
            playMode: PlayMode.Alternate,
          })
        Row() {
          Text("━━╸")
            .fontSize(12)
            .fontColor(AppColors.Primary)
            .opacity(0.4)
        }
        .offset({ x: -65, y: 0 })
        Row() {
          Text("╺━━")
            .fontSize(12)
            .fontColor(AppColors.Primary)
            .opacity(0.4)
        }
        .offset({ x: 65, y: 0 })
        Column() {
          Image($r("app.media.ic_gpu"))
            .width(44)
            .height(44)
            .fillColor(AppColors.Primary)
            .offset({ y: this.dianLaoBounce })
        }
        .width(76)
        .height(76)
        .borderRadius(24)
        .backgroundColor(AppColors.CardBackground)
        .justifyContent(FlexAlign.Center)
        .shadow(AppShadows.Medium)
        .borderWidth(2)
        .borderColor(AppColors.Primary)
        .onClick(() => {
          animateTo(
            {
              duration: 300,
              curve: Curve.EaseOut,
            },
            () => {
              this.dianLaoIndex = (this.dianLaoIndex + 1) % this.dianLaoQuotes.length;
            },
          );

          this.triggerBounce();
        })
        Column()
          .width(12)
          .height(12)
          .borderRadius(6)
          .backgroundColor("#4CAF50")
          .shadow({
            radius: 6,
            color: "#4CAF50",
            offsetX: 0,
            offsetY: 0,
          })
          .offset({ x: 30, y: -30 })
        Text("5090")
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextOnPrimary)
          .fontFamily("monospace")
          .backgroundColor(AppColors.Primary)
          .borderRadius(4)
          .padding({ left: 5, right: 5, top: 2, bottom: 2 })
          .offset({ x: 28, y: 28 })
      }
      .offset({ y: this.headerOffset })
      .opacity(this.headerOpacity)
      Row() {
        Text("new")
          .fontSize(13)
          .fontColor(AppColors.Primary)
          .fontFamily("monospace")
          .fontWeight(FontWeight.Medium)
        Text(" DianLao")
          .fontSize(13)
          .fontColor(AppColors.TextPrimary)
          .fontFamily("monospace")
          .fontWeight(FontWeight.Bold)
        Text("()")
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
          .fontFamily("monospace")
      }
      .margin({ top: AppSpacing.Large })
      .offset({ y: this.headerOffset })
      .opacity(this.headerOpacity)
      Text("添加主机")
        .fontSize(AppSizes.FontLargeTitle)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .margin({ top: AppSpacing.Small })
        .offset({ y: this.headerOffset })
        .opacity(this.headerOpacity)
      Text(this.dianLaoQuotes[this.dianLaoIndex])
        .fontSize(AppSizes.FontCaption)
        .fontColor(AppColors.TextTertiary)
        .fontFamily("monospace")
        .margin({ top: AppSpacing.Small })
        .textAlign(TextAlign.Center)
        .offset({ y: this.headerOffset })
        .opacity(this.headerOpacity)
        .onClick(() => {
          animateTo(
            {
              duration: 200,
              curve: Curve.EaseOut,
            },
            () => {
              this.dianLaoIndex = (this.dianLaoIndex + 1) % this.dianLaoQuotes.length;
            },
          );
        })
    }
    .width("100%")
    .padding({
      top: AppSpacing.Medium,
      bottom: AppSpacing.XXLarge,
      left: AppSpacing.XLarge,
      right: AppSpacing.XLarge,
    })
    .alignItems(HorizontalAlign.Center);
  }

  /**
   * DianLao bounce animation
   */
  private startDianLaoBounce(): void {
    animateTo(
      {
        duration: 2000,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate,
      },
      () => {
        this.dianLaoScale = 1.15;
      },
    );
  }

  /**
   * Click bounce feedback
   */
  private triggerBounce(): void {
    animateTo(
      {
        duration: 150,
        curve: Curve.EaseOut,
      },
      () => {
        this.dianLaoBounce = -6;
      },
    );
    setTimeout(() => {
      animateTo(
        {
          duration: 200,
          curve: Curve.EaseInOut,
        },
        () => {
          this.dianLaoBounce = 0;
        },
      );
    }, 150);
  }

  @Builder
  InputCard() {
    Column() {
      Column() {
        Row() {
          Text("主机地址")
            .fontSize(AppSizes.FontCaption)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.inputFocused ? AppColors.Primary : AppColors.TextSecondary)
        }
        .width("100%")
        .margin({ bottom: AppSpacing.Small })
        Row() {
          Image($r("app.media.ic_computer"))
            .width(18)
            .height(18)
            .fillColor(
              this.inputFocused || this.ipAddress ? AppColors.Primary : AppColors.TextTertiary,
            )
            .margin({ right: AppSpacing.Medium })
            .animation({ duration: AppAnimation.Fast })
          TextInput({ placeholder: "192.168.1.100 或 hostname", text: this.ipAddress })
            .layoutWeight(1)
            .height(44)
            .fontSize(AppSizes.FontBody)
            .fontColor(AppColors.TextPrimary)
            .caretColor(AppColors.Primary)
            .placeholderColor(AppColors.TextTertiary)
            .placeholderFont({ size: AppSizes.FontBody })
            .backgroundColor(Color.Transparent)
            .onChange((value: string) => {
              this.ipAddress = value;
              this.validateInput();
              this.errorMessage = "";
            })
            .onSubmit(() => {
              if (this.isValidInput) {
                this.addComputer();
              }
            })

          if (this.ipAddress.length > 0) {
            Button({ type: ButtonType.Circle }) {
              Text("✕")
                .fontSize(12)
                .fontColor(AppColors.TextTertiary)
            }
            .width(24)
            .height(24)
            .backgroundColor(AppColors.Background)
            .onClick(() => {
              this.ipAddress = "";
              this.isValidInput = false;
              this.errorMessage = "";
            })
            .transition(
              TransitionEffect.OPACITY.animation({ duration: AppAnimation.Fast }).combine(
                TransitionEffect.scale({ x: 0.8, y: 0.8 }),
              ),
            );
          }
        }
        .width("100%")
        .height(52)
        .padding({ left: AppSpacing.Medium, right: AppSpacing.Small })
        .backgroundColor(AppColors.Background)
        .borderRadius(AppSizes.RadiusLarge)
        .border({
          width: this.inputFocused ? 1.5 : 1,
          color: this.errorMessage
            ? AppColors.Error
            : this.inputFocused
              ? AppColors.Primary
              : AppColors.CardBorder,
        })
        .animation({ duration: AppAnimation.Fast })

        if (!this.errorMessage && this.ipAddress.length === 0) {
          Text("支持 IPv4、IPv6 和自定义端口（如 :47989）")
            .fontSize(11)
            .fontColor(AppColors.TextTertiary)
            .margin({ top: AppSpacing.XSmall })
            .alignSelf(ItemAlign.Start);
        }
      }.width("100%")

      if (this.errorMessage) {
        Row() {
          Image($r("app.media.ic_error"))
            .width(14)
            .height(14)
            .fillColor(AppColors.Error)
            .margin({ right: 6 })
          Text(this.errorMessage)
            .fontSize(AppSizes.FontCaption)
            .fontColor(AppColors.Error)
            .layoutWeight(1)
        }
        .width("100%")
        .padding(AppSpacing.Medium)
        .backgroundColor("#FFF5F5")
        .borderRadius(AppSizes.RadiusMedium)
        .margin({ top: AppSpacing.Small })
        .transition(
          TransitionEffect.OPACITY.animation({ duration: AppAnimation.Fast }).combine(
            TransitionEffect.translate({ y: -4 }),
          ),
        );
      }

      // Add button - HarmonyOS emphasis button guidelines
      Button({ type: ButtonType.Normal }) {
        Row() {
          if (this.isAdding) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color(AppColors.TextOnPrimary)
              .margin({ right: AppSpacing.Small });
          } else if (this.showSuccess) {
            Text("✓")
              .fontSize(18)
              .fontColor(AppColors.TextOnPrimary)
              .margin({ right: AppSpacing.Small });
          }
          Text(this.showSuccess ? "已添加" : this.isAdding ? "连接中..." : "添加主机")
            .fontSize(AppSizes.FontSubtitle)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TextOnPrimary)
        }.justifyContent(FlexAlign.Center)
      }
      .width("100%")
      .height(50)
      .borderRadius(AppSizes.RadiusXLarge)
      .backgroundColor(this.showSuccess ? AppColors.Success : AppColors.Primary)
      .opacity((this.isValidInput && !this.isAdding) || this.showSuccess ? 1.0 : 0.4)
      .shadow(this.isValidInput && !this.isAdding ? AppShadows.Medium : AppShadows.Small)
      .margin({ top: AppSpacing.XLarge })
      .onClick(() => {
        if (this.isValidInput && !this.isAdding) {
          this.addComputer();
        }
      })
      .animation({ duration: AppAnimation.Normal })
    }
    .width("100%")
    .padding(AppSpacing.XLarge)
    .margin({ left: AppSpacing.Large, right: AppSpacing.Large })
    .backgroundColor(AppColors.CardBackground)
    .borderRadius(AppSizes.RadiusXLarge)
    .borderWidth(1)
    .borderColor(AppColors.CardBorder)
    .shadow(AppShadows.Small);
  }

  @Builder
  HelpSection() {
    Column() {
      Row() {
        Text("💡")
          .fontSize(14)
          .margin({ right: 6 })
        Text("连接提示")
          .fontSize(AppSizes.FontCaption)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextSecondary)
      }
      .width("100%")
      .margin({ bottom: AppSpacing.Medium })
      Flex({ wrap: FlexWrap.Wrap }) {
        this.TipChip("📡", "同一网络")
        this.TipChip("☀️", "Sunshine / GFE")
        this.TipChip("🔓", "开放防火墙")
        this.TipChip("🌐", "IPv4 / IPv6")
        this.TipChip("🔌", "自定义端口")
        this.TipChip("📝", "[::1]:47989")
      }.width("100%")
    }
    .width("100%")
    .padding({ left: AppSpacing.XLarge, right: AppSpacing.XLarge, top: AppSpacing.XXLarge });
  }

  @Builder
  TipChip(icon: string, label: string) {
    Row() {
      Text(icon)
        .fontSize(13)
        .margin({ right: 6 })
      Text(label)
        .fontSize(11)
        .fontColor(AppColors.TextSecondary)
    }
    .height(32)
    .padding({ left: AppSpacing.Medium, right: AppSpacing.Medium })
    .backgroundColor(AppColors.CardBackground)
    .borderRadius(AppSizes.RadiusFull)
    .borderWidth(1)
    .borderColor(AppColors.CardBorder)
    .margin({ right: AppSpacing.Small, bottom: AppSpacing.Small });
  }

  private validateInput(): void {
    const value = this.ipAddress.trim();

    if (!value) {
      this.isValidInput = false;
      return;
    }

    const parseResult = this.parseAddressAndPort(value);
    if (!parseResult) {
      this.isValidInput = false;
      return;
    }

    const address = parseResult.address;
    const port = parseResult.port;

    if (port !== undefined && (port <= 0 || port > 65535)) {
      this.isValidInput = false;
      return;
    }

    const ipv4Regex = /^(\d{1,3}\.){3}\d{1,3}$/;
    if (ipv4Regex.test(address)) {
      const parts = address.split(".");
      this.isValidInput = parts.every((part) => {
        const num = parseInt(part);
        return num >= 0 && num <= 255;
      });
      return;
    }

    if (address.includes(":")) {
      this.isValidInput = true;
      return;
    }

    const hostnameRegex =
      /^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$/;
    this.isValidInput = hostnameRegex.test(address);
  }

  /**
   * Parse address and port
   * Supported formats:
   *   - "192.168.1.100" -> { address: "192.168.1.100" }
   *   - "192.168.1.100:47989" -> { address: "192.168.1.100", port: 47989 }
   *   - "[::1]" -> { address: "::1" }
   *   - "[::1]:47989" -> { address: "::1", port: 47989 }
   *   - "::1" -> { address: "::1" }
   */
  private parseAddressAndPort(input: string): AddressPortResult | null {
    let colonCount = 0;
    for (let i = 0; i < input.length; i++) {
      if (input.charAt(i) === ":") {
        colonCount++;
      }
    }
    const isLikelyIPv6 = colonCount >= 2;
    const result = new AddressPortResult();

    if (isLikelyIPv6) {
      if (input.startsWith("[")) {
        const closeBracket = input.indexOf("]");
        if (closeBracket > 0) {
          result.address = input.substring(1, closeBracket);
          if (closeBracket < input.length - 1 && input.charAt(closeBracket + 1) === ":") {
            const portStr = input.substring(closeBracket + 2);
            const port = parseInt(portStr);
            if (!isNaN(port)) {
              result.port = port;
              return result;
            }
            return null;
          }
          return result;
        }
        return null;
      } else {
        result.address = input;
        return result;
      }
    } else {
      const colonIndex = input.indexOf(":");
      if (colonIndex > 0) {
        result.address = input.substring(0, colonIndex);
        const portStr = input.substring(colonIndex + 1);
        const port = parseInt(portStr);
        if (!isNaN(port)) {
          result.port = port;
          return result;
        }
        return null;
      }
      result.address = input;
      return result;
    }
  }

  private async addComputer(): Promise<void> {
    if (!this.isValidInput || this.isAdding) {
      return;
    }

    this.isAdding = true;
    this.errorMessage = "";

    try {
      const result = await this.computerManager.addComputer(this.ipAddress.trim());

      if (result) {
        animateTo({ duration: AppAnimation.Normal, curve: Curve.EaseOut }, () => {
          this.showSuccess = true;
          this.isAdding = false;
        });

        promptAction.showToast({
          message: "🎉 Host added successfully",
          duration: 1500,
        });

        setTimeout(() => {
          router.back();
        }, 800);
      } else {
        this.errorMessage = "Cannot connect to host, please check the address";
        this.isAdding = false;
      }
    } catch (err) {
      this.errorMessage = (err as Error).message || "Connection failed, please retry";
      this.isAdding = false;
    }
  }
}
