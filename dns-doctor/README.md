# ops-tools

这是一个 Linux 运维工具合集仓库，包含多个可直接在服务器上使用的小工具。

## 工具列表

### dns-doctor
DNS 诊断与修复工具（支持 Docker DNS）

安装：
```bash
curl -fsSL https://raw.githubusercontent.com/xiaodaiceshi/ops-tools/main/dns-doctor/install.sh | sudo bash

### 使用方法
dns-doctor status        # 查看云环境、DNS 模式、主网卡
dns-doctor check         # 检查 DNS 与 Docker DNS
dns-doctor fix dns       # 修复宿主机 DNS
dns-doctor fix docker    # 修复 Docker DNS
dns-doctor fix all       # 一键修复



---

## 4️⃣ dns-doctor 专用 README.md

```bash
nano dns-doctor/README.md
