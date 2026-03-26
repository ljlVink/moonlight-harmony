/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */


import { scanBarcode, scanCore } from '@kit.ScanKit';
import { image } from '@kit.ImageKit';
import { generateQrPixelMap } from './QrCodeGenerator';
import {
  AnalogStickAction,
  ComboAction,
  CustomKeyDef,
  DigitalStickAction,
  DPadAction,
  GamepadButtonAction,
  GamepadStickAction,
  GamepadTriggerAction,
  generateKeyId,
  KeyAction,
  KeyBehavior,
  KeyboardAction,
  KeyShape,
  MouseButtonAction,
  MouseScrollAction,
  ShortcutAction,
  SpecialAction,
  SpecialActionId,
  WheelPadAction,
  WheelPadSegment,
} from './CustomKeyTypes';
export interface QrCodeResult {
  pixelMap: image.PixelMap | null;
  error?: string;
}


interface CompactKeyV2 {
  l: string;       // label
  a: string;       // action (v2 encoded string)
  s: string;       // shape: 'r' | 'c'
  b: string;       // behavior: 'm' | 't'
  x: number;       // xPercent
  y: number;       // yPercent
  w: number;       // width
  h: number;       // height
  o?: number;      // opacity (default=80)
  r?: number;      // borderRadius (default=12)
  bg?: string;     // bgColor
  tc?: string;     // textColor
  pc?: string;     // pressedColor
  fs?: number;     // fontSize (default=14)
  ly?: number;     // layer (default=0)
  bw?: number;     // borderWidth (default=1)
  hp?: string;     // haptic (default='light')
}


interface CompactExportV2 {
  v: number;       // version (2)
  n: string;       // profile name
  k: CompactKeyV2[]; // keys
}


const QR_MAX_CHARS = 4000;


//   K{vk}                           keyboard
//   M{button}                       mouse
//   S{direction}                    mouseScroll
//   B{mask}                         gamepadButton
//   T,{l|r}                         gamepadTrigger
//   J,{l|r},{u|d|l|r}               gamepadStick
//   A,{l|r}[,{sens}][,i]            analogStick
//   D                               dpad
//   P,{id}                          special
//   W|{label}:{act}|{label}:{act}   wheelPad
//   X|{up}|{dn}|{lt}|{rt}[|{ck}]   digitalStick
//   C|{act}|{act}|...               combo
//   H,{k1},{k2}[/{sk1},{sk2}/...]   shortcut


function encodeAction(a: KeyAction): string {
  switch (a.type) {
    case 'keyboard':
      return `K${(a as KeyboardAction).vk}`;
    case 'mouse':
      return `M${(a as MouseButtonAction).button}`;
    case 'mouseScroll':
      return `S${(a as MouseScrollAction).direction}`;
    case 'gamepadButton':
      return `B${(a as GamepadButtonAction).mask}`;
    case 'gamepadTrigger':
      return `T,${(a as GamepadTriggerAction).trigger === 'left' ? 'l' : 'r'}`;
    case 'gamepadStick': {
      const gs = a as GamepadStickAction;
      const stk = gs.stick === 'left' ? 'l' : 'r';
      const dir = gs.direction.charAt(0); // u/d/l/r
      return `J,${stk},${dir}`;
    }
    case 'analogStick': {
      const as2 = a as AnalogStickAction;
      let s = `A,${as2.stick === 'left' ? 'l' : 'r'}`;
      if (as2.sensitivity !== undefined && as2.sensitivity !== 1.0) {
        s += `,${as2.sensitivity}`;
      }
      if (as2.invisible === true) {
        s += `,i`;
      }
      return s;
    }
    case 'dpad':
      return 'D';
    case 'special':
      return `P,${(a as SpecialAction).id}`;
    case 'wheelPad': {
      const wp = a as WheelPadAction;
      const segs = wp.segments.map((seg: WheelPadSegment) =>
        `${seg.label}:${encodeAction(seg.action)}`
      );
      return `W|${segs.join('|')}`;
    }
    case 'digitalStick': {
      const ds = a as DigitalStickAction;
      let s = `X|${encodeAction(ds.upAction)}|${encodeAction(ds.downAction)}|${encodeAction(ds.leftAction)}|${encodeAction(ds.rightAction)}`;
      if (ds.clickAction) {
        s += `|${encodeAction(ds.clickAction)}`;
      }
      return s;
    }
    case 'combo': {
      const cb = a as ComboAction;
      const acts = cb.actions.map((ca: KeyAction) => encodeAction(ca));
      return `C|${acts.join('|')}`;
    }
    case 'shortcut': {
      const sh = a as ShortcutAction;
      let s = `H,${sh.keys.join(',')}`;
      if (sh.keySequence && sh.keySequence.length > 0) {
        const seqs = sh.keySequence.map((seq: number[]) => seq.join(','));
        s += `/${seqs.join('/')}`;
      }
      return s;
    }
    default:
      return 'D'; // fallback
  }
}


function decodeSimpleAction(s: string): KeyAction {
  if (s.startsWith('K')) {
    const vk = parseInt(s.substring(1));
    if (!isNaN(vk)) {
      return { type: 'keyboard', vk: vk } as KeyboardAction;
    }
  }
  if (s.startsWith('M')) {
    const btn = parseInt(s.substring(1));
    if (!isNaN(btn)) {
      return { type: 'mouse', button: btn } as MouseButtonAction;
    }
  }
  if (s.startsWith('S')) {
    const dir = parseInt(s.substring(1));
    if (!isNaN(dir)) {
      return { type: 'mouseScroll', direction: dir } as MouseScrollAction;
    }
  }
  if (s.startsWith('B')) {
    const mask = parseInt(s.substring(1));
    if (!isNaN(mask)) {
      return { type: 'gamepadButton', mask: mask } as GamepadButtonAction;
    }
  }
  if (s.startsWith('T,')) {
    return { type: 'gamepadTrigger', trigger: s.charAt(2) === 'l' ? 'left' : 'right' } as GamepadTriggerAction;
  }
  if (s.startsWith('J,')) {
    const parts = s.split(',');
    const stick = parts[1] === 'l' ? 'left' : 'right';
    const dirMap: Record<string, string> = { 'u': 'up', 'd': 'down', 'l': 'left', 'r': 'right' };
    const dir = dirMap[parts[2]] ?? 'up';
    return { type: 'gamepadStick', stick: stick, direction: dir } as GamepadStickAction;
  }
  if (s.startsWith('A,')) {
    const parts = s.split(',');
    const stick = parts[1] === 'l' ? 'left' : 'right';
    const result: AnalogStickAction = { type: 'analogStick', stick: stick };
    for (let i = 2; i < parts.length; i++) {
      if (parts[i] === 'i') {
        result.invisible = true;
      } else {
        const num = parseFloat(parts[i]);
        if (!isNaN(num)) {
          result.sensitivity = num;
        }
      }
    }
    return result;
  }
  if (s === 'D') {
    return { type: 'dpad' } as DPadAction;
  }
  if (s.startsWith('P,')) {
    return { type: 'special', id: s.substring(2) as SpecialActionId } as SpecialAction;
  }
  if (s.startsWith('H,')) {
    const hBody = s.substring(2);
    const slashIdx = hBody.indexOf('/');
    if (slashIdx >= 0) {
      const keysStr = hBody.substring(0, slashIdx);
      const seqStr = hBody.substring(slashIdx + 1);
      const keys = keysStr.split(',').map((n: string) => parseInt(n)).filter((n: number) => !isNaN(n));
      const keySequence = seqStr.split('/').map((seg: string) =>
        seg.split(',').map((n: string) => parseInt(n)).filter((n: number) => !isNaN(n))
      );
      if (keys.length > 0) {
        return { type: 'shortcut', keys: keys, keySequence: keySequence } as ShortcutAction;
      }
    } else {
      const keys = hBody.split(',').map((n: string) => parseInt(n)).filter((n: number) => !isNaN(n));
      if (keys.length > 0) {
        return { type: 'shortcut', keys: keys } as ShortcutAction;
      }
    }
  }
  return { type: 'special', id: 'none' } as SpecialAction;
}


function decodeAction(s: string): KeyAction {
  if (s.startsWith('W|')) {
    const body = s.substring(2);
    const segParts = body.split('|');
    const segments: WheelPadSegment[] = [];
    for (const sp of segParts) {
      const colonIdx = sp.lastIndexOf(':');
      if (colonIdx >= 0) {
        const label = sp.substring(0, colonIdx);
        const actStr = sp.substring(colonIdx + 1);
        segments.push({ label: label, action: decodeSimpleAction(actStr) });
      }
    }
    return { type: 'wheelPad', segments: segments } as WheelPadAction;
  }
  if (s.startsWith('X|')) {
    const body = s.substring(2);
    const parts = body.split('|');
    const result: DigitalStickAction = {
      type: 'digitalStick',
      upAction: decodeSimpleAction(parts[0] ?? 'K87'),
      downAction: decodeSimpleAction(parts[1] ?? 'K83'),
      leftAction: decodeSimpleAction(parts[2] ?? 'K65'),
      rightAction: decodeSimpleAction(parts[3] ?? 'K68'),
    };
    if (parts.length > 4 && parts[4]) {
      result.clickAction = decodeSimpleAction(parts[4]);
    }
    return result;
  }
  if (s.startsWith('C|')) {
    const body = s.substring(2);
    const parts = body.split('|');
    const actions: KeyAction[] = parts.map((p: string) => decodeSimpleAction(p));
    return { type: 'combo', actions: actions } as ComboAction;
  }
  return decodeSimpleAction(s);
}


function toCompact(key: CustomKeyDef): CompactKeyV2 {
  const ck: CompactKeyV2 = {
    l: key.label,
    a: encodeAction(key.action),
    s: key.shape === 'circle' ? 'c' : 'r',
    b: key.behavior === 'toggle' ? 't' : 'm',
    x: Math.round(key.xPercent * 10000) / 10000,
    y: Math.round(key.yPercent * 10000) / 10000,
    w: key.width,
    h: key.height,
  };
  if (key.opacity !== 80) ck.o = key.opacity;
  if (key.borderRadius !== 12) ck.r = key.borderRadius;
  if (key.bgColor !== '#30FFFFFF') ck.bg = key.bgColor;
  if (key.textColor !== '#E0FFFFFF') ck.tc = key.textColor;
  if (key.pressedColor !== '#80A8D8EA') ck.pc = key.pressedColor;
  if (key.fontSize !== 14) ck.fs = key.fontSize;
  if (key.layer !== 0) ck.ly = key.layer;
  if ((key.borderWidth ?? 1) !== 1) ck.bw = key.borderWidth;
  if (key.haptic !== 'light') ck.hp = key.haptic;
  return ck;
}


function fromCompactV2(ck: CompactKeyV2): CustomKeyDef {
  return {
    id: generateKeyId(),
    label: ck.l,
    action: decodeAction(ck.a),
    shape: (ck.s === 'c' ? 'circle' : 'rect') as KeyShape,
    behavior: (ck.b === 't' ? 'toggle' : 'momentary') as KeyBehavior,
    xPercent: ck.x,
    yPercent: ck.y,
    width: ck.w,
    height: ck.h,
    layer: ck.ly ?? 0,
    opacity: ck.o ?? 80,
    borderRadius: ck.r ?? 12,
    normalColor: '#60FFFFFF',
    pressedColor: ck.pc ?? '#80A8D8EA',
    bgColor: ck.bg ?? '#30FFFFFF',
    textColor: ck.tc ?? '#E0FFFFFF',
    fontSize: ck.fs ?? 14,
    borderWidth: ck.bw ?? 1,
    haptic: ck.hp ?? 'light',
  };
}


function fromCompactV1(raw: Record<string, Object>): CustomKeyDef {
  return {
    id: generateKeyId(),
    label: raw['l'] as string ?? '',
    action: raw['a'] as KeyAction,
    shape: ((raw['s'] as string) === 'c' ? 'circle' : 'rect') as KeyShape,
    behavior: ((raw['b'] as string) === 't' ? 'toggle' : 'momentary') as KeyBehavior,
    xPercent: raw['x'] as number ?? 0.5,
    yPercent: raw['y'] as number ?? 0.5,
    width: raw['w'] as number ?? 60,
    height: raw['h'] as number ?? 60,
    layer: (raw['ly'] as number) ?? 0,
    opacity: (raw['o'] as number) ?? 80,
    borderRadius: (raw['r'] as number) ?? 12,
    normalColor: '#60FFFFFF',
    pressedColor: (raw['pc'] as string) ?? '#80A8D8EA',
    bgColor: (raw['bg'] as string) ?? '#30FFFFFF',
    textColor: (raw['tc'] as string) ?? '#E0FFFFFF',
    fontSize: (raw['fs'] as number) ?? 14,
    borderWidth: (raw['bw'] as number) ?? 1,
    haptic: (raw['hp'] as string) ?? 'light',
  };
}


export class QrShareService {

  static serialize(profileName: string, keys: CustomKeyDef[]): string {
    const data: CompactExportV2 = {
      v: 2,
      n: profileName,
      k: keys.map((k: CustomKeyDef) => toCompact(k)),
    };
    return JSON.stringify(data);
  }

  static deserialize(json: string): [string, CustomKeyDef[]] | null {
    try {
      const raw = JSON.parse(json) as Record<string, Object>;
      const version = raw['v'] as number ?? 1;
      const keyArr = raw['k'] as Object[];
      if (!keyArr || !Array.isArray(keyArr) || keyArr.length === 0) {
        return null;
      }
      const profileName = (raw['n'] as string) ?? '导入配置';

      if (version >= 2) {
        const keys: CustomKeyDef[] = keyArr.map((item: Object) =>
          fromCompactV2(item as CompactKeyV2)
        );
        return [profileName, keys];
      }
      const keys: CustomKeyDef[] = keyArr.map((item: Object) =>
        fromCompactV1(item as Record<string, Object>)
      );
      return [profileName, keys];
    } catch (_e) {
      return null;
    }
  }


  static canFitInQr(json: string): boolean {
    return json.length <= QR_MAX_CHARS;
  }

  static async generateQrCode(content: string, size: number = 600): Promise<QrCodeResult> {
    try {
      const pixelMap = await generateQrPixelMap(content, size);
      return { pixelMap };
    } catch (e) {
      const errMsg = (e as Record<string, Object>)?.message as string
        ?? (e as Record<string, Object>)?.code as string
        ?? JSON.stringify(e);
      console.error('[QrShareService] 生成二维码失败:', errMsg);
      return { pixelMap: null, error: errMsg };
    }
  }

  static async scanQrCode(): Promise<string | null> {
    try {
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: true,
      };
      const result = await scanBarcode.startScanForResult(getContext(), options);
      if (result && result.originalValue) {
        return result.originalValue;
      }
      return null;
    } catch (e) {
      console.error('[QrShareService] 扫码失败:', JSON.stringify(e));
      return null;
    }
  }
}
