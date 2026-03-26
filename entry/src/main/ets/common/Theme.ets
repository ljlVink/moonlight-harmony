/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

export enum ThemeMode {
  DARK = 'dark',
  LIGHT = 'light'
}

export class DarkThemeColors {
  static readonly Primary = '#D7A574';
  static readonly PrimaryDark = '#B8865A';
  static readonly PrimaryLight = '#E8C4A0';
  static readonly PrimaryGlow = '#D7A57440'
  static readonly Accent = '#F5D59A';
  static readonly AccentDark = '#D4B67A';
  static readonly AccentLight = '#FFE8B8';
  static readonly Background = '#1A1210';
  static readonly BackgroundDark = '#0F0A08';
  static readonly BackgroundElevated = '#241C18';
  static readonly Surface = '#2A2220';
  static readonly SurfaceDark = '#201816';
  static readonly SurfaceLight = '#342A26';
  static readonly CardBackground = '#2E2422';
  static readonly CardBackgroundHover = '#3A302C';
  static readonly CardBackgroundActive = '#463C38';
  static readonly CardBorder = '#3A302C';

  static readonly TextPrimary = '#F5F0EB';
  static readonly TextSecondary = '#B8A898';
  static readonly TextTertiary = '#786858';
  static readonly TextOnPrimary = '#1A1210';
  static readonly TextGlow = '#D7A574';

  static readonly Success = '#8BC34A';
  static readonly Warning = '#FFB74D';
  static readonly Error = '#FF7043';
  static readonly Info = '#4FC3F7';

  static readonly Border = '#3A302C';
  static readonly BorderGlow = '#D7A57460';
  static readonly Divider = '#2E2422';

  static readonly Online = '#8BC34A';
  static readonly Offline = '#786858';
  static readonly Paired = '#D7A574';
  static readonly Unpaired = '#FFB74D';

  static readonly GlowPrimary = '#D7A57440';
  static readonly GlowAccent = '#F5D59A40';
}

export class LightThemeColors {
  static readonly Primary = '#2873B3';
  static readonly PrimaryDark = '#1A5A8A';
  static readonly PrimaryLight = '#4A98D0';
  static readonly PrimaryGlow = '#2873B340';

  static readonly Accent = '#A8D5E8';
  static readonly AccentDark = '#7BC0DB';
  static readonly AccentLight = '#D4EDF7';

  static readonly Background = '#F5F9FC';
  static readonly BackgroundDark = '#E8F1F7';
  static readonly BackgroundElevated = '#FFFFFF';
  static readonly Surface = '#FFFFFF';
  static readonly SurfaceDark = '#F0F5F9';
  static readonly SurfaceLight = '#FFFFFF';

  static readonly CardBackground = '#FFFFFF';
  static readonly CardBackgroundHover = '#F5F9FC';
  static readonly CardBackgroundActive = '#E8F1F7';
  static readonly CardBorder = '#D4E6F0';

  static readonly TextPrimary = '#1A3A4A';
  static readonly TextSecondary = '#506A7A';
  static readonly TextTertiary = '#6E8894';
  static readonly TextOnPrimary = '#FFFFFF';
  static readonly TextGlow = '#2873B3';

  static readonly Success = '#4CAF50';
  static readonly Warning = '#FF9800';
  static readonly Error = '#F44336';
  static readonly Info = '#2196F3';

  static readonly Border = '#D4E6F0';
  static readonly BorderGlow = '#2873B360';
  static readonly Divider = '#E8F1F7';

  static readonly Online = '#4CAF50';
  static readonly Offline = '#9E9E9E';
  static readonly Paired = '#2873B3';
  static readonly Unpaired = '#FF9800';

  static readonly GlowPrimary = '#2873B340';
  static readonly GlowAccent = '#A8D5E840';
}

export class AppColors {
  static readonly Primary = $r('app.color.primary');
  static readonly PrimaryDark = $r('app.color.primary_dark');
  static readonly PrimaryLight = $r('app.color.primary_light');
  static readonly PrimaryGlow = $r('app.color.glow_primary');

  static readonly Accent = $r('app.color.accent');
  static readonly AccentDark = $r('app.color.accent_dark');
  static readonly AccentLight = $r('app.color.accent');

  static readonly Background = $r('app.color.background');
  static readonly BackgroundDark = $r('app.color.background');
  static readonly BackgroundElevated = $r('app.color.background_elevated');
  static readonly Surface = $r('app.color.surface');
  static readonly SurfaceDark = $r('app.color.surface_dark');
  static readonly SurfaceLight = $r('app.color.surface');
  static readonly SurfaceTransparent = $r('app.color.surface_transparent');

  static readonly CardBackground = $r('app.color.card_background');
  static readonly CardBackgroundHover = $r('app.color.card_background');
  static readonly CardBackgroundActive = $r('app.color.card_background');
  static readonly CardBorder = $r('app.color.card_border');

  static readonly TextPrimary = $r('app.color.text_primary');
  static readonly TextSecondary = $r('app.color.text_secondary');
  static readonly TextTertiary = $r('app.color.text_tertiary');
  static readonly TextOnPrimary = $r('app.color.text_on_primary');
  static readonly TextGlow = $r('app.color.primary');

  static readonly Success = $r('app.color.success_green');
  static readonly Warning = $r('app.color.warning_yellow');
  static readonly Error = $r('app.color.error_red');
  static readonly Info = $r('app.color.info_blue');

  static readonly Border = $r('app.color.border');
  static readonly BorderGlow = $r('app.color.glow_primary');
  static readonly Divider = $r('app.color.divider');

  static readonly Online = $r('app.color.online_green');
  static readonly Offline = $r('app.color.offline_gray');
  static readonly Paired = $r('app.color.primary');
  static readonly Unpaired = $r('app.color.warning_yellow');

  static readonly Gaming = $r('app.color.error_red');
  static readonly Streaming = $r('app.color.success_green');

  static readonly GlowGreen = $r('app.color.glow_primary');
  static readonly GlowCyan = $r('app.color.glow_accent');
  static readonly GradientStart = $r('app.color.primary');
  static readonly GradientEnd = $r('app.color.accent');

  static readonly Overlay = $r('app.color.overlay');
  static readonly OverlayLight = '#00000060';
}

export class StatusColors {
  static readonly OnlineLight = '#4CAF50';
  static readonly OnlineDark = '#8BC34A';

  static readonly OfflineLight = '#9E9E9E';
  static readonly OfflineDark = '#786858';

  static readonly PairedLight = '#3D8ECF';
  static readonly PairedDark = '#D7A574';

  static readonly UnpairedLight = '#FF9800';
  static readonly UnpairedDark = '#FFB74D';

  static readonly GamingLight = '#F44336';
  static readonly GamingDark = '#FF7043';
}

export class AppSizes {
  static readonly IconSmall = 16;
  static readonly IconMedium = 24;
  static readonly IconLarge = 32;
  static readonly IconXLarge = 48;

  static readonly AvatarSmall = 32;
  static readonly AvatarMedium = 48;
  static readonly AvatarLarge = 64;
  static readonly AvatarXLarge = 80;

  static readonly ButtonSmall = 32;
  static readonly ButtonMedium = 44;
  static readonly ButtonLarge = 56;

  static readonly RadiusSmall = 4;
  static readonly RadiusMedium = 8;
  static readonly RadiusLarge = 12;
  static readonly RadiusXLarge = 16;
  static readonly RadiusFull = 9999;

  static readonly FontCaption = 12;
  static readonly FontBody = 14;
  static readonly FontSubtitle = 16;
  static readonly FontTitle = 18;
  static readonly FontHeadline = 20;
  static readonly FontLargeTitle = 24;
}

export class AppSpacing {
  static readonly XSmall = 4;
  static readonly Small = 8;
  static readonly Medium = 12;
  static readonly Large = 16;
  static readonly XLarge = 24;
  static readonly XXLarge = 32;
  static readonly XXXLarge = 48;
}

export class AppAnimation {
  static readonly Fast = 150;
  static readonly Normal = 250;
  static readonly Slow = 350;

  static readonly EaseIn = Curve.EaseIn;
  static readonly EaseOut = Curve.EaseOut;
  static readonly EaseInOut = Curve.EaseInOut;
  static readonly Spring = Curve.FastOutSlowIn;
}

export class AppShadows {
  static readonly Small: ShadowOptions = {
    radius: 4,
    color: '#D7A57420',
    offsetX: 0,
    offsetY: 2
  };

  static readonly Medium: ShadowOptions = {
    radius: 8,
    color: '#D7A57430',
    offsetX: 0,
    offsetY: 4
  };

  static readonly Large: ShadowOptions = {
    radius: 16,
    color: '#D7A57440',
    offsetX: 0,
    offsetY: 8
  };

  static readonly GlowGreen: ShadowOptions = {
    radius: 20,
    color: '#D7A57460',
    offsetX: 0,
    offsetY: 0
  };

  static readonly GlowCyan: ShadowOptions = {
    radius: 20,
    color: '#F5D59A60',
    offsetX: 0,
    offsetY: 0
  };
}
