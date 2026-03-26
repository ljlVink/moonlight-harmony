/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { common } from "@kit.AbilityKit";
import { fileIo } from "@kit.CoreFileKit";
import { util } from "@kit.ArkTS";
import { http } from "@kit.NetworkKit";
import { deviceInfo } from "@kit.BasicServicesKit";
import { HttpClient } from "../utils/HttpClient";
import { XmlUtil } from "../utils/XmlUtil";
import { StringUtil } from "../utils/StringUtil";
import { CryptoUtil } from "../utils/CryptoUtil";
import { DEFAULT_HTTP_PORT, DEFAULT_HTTPS_PORT } from "../common/NetworkConstants";

/**
 *
 */
export interface ServerInfo {
  hostname: string;
  uniqueId: string;
  macAddress: string;
  paired: boolean;
  currentGame: number;
  serverCodecModeSupport: number;
  gpuType: string;
  gfeVersion: string;
  appVersion: string;
  maxLumaPixelsHEVC: number;
  serverCapabilities: string;
  httpsPort: number;
  externalPort: number;
  localAddress: string;
  externalAddress: string;
}

export interface DisplayInfo {
  index: number;
  name: string;
  guid: string;
}

interface DisplaysResponse {
  status_code: number;
  status_message?: string;
  displays?: DisplayItem[];
}

interface DisplayItem {
  friendly_name?: string;
  display_name?: string;
  device_id?: string;
}

interface RotateDisplayResponse {
  status_code?: number;
  status_message?: string;
  success?: boolean;
}

export class NvHttp {
  private address: string;
  private serverCert: string | null;
  private uniqueId: string;
  private clientName: string;
  private context: common.UIAbilityContext | null = null;
  private certFilePath: string = "";
  private keyFilePath: string = "";

  static readonly DEFAULT_HTTPS_PORT = DEFAULT_HTTPS_PORT;
  static readonly DEFAULT_HTTP_PORT = DEFAULT_HTTP_PORT;
  static readonly CONNECTION_TIMEOUT = 3000;
  static readonly LONG_CONNECTION_TIMEOUT = 5000;
  static readonly READ_TIMEOUT = 5000;

  private httpsPort: number = 0;
  private httpPort: number = NvHttp.DEFAULT_HTTP_PORT;

  private static cachedUniqueId: string | null = null;
  private static cachedClientName: string | null = null;

  constructor(
    address: string,
    serverCert: string | null,
    context?: common.UIAbilityContext,
    httpPort?: number,
  ) {
    const parsedHost = this.parseAddressHost(address);
    const parsedPort = this.parseAddressPort(address);
    this.address = parsedHost;
    this.serverCert = serverCert;
    this.httpPort = httpPort || parsedPort || NvHttp.DEFAULT_HTTP_PORT;
    if (context) {
      this.context = context;
      this.certFilePath = context.filesDir + "/client_cert.pem";
      this.keyFilePath = context.filesDir + "/client_key.pem";
    }
    this.uniqueId = this.getOrCreateUniqueId(context);
    this.clientName = this.getClientName();
  }

  private parseAddressHost(addressInput: string): string {
    const trimmed = addressInput.trim();

    if (trimmed.startsWith("[")) {
      const closeBracket = trimmed.indexOf("]");
      if (closeBracket > 0) {
        return trimmed.substring(1, closeBracket);
      }
    }

    const colonIndex = trimmed.indexOf(":");
    if (colonIndex > 0 && trimmed.indexOf(":", colonIndex + 1) === -1) {
      return trimmed.substring(0, colonIndex);
    }

    return trimmed;
  }

  private parseAddressPort(addressInput: string): number | undefined {
    const trimmed = addressInput.trim();

    if (trimmed.startsWith("[")) {
      const closeBracket = trimmed.indexOf("]");
      if (
        closeBracket > 0 &&
        closeBracket < trimmed.length - 1 &&
        trimmed.charAt(closeBracket + 1) === ":"
      ) {
        const portStr = trimmed.substring(closeBracket + 2);
        const port = parseInt(portStr);
        if (port > 0 && port <= 65535) {
          return port;
        }
      }
      return undefined;
    }

    const colonIndex = trimmed.indexOf(":");
    if (colonIndex > 0 && trimmed.indexOf(":", colonIndex + 1) === -1) {
      const portStr = trimmed.substring(colonIndex + 1);
      const port = parseInt(portStr);
      if (port > 0 && port <= 65535) {
        return port;
      }
    }

    return undefined;
  }

  private hasCertificateFiles(): boolean {
    if (!this.certFilePath || !this.keyFilePath) {
      return false;
    }
    try {
      return fileIo.accessSync(this.certFilePath) && fileIo.accessSync(this.keyFilePath);
    } catch (err) {
      return false;
    }
  }

  private getOrCreateUniqueId(context?: common.UIAbilityContext): string {
    if (NvHttp.cachedUniqueId) {
      return NvHttp.cachedUniqueId;
    }

    if (context) {
      const uniqueIdPath = context.filesDir + "/unique_id.txt";
      try {
        if (fileIo.accessSync(uniqueIdPath)) {
          const file = fileIo.openSync(uniqueIdPath, fileIo.OpenMode.READ_ONLY);
          const stat = fileIo.statSync(uniqueIdPath);
          const buffer = new ArrayBuffer(stat.size);
          fileIo.readSync(file.fd, buffer);
          fileIo.closeSync(file);
          const textDecoder = util.TextDecoder.create("utf-8");
          const savedId = textDecoder.decodeToString(new Uint8Array(buffer)).trim();
          if (savedId.length === 16) {
            NvHttp.cachedUniqueId = savedId;
            console.info(`NvHttp: 从文件加载 uniqueId: ${savedId}`);
            return savedId;
          }
        }
      } catch (err) {
        console.warn(`NvHttp: 无法读取 uniqueId 文件: ${err}`);
      }
    }

    const randomBytes = CryptoUtil.generateRandomBytes(8);
    const result = CryptoUtil.bytesToHex(randomBytes).toLowerCase();
    NvHttp.cachedUniqueId = result;
    console.info(`NvHttp: 生成新 uniqueId: ${result}`);

    if (context) {
      const uniqueIdPath = context.filesDir + "/unique_id.txt";
      try {
        const file = fileIo.openSync(
          uniqueIdPath,
          fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC,
        );
        const textEncoder = new util.TextEncoder();
        const encoded = textEncoder.encodeInto(result);
        fileIo.writeSync(file.fd, encoded.buffer);
        fileIo.closeSync(file);
        console.info(`NvHttp: uniqueId 已保存到文件`);
      } catch (err) {
        console.error(`NvHttp: 无法保存 uniqueId: ${err}`);
      }
    }

    return result;
  }

  private getClientName(): string {
    if (NvHttp.cachedClientName) {
      return NvHttp.cachedClientName;
    }

    try {
      const name = deviceInfo.marketName || deviceInfo.productModel || "Moonlight-HarmonyOS";
      NvHttp.cachedClientName = name;
      console.info(`NvHttp: 客户端名称: ${name}`);
      return name;
    } catch (err) {
      console.warn(`NvHttp: 无法获取设备名称: ${err}`);
      NvHttp.cachedClientName = "Moonlight-HarmonyOS";
      return "Moonlight-HarmonyOS";
    }
  }

  private getFormattedAddress(): string {
    if (this.address.includes(":") && !this.address.startsWith("[")) {
      return `[${this.address}]`;
    }
    return this.address;
  }

  private getHttpBaseUrl(): string {
    return `http://${this.getFormattedAddress()}:${this.httpPort}`;
  }

  private async getHttpsBaseUrl(): Promise<string> {
    if (this.httpsPort <= 0) {
      try {
        const url = this.buildUrl(this.getHttpBaseUrl(), "serverinfo");
        const response = await this.doRequest(url);
        const port = XmlUtil.getIntValue(response, "HttpsPort", 0);
        if (port > 0) {
          this.httpsPort = port;
          console.info(`NvHttp: 自动解析 HTTPS 端口: ${port}`);
        }
      } catch (err) {
        console.warn(`NvHttp: 自动解析 HTTPS 端口失败: ${err}`);
      }
    }

    let port: number;
    if (this.httpsPort > 0) {
      port = this.httpsPort;
    } else if (this.httpPort !== NvHttp.DEFAULT_HTTP_PORT) {
      port = this.httpPort - 5;
      console.info(`NvHttp: 使用计算的 HTTPS 端口 ${port} (httpPort=${this.httpPort})`);
    } else {
      port = NvHttp.DEFAULT_HTTPS_PORT;
    }
    return `https://${this.getFormattedAddress()}:${port}`;
  }

  private buildUrl(baseUrl: string, path: string, query?: string): string {
    let url = `${baseUrl}/${path}?uniqueid=${this.uniqueId}&clientname=${encodeURIComponent(this.clientName)}&uuid=${this.generateUUID()}`;
    if (query) {
      url += `&${query}`;
    }
    return url;
  }

  private generateUUID(): string {
    return StringUtil.generateUUID();
  }

  private async doRequest(
    url: string,
    timeout: number = NvHttp.READ_TIMEOUT,
    useClientCert: boolean = false,
  ): Promise<string> {
    console.debug(`NvHttp: 请求 ${url}`);

    if (useClientCert && this.certFilePath && this.keyFilePath) {
      return HttpClient.getWithClientCert(url, this.certFilePath, this.keyFilePath, {
        connectTimeout: NvHttp.CONNECTION_TIMEOUT,
        transferTimeout: timeout,
      });
    } else {
      return HttpClient.get(url, {
        connectTimeout: NvHttp.CONNECTION_TIMEOUT,
        transferTimeout: timeout,
      });
    }
  }

  async getServerInfo(likelyOnline: boolean = true): Promise<ServerInfo> {
    let response: string;

    try {
      if (this.serverCert && this.hasCertificateFiles()) {
        try {
          console.debug(`NvHttp: getServerInfo 尝试 HTTPS + 客户端证书`);
          const url = this.buildUrl(await this.getHttpsBaseUrl(), "serverinfo");
          response = await this.doRequest(url, NvHttp.READ_TIMEOUT, true);
        } catch (err) {
          const errMsg = String(err).toLowerCase();
          const isCertError =
            errMsg.includes("401") ||
            errMsg.includes("certificate") ||
            errMsg.includes("handshake") ||
            errMsg.includes("ssl") ||
            errMsg.includes("tls");
          if (isCertError) {
            console.warn(`NvHttp: HTTPS serverinfo 证书错误: ${err}, 降级到 HTTP`);
            const url = this.buildUrl(this.getHttpBaseUrl(), "serverinfo");
            response = await this.doRequest(url);
          } else {
            console.warn(`NvHttp: HTTPS serverinfo 失败 (非证书错误，不降级): ${err}`);
            throw new Error(`HTTPS serverinfo 失败: ${err}`);
          }
        }
      } else {
        console.debug(
          `NvHttp: getServerInfo 使用 HTTP (serverCert=${!!this.serverCert}, hasCertFiles=${this.hasCertificateFiles()})`,
        );
        const url = this.buildUrl(this.getHttpBaseUrl(), "serverinfo");
        response = await this.doRequest(url);
      }
    } catch (err) {
      throw new Error(`获取服务器信息失败: ${err}`);
    }

    const serverInfo = this.parseServerInfo(response);
    console.debug(
      `NvHttp: serverInfo - hostname=${serverInfo.hostname}, paired=${serverInfo.paired}, mac=${serverInfo.macAddress}`,
    );

    if (serverInfo.httpsPort > 0) {
      this.httpsPort = serverInfo.httpsPort;
    }

    return serverInfo;
  }

  async getAppList(): Promise<AppEntry[]> {
    const url = this.buildUrl(await this.getHttpsBaseUrl(), "applist");
    console.info(
      `NvHttp.getAppList: url=${url}, serverCert=${this.serverCert ? "有(长度" + this.serverCert.length + ")" : "无"}, hasCertFiles=${this.hasCertificateFiles()}`,
    );

    const response = await this.doRequest(url, NvHttp.READ_TIMEOUT, true);
    console.info(`NvHttp.getAppList: HTTPS 请求成功`);
    return this.parseAppList(response);
  }

  async unpair(): Promise<void> {
    const url = this.buildUrl(this.getHttpBaseUrl(), "unpair");
    await this.doRequest(url);
  }

  async launchApp(appId: number, config: LaunchConfig): Promise<string> {
    const effectiveAppId = config.appId || appId;
    const query = this.buildLaunchQuery(effectiveAppId, config, "launch");
    const url = this.buildUrl(await this.getHttpsBaseUrl(), "launch", query);

    const response = await this.doRequest(url, 60000, true);
    console.info(`NvHttp: launchApp 响应: ${response}`);

    const gamesession = XmlUtil.getValue(response, "gamesession");
    if (gamesession === "0") {
      throw new Error("启动应用失败");
    }

    const sessionUrl = XmlUtil.getValue(response, "sessionUrl0") || "";
    console.info(`NvHttp: launchApp gamesession=${gamesession}, sessionUrl0=${sessionUrl}`);
    return sessionUrl;
  }

  async resumeApp(config: LaunchConfig): Promise<string> {
    const query = this.buildLaunchQuery(config.appId, config, "resume");
    const url = this.buildUrl(await this.getHttpsBaseUrl(), "resume", query);

    console.info(`NvHttp: resumeApp URL: ${url}`);

    const response = await this.doRequest(url, 60000, true);

    const resume = XmlUtil.getValue(response, "resume");
    if (resume === "0") {
      throw new Error("恢复会话失败");
    }

    return XmlUtil.getValue(response, "sessionUrl0") || "";
  }

  async quitApp(): Promise<boolean> {
    const url = this.buildUrl(await this.getHttpsBaseUrl(), "cancel");
    const response = await this.doRequest(url, 60000, true);

    const cancel = XmlUtil.getValue(response, "cancel");
    return cancel !== "0";
  }

  async setBitrate(bitrateKbps: number): Promise<boolean> {
    try {
      const url = this.buildUrl(await this.getHttpsBaseUrl(), "bitrate", `bitrate=${bitrateKbps}`);
      const response = await this.doRequest(url, NvHttp.READ_TIMEOUT, true);
      const result = XmlUtil.getValue(response, "bitrate");
      return result !== "0";
    } catch (err) {
      return false;
    }
  }

  async sendSuperCmd(cmdId: string): Promise<boolean> {
    try {
      const url = this.buildUrl(await this.getHttpsBaseUrl(), "supercmd", `cmdId=${cmdId}`);
      const response = await this.doRequest(url, NvHttp.READ_TIMEOUT, true);
      const result = XmlUtil.getValue(response, "supercmd");
      return result !== "0";
    } catch (err) {
      return false;
    }
  }

  async pcSleep(): Promise<boolean> {
    try {
      const url = this.buildUrl(await this.getHttpsBaseUrl(), "pcsleep");
      const response = await this.doRequest(url, NvHttp.READ_TIMEOUT, true);
      const result = XmlUtil.getValue(response, "pcsleep");
      return result !== "0";
    } catch (err) {
      console.warn("NvHttp: 休眠主机失败", err);
      return false;
    }
  }

  /**
   *
   *
   */
  async rotateDisplay(angle: number, displayName?: string): Promise<boolean> {
    try {
      let query = `angle=${angle}`;
      if (displayName) {
        query += `&display_name=${encodeURIComponent(displayName)}`;
      }

      const url = this.buildUrl(await this.getHttpsBaseUrl(), "rotate-display", query);
      const response = await this.doRequest(url, NvHttp.READ_TIMEOUT, true);

      const json = JSON.parse(response) as RotateDisplayResponse;

      const statusCode = json.status_code ?? 0;
      const success = json.success ?? false;

      if (statusCode !== 200 || !success) {
        const errorMsg = json.status_message ?? "未知错误";
        console.warn(`NvHttp: 旋转显示失败: ${errorMsg}`);
        return false;
      }

      console.info(`NvHttp: 显示旋转成功，角度=${angle}`);
      return true;
    } catch (err) {
      console.warn(`NvHttp: 旋转显示请求失败: ${err}`);
      return false;
    }
  }

  async getDisplays(): Promise<DisplayInfo[]> {
    const url = this.buildUrl(await this.getHttpsBaseUrl(), "displays");
    const response = await this.doRequest(url, NvHttp.LONG_CONNECTION_TIMEOUT, true);

    const json = JSON.parse(response) as DisplaysResponse;

    if (json.status_code !== 200) {
      throw new Error(`获取显示器列表失败: ${json.status_message || "未知错误"}`);
    }

    const displays: DisplayInfo[] = [];
    if (json.displays && Array.isArray(json.displays)) {
      for (let i = 0; i < json.displays.length; i++) {
        const displayObj = json.displays[i];
        const friendlyName =
          displayObj.friendly_name || displayObj.display_name || `显示器 ${i + 1}`;
        const guid = displayObj.device_id || "";
        displays.push({ index: i, name: friendlyName, guid: guid });
      }
    }

    console.info(`NvHttp: 获取到 ${displays.length} 个显示器`);
    return displays;
  }

  async getAppAsset(appId: number): Promise<ArrayBuffer | null> {
    const url = this.buildUrl(
      await this.getHttpsBaseUrl(),
      "appasset",
      `appid=${appId}&AssetType=2&AssetIdx=0`,
    );

    try {
      console.info(`NvHttp: 获取应用图标 appId=${appId}, url=${url}`);
      let data: ArrayBuffer;

      if (this.hasCertificateFiles()) {
        data = await HttpClient.getBinaryWithClientCert(url, this.certFilePath, this.keyFilePath, {
          connectTimeout: NvHttp.CONNECTION_TIMEOUT,
          transferTimeout: NvHttp.READ_TIMEOUT,
        });
      } else {
        data = await HttpClient.getBinary(url, {
          skipServerValidation: true,
          connectTimeout: NvHttp.CONNECTION_TIMEOUT,
          transferTimeout: NvHttp.READ_TIMEOUT,
        });
      }

      console.info(`NvHttp: 获取应用图标成功 appId=${appId}, 大小=${data.byteLength} 字节`);
      return data;
    } catch (err) {
      console.warn(`NvHttp: 获取应用图标失败 appId=${appId}`, err);
    }
    return null;
  }

  async getAppAssetCached(appId: number): Promise<string | null> {
    if (!this.context) {
      console.warn("NvHttp: 无法缓存图标，context 未设置");
      return null;
    }

    const cacheDir = this.context.cacheDir + "/app_icons";
    const safeAddress = this.address.replace(/[:\[\]\/\\]/g, "_");
    const cachedPath = `${cacheDir}/${safeAddress}_${appId}.png`;

    try {
      if (fileIo.accessSync(cachedPath)) {
        console.info(`NvHttp: 使用缓存的图标 ${cachedPath}`);
        return cachedPath;
      }
    } catch (err) {}

    const data = await this.getAppAsset(appId);
    if (!data || data.byteLength < 100) {
      console.warn(`NvHttp: 图标数据无效 appId=${appId}, size=${data?.byteLength}`);
      return null;
    }

    try {
      if (!fileIo.accessSync(cacheDir)) {
        fileIo.mkdirSync(cacheDir);
      }
    } catch (err) {
      try {
        fileIo.mkdirSync(cacheDir);
      } catch (mkdirErr) {
        console.warn(`NvHttp: 创建缓存目录失败`, mkdirErr);
      }
    }

    try {
      const file = fileIo.openSync(
        cachedPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC,
      );
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);
      console.info(`NvHttp: 图标已缓存到 ${cachedPath}`);
      return cachedPath;
    } catch (err) {
      console.error(`NvHttp: 缓存图标失败`, err);
      return null;
    }
  }

  getBoxArtUrl(appId: number): string {
    return this.buildUrl(
      this.getHttpBaseUrl(),
      "appasset",
      `appid=${appId}&AssetType=2&AssetIdx=0`,
    );
  }

  private buildLaunchQuery(appId: number, config: LaunchConfig, verb: string): string {
    let fps = config.fps;

    const params: string[] = [
      `appid=${appId}`,
      `mode=${config.width}x${config.height}x${fps}`,
      `additionalStates=1`,
      `sops=${config.sops ? 1 : 0}`,
      `resolutionScale=100`,
      `rikey=${config.riKey}`,
      `rikeyid=${config.riKeyId}`,
      `localAudioPlayMode=${config.localAudio ? 1 : 0}`,
      `surroundAudioInfo=${config.audioConfig}`,
      `remoteControllersBitmap=0`,
      `gcmap=0`,
      `gcpersist=0`,
    ];

    if (config.displayGuid && config.displayGuid.length > 0) {
      params.push(`display_name=${encodeURIComponent(config.displayGuid)}`);
      console.info(`NvHttp: 使用指定显示器: ${config.displayGuid}`);
    }

    if (config.enableHdr) {
      // hdrMode: 0=SDR, 1=HDR10(PQ), 2=HLG
      const hdrModeValue = config.hdrMode ?? 1;
      params.push(`hdrMode=${hdrModeValue}`);
      params.push("clientHdrCapVersion=0");
      params.push("clientHdrCapSupportedFlagsInUint32=0");
      params.push("clientHdrCapMetaDataId=NV_STATIC_METADATA_TYPE_1");
      params.push("clientHdrCapDisplayData=0x0x0x0x0x0x0x0x0x0x0");
    }

    const minBrightness = config.minBrightness ?? 2;
    const maxBrightness = config.maxBrightness ?? 500;
    const maxAvgBrightness = config.maxAverageBrightness ?? 200;
    params.push(`minBrightness=${minBrightness}`);
    params.push(`maxBrightness=${maxBrightness}`);
    params.push(`maxAverageBrightness=${maxAvgBrightness}`);

    if (config.screenCombinationMode !== undefined && config.screenCombinationMode !== -1) {
      params.push(`customScreenMode=${config.screenCombinationMode}`);
    }

    console.info(`NvHttp: buildLaunchQuery: ${params.join("&")}`);
    return params.join("&");
  }

  getServerCert(): string {
    return this.serverCert || "";
  }

  private parseServerInfo(xml: string): ServerInfo {
    return {
      hostname: XmlUtil.getValue(xml, "hostname") || "UNKNOWN",
      uniqueId: XmlUtil.getValue(xml, "uniqueid"),
      macAddress: XmlUtil.getValue(xml, "mac"),
      paired: XmlUtil.getValue(xml, "PairStatus") === "1",
      currentGame: XmlUtil.getIntValue(xml, "currentgame", 0),
      serverCodecModeSupport: XmlUtil.getIntValue(xml, "ServerCodecModeSupport", 0),
      gpuType: XmlUtil.getValue(xml, "gputype"),
      gfeVersion: XmlUtil.getValue(xml, "GfeVersion"),
      appVersion: XmlUtil.getValue(xml, "appversion"),
      maxLumaPixelsHEVC: XmlUtil.getIntValue(xml, "MaxLumaPixelsHEVC", 0),
      serverCapabilities: XmlUtil.getValue(xml, "ServerCapabilities"),
      httpsPort: XmlUtil.getIntValue(xml, "HttpsPort", NvHttp.DEFAULT_HTTPS_PORT),
      externalPort: XmlUtil.getIntValue(xml, "ExternalPort", NvHttp.DEFAULT_HTTP_PORT),
      localAddress: XmlUtil.getValue(xml, "LocalIP"),
      externalAddress: XmlUtil.getValue(xml, "ExternalIP"),
    };
  }

  private parseAppList(xml: string): AppEntry[] {
    const apps: AppEntry[] = [];
    const appRegex = /<App>([\s\S]*?)<\/App>/g;
    let match: RegExpExecArray | null = null;

    while ((match = appRegex.exec(xml)) !== null) {
      const appXml: string = match[1];

      const id = XmlUtil.getIntValue(appXml, "ID", 0);
      const name = XmlUtil.getValue(appXml, "AppTitle");
      const isRunningStr = XmlUtil.getValue(appXml, "IsRunning");
      const isRunning = isRunningStr === "1";
      const isHdrSupported = XmlUtil.getValue(appXml, "IsHdrSupported") === "1";

      let superCmdsStr = XmlUtil.getValue(appXml, "SuperCmds");
      let cmdList: SuperCmd[] | undefined = undefined;
      if (superCmdsStr && superCmdsStr !== "null") {
        try {
          superCmdsStr = NvHttp.decodeHtmlEntities(superCmdsStr);
          cmdList = JSON.parse(superCmdsStr) as SuperCmd[];
        } catch {}
      }

      const entry: AppEntry = {
        id: id,
        name: name,
        isRunning: isRunning,
        isHdrSupported: isHdrSupported,
        cmdList: cmdList,
      };
      apps.push(entry);
    }

    return apps;
  }

  private static decodeHtmlEntities(text: string): string {
    let result = text
      .replace(/&quot;/g, '"')
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&apos;/g, "'");

    const numericEntityRegex = /&#(\d+);/g;
    let match: RegExpExecArray | null = null;
    while ((match = numericEntityRegex.exec(text)) !== null) {
      const code = parseInt(match[1]);
      result = result.replace(match[0], String.fromCharCode(code));
    }

    return result;
  }
}

export interface AppEntry {
  id: number;
  name: string;
  isRunning: boolean;
  isHdrSupported: boolean;
  cmdList?: SuperCmd[];
}

export interface SuperCmd {
  id: string;
  name: string;
}

export interface LaunchConfig {
  appId: number;
  width: number;
  height: number;
  fps: number;
  bitrate: number;
  sops: boolean;
  localAudio: boolean;
  riKey: string;
  riKeyId: number;
  audioConfig: string;
  enableHdr?: boolean;
  hdrMode?: number; // 0=SDR, 1=HDR10(PQ), 2=HLG
  displayGuid?: string;
  minBrightness?: number;
  maxBrightness?: number;
  maxAverageBrightness?: number;
  screenCombinationMode?: number;
}
