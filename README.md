# ops-tools

一个 **Linux 运维工具合集仓库**，用于存放可直接在服务器上使用的小型运维工具。  
所有工具遵循 **安全、克制、工程化** 的设计原则，支持通过 `curl | bash` 快速安装。

---

## 📦 工具列表

### dns-doctor

DNS 诊断与修复工具（支持 Docker DNS）

**安装：**
```bash
curl -fsSL https://raw.githubusercontent.com/xiaodaiceshi/ops-tools/main/dns-doctor/install.sh | sudo bash

使用：

dns-doctor status        # 查看云环境、DNS 模式、主网卡
dns-doctor check         # 检查宿主机 DNS 与 Docker DNS
dns-doctor fix dns       # 修复宿主机 DNS
dns-doctor fix docker    # 修复 Docker DNS
dns-doctor fix all       # 一键修复（DNS + Docker DNS）

📁 仓库结构

ops-tools/
├── README.md
└── dns-doctor/
    ├── install.sh
    └── README.md

⚠️ 使用约定

    所有工具通过各自的 install.sh 安装

    所有修改系统配置的操作必须人工触发

    执行 curl | bash 前，建议先阅读脚本内容


---

### 4️⃣ 保存文件

- `Ctrl + S`（Windows）
- `Cmd + S`（macOS）

---

### 5️⃣ 预览 README（可选）

在 VS Code 里：

- 打开 `README.md`
- 按：
  ```text
  Ctrl + Shift + V