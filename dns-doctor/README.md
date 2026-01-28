# dns-doctor

DNS 诊断与修复工具（支持 Docker DNS）

---

## 🚀 安装

在 **Ubuntu / systemd** 服务器上执行：

```bash
curl -fsSL https://raw.githubusercontent.com/xiaodaiceshi/ops-tools/main/dns-doctor/install.sh | sudo bash

## 🚀 使用

```bash
dns-doctor status        # 查看云环境、DNS 模式、主网卡
dns-doctor check         # 检查宿主机 DNS 与 Docker DNS
dns-doctor fix dns       # 修复宿主机 DNS
dns-doctor fix docker    # 修复 Docker DNS
dns-doctor fix all       # 一键修复（DN
