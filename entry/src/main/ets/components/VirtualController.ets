/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { InputEvent, InputType, ControllerButton, ControllerButtonEvent, ControllerAxis, ControllerAxisEvent } from '../model/InputEvent';
import { AnalogStick, AnalogStickConfig } from './AnalogStick';
import { vibrator } from '@kit.SensorServiceKit';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { display } from '@kit.ArkUI';

const SCALE_KEY = 'virtual_controller_scale';
const OPACITY_KEY = 'virtual_controller_opacity';

export interface VirtualControllerConfig {
  /**
  opacity?: number;
  /**
  scale?: number;
  /**
  showLeftStick?: boolean;
  /**
  showRightStick?: boolean;
  /**
  showDpad?: boolean;
  /**
  showButtons?: boolean;
  /**
  showShoulder?: boolean;
  /**
  showCenter?: boolean;
  /**
  showGuideButton?: boolean;
  /**
  showL3R3?: boolean;
  /**
  enableVibration?: boolean;
  /**
  deadzone?: number;
}

@Component
export struct VirtualController {
  config: VirtualControllerConfig = {};

  onInput: (input: InputEvent) => void = () => {};

  /**
  touchPassthrough: boolean = false;

  /**
  @Prop controllerScale: number = 1.0;

  private controllerOpacity: number = 0.75;
  private controllerDeadzone: number = 0.15;

  aboutToAppear(): void {
    if (this.config.opacity !== undefined) {
      this.controllerOpacity = this.config.opacity;
    }
    if (this.config.deadzone !== undefined) {
      this.controllerDeadzone = this.config.deadzone;
    }
  }

  private withAlpha(color: string, alpha: number): string {
    const hex = Math.round(alpha * 255).toString(16).padStart(2, '0');
    return '#' + hex + color.substring(1);
  }

  build() {
    Column() {
      if (this.config.showShoulder !== false) {
        Row() {
          Column({ space: 6 }) {
            // LT
            Column() {
              Text('LT')
                .fontSize(12 * this.controllerScale)
                .fontColor(this.withAlpha('#FFFFFF', 0.5))
                .fontWeight(FontWeight.Bold)
            }
            .width(60 * this.controllerScale)
            .height(44 * this.controllerScale)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(Color.Transparent)
            .borderRadius(12)
            .border({ width: 1, color: this.withAlpha('#FFFFFF', 0.15) })
            .hitTestBehavior(HitTestMode.Block)
            .onTouch((event: TouchEvent) => this.handleTriggerTouch(true, event))

            // LB
            Column() {
              Text('LB')
                .fontSize(12 * this.controllerScale)
                .fontColor(this.withAlpha('#FFFFFF', 0.5))
                .fontWeight(FontWeight.Medium)
            }
            .width(64 * this.controllerScale)
            .height(34 * this.controllerScale)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(Color.Transparent)
            .borderRadius(17 * this.controllerScale)
            .border({ width: 1, color: this.withAlpha('#FFFFFF', 0.15) })
            .hitTestBehavior(HitTestMode.Block)
            .onTouch((event: TouchEvent) => this.handleButtonTouch(ControllerButton.LB, event))
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Column({ space: 6 }) {
            // RT
            Column() {
              Text('RT')
                .fontSize(12 * this.controllerScale)
                .fontColor(this.withAlpha('#FFFFFF', 0.5))
                .fontWeight(FontWeight.Bold)
            }
            .width(60 * this.controllerScale)
            .height(44 * this.controllerScale)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(Color.Transparent)
            .borderRadius(12)
            .border({ width: 1, color: this.withAlpha('#FFFFFF', 0.15) })
            .hitTestBehavior(HitTestMode.Block)
            .onTouch((event: TouchEvent) => this.handleTriggerTouch(false, event))

            // RB
            Column() {
              Text('RB')
                .fontSize(12 * this.controllerScale)
                .fontColor(this.withAlpha('#FFFFFF', 0.5))
                .fontWeight(FontWeight.Medium)
            }
            .width(64 * this.controllerScale)
            .height(34 * this.controllerScale)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(Color.Transparent)
            .borderRadius(17 * this.controllerScale)
            .border({ width: 1, color: this.withAlpha('#FFFFFF', 0.15) })
            .hitTestBehavior(HitTestMode.Block)
            .onTouch((event: TouchEvent) => this.handleButtonTouch(ControllerButton.RB, event))
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })
      }

      Row() {
        Column() {
          if (this.config.showLeftStick !== false) {
            Column() {
              AnalogStick({
                config: {
                  isLeftStick: true,
                  outerRadius: 55 * this.controllerScale,
                  innerRadius: 24 * this.controllerScale,
                  deadzone: this.controllerDeadzone,
                  opacity: this.controllerOpacity,
                  enableClick: true
                } as AnalogStickConfig,
                onInput: (event: InputEvent) => this.onInput(event)
              })
            }
            .margin({ bottom: 16 })
          }

          if (this.config.showDpad !== false) {
            this.buildCrossDpad()
          }
        }
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 24 })

        Blank()

        Column() {
          if (this.config.showButtons !== false) {
            Column() {
              // Y
              this.buildActionButton('Y', ControllerButton.Y, '#FFB900')

              Row({ space: 8 }) {
                // X
                this.buildActionButton('X', ControllerButton.X, '#4BA3E3')
                // B
                this.buildActionButton('B', ControllerButton.B, '#E87070')
              }
              .margin({ top: 8 })

              // A
              Column() {
                this.buildActionButton('A', ControllerButton.A, '#50C878')
              }
              .margin({ top: 8 })
            }
            .margin({ bottom: 16 })
          }

          if (this.config.showRightStick !== false) {
            AnalogStick({
              config: {
                isLeftStick: false,
                outerRadius: 55 * this.controllerScale,
                innerRadius: 24 * this.controllerScale,
                deadzone: this.controllerDeadzone,
                opacity: this.controllerOpacity,
                enableClick: true
              } as AnalogStickConfig,
              onInput: (event: InputEvent) => this.onInput(event)
            })
          }
        }
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .padding({ right: 24 })
      }
      .width('100%')

      if (this.config.showCenter !== false) {
        Row({ space: 12 }) {
          // Back
          this.buildCenterButton('◂', 'BACK', ControllerButton.BACK)

          if (this.config.showGuideButton !== false) {
            Column() {
              Text('◉')
                .fontSize(18 * this.controllerScale)
                .fontColor(this.withAlpha('#7EB8E0', 0.6))
            }
            .width(42 * this.controllerScale)
            .height(42 * this.controllerScale)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(Color.Transparent)
            .borderRadius(21 * this.controllerScale)
            .border({ width: 1.5, color: this.withAlpha('#7EB8E0', 0.25) })
            .hitTestBehavior(HitTestMode.Block)
            .onTouch((event: TouchEvent) => this.handleButtonTouch(ControllerButton.SPECIAL, event))
          }

          // Start
          this.buildCenterButton('▸', 'START', ControllerButton.START)
        }
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 20 })
      }

      if (this.config.showL3R3 === true) {
        Row() {
          this.buildSmallButton('L3', ControllerButton.LS)
          Blank()
          this.buildSmallButton('R3', ControllerButton.RS)
        }
        .width('100%')
        .padding({ left: 100, right: 100 })
        .margin({ bottom: 16 })
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
  }

  @Builder
  buildActionButton(label: string, button: ControllerButton, color: string) {
    Column() {
      Text(label)
        .fontSize(17 * this.controllerScale)
        .fontColor(this.withAlpha(color, 0.7))
        .fontWeight(FontWeight.Bold)
    }
    .width(48 * this.controllerScale)
    .height(48 * this.controllerScale)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.Transparent)
    .borderRadius(24 * this.controllerScale)
    .border({ width: 1.5, color: this.withAlpha(color, 0.35) })
    .hitTestBehavior(HitTestMode.Block)
    .onTouch((event: TouchEvent) => this.handleButtonTouch(button, event))
  }

  private dpadDirection: number = 0;

  @Builder
  buildCrossDpad() {
    Stack() {
      Column() {
        Row() {
          Column().width(36 * this.controllerScale).height(36 * this.controllerScale)
            .borderRadius({ topLeft: 14, topRight: 0, bottomLeft: 0, bottomRight: 0 })
          Column() {
            Text('▴')
              .fontSize(14 * this.controllerScale)
              .fontColor(this.withAlpha('#FFFFFF', 0.5))
              .fontWeight(FontWeight.Bold)
          }
          .width(36 * this.controllerScale)
          .height(36 * this.controllerScale)
          .justifyContent(FlexAlign.Center)
          .borderRadius({ topLeft: 14, topRight: 14, bottomLeft: 0, bottomRight: 0 })
          .border({
            width: { top: 1, left: 1, right: 1, bottom: 0 },
            color: this.withAlpha('#FFFFFF', 0.18)
          })
          Column().width(36 * this.controllerScale).height(36 * this.controllerScale)
            .borderRadius({ topLeft: 0, topRight: 14, bottomLeft: 0, bottomRight: 0 })
        }

        Row() {
          Column() {
            Text('◂')
              .fontSize(14 * this.controllerScale)
              .fontColor(this.withAlpha('#FFFFFF', 0.5))
              .fontWeight(FontWeight.Bold)
          }
          .width(36 * this.controllerScale)
          .height(36 * this.controllerScale)
          .justifyContent(FlexAlign.Center)
          .borderRadius({ topLeft: 14, topRight: 0, bottomLeft: 14, bottomRight: 0 })
          .border({
            width: { top: 1, left: 1, right: 0, bottom: 1 },
            color: this.withAlpha('#FFFFFF', 0.18)
          })

          Column() {
            Circle()
              .width(8 * this.controllerScale)
              .height(8 * this.controllerScale)
              .fill('#FFFFFF')
              .fillOpacity(0.12)
          }
          .width(36 * this.controllerScale)
          .height(36 * this.controllerScale)
          .justifyContent(FlexAlign.Center)

          Column() {
            Text('▸')
              .fontSize(14 * this.controllerScale)
              .fontColor(this.withAlpha('#FFFFFF', 0.5))
              .fontWeight(FontWeight.Bold)
          }
          .width(36 * this.controllerScale)
          .height(36 * this.controllerScale)
          .justifyContent(FlexAlign.Center)
          .borderRadius({ topLeft: 0, topRight: 14, bottomLeft: 0, bottomRight: 14 })
          .border({
            width: { top: 1, left: 0, right: 1, bottom: 1 },
            color: this.withAlpha('#FFFFFF', 0.18)
          })
        }

        Row() {
          Column().width(36 * this.controllerScale).height(36 * this.controllerScale)
            .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 14, bottomRight: 0 })
          Column() {
            Text('▾')
              .fontSize(14 * this.controllerScale)
              .fontColor(this.withAlpha('#FFFFFF', 0.5))
              .fontWeight(FontWeight.Bold)
          }
          .width(36 * this.controllerScale)
          .height(36 * this.controllerScale)
          .justifyContent(FlexAlign.Center)
          .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 14, bottomRight: 14 })
          .border({
            width: { top: 0, left: 1, right: 1, bottom: 1 },
            color: this.withAlpha('#FFFFFF', 0.18)
          })
          Column().width(36 * this.controllerScale).height(36 * this.controllerScale)
            .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 14 })
        }
      }
      .hitTestBehavior(HitTestMode.None)

      Column()
        .width(108 * this.controllerScale)
        .height(108 * this.controllerScale)
        .backgroundColor(Color.Transparent)
        .hitTestBehavior(HitTestMode.Block)
        .onTouch((event: TouchEvent) => this.handleDpadTouch(event))
    }
    .width(108 * this.controllerScale)
    .height(108 * this.controllerScale)
  }

  @Builder
  buildCenterButton(icon: string, label: string, button: ControllerButton) {
    Column() {
      Row({ space: 4 }) {
        Text(icon)
          .fontSize(13 * this.controllerScale)
          .fontColor(this.withAlpha('#FFFFFF', 0.4))
        Text(label)
          .fontSize(8 * this.controllerScale)
          .fontColor(this.withAlpha('#FFFFFF', 0.4))
          .fontWeight(FontWeight.Medium)
      }
    }
    .height(34 * this.controllerScale)
    .padding({ left: 10, right: 10 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.Transparent)
    .borderRadius(17 * this.controllerScale)
    .border({ width: 1, color: this.withAlpha('#FFFFFF', 0.12) })
    .hitTestBehavior(HitTestMode.Block)
    .onTouch((event: TouchEvent) => this.handleButtonTouch(button, event))
  }

  @Builder
  buildSmallButton(label: string, button: ControllerButton) {
    Column() {
      Text(label)
        .fontSize(11 * this.controllerScale)
        .fontColor(this.withAlpha('#FFFFFF', 0.4))
        .fontWeight(FontWeight.Medium)
    }
    .width(44 * this.controllerScale)
    .height(30 * this.controllerScale)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.Transparent)
    .borderRadius(15 * this.controllerScale)
    .border({ width: 1, color: this.withAlpha('#FFFFFF', 0.12) })
    .hitTestBehavior(HitTestMode.Block)
    .onTouch((event: TouchEvent) => this.handleButtonTouch(button, event))
  }

  private handleDpadTouch(event: TouchEvent): void {
    event.stopPropagation();

    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      const allDirs: number[] = [
        ControllerButton.UP as number,
        ControllerButton.DOWN as number,
        ControllerButton.LEFT as number,
        ControllerButton.RIGHT as number
      ];
      for (const dir of allDirs) {
        if (this.dpadDirection & dir) {
          this.onInput({
            type: InputType.CONTROLLER_BUTTON,
            timestamp: Date.now(),
            controllerIndex: 0,
            button: dir as ControllerButton,
            isPressed: false
          } as ControllerButtonEvent);
        }
      }
      this.dpadDirection = 0;
      return;
    }

    const touch = event.touches[0];
    if (!touch) return;

    if (event.type === TouchType.Down || event.type === TouchType.Move) {
      const totalSize = 108 * this.controllerScale;
      const oneThird = totalSize / 3;
      const twoThirds = oneThird * 2;

      let newDirection = 0;
      if (touch.x < oneThird)  newDirection |= ControllerButton.LEFT as number;
      if (touch.x > twoThirds) newDirection |= ControllerButton.RIGHT as number;
      if (touch.y < oneThird)  newDirection |= ControllerButton.UP as number;
      if (touch.y > twoThirds) newDirection |= ControllerButton.DOWN as number;

      if (newDirection !== this.dpadDirection) {
        const released = this.dpadDirection & ~newDirection;
        const pressed = newDirection & ~this.dpadDirection;

        const allDirs: number[] = [
          ControllerButton.UP as number,
          ControllerButton.DOWN as number,
          ControllerButton.LEFT as number,
          ControllerButton.RIGHT as number
        ];

        for (const dir of allDirs) {
          if (released & dir) {
            this.onInput({
              type: InputType.CONTROLLER_BUTTON,
              timestamp: Date.now(),
              controllerIndex: 0,
              button: dir as ControllerButton,
              isPressed: false
            } as ControllerButtonEvent);
          }
        }
        for (const dir of allDirs) {
          if (pressed & dir) {
            this.onInput({
              type: InputType.CONTROLLER_BUTTON,
              timestamp: Date.now(),
              controllerIndex: 0,
              button: dir as ControllerButton,
              isPressed: true
            } as ControllerButtonEvent);
          }
        }

        if (pressed && this.config.enableVibration !== false) {
          this.triggerVibration();
        }

        this.dpadDirection = newDirection;
      }
    }
  }

  private handleButtonTouch(button: ControllerButton, event: TouchEvent): void {
    event.stopPropagation();
    const isPressed = event.type === TouchType.Down;
    const isReleased = event.type === TouchType.Up || event.type === TouchType.Cancel;
    
    if (!isPressed && !isReleased) {
      return;
    }
    
    const inputEvent: ControllerButtonEvent = {
      type: InputType.CONTROLLER_BUTTON,
      timestamp: Date.now(),
      controllerIndex: 0,
      button: button,
      isPressed: isPressed
    };
    this.onInput(inputEvent);
    
    if (isPressed && this.config.enableVibration !== false) {
      this.triggerVibration();
    }
  }
  
  private handleTriggerTouch(isLeft: boolean, event: TouchEvent): void {
    event.stopPropagation();
    const isPressed = event.type === TouchType.Down;
    const isReleased = event.type === TouchType.Up || event.type === TouchType.Cancel;
    
    if (!isPressed && !isReleased) {
      return;
    }
    
    const axis = isLeft ? ControllerAxis.LEFT_TRIGGER : ControllerAxis.RIGHT_TRIGGER;
    const value = isPressed ? 255 : 0;
    
    const axisEvent: ControllerAxisEvent = {
      type: InputType.CONTROLLER_AXIS,
      timestamp: Date.now(),
      controllerIndex: 0,
      axis: axis,
      value: value
    };
    this.onInput(axisEvent);
    
    if (isPressed && this.config.enableVibration !== false) {
      this.triggerVibration();
    }
  }
  
  private triggerVibration(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 30
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {
    }
  }

}

// =============================================================================
// =============================================================================

@Component
export struct VirtualControllerOverlay {
  /**
  onInput: (input: InputEvent) => void = () => {};

  /**
  @Link touchPassthrough: boolean;

  /**
  @Link controllerScale: number;

  /**
  @Link controllerOpacity: number;

  /**
  onlyL3R3: boolean = false;
  /**
  showGuideButton: boolean = true;
  /**
  vibrateOsc: boolean = true;
  /**
  halfHeightPortrait: boolean = true;

  @State private hitTestReady: number = 0;
  @State private isPortrait: boolean = false;

  aboutToAppear(): void {
    try {
      const d = display.getDefaultDisplaySync();
      this.isPortrait = d.height > d.width;
    } catch (_) {}
    setTimeout(() => {
      this.hitTestReady = 1;
    }, 100);
  }

  build() {
    Stack() {
      Column() {
        VirtualController({
          touchPassthrough: this.touchPassthrough,
          controllerScale: this.controllerScale,
          config: {
            opacity: 1.0,
            deadzone: 0.15,
            showLeftStick: !this.onlyL3R3,
            showRightStick: !this.onlyL3R3,
            showDpad: !this.onlyL3R3,
            showButtons: !this.onlyL3R3,
            showShoulder: !this.onlyL3R3,
            showCenter: !this.onlyL3R3,
            showGuideButton: this.showGuideButton,
            showL3R3: this.onlyL3R3,
            enableVibration: this.vibrateOsc
          } as VirtualControllerConfig,
          onInput: (input: InputEvent) => {
            this.onInput(input);
          }
        })
      }
      .width('100%')
      .height(this.halfHeightPortrait && this.isPortrait ? '50%' : '100%')
      .justifyContent(FlexAlign.End)
      .opacity(this.controllerOpacity)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(this.touchPassthrough ? HitTestMode.Transparent : HitTestMode.Default)
    .opacity(this.hitTestReady > 0 ? 1 : 0.99)
  }

  static async loadScale(): Promise<number> {
    return await PreferencesUtil.get<number>(SCALE_KEY, 1.0);
  }

  static saveScale(value: number): void {
    PreferencesUtil.put(SCALE_KEY, value);
  }

  static async loadOpacity(): Promise<number> {
    return await PreferencesUtil.get<number>(OPACITY_KEY, 0.75);
  }

  static saveOpacity(value: number): void {
    PreferencesUtil.put(OPACITY_KEY, value);
  }
}
