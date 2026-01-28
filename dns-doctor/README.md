# 🩺 dns-doctor

**DNS 诊断与修复工具（支持 Docker DNS）**

`dns-doctor` 用于快速定位 Linux 服务器上的 DNS 问题，并在 **人工确认** 后修复宿主机 DNS 及 Docker DNS。
适用于云服务器、Docker 主机以及 DNS 行为不确定的环境。

---

## ✨ 功能特性

* 🌐 **云环境识别（安全版）**
  * Oracle Cloud
  * AWS（仅 IMDSv2）
  * 阿里云 / 腾讯云 / 华为云
  * 不可靠环境统一标记为 `Unknown`（不误判）
* 🔍 **DNS 状态诊断**
  * 自动识别 DNS 管理方式：
    * `systemd-resolved`
    * 静态 `/etc/resolv.conf`
  * 实测公网域名解析状态
* 🐳 **Docker DNS 支持**
  * 检测容器内 DNS 是否正常
  * 修复 Docker daemon DNS 配置
* 🔐 **安全设计**
  * 所有修复操作需人工触发
  * 修复前自动备份配置
  * 不依赖 IP 段猜测云厂商
    
    ## 🚀 安装

在 **Ubuntu / systemd** 服务器上执行：

```bash
curl -fsSL https://raw.githubusercontent.com/xiaodaiceshi/ops-tools/main/dns-doctor/install.sh | sudo bash
```

安装完成后，将自动生成命令：

```bash
dns-doctor
```

> ⚠️ **安全提示**
> `curl | bash` 执行前，建议先查看脚本内容，确认无误后再运行。

---

## 🛠 使用方法

### 查看当前环境状态

```bash
dns-doctor status
```

输出示例：

```text
Cloud      : Oracle Cloud
DNS Mode   : resolved
Interface  : enp0s6
```

---

### 检查 DNS 状态

```bash
dns-doctor check
```

检查内容包括：

* 宿主机 DNS 是否可正常解析公网域名
* Docker 容器内 DNS 是否正常（如 Docker 已安装）

---

### 修复宿主机 DNS

```bash
dns-doctor fix dns
```

* 根据当前 DNS 模式自动选择修复方式
* 修改前会自动备份配置文件

---

### 修复 Docker DNS

```bash
dns-doctor fix docker
```

* 写入 Docker daemon DNS 配置
* 自动重启 Docker 服务

---

### 一键修复（推荐）

```bash
dns-doctor fix all
```

执行顺序：

1. 检查宿主机 DNS → 异常则修复
2. 检查 Docker DNS → 异常则修复

---

## 📁 配置备份说明

所有修改前的配置都会自动备份到：

```text
/var/backups/dns-doctor/
```

示例：

```text
/var/backups/dns-doctor/
├── resolv.conf.20240101-120000
├── netplan-20240101-120000/
└── docker-20240101-120000/
```

---

## ⚙️ 适用环境

* Ubuntu 18.04+
* systemd
* Docker（可选，仅在使用 Docker DNS 功能时需要）

---

## 🧠 设计原则

* **宁可返回 `Unknown`，也不误判云厂商**
* **诊断与修复逻辑明确分离**
* **install.sh ≠ 自动修复**
* **不在安装阶段修改系统配置**

---

## ❌ 不适用场景

* 非 systemd 系统
* 需要复杂分域 DNS / VPN DNS 的环境
* 大规模批量运维（建议使用 Ansible）

---

## 📌 常见使用场景

* 新服务器上线后的 DNS 环境确认
* Docker 容器无法解析域名
* 云服务器 DNS 行为异常排查
* 排查 `Temporary failure in name resolution`

---

## 📄 License

MIT License

