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

import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { vibrator } from '@kit.SensorServiceKit';
import { display } from '@kit.ArkUI';

// =============================================================================
// =============================================================================

/**
class VK {
  static readonly ESCAPE: number = 0x1B;
  static readonly F1: number = 0x70;
  static readonly F2: number = 0x71;
  static readonly F3: number = 0x72;
  static readonly F4: number = 0x73;
  static readonly F5: number = 0x74;
  static readonly F6: number = 0x75;
  static readonly F7: number = 0x76;
  static readonly F8: number = 0x77;
  static readonly F9: number = 0x78;
  static readonly F10: number = 0x79;
  static readonly F11: number = 0x7A;
  static readonly F12: number = 0x7B;
  static readonly PRINT_SCREEN: number = 0x2C;
  static readonly SCROLL_LOCK: number = 0x91;
  static readonly PAUSE: number = 0x13;
  static readonly INSERT: number = 0x2D;
  static readonly DELETE: number = 0x2E;
  static readonly HOME: number = 0x24;
  static readonly END: number = 0x23;
  static readonly PAGE_UP: number = 0x21;
  static readonly PAGE_DOWN: number = 0x22;
  static readonly OEM_3: number = 0xC0;      // `~
  static readonly KEY_1: number = 0x31;
  static readonly KEY_2: number = 0x32;
  static readonly KEY_3: number = 0x33;
  static readonly KEY_4: number = 0x34;
  static readonly KEY_5: number = 0x35;
  static readonly KEY_6: number = 0x36;
  static readonly KEY_7: number = 0x37;
  static readonly KEY_8: number = 0x38;
  static readonly KEY_9: number = 0x39;
  static readonly KEY_0: number = 0x30;
  static readonly OEM_MINUS: number = 0xBD;   // -_
  static readonly OEM_PLUS: number = 0xBB;    // =+
  static readonly BACK: number = 0x08;         // Backspace
  static readonly TAB: number = 0x09;
  static readonly KEY_Q: number = 0x51;
  static readonly KEY_W: number = 0x57;
  static readonly KEY_E: number = 0x45;
  static readonly KEY_R: number = 0x52;
  static readonly KEY_T: number = 0x54;
  static readonly KEY_Y: number = 0x59;
  static readonly KEY_U: number = 0x55;
  static readonly KEY_I: number = 0x49;
  static readonly KEY_O: number = 0x4F;
  static readonly KEY_P: number = 0x50;
  static readonly OEM_4: number = 0xDB;       // [{
  static readonly OEM_6: number = 0xDD;       // ]}
  static readonly OEM_5: number = 0xDC;       // \|
  static readonly CAPS_LOCK: number = 0x14;
  static readonly KEY_A: number = 0x41;
  static readonly KEY_S: number = 0x53;
  static readonly KEY_D: number = 0x44;
  static readonly KEY_F: number = 0x46;
  static readonly KEY_G: number = 0x47;
  static readonly KEY_H: number = 0x48;
  static readonly KEY_J: number = 0x4A;
  static readonly KEY_K: number = 0x4B;
  static readonly KEY_L: number = 0x4C;
  static readonly OEM_1: number = 0xBA;       // ;:
  static readonly OEM_7: number = 0xDE;       // '"
  static readonly RETURN: number = 0x0D;
  static readonly LSHIFT: number = 0xA0;
  static readonly KEY_Z: number = 0x5A;
  static readonly KEY_X: number = 0x58;
  static readonly KEY_C: number = 0x43;
  static readonly KEY_V: number = 0x56;
  static readonly KEY_B: number = 0x42;
  static readonly KEY_N: number = 0x4E;
  static readonly KEY_M: number = 0x4D;
  static readonly OEM_COMMA: number = 0xBC;    // ,<
  static readonly OEM_PERIOD: number = 0xBE;   // .>
  static readonly OEM_2: number = 0xBF;        // /?
  static readonly RSHIFT: number = 0xA1;
  static readonly LCONTROL: number = 0xA2;
  static readonly LWIN: number = 0x5B;
  static readonly LMENU: number = 0xA4;        // Alt
  static readonly SPACE: number = 0x20;
  static readonly RMENU: number = 0xA5;
  static readonly RCONTROL: number = 0xA3;
  static readonly LEFT: number = 0x25;
  static readonly UP: number = 0x26;
  static readonly RIGHT: number = 0x27;
  static readonly DOWN: number = 0x28;
}

// =============================================================================
// =============================================================================

/**
enum KeyType {
  NORMAL,
  MODIFIER,
  SPACER,
}

/**
interface KeyDef {
  /**
  label: string;
  /**
  subLabel?: string;
  /**
  vk: number;
  /**
  weight?: number;
  /**
  type?: KeyType;
}

// =============================================================================
// =============================================================================

/**
const ROW_FUNC: KeyDef[] = [
  { label: 'Esc', vk: VK.ESCAPE },
  { label: 'F1', vk: VK.F1 }, { label: 'F2', vk: VK.F2 },
  { label: 'F3', vk: VK.F3 }, { label: 'F4', vk: VK.F4 },
  { label: 'F5', vk: VK.F5 }, { label: 'F6', vk: VK.F6 },
  { label: 'F7', vk: VK.F7 }, { label: 'F8', vk: VK.F8 },
  { label: 'F9', vk: VK.F9 }, { label: 'F10', vk: VK.F10 },
  { label: 'F11', vk: VK.F11 }, { label: 'F12', vk: VK.F12 },
  { label: 'Ins', vk: VK.INSERT }, { label: 'Del', vk: VK.DELETE },
];

/**
const ROW_NUM: KeyDef[] = [
  { label: '`', subLabel: '~', vk: VK.OEM_3 },
  { label: '1', vk: VK.KEY_1 }, { label: '2', vk: VK.KEY_2 },
  { label: '3', vk: VK.KEY_3 }, { label: '4', vk: VK.KEY_4 },
  { label: '5', vk: VK.KEY_5 }, { label: '6', vk: VK.KEY_6 },
  { label: '7', vk: VK.KEY_7 }, { label: '8', vk: VK.KEY_8 },
  { label: '9', vk: VK.KEY_9 }, { label: '0', vk: VK.KEY_0 },
  { label: '-', subLabel: '_', vk: VK.OEM_MINUS },
  { label: '=', subLabel: '+', vk: VK.OEM_PLUS },
  { label: '⌫', vk: VK.BACK, weight: 2 },
];

/**
const ROW_Q: KeyDef[] = [
  { label: 'Tab', vk: VK.TAB, weight: 1.5 },
  { label: 'Q', vk: VK.KEY_Q }, { label: 'W', vk: VK.KEY_W },
  { label: 'E', vk: VK.KEY_E }, { label: 'R', vk: VK.KEY_R },
  { label: 'T', vk: VK.KEY_T }, { label: 'Y', vk: VK.KEY_Y },
  { label: 'U', vk: VK.KEY_U }, { label: 'I', vk: VK.KEY_I },
  { label: 'O', vk: VK.KEY_O }, { label: 'P', vk: VK.KEY_P },
  { label: '[', subLabel: '{', vk: VK.OEM_4 },
  { label: ']', subLabel: '}', vk: VK.OEM_6 },
  { label: '\\', subLabel: '|', vk: VK.OEM_5, weight: 1.5 },
];

/**
const ROW_A: KeyDef[] = [
  { label: 'Caps', vk: VK.CAPS_LOCK, weight: 1.8 },
  { label: 'A', vk: VK.KEY_A }, { label: 'S', vk: VK.KEY_S },
  { label: 'D', vk: VK.KEY_D }, { label: 'F', vk: VK.KEY_F },
  { label: 'G', vk: VK.KEY_G }, { label: 'H', vk: VK.KEY_H },
  { label: 'J', vk: VK.KEY_J }, { label: 'K', vk: VK.KEY_K },
  { label: 'L', vk: VK.KEY_L },
  { label: ';', subLabel: ':', vk: VK.OEM_1 },
  { label: "'", subLabel: '"', vk: VK.OEM_7 },
  { label: 'Enter', vk: VK.RETURN, weight: 2.2 },
];

/**
const ROW_Z: KeyDef[] = [
  { label: 'Shift', vk: VK.LSHIFT, weight: 2.4, type: KeyType.MODIFIER },
  { label: 'Z', vk: VK.KEY_Z }, { label: 'X', vk: VK.KEY_X },
  { label: 'C', vk: VK.KEY_C }, { label: 'V', vk: VK.KEY_V },
  { label: 'B', vk: VK.KEY_B }, { label: 'N', vk: VK.KEY_N },
  { label: 'M', vk: VK.KEY_M },
  { label: ',', subLabel: '<', vk: VK.OEM_COMMA },
  { label: '.', subLabel: '>', vk: VK.OEM_PERIOD },
  { label: '/', subLabel: '?', vk: VK.OEM_2 },
  { label: 'Shift', vk: VK.RSHIFT, weight: 2.4, type: KeyType.MODIFIER },
];

/**
const ROW_BOTTOM: KeyDef[] = [
  { label: 'Ctrl', vk: VK.LCONTROL, weight: 1.5, type: KeyType.MODIFIER },
  { label: 'Win', vk: VK.LWIN, weight: 1.2, type: KeyType.MODIFIER },
  { label: 'Alt', vk: VK.LMENU, weight: 1.3, type: KeyType.MODIFIER },
  { label: '', vk: VK.SPACE, weight: 6 },
  { label: 'Alt', vk: VK.RMENU, weight: 1.3, type: KeyType.MODIFIER },
  { label: 'Ctrl', vk: VK.RCONTROL, weight: 1.5, type: KeyType.MODIFIER },
  { label: '←', vk: VK.LEFT },
  { label: '↑', vk: VK.UP },
  { label: '↓', vk: VK.DOWN },
  { label: '→', vk: VK.RIGHT },
];

/**
const KEYBOARD_ROWS: KeyDef[][] = [
  ROW_FUNC, ROW_NUM, ROW_Q, ROW_A, ROW_Z, ROW_BOTTOM,
];

// =============================================================================
// =============================================================================

/**
const KEY_GAP = 4;
/**
const ROW_GAP = 4;
/**
const KEY_RADIUS = 10;
/**
const KB_PADDING = 8;
/**
const TITLE_BAR_HEIGHT = 36;
/**
const KEY_HEIGHT = 36;
/**
const FUNC_KEY_HEIGHT = 30;

/**
const KB_BG_IMAGE_KEY = 'virtual_keyboard_bg_image';

// =============================================================================
// =============================================================================

@Component
export struct VirtualKeyboard {
  /**
  onVirtualKeyEvent: (vk: number, isDown: boolean) => void = () => {};
  /**
  onClose: () => void = () => {};

  /**
  @State private opacity_: number = 0.85;
  /**
  @State private posX: number = 0;
  @State private posY: number = 0;

  /**
  @State private backgroundImageUri: string = '';
  /**
  @State private comboMode: boolean = false;
  /**
  @State private stickyModifiers: Set<number> = new Set<number>();
  /**
  private dragStartX: number = 0;
  private dragStartY: number = 0;
  private dragStartOffsetX: number = 0;
  private dragStartOffsetY: number = 0;

  async aboutToAppear(): Promise<void> {
    try {
      const d = display.getDefaultDisplaySync();
      this.posY = px2vp(d.height) - (TITLE_BAR_HEIGHT + (KEYBOARD_ROWS.length - 1) * KEY_HEIGHT
        + FUNC_KEY_HEIGHT + (KEYBOARD_ROWS.length - 1) * ROW_GAP + KB_PADDING * 2);
    } catch (_e) {
      this.posY = 500;
    }

    const savedUri = await PreferencesUtil.get<string>(KB_BG_IMAGE_KEY, '');
    if (savedUri) {
      try {
        await fileIo.access(savedUri);
        this.backgroundImageUri = savedUri;
      } catch (_e) {
        await PreferencesUtil.put(KB_BG_IMAGE_KEY, '');
      }
    }
  }

  build() {
    Column() {
      this.TitleBar()

      Stack() {
        if (this.backgroundImageUri) {
          Image('file://' + this.backgroundImageUri)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .borderRadius({ bottomLeft: 15, bottomRight: 15 })
            .opacity(0.35)
            .position({ left: 0, top: 0 })
        }

        Column({ space: ROW_GAP }) {
          ForEach(KEYBOARD_ROWS, (row: KeyDef[], rowIndex: number) => {
            this.KeyRow(row, rowIndex === 0)
          }, (_row: KeyDef[], index: number) => `row_${index}`)
        }
        .padding(KB_PADDING)
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .alignContent(Alignment.TopStart)
    }
    .height(TITLE_BAR_HEIGHT + (KEYBOARD_ROWS.length - 1) * KEY_HEIGHT
      + FUNC_KEY_HEIGHT + (KEYBOARD_ROWS.length - 1) * ROW_GAP + KB_PADDING * 2)
    .constraintSize({ maxHeight: '60%' })
    .backgroundColor('#E01A1A2E')
    .borderRadius(16)
    .border({ width: 1, color: '#20FFFFFF' })
    .shadow({ radius: 20, color: '#60000000', offsetY: 4 })
    .opacity(this.opacity_)
    .position({ x: this.posX, y: this.posY })
    .onAreaChange((_old: Area, area: Area) => {
      const actualH = area.height as number;
      const globalY = (area.globalPosition?.y ?? -1) as number;
      if (globalY >= 0 && actualH > 0) {
        const screenH = px2vp(display.getDefaultDisplaySync().height);
        const overflow = (globalY + actualH) - screenH;
        if (overflow > 10) {
          this.posY = Math.max(0, this.posY - overflow);
        }
      }
    })
    .clip(true)
  }

  @Builder
  TitleBar() {
    Stack({ alignContent: Alignment.Top }) {
      Row() {
        Text('PC 键盘')
          .fontSize(12)
          .fontColor('#B0FFFFFF')
          .fontWeight(FontWeight.Medium)
          .margin({ left: 8 })

        Row({ space: 4 }) {
          Text('⌘')
            .fontSize(13)
            .fontColor(this.comboMode ? '#FFFFFF' : '#80FFFFFF')
            .fontWeight(FontWeight.Bold)
          Text('组合键')
            .fontSize(10)
            .fontColor(this.comboMode ? '#FFFFFF' : '#80FFFFFF')
            .fontWeight(FontWeight.Medium)
        }
        .height(24)
        .padding({ left: 8, right: 8 })
        .alignItems(VerticalAlign.Center)
        .borderRadius(12)
        .backgroundColor(this.comboMode ? '#50A8D8EA' : '#20FFFFFF')
        .border({ width: 1, color: this.comboMode ? '#80A8D8EA' : '#00000000' })
        .margin({ left: 8 })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.85 })
        .shadow({
          radius: this.comboMode ? 6 : 0,
          color: this.comboMode ? '#40A8D8EA' : '#00000000',
          offsetY: 0,
        })
        .onClick(() => {
          this.comboMode = !this.comboMode;
          if (!this.comboMode && this.stickyModifiers.size > 0) {
            this.stickyModifiers.forEach((modVk: number) => {
              this.onVirtualKeyEvent(modVk, false);
            });
            this.stickyModifiers = new Set<number>();
          }
        })

        Blank()

        Text('👁')
          .fontSize(11)
          .fontColor('#80FFFFFF')

        Slider({
          value: this.opacity_ * 100,
          min: 20,
          max: 100,
          step: 5,
          style: SliderStyle.OutSet,
        })
          .width(80)
          .blockColor('#A8D8EA')
          .blockSize({ width: 12, height: 12 })
          .trackColor('#30FFFFFF')
          .selectedColor('#A8D8EA')
          .trackThickness(3)
          .showSteps(false)
          .showTips(false)
          .sliderInteractionMode(SliderInteraction.SLIDE_ONLY)
          .onChange((value: number) => {
            this.opacity_ = value / 100;
          })

        Text('❏')
          .fontSize(15)
          .fontColor(this.backgroundImageUri ? '#A8D8EA' : '#80FFFFFF')
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .borderRadius(14)
          .backgroundColor(this.backgroundImageUri ? '#30A8D8EA' : '#20FFFFFF')
          .margin({ left: 4 })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.85 })
          .onClick(() => {
            if (this.backgroundImageUri) {
              this.clearBackgroundImage();
            } else {
              this.pickBackgroundImage();
            }
          })

        Text('✕')
          .fontSize(14)
          .fontColor('#99FFFFFF')
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .borderRadius(14)
          .backgroundColor('#30FFFFFF')
          .margin({ left: 4, right: 4 })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.85 })
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)

      Row()
        .width(36)
        .height(4)
        .backgroundColor('#40FFFFFF')
        .borderRadius(2)
        .margin({ top: 3 })
    }
    .width('100%')
    .height(TITLE_BAR_HEIGHT)
    .gesture(
      PanGesture({ direction: PanDirection.All })
        .onActionStart((event: GestureEvent) => {
          this.dragStartX = event.offsetX;
          this.dragStartY = event.offsetY;
          this.dragStartOffsetX = this.posX;
          this.dragStartOffsetY = this.posY;
        })
        .onActionUpdate((event: GestureEvent) => {
          this.posX = this.dragStartOffsetX + event.offsetX - this.dragStartX;
          this.posY = this.dragStartOffsetY + event.offsetY - this.dragStartY;
        })
    )
  }

  @Builder
  KeyRow(keys: KeyDef[], isFuncRow: boolean) {
    Row({ space: KEY_GAP }) {
      ForEach(keys, (key: KeyDef) => {
        this.KeyButton(key, isFuncRow)
      }, (key: KeyDef) => `${key.vk}_${key.label}`)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .layoutWeight(isFuncRow ? 0.8 : 1)
  }

  @Builder
  KeyButton(key: KeyDef, isFuncRow: boolean) {
    Text(key.label)
      .fontSize(isFuncRow ? 10 : (key.weight && key.weight > 1.5 ? 11 : 13))
      .fontColor(this.getKeyTextColor(key))
      .fontWeight(FontWeight.Bold)
      .fontFamily('HarmonyOS Sans')
      .textAlign(TextAlign.Center)
      .height('100%')
      .layoutWeight(key.weight ?? 1)
      .backgroundColor(this.getKeyBgColor(key))
      .borderRadius(KEY_RADIUS)
      .border({
        width: { top: 1, left: 1, right: 1, bottom: 1 },
        color: {
          top: this.isKeyActive(key) ? '#70A8D8EA' : '#28FFFFFF',
          left: this.isKeyActive(key) ? '#50A8D8EA' : '#18FFFFFF',
          right: this.isKeyActive(key) ? '#50A8D8EA' : '#10FFFFFF',
          bottom: this.isKeyActive(key) ? '#40A8D8EA' : '#08FFFFFF',
        },
      })
      .shadow({
        radius: this.isKeyActive(key) ? 6 : 2,
        color: this.isKeyActive(key) ? '#40A8D8EA' : '#18000000',
        offsetY: 1,
      })
      .onTouch((event: TouchEvent) => {
        this.handleKeyTouch(key, event);
      })
  }

  private getKeyBgColor(key: KeyDef): string {
    if (this.isKeyActive(key)) {
      return '#60A8D8EA';
    }
    if (key.type === KeyType.MODIFIER) {
      return '#2A3A4A5A';
    }
    if (key.vk === VK.SPACE) {
      return '#1A3A4A5A';
    }
    return '#22FFFFFF';
  }

  private getKeyTextColor(key: KeyDef): string {
    if (this.isKeyActive(key)) {
      return '#FFFFFF';
    }
    if (key.type === KeyType.MODIFIER) {
      return '#C0D0E0FF';
    }
    return '#E8F0FFFF';
  }

  /**
  private isKeyActive(key: KeyDef): boolean {
    return this.comboMode && this.stickyModifiers.has(key.vk);
  }

  private handleKeyTouch(key: KeyDef, event: TouchEvent): void {
    const touchType = event.type;

    if (this.comboMode && key.type === KeyType.MODIFIER) {
      if (touchType === TouchType.Down) {
        const newSet = new Set<number>(this.stickyModifiers);
        if (newSet.has(key.vk)) {
          newSet.delete(key.vk);
          this.onVirtualKeyEvent(key.vk, false);
        } else {
          newSet.add(key.vk);
          this.onVirtualKeyEvent(key.vk, true);
        }
        this.stickyModifiers = newSet;
      }
      return;
    }

    if (touchType === TouchType.Down) {
      this.onVirtualKeyEvent(key.vk, true);
      try {
        vibrator.startVibration({ type: 'time', duration: 20 }, { id: 0, usage: 'touch' });
      } catch (_e) {}
    } else if (touchType === TouchType.Up || touchType === TouchType.Cancel) {
      this.onVirtualKeyEvent(key.vk, false);

      if (this.comboMode && this.stickyModifiers.size > 0) {
        this.stickyModifiers.forEach((modVk: number) => {
          this.onVirtualKeyEvent(modVk, false);
        });
        this.stickyModifiers = new Set<number>();
      }
    }
  }

  private async pickBackgroundImage(): Promise<void> {
    try {
      const photoPicker = new picker.PhotoViewPicker();
      const options = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await photoPicker.select(options);
      if (result.photoUris && result.photoUris.length > 0) {
        const srcUri = result.photoUris[0];
        const context = getContext(this);
        const destPath = context.filesDir + '/keyboard_bg.jpg';
        const srcFile = fileIo.openSync(srcUri, fileIo.OpenMode.READ_ONLY);
        const destFile = fileIo.openSync(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
        fileIo.copyFileSync(srcFile.fd, destFile.fd);
        fileIo.closeSync(srcFile);
        fileIo.closeSync(destFile);
        this.backgroundImageUri = destPath;
        await PreferencesUtil.put(KB_BG_IMAGE_KEY, destPath);
      }
    } catch (e) {
      console.error('VirtualKeyboard: pickBackgroundImage failed', e);
    }
  }

  private async clearBackgroundImage(): Promise<void> {
    try {
      if (this.backgroundImageUri) {
        try {
          fileIo.unlinkSync(this.backgroundImageUri);
        } catch (_e) {
          // ignore
        }
      }
      this.backgroundImageUri = '';
      await PreferencesUtil.put(KB_BG_IMAGE_KEY, '');
    } catch (e) {
      console.error('VirtualKeyboard: clearBackgroundImage failed', e);
    }
  }
}
