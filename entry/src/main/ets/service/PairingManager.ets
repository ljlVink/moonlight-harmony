/*
 * Moonlight for HarmonyOS
 * Copyright (C) 2024-2025 Moonlight/AlkaidLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import { cryptoFramework } from "@kit.CryptoArchitectureKit";
import { fileIo } from "@kit.CoreFileKit";
import { util } from "@kit.ArkTS";
import { deviceInfo } from "@kit.BasicServicesKit";
import { CryptoUtil } from "../utils/CryptoUtil";
import { common } from "@kit.AbilityKit";
import { HttpClient } from "../utils/HttpClient";
import { XmlUtil } from "../utils/XmlUtil";
import { NvHttp } from "./NvHttp";

export enum PairState {
  NOT_PAIRED = "NOT_PAIRED",
  PAIRED = "PAIRED",
  PIN_WRONG = "PIN_WRONG",
  FAILED = "FAILED",
  ALREADY_IN_PROGRESS = "ALREADY_IN_PROGRESS",
}

export interface PairResult {
  state: PairState;
  serverCert?: Uint8Array;
  pairName?: string;
}

export class PairingManager {
  private baseUrl: string;
  private address: string;
  private uniqueId: string;
  private clientName: string;
  private formattedHost: string;

  private keyPair: cryptoFramework.KeyPair | null = null;
  private clientCertDer: Uint8Array | null = null;
  private clientCertPem: Uint8Array | null = null;

  private serverCertDer: Uint8Array | null = null;

  private certFilePath: string = "";
  private keyFilePath: string = "";
  private context: common.Context | null = null;

  static readonly DEFAULT_HTTP_PORT = NvHttp.DEFAULT_HTTP_PORT;
  static readonly DEFAULT_HTTPS_PORT = NvHttp.DEFAULT_HTTPS_PORT;

  private static cachedClientName: string | null = null;

  constructor(address: string, uniqueId: string, context?: common.Context, httpPort?: number) {
    const parsedHost = this.parseAddressHost(address);
    const parsedPort = this.parseAddressPort(address);
    this.address = parsedHost;
    const port = httpPort || parsedPort || PairingManager.DEFAULT_HTTP_PORT;
    const formattedHost = this.formatAddressForUrl(this.address);
    this.formattedHost = formattedHost;
    this.baseUrl = `http://${formattedHost}:${port}`;
    this.uniqueId = uniqueId;
    this.clientName = this.getClientName();
    if (context) {
      this.context = context;
      const filesDir = context.filesDir;
      this.certFilePath = `${filesDir}/client_cert.pem`;
      this.keyFilePath = `${filesDir}/client_key.pem`;
    }
  }

  private getClientName(): string {
    if (PairingManager.cachedClientName) {
      return PairingManager.cachedClientName;
    }

    try {
      const name = deviceInfo.marketName || deviceInfo.productModel || "Moonlight-HarmonyOS";
      PairingManager.cachedClientName = name;
      return name;
    } catch (err) {
      console.warn(`PairingManager: 无法获取设备名称: ${err}`);
      PairingManager.cachedClientName = "Moonlight-HarmonyOS";
      return "Moonlight-HarmonyOS";
    }
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

  /**
   * e.g. "fe80::1" → "[fe80::1]", "192.168.1.1" → "192.168.1.1"
   */
  private formatAddressForUrl(addr: string): string {
    if (addr.includes(":") && !addr.startsWith("[")) {
      return `[${addr}]`;
    }
    return addr;
  }

  async initialize(): Promise<void> {
    if (this.keyPair) {
      return;
    }

    if (this.certFilePath && this.keyFilePath) {
      try {
        const certExists = fileIo.accessSync(this.certFilePath);
        const keyExists = fileIo.accessSync(this.keyFilePath);

        if (certExists && keyExists) {
          console.info("PairingManager: 发现已存在的证书文件，尝试加载...");

          const keyFile = await fileIo.open(this.keyFilePath, fileIo.OpenMode.READ_ONLY);
          const keyStats = await fileIo.stat(this.keyFilePath);
          const keyBuffer = new ArrayBuffer(keyStats.size);
          await fileIo.read(keyFile.fd, keyBuffer);
          await fileIo.close(keyFile);

          const keyContent = new Uint8Array(keyBuffer);
          const textDecoder = util.TextDecoder.create("utf-8");
          const keyPem = textDecoder.decodeToString(keyContent);

          const generator = cryptoFramework.createAsyKeyGenerator("RSA2048");
          const keyPairResult = await generator.convertPemKey(null, keyPem);
          this.keyPair = keyPairResult;

          const certFile = await fileIo.open(this.certFilePath, fileIo.OpenMode.READ_ONLY);
          const certStats = await fileIo.stat(this.certFilePath);
          const certBuffer = new ArrayBuffer(certStats.size);
          await fileIo.read(certFile.fd, certBuffer);
          await fileIo.close(certFile);

          this.clientCertPem = new Uint8Array(certBuffer);

          const certPemStr = textDecoder.decodeToString(this.clientCertPem);
          const certBase64 = certPemStr
            .replace("-----BEGIN CERTIFICATE-----", "")
            .replace("-----END CERTIFICATE-----", "")
            .replace(/\s/g, "");
          const textEncoder = new util.TextEncoder();
          const base64Helper = new util.Base64Helper();
          this.clientCertDer = base64Helper.decodeSync(certBase64);

          console.info(
            `PairingManager: 成功加载已存在的证书，PEM长度=${this.clientCertPem.length}, DER长度=${this.clientCertDer.length}`,
          );
          return;
        }
      } catch (err) {
        console.warn(`PairingManager: 加载已存在证书失败: ${err}, 将生成新的密钥对`);
      }
    }

    console.info("PairingManager: 生成新的 RSA 密钥对...");
    this.keyPair = await CryptoUtil.generateRsaKeyPair();
    console.info("PairingManager: RSA 密钥对生成完成");

    this.clientCertDer = await CryptoUtil.generateSelfSignedCert(this.keyPair);
    console.info(`PairingManager: 证书 DER 生成完成，长度 = ${this.clientCertDer.length}`);

    this.clientCertPem = CryptoUtil.getPemCertBytes(this.clientCertDer);
    console.info(`PairingManager: 证书 PEM 生成完成，长度 = ${this.clientCertPem.length}`);

    await this.saveCertificatesToFile();

    console.info("PairingManager: 密钥对和证书生成完成");
  }

  private async saveCertificatesToFile(): Promise<void> {
    if (!this.certFilePath || !this.keyFilePath || !this.keyPair || !this.clientCertPem) {
      console.warn("PairingManager: 无法保存证书（路径或数据不完整）");
      return;
    }

    try {
      const textDecoder = util.TextDecoder.create("utf-8");
      const certContent = textDecoder.decodeToString(this.clientCertPem);
      const certFile = await fileIo.open(
        this.certFilePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC,
      );
      await fileIo.write(certFile.fd, certContent);
      await fileIo.close(certFile);
      console.info(`PairingManager: 证书已保存到 ${this.certFilePath}`);

      const priKeyBlob = this.keyPair.priKey.getEncodedPem("PKCS8");
      const keyFile = await fileIo.open(
        this.keyFilePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC,
      );
      await fileIo.write(keyFile.fd, priKeyBlob);
      await fileIo.close(keyFile);
      console.info(`PairingManager: 私钥已保存到 ${this.keyFilePath}`);
    } catch (err) {
      console.error(`PairingManager: 保存证书失败: ${err}`);
    }
  }

  getClientCertHex(): string {
    if (!this.clientCertPem) {
      return "";
    }
    return CryptoUtil.bytesToHex(this.clientCertPem);
  }

  getClientCertSignature(): Uint8Array {
    if (!this.clientCertDer) {
      return new Uint8Array(0);
    }
    return CryptoUtil.extractCertSignature(this.clientCertDer);
  }

  getServerCert(): Uint8Array | null {
    return this.serverCertDer;
  }

  private async doRequest(
    url: string,
    timeout: number = 7000,
    useClientCert: boolean = false,
  ): Promise<string> {
    console.info(`PairingManager: 请求 ${url}`);
    console.info(
      `PairingManager: 超时设置 = ${timeout > 0 ? timeout : "无限制"}, 使用客户端证书 = ${useClientCert}`,
    );

    if (useClientCert && this.certFilePath && this.keyFilePath) {
      return HttpClient.getWithClientCert(url, this.certFilePath, this.keyFilePath, {
        connectTimeout: 30000,
        transferTimeout: timeout > 0 ? timeout : 300000,
      });
    } else {
      return HttpClient.get(url, {
        connectTimeout: 30000,
        transferTimeout: timeout > 0 ? timeout : 300000,
      });
    }
  }

  private buildPairUrl(params: string): string {
    return `${this.baseUrl}/pair?uniqueid=${this.uniqueId}&clientname=${encodeURIComponent(this.clientName)}&${params}`;
  }

  private extractServerCert(xml: string): Uint8Array | null {
    const certHex = XmlUtil.getValue(xml, "plaincert");
    if (!certHex) {
      return null;
    }

    const pemBytes = CryptoUtil.hexToBytes(certHex);

    let pemString = "";
    for (let i = 0; i < pemBytes.length; i++) {
      pemString += String.fromCharCode(pemBytes[i]);
    }

    console.info(`PairingManager: 服务器证书 PEM 前80字符 = ${pemString.substring(0, 80)}`);

    const derBytes = CryptoUtil.pemToDer(pemString);
    console.info(`PairingManager: 服务器证书 DER 长度 = ${derBytes.length}`);

    return derBytes;
  }

  private async hashData(data: Uint8Array, useSha256: boolean): Promise<Uint8Array> {
    if (useSha256) {
      return await CryptoUtil.sha256(data);
    } else {
      return await CryptoUtil.sha1(data);
    }
  }

  private getHashLength(useSha256: boolean): number {
    return useSha256 ? 32 : 20;
  }

  private serverInfoCache: string | null = null;

  private async fetchServerInfo(): Promise<string> {
    if (this.serverInfoCache) {
      return this.serverInfoCache;
    }
    const url = `${this.baseUrl}/serverinfo?uniqueid=${this.uniqueId}`;
    this.serverInfoCache = await this.doRequest(url, 10000);
    return this.serverInfoCache;
  }

  private async fetchServerMajorVersion(): Promise<number> {
    try {
      const response = await this.fetchServerInfo();
      const appVersion = XmlUtil.getValue(response, "appversion");
      if (appVersion) {
        const parts = appVersion.split(".");
        if (parts.length > 0) {
          const major = parseInt(parts[0]);
          if (!isNaN(major)) {
            console.info(`PairingManager: 检测到服务器主版本号 = ${major}`);
            return major;
          }
        }
      }
    } catch (err) {
      console.warn(`PairingManager: 获取服务器版本失败: ${err}, 使用默认值 7`);
    }
    return 7;
  }

  private async getHttpsUrl(): Promise<string> {
    try {
      const response = await this.fetchServerInfo();
      const httpsPortStr = XmlUtil.getValue(response, "HttpsPort");
      if (httpsPortStr) {
        const httpsPort = parseInt(httpsPortStr);
        if (httpsPort > 0) {
          console.info(`PairingManager: 从 serverinfo 获取 HTTPS 端口: ${httpsPort}`);
          return `https://${this.formattedHost}:${httpsPort}`;
        }
      }
    } catch (err) {
      console.warn(`PairingManager: 获取 HTTPS 端口失败: ${err}`);
    }
    const fallbackPort = PairingManager.DEFAULT_HTTPS_PORT;
    console.info(`PairingManager: 使用默认 HTTPS 端口: ${fallbackPort}`);
    return `https://${this.formattedHost}:${fallbackPort}`;
  }

  /**
   *
   */
  async pair(pin: string): Promise<PairResult> {
    await this.initialize();

    const serverMajorVersion = await this.fetchServerMajorVersion();
    const useSha256 = serverMajorVersion >= 7;
    console.info(
      `PairingManager: 服务器版本 ${serverMajorVersion}, 使用 ${useSha256 ? "SHA-256" : "SHA-1"} 哈希算法`,
    );

    try {
      console.info("PairingManager: 步骤1 - 发送 salt 和客户端证书");
      console.info(`PairingManager: PIN = ${pin}`);

      const salt = CryptoUtil.generateRandomBytes(16);
      const saltedPin = CryptoUtil.saltPin(salt, pin);
      const saltedPinHash = await this.hashData(saltedPin, useSha256);
      const aesKey = CryptoUtil.generateAesKeyFromHash(saltedPinHash);

      console.info(`PairingManager: salt = ${CryptoUtil.bytesToHex(salt)}`);
      console.info(`PairingManager: clientCert长度 = ${this.getClientCertHex().length}`);

      const step1Url = this.buildPairUrl(
        `devicename=roth&updateState=1&phrase=getservercert` +
          `&salt=${CryptoUtil.bytesToHex(salt)}&clientcert=${this.getClientCertHex()}`,
      );

      console.info("PairingManager: 等待服务器响应（用户需要在服务器上输入 PIN）...");

      const step1Response = await this.doRequest(step1Url, 300000);

      console.info(`PairingManager: 步骤1响应 = ${step1Response.substring(0, 200)}...`);

      if (XmlUtil.getValue(step1Response, "paired") !== "1") {
        console.error("PairingManager: 步骤1失败 - paired != 1");
        return { state: PairState.FAILED };
      }

      const pairName = XmlUtil.getValue(step1Response, "pairname");
      this.serverCertDer = this.extractServerCert(step1Response);

      if (!this.serverCertDer) {
        await this.unpair();
        return { state: PairState.ALREADY_IN_PROGRESS, pairName };
      }

      console.info("PairingManager: 步骤2 - 发送客户端挑战");

      const randomChallenge = CryptoUtil.generateRandomBytes(16);
      const encryptedChallenge = await CryptoUtil.aesEncrypt(randomChallenge, aesKey);

      const step2Url = this.buildPairUrl(
        `devicename=roth&updateState=1` +
          `&clientchallenge=${CryptoUtil.bytesToHex(encryptedChallenge)}`,
      );

      const step2Response = await this.doRequest(step2Url);

      if (XmlUtil.getValue(step2Response, "paired") !== "1") {
        await this.unpair();
        return { state: PairState.FAILED, pairName };
      }

      const encServerChallengeResponse = CryptoUtil.hexToBytes(
        XmlUtil.getValue(step2Response, "challengeresponse"),
      );
      const decServerChallengeResponse = await CryptoUtil.aesDecrypt(
        encServerChallengeResponse,
        aesKey,
      );

      const hashLength = this.getHashLength(useSha256);
      const serverResponse = decServerChallengeResponse.slice(0, hashLength);
      const serverChallenge = decServerChallengeResponse.slice(hashLength, hashLength + 16);

      console.info("PairingManager: 步骤3 - 发送服务器挑战响应");

      const clientSecret = CryptoUtil.generateRandomBytes(16);

      const clientCertSignature = this.getClientCertSignature();
      const challengeRespData = CryptoUtil.concatBytes(
        CryptoUtil.concatBytes(serverChallenge, clientCertSignature),
        clientSecret,
      );
      const challengeRespHash = await this.hashData(challengeRespData, useSha256);
      const challengeRespEncrypted = await CryptoUtil.aesEncrypt(challengeRespHash, aesKey);

      const step3Url = this.buildPairUrl(
        `devicename=roth&updateState=1` +
          `&serverchallengeresp=${CryptoUtil.bytesToHex(challengeRespEncrypted)}`,
      );

      const step3Response = await this.doRequest(step3Url);

      if (XmlUtil.getValue(step3Response, "paired") !== "1") {
        await this.unpair();
        return { state: PairState.FAILED, pairName };
      }

      const serverSecretResp = CryptoUtil.hexToBytes(
        XmlUtil.getValue(step3Response, "pairingsecret"),
      );
      const serverSecret = serverSecretResp.slice(0, 16);
      const serverSignature = serverSecretResp.slice(16);

      const serverSignatureValid = await CryptoUtil.verifyWithCert(
        serverSecret,
        serverSignature,
        this.serverCertDer!,
      );
      if (!serverSignatureValid) {
        console.error("PairingManager: 服务器签名验证失败，可能存在中间人攻击");
        await this.unpair();
        return { state: PairState.FAILED, pairName };
      }
      console.info("PairingManager: 服务器签名验证通过");

      const serverCertSignature = CryptoUtil.extractCertSignature(this.serverCertDer!);
      const expectedServerResponse = await this.hashData(
        CryptoUtil.concatBytes(
          CryptoUtil.concatBytes(randomChallenge, serverCertSignature),
          serverSecret,
        ),
        useSha256,
      );

      if (!this.arraysEqual(expectedServerResponse, serverResponse)) {
        await this.unpair();
        return { state: PairState.PIN_WRONG, pairName };
      }

      console.info("PairingManager: 步骤4 - 发送客户端 secret");

      console.info(`PairingManager: clientSecret 长度 = ${clientSecret.length}`);
      const clientSignature = await CryptoUtil.rsaSign(clientSecret, this.keyPair!.priKey);
      console.info(`PairingManager: clientSignature 长度 = ${clientSignature.length}`);
      const clientPairingSecret = CryptoUtil.concatBytes(clientSecret, clientSignature);
      console.info(`PairingManager: clientPairingSecret 长度 = ${clientPairingSecret.length}`);

      const step4Url = this.buildPairUrl(
        `devicename=roth&updateState=1` +
          `&clientpairingsecret=${CryptoUtil.bytesToHex(clientPairingSecret)}`,
      );

      const step4Response = await this.doRequest(step4Url);

      if (XmlUtil.getValue(step4Response, "paired") !== "1") {
        await this.unpair();
        return { state: PairState.FAILED, pairName };
      }

      console.info("PairingManager: 步骤5 - 完成配对");

      const httpsUrl = await this.getHttpsUrl();
      const step5Url =
        `${httpsUrl}/pair?` +
        `uniqueid=${this.uniqueId}&devicename=roth&updateState=1&phrase=pairchallenge`;

      const step5Response = await this.doRequest(step5Url, 7000, true);

      if (XmlUtil.getValue(step5Response, "paired") !== "1") {
        await this.unpair();
        return { state: PairState.FAILED, pairName };
      }

      console.info("PairingManager: 配对成功!");
      return {
        state: PairState.PAIRED,
        serverCert: this.serverCertDer,
        pairName,
      };
    } catch (err) {
      console.error("PairingManager: 配对失败", err);
      return { state: PairState.FAILED };
    }
  }

  async unpair(): Promise<void> {
    try {
      const url = `${this.baseUrl}/unpair?uniqueid=${this.uniqueId}`;
      await this.doRequest(url);
    } catch (err) {
      console.warn("PairingManager: 取消配对失败", err);
    }
  }

  private arraysEqual(a: Uint8Array, b: Uint8Array): boolean {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
      if (a[i] !== b[i]) return false;
    }
    return true;
  }

  static generatePin(): string {
    return CryptoUtil.generatePin();
  }
}
