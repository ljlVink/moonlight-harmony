/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { AppColors } from "../common/Theme";
import { BackgroundImageUtil } from "../utils/BackgroundImageUtil";
import { common } from "@kit.AbilityKit";
import { promptAction } from "@kit.ArkUI";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { fileIo } from "@kit.CoreFileKit";
import { BusinessError } from "@kit.BasicServicesKit";

interface BackgroundImageProps {
  imageUrl: string;
  imageOpacity?: number;
  enableLongPressSave?: boolean;
}
@Component
export struct BackgroundImage {
  @Prop imageUrl: string = "";
  @Prop imageOpacity: number = 0.15;
  @Prop enableLongPressSave: boolean = true;
  @State showSaveDialog: boolean = false;
  @State currentOpacity: number = 0;
  private lastImageUrl: string = "";

  private backgroundUtil = BackgroundImageUtil.getInstance();

  handleSaveButtonClick: SaveButtonCallback = async (
    event: ClickEvent,
    result: SaveButtonOnClickResult,
    error?: BusinessError,
  ) => {
    if (result === SaveButtonOnClickResult.SUCCESS) {
      try {
        const context = getContext(this) as common.UIAbilityContext;
        promptAction.showToast({ message: "Saving image..." });

        let imageData = this.backgroundUtil.getCachedImageData();
        if (!imageData) {
          imageData = await this.backgroundUtil.downloadImageData(this.imageUrl);
        }

        if (!imageData) {
          promptAction.showToast({ message: "Failed to get image data" });
          this.showSaveDialog = false;
          return;
        }

        const helper = photoAccessHelper.getPhotoAccessHelper(context);
        const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, "jpg");

        const file = await fileIo.open(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
        await fileIo.write(file.fd, imageData);
        await fileIo.close(file.fd);

        promptAction.showToast({ message: "Image saved to album" });
      } catch (err) {
        console.error("BackgroundImage: Failed to save image", err);
        const e = err as BusinessError;
        promptAction.showToast({ message: `Save failed: ${e.message || "Unknown error"}` });
      }
    } else if (result === SaveButtonOnClickResult.TEMPORARY_AUTHORIZATION_FAILED) {
      console.error("BackgroundImage: Authorization failed", error);
      promptAction.showToast({ message: "Save authorization failed" });
    }
    this.showSaveDialog = false;
  };

  build() {
    Stack() {
      Column()
        .width("100%")
        .height("100%")
        .backgroundColor(AppColors.Background)

      if (this.imageUrl && this.imageUrl.length > 0) {
        Image(this.imageUrl)
          .width("100%")
          .height("100%")
          .objectFit(ImageFit.Cover)
          .opacity(this.currentOpacity)
          .animation({
            duration: 600,
            curve: Curve.EaseOut,
          })
          .onAppear(() => {
            if (this.lastImageUrl !== this.imageUrl) {
              this.currentOpacity = 0;
              this.lastImageUrl = this.imageUrl;
            }
          })
          .onComplete(() => {
            this.currentOpacity = this.imageOpacity;
            if (this.enableLongPressSave) {
              this.backgroundUtil.preloadAndCacheImage();
            }
          })
          .onError(() => {
            console.warn("BackgroundImage: Failed to load background image", this.imageUrl);
          })
          .gesture(
            LongPressGesture({ repeat: false, duration: 800 }).onAction(() => {
              if (this.enableLongPressSave) {
                this.showSaveDialog = true;
              }
            }),
          );

        Column()
          .width("100%")
          .height("100%")
          .linearGradient({
            angle: 180,
            colors: [
              [AppColors.Background, 0.0],
              ["rgba(0,0,0,0)", 0.4],
              [AppColors.Background, 1.0],
            ],
          });
      }
    }
    .width("100%")
    .height("100%")
    .bindSheet($$this.showSaveDialog, this.SaveImageSheet(), {
      height: SheetSize.FIT_CONTENT,
      backgroundColor: AppColors.CardBackground,
      blurStyle: BlurStyle.COMPONENT_ULTRA_THICK,
      preferType: SheetType.BOTTOM,
      title: { title: "Save Background Image" },
    });
  }

  @Builder
  SaveImageSheet() {
    Column() {
      Text("Save current background image to album?")
        .fontSize(14)
        .fontColor(AppColors.TextSecondary)
        .margin({ bottom: 24, top: 8 })
      Row({ space: 16 }) {
        Button("Cancel")
          .backgroundColor(AppColors.CardBackgroundHover)
          .fontColor(AppColors.TextPrimary)
          .height(44)
          .width("45%")
          .onClick(() => {
            this.showSaveDialog = false;
          })
        SaveButton({
          icon: SaveIconStyle.FULL_FILLED,
          text: SaveDescription.SAVE_IMAGE,
          buttonType: ButtonType.Capsule,
        })
          .onClick(this.handleSaveButtonClick)
          .height(44)
      }
      .width("100%")
      .justifyContent(FlexAlign.Center)
      .padding({ left: 16, right: 16, bottom: 24 })
    }.width("100%");
  }
}
@Component
export struct SimpleBackgroundImage {
  @Prop imageUrl: string = "";
  @Prop imageOpacity: number = 0.2;

  build() {
    Stack() {
      Column()
        .width("100%")
        .height("100%")
        .backgroundColor(AppColors.Background)

      if (this.imageUrl && this.imageUrl.length > 0) {
        Image(this.imageUrl)
          .width("100%")
          .height("100%")
          .objectFit(ImageFit.Cover)
          .opacity(this.imageOpacity);
      }
    }
    .width("100%")
    .height("100%");
  }
}
