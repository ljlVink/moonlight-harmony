/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */


export interface ColorTheme {

  name: string;
  preview: string;
  bgColor: string;
  textColor: string;
  pressedColor: string;
  normalColor: string;
}


export const COLOR_THEMES: ColorTheme[] = [
  { name: '冰蓝', preview: '#A8D8EA', bgColor: '#301A3050', textColor: '#E0A8D8EA', pressedColor: '#80A8D8EA', normalColor: '#60A8D8EA' },
  { name: '暗夜', preview: '#808080', bgColor: '#301A1A2E', textColor: '#C0FFFFFF', pressedColor: '#60808090', normalColor: '#40FFFFFF' },
  { name: '翠绿', preview: '#50C080', bgColor: '#30204030', textColor: '#E050C080', pressedColor: '#8050C080', normalColor: '#6050C080' },
  { name: '烈焰', preview: '#FF6B6B', bgColor: '#30401A1A', textColor: '#E0FF6B6B', pressedColor: '#80FF6B6B', normalColor: '#60FF6B6B' },
  { name: '金辉', preview: '#FFD700', bgColor: '#30403010', textColor: '#E0FFD700', pressedColor: '#80FFD700', normalColor: '#60FFD700' },
  { name: '紫韵', preview: '#B070E0', bgColor: '#302A1A40', textColor: '#E0B070E0', pressedColor: '#80B070E0', normalColor: '#60B070E0' },
  { name: '暖橙', preview: '#FF8C00', bgColor: '#30402A10', textColor: '#E0FF8C00', pressedColor: '#80FF8C00', normalColor: '#60FF8C00' },
  { name: '樱粉', preview: '#FFB7C5', bgColor: '#30401A28', textColor: '#E0FFB7C5', pressedColor: '#80FFB7C5', normalColor: '#60FFB7C5' },
  { name: '青碧', preview: '#00CED1', bgColor: '#30103030', textColor: '#E000CED1', pressedColor: '#8000CED1', normalColor: '#6000CED1' },
  { name: '赤金', preview: '#CD7F32', bgColor: '#30302010', textColor: '#E0CD7F32', pressedColor: '#80CD7F32', normalColor: '#60CD7F32' },
  { name: '纯白', preview: '#FFFFFF', bgColor: '#25FFFFFF', textColor: '#E0FFFFFF', pressedColor: '#60FFFFFF', normalColor: '#40FFFFFF' },
  { name: '隐形', preview: '#404040', bgColor: '#10FFFFFF', textColor: '#40FFFFFF', pressedColor: '#30FFFFFF', normalColor: '#20FFFFFF' },
];


export function parseHexRGB(hex: string): [number, number, number] {
  const clean = hex.replace('#', '');
  let r: number, g: number, b: number;
  if (clean.length === 8) {
    r = parseInt(clean.substring(2, 4), 16);
    g = parseInt(clean.substring(4, 6), 16);
    b = parseInt(clean.substring(6, 8), 16);
  } else {
    r = parseInt(clean.substring(0, 2), 16);
    g = parseInt(clean.substring(2, 4), 16);
    b = parseInt(clean.substring(4, 6), 16);
  }
  return [r || 0, g || 0, b || 0];
}

export function toHexARGB(a: number, r: number, g: number, b: number): string {
  const clamp = (v: number): number => Math.max(0, Math.min(255, Math.round(v)));
  const toHex = (v: number): string => clamp(v).toString(16).padStart(2, '0').toUpperCase();
  return `#${toHex(a)}${toHex(r)}${toHex(g)}${toHex(b)}`;
}

export function generateThemeFromAccent(r: number, g: number, b: number): ColorTheme {
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

  let textR = r, textG = g, textB = b;
  if (luminance < 0.4) {
    const boost = 1.4;
    textR = Math.min(255, r * boost + 40);
    textG = Math.min(255, g * boost + 40);
    textB = Math.min(255, b * boost + 40);
  }

  return {
    name: '智能',
    preview: toHexARGB(255, r, g, b),
    bgColor: toHexARGB(0x30, r, g, b),
    textColor: toHexARGB(0xE0, textR, textG, textB),
    pressedColor: toHexARGB(0x80, r, g, b),
    normalColor: toHexARGB(0x60, r, g, b),
  };
}


export interface RGBPixel {
  r: number;
  g: number;
  b: number;
}


export interface KMeansCluster {
  center: RGBPixel;
  count: number;
}


export function kMeansPlusPlus(samples: RGBPixel[], k: number, maxIter: number = 20): KMeansCluster[] {
  if (samples.length === 0) return [];
  const n = samples.length;
  const actualK = Math.min(k, n);

  const centers: RGBPixel[] = [];
  centers.push(samples[Math.floor(Math.random() * n)]);

  const distSq = new Float64Array(n);
  for (let c = 1; c < actualK; c++) {
    let totalDist = 0;
    for (let i = 0; i < n; i++) {
      let minD = Number.MAX_VALUE;
      for (let j = 0; j < c; j++) {
        const dr = samples[i].r - centers[j].r;
        const dg = samples[i].g - centers[j].g;
        const db = samples[i].b - centers[j].b;
        const d = dr * dr + dg * dg + db * db;
        if (d < minD) minD = d;
      }
      distSq[i] = minD;
      totalDist += minD;
    }
    let r = Math.random() * totalDist;
    for (let i = 0; i < n; i++) {
      r -= distSq[i];
      if (r <= 0) {
        centers.push(samples[i]);
        break;
      }
    }
    if (centers.length === c) {
      let maxIdx = 0;
      for (let i = 1; i < n; i++) {
        if (distSq[i] > distSq[maxIdx]) maxIdx = i;
      }
      centers.push(samples[maxIdx]);
    }
  }

  const assignments = new Int32Array(n);
  for (let iter = 0; iter < maxIter; iter++) {
    for (let i = 0; i < n; i++) {
      let minD = Number.MAX_VALUE;
      let bestC = 0;
      for (let c = 0; c < actualK; c++) {
        const dr = samples[i].r - centers[c].r;
        const dg = samples[i].g - centers[c].g;
        const db = samples[i].b - centers[c].b;
        const d = dr * dr + dg * dg + db * db;
        if (d < minD) { minD = d; bestC = c; }
      }
      assignments[i] = bestC;
    }

    let changed = false;
    for (let c = 0; c < actualK; c++) {
      let sumR = 0, sumG = 0, sumB = 0, cnt = 0;
      for (let i = 0; i < n; i++) {
        if (assignments[i] === c) {
          sumR += samples[i].r; sumG += samples[i].g; sumB += samples[i].b;
          cnt++;
        }
      }
      if (cnt > 0) {
        const newR = Math.round(sumR / cnt);
        const newG = Math.round(sumG / cnt);
        const newB = Math.round(sumB / cnt);
        if (newR !== centers[c].r || newG !== centers[c].g || newB !== centers[c].b) {
          centers[c] = { r: newR, g: newG, b: newB };
          changed = true;
        }
      }
    }
    if (!changed) break;
  }

  const counts = new Array<number>(actualK).fill(0);
  for (let i = 0; i < n; i++) {
    counts[assignments[i]]++;
  }

  const result: KMeansCluster[] = [];
  for (let c = 0; c < actualK; c++) {
    result.push({ center: centers[c], count: counts[c] });
  }
  result.sort((a, b) => b.count - a.count);
  return result;
}


export function pickAccentFromClusters(clusters: KMeansCluster[], totalSamples: number): RGBPixel {
  const viable = clusters.filter(c => {
    const ratio = c.count / totalSamples;
    const brightness = c.center.r + c.center.g + c.center.b;
    return ratio >= 0.05 && brightness > 30;
  });

  if (viable.length === 0) {
    return clusters[0]?.center ?? { r: 128, g: 128, b: 128 };
  }

  let best = viable[0];
  let bestSaturation = 0;
  for (const c of viable) {
    const max = Math.max(c.center.r, c.center.g, c.center.b);
    const min = Math.min(c.center.r, c.center.g, c.center.b);
    const saturation = max > 0 ? (max - min) / max : 0;
    const score = saturation * Math.pow(c.count / totalSamples, 0.3);
    if (score > bestSaturation) {
      bestSaturation = score;
      best = c;
    }
  }
  return best.center;
}
